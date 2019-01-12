
#define DECAL_VOLUME_CLUSTER_LATE_DECAL_INDICES_ALLOC 1
#define USE_TWO_LEVEL_MEM_ALLOC 0

#if DECAL_VOLUME_CLUSTER_GCN

#if DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP != 64
#error this variant works only on group size 64
#endif // #if DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP != 64

groupshared uint sharedOffsetToFirstDecalIndexPerCell[DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS];

void DecalVisibilitySubGroup( uint numThreadsPerCell, uint bucket, bool cellValid, uint3 groupThreadID, uint encodedCellXYZ, uint passDecalCount, uint frustumDecalCount, uint prevPassOffsetToFirstDecalIndex )
{
	// every n threads process single cell, for instance group of 64 threads can process 2, 4, 8, 16, 32 or 64 cells

	uint threadIndex = groupThreadID.x; // warp/wave index
	uint localCellIndex = groupThreadID.x >> bucket; // cell index, e.g., every 4 threads process one cell, in this case, whole group is processing 16 cells
	uint cellThreadIndex = ModuloPowerOfTwo( groupThreadID.x, numThreadsPerCell ); // thread within 'cell'
	uint firstCellIndex = localCellIndex << bucket;

	// allocate speculatively one chunk per cell, might cause overallocation
	if ( cellValid && cellThreadIndex == 0 )
	{
		InterlockedAdd( outDecalVolumeIndicesCount[0], passDecalCount, sharedOffsetToFirstDecalIndexPerCell[localCellIndex] );
	}

	GroupMemoryBarrierWithGroupSync(); // not needed, group size is 64

	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
	float3 numCellsXYZRcp = DecalVolume_CellCountXYZRcp();
	uint cellCount = DecalVolume_CellCountCurrentPass();
	uint3 cellXYZ = DecalVolume_DecodeCellCoord( encodedCellXYZ );
	uint maxDecalIndices = DecalVolume_GetMaxOutDecalIndices();

	uint cellOffsetToFirstDecalIndex = 0;
	uint decalIndex = 0;
	uint intersects = 0;

	if ( cellValid )
	{
		cellOffsetToFirstDecalIndex = sharedOffsetToFirstDecalIndexPerCell[localCellIndex];
		//cellOffsetToFirstDecalIndex = ReadLane( offsetToFirstDecalIndexPerCell, firstCellIndex );

#if DECAL_VOLUME_CLUSTER_LAST_PASS
		cellOffsetToFirstDecalIndex += cellCount;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

		Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, numCellsXYZRcp, cellXYZ );

		uint iGlobalDecalBase = 0;

		// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		decalIndex = cellThreadIndex < passDecalCount ? iGlobalDecalBase + cellThreadIndex : 0xffffffff;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint index = iGlobalDecalBase + cellThreadIndex;
		decalIndex = index < passDecalCount ? inDecalVolumeIndices[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

		// Compare against frustum number of decals
		if ( decalIndex < frustumDecalCount )
		{
			intersects = DecalVolume_TestFrustum( frustum, decalIndex );
		}
	}

	ulong visibleMask = BallotMask( intersects > 0 );

	if ( cellValid )
	{
		//uint cellMask = numThreadsPerCell == 32 ? 0xffffffff : ( ( 1 << numThreadsPerCell ) - 1 ); // (1 << 32) - 1 is undefined when operating on uint
		ulong cellMask = (ulong)addI64( (long)shlU64( 1, numThreadsPerCell ), -1 ); // BitFieldMask
		//uint cellVisibility = ( sharedVisibility[firstCellIndex/32] >> (firstCellIndex - threadWordIndex * 32) ) & cellMask;
		//uint cellVisibility = ( visibleMask >> firstCellIndex ) & cellMask; // only cell relevant bits
		ulong cellVisibility = andU64( shrU64( visibleMask, firstCellIndex ), cellMask );

		//ulong cellThreadBit = 1 << cellThreadIndex;
		ulong cellThreadBit = shlU64( 1, cellThreadIndex );
		if ( /*cellValid && */cmpNeqU64( andU64( cellVisibility, cellThreadBit ), 0 ) )
		{
			ulong cellLowerBits = andU64( cellVisibility, (ulong)addI64( (long)cellThreadBit, -1 ) );
			uint localIndex = CountSetBits64( cellLowerBits );

			uint cellIndex = localIndex;
			uint globalIndex = cellOffsetToFirstDecalIndex + cellIndex;
			if ( globalIndex < maxDecalIndices )
			{
				outDecalVolumeIndices[cellOffsetToFirstDecalIndex + cellIndex] = decalIndex;
			}
		}

		if ( /*cellValid && */cellThreadIndex == 0 )
		{
			// One output per cell
			uint cellDecalCount = CountSetBits64( cellVisibility );
			DecalVolume_OutputCellIndirection( cellXYZ, encodedCellXYZ, cellDecalCount, cellOffsetToFirstDecalIndex, numCellsXYZ );
		}
	}
}


#else // #if DECAL_VOLUME_CLUSTER_GCN

groupshared uint sharedOffsetToFirstDecalIndexPerCell[DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS];
groupshared uint sharedVisibility[2];
groupshared uint sharedMemAlloc;
groupshared uint sharedMemAllocGlobalBase;

void DecalVisibilitySubGroup( uint numThreadsPerCell, uint bucket, bool cellValid, uint3 groupThreadID, uint encodedCellXYZ, uint passDecalCount, uint frustumDecalCount, uint prevPassOffsetToFirstDecalIndex )
{
	// every n threads process single cell, for instance group of 64 threads can process 2, 4, 8, 16, 32 or 64 cells

	uint threadIndex = groupThreadID.x; // warp/wave index
	uint localCellIndex = groupThreadID.x >> bucket; // cell index, e.g., every 4 threads process one cell, in this case, whole group is processing 16 cells
	uint cellThreadIndex = ModuloPowerOfTwo( groupThreadID.x, numThreadsPerCell ); // thread within 'cell'
	uint firstCellIndex = localCellIndex << bucket;
	uint threadWordIndex = threadIndex / 32; // selects which sharedVisibility index to write to
	uint bitIndex = threadIndex - threadWordIndex * 32;

	if ( threadIndex < 2 )
	{
		sharedVisibility[threadIndex] = 0;
	}

#if !DECAL_VOLUME_CLUSTER_LATE_DECAL_INDICES_ALLOC

#if USE_TWO_LEVEL_MEM_ALLOC
	// do multiple atomic adds to shared memory

	if ( threadIndex == 0 )
	{
		sharedMemAlloc = 0;
	}

	GroupMemoryBarrierWithGroupSync();

	// allocate speculatively one chunk per cell, might cause overallocation
	if ( cellValid && cellThreadIndex == 0 )
	{
		InterlockedAdd( sharedMemAlloc, passDecalCount, sharedOffsetToFirstDecalIndexPerCell[localCellIndex] );
	}

	GroupMemoryBarrierWithGroupSync();

	// and only one atomic add to global memory
	if ( threadIndex == 0 )
	{
		InterlockedAdd( outDecalVolumeIndicesCount[0], sharedMemAlloc, sharedMemAllocGlobalBase );
	}

#else // #if USE_TWO_LEVEL_MEM_ALLOC

	// allocate speculatively one chunk per cell, might cause overallocation
	if ( cellValid && cellThreadIndex == 0 )
	{
		InterlockedAdd( outDecalVolumeIndicesCount[0], passDecalCount, sharedOffsetToFirstDecalIndexPerCell[localCellIndex] );
	}

#endif // #else // #if USE_TWO_LEVEL_MEM_ALLOC

#endif // #if !DECAL_VOLUME_CLUSTER_LATE_DECAL_INDICES_ALLOC

	// wait for memory allocations
	GroupMemoryBarrierWithGroupSync();

	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
	float3 numCellsXYZRcp = DecalVolume_CellCountXYZRcp();
	uint cellCount = DecalVolume_CellCountCurrentPass();
	uint3 cellXYZ = DecalVolume_DecodeCellCoord( encodedCellXYZ );
	uint maxDecalIndices = DecalVolume_GetMaxOutDecalIndices();

	uint cellOffsetToFirstDecalIndex = 0;
	uint decalIndex = 0;

	if ( cellValid )
	{
//		cellOffsetToFirstDecalIndex = sharedOffsetToFirstDecalIndexPerCell[localCellIndex];
//
//#if USE_TWO_LEVEL_MEM_ALLOC
//		cellOffsetToFirstDecalIndex += sharedMemAllocGlobalBase;
//#endif // #if USE_TWO_LEVEL_MEM_ALLOC
//
//#if DECAL_VOLUME_CLUSTER_LAST_PASS
//		cellOffsetToFirstDecalIndex += cellCount;
//#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

		Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, numCellsXYZRcp, cellXYZ );

		uint iGlobalDecalBase = 0;

		// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		decalIndex = cellThreadIndex < passDecalCount ? iGlobalDecalBase + cellThreadIndex : 0xffffffff;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint index = iGlobalDecalBase + cellThreadIndex;
		decalIndex = index < passDecalCount ? inDecalVolumeIndices[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

		// Compare against frustum number of decals
		uint intersects = 0;
		if ( decalIndex < frustumDecalCount )
		{
			intersects = DecalVolume_TestFrustum( frustum, decalIndex );

			if ( intersects )
			{
				uint bitValue = intersects << bitIndex;
				InterlockedOr( sharedVisibility[threadWordIndex], bitValue );
			}
		}
	}

	// wait for all writes to sharedVisibility
	GroupMemoryBarrierWithGroupSync();

	//uint firstCellIndex = localCellIndex * numThreadsPerCell;
	uint cellMask = numThreadsPerCell == 32 ? 0xffffffff : ( ( 1 << numThreadsPerCell ) - 1 ); // (1 << 32) - 1 is undefined when operating on uint
	//uint cellVisibility = ( sharedVisibility[firstCellIndex/32] >> (firstCellIndex - threadWordIndex * 32) ) & cellMask;
	uint cellVisibility = ( sharedVisibility[threadWordIndex] >> ( firstCellIndex - threadWordIndex * 32 ) ) & cellMask; // only cell relevant bits
	uint cellDecalCount = countbits( cellVisibility );

#if DECAL_VOLUME_CLUSTER_LATE_DECAL_INDICES_ALLOC

#if USE_TWO_LEVEL_MEM_ALLOC
	// do multiple atomic adds to shared memory

	if ( threadIndex == 0 )
	{
		sharedMemAlloc = 0;
	}

	GroupMemoryBarrierWithGroupSync();

	// allocate speculatively one chunk per cell, might cause overallocation
	if ( cellValid && cellThreadIndex == 0 )
	{
		InterlockedAdd( sharedMemAlloc, cellDecalCount, sharedOffsetToFirstDecalIndexPerCell[localCellIndex] );
	}

	GroupMemoryBarrierWithGroupSync();

	// and only one atomic add to global memory
	if ( threadIndex == 0 )
	{
		InterlockedAdd( outDecalVolumeIndicesCount[0], sharedMemAlloc, sharedMemAllocGlobalBase );
	}

	// wait for memory allocation
	GroupMemoryBarrierWithGroupSync();

#else // #if USE_TWO_LEVEL_MEM_ALLOC

	// allocate speculatively one chunk per cell, might cause overallocation
	if ( cellValid && cellThreadIndex == 0 )
	{
		InterlockedAdd( outDecalVolumeIndicesCount[0], cellDecalCount, sharedOffsetToFirstDecalIndexPerCell[localCellIndex] );
	}

	// wait for memory allocation
	GroupMemoryBarrierWithGroupSync();

#endif // #else // #if USE_TWO_LEVEL_MEM_ALLOC

#endif // #if DECAL_VOLUME_CLUSTER_LATE_DECAL_INDICES_ALLOC

	if ( cellValid )
	{
		cellOffsetToFirstDecalIndex = sharedOffsetToFirstDecalIndexPerCell[localCellIndex];

#if USE_TWO_LEVEL_MEM_ALLOC
		cellOffsetToFirstDecalIndex += sharedMemAllocGlobalBase;
#endif // #if USE_TWO_LEVEL_MEM_ALLOC

#if DECAL_VOLUME_CLUSTER_LAST_PASS
		cellOffsetToFirstDecalIndex += cellCount;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

		uint cellThreadBit = 1 << cellThreadIndex;
		if ( cellValid && ( cellVisibility & cellThreadBit ) )
		{
			uint cellLowerBits = cellVisibility & ( cellThreadBit - 1 );
			uint localIndex = countbits( cellLowerBits );

			uint cellIndex = localIndex;
			uint globalIndex = cellOffsetToFirstDecalIndex + cellIndex;
			if ( globalIndex < maxDecalIndices )
			{
				outDecalVolumeIndices[cellOffsetToFirstDecalIndex + cellIndex] = decalIndex;
			}
		}

		if ( cellThreadIndex == 0 )
		{
			// One output per cell
			DecalVolume_OutputCellIndirection( cellXYZ, encodedCellXYZ, cellDecalCount, cellOffsetToFirstDecalIndex, numCellsXYZ );
		}
	}
}


//void DecalVisibilitySubWordLoop( uint numThreadsPerCell, bool cellValid, uint3 cellThreadID, uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint prevPassOffsetToFirstDecalIndex )
//{
//	uint threadIndex = cellThreadID.x; // warp/wave index
//	uint localCellIndex = cellThreadID.x / numThreadsPerCell;
//	uint cellThreadIndex = cellThreadID.x % numThreadsPerCell;
//	uint threadWordIndex = threadIndex / 32;
//	uint bitIndex = threadIndex - threadWordIndex * 32;
//
//	if ( threadIndex == 0 )
//	{
//		sharedVisibility[0] = 0;
//		sharedVisibility[1] = 0;
//	}
//
//	if ( cellThreadIndex == 0 )
//	{
//		InterlockedAdd( outDecalVolumeIndicesCount[0], passDecalCount, offsetToFirstDecalIndex[localCellIndex] );
//	}
//
//	GroupMemoryBarrierWithGroupSync();
//
//	uint cellOffsetToFirstDecalIndex = offsetToFirstDecalIndex[localCellIndex];
//
//	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
//	uint cellCount = DecalVolume_CellCountCurrentPass();
//	uint3 cellXYZ = DecalVolume_DecodeCellCoord( flatCellIndex );
//	uint maxDecalIndices = DecalVolume_GetMaxOutDecalIndices();
//
//#if DECAL_VOLUME_CLUSTER_LAST_PASS
//	cellOffsetToFirstDecalIndex += cellCount;
//#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS
//
//	Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, cellXYZ );
//
//	uint cellTotalDecalCount = 0;
//
//	uint iGlobalDecalBase = 0;
//	uint passDecalCount32 = AlignPowerOfTwo( passDecalCount, numThreadsPerCell );
//	//for ( uint iGlobalDecalBase = 0; iGlobalDecalBase < passDecalCount32; ++numThreadsPerCell )
//	do
//	{
//
//		// every thread calculates intersection with one decal
//#if DECAL_VOLUME_CLUSTER_FIRST_PASS
//		uint decalIndex = cellThreadIndex < passDecalCount ? iGlobalDecalBase + cellThreadIndex : 0xffffffff;
//#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
//		uint index = iGlobalDecalBase + cellThreadIndex;
//		uint decalIndex = index < passDecalCount ? inDecalVolumeIndices[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
//#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
//
//		// Compare against frustum number of decals
//		uint intersects = 0;
//		//if ( cellValid && decalIndex < frustumDecalCount )
//		if ( decalIndex < frustumDecalCount )
//		{
//			intersects = DecalVolume_TestFrustum( frustum, decalIndex );
//
//			if ( intersects )
//			{
//				uint bitValue = intersects << threadIndex;
//				//InterlockedOr( sharedVisibility, bitValue );
//				InterlockedOr( sharedVisibility[threadWordIndex], bitValue );
//			}
//		}
//
//		GroupMemoryBarrierWithGroupSync();
//
//		uint firstCellIndex = localCellIndex * numThreadsPerCell;
//		uint cellMask = numThreadsPerCell == 32 ? 0xffffffff : ( ( 1 << numThreadsPerCell ) - 1 );
//		//uint cellVisibility = ( sharedVisibility >> firstCellIndex ) & cellMask;
//		uint cellVisibility = ( sharedVisibility[threadWordIndex] >> ( firstCellIndex - threadWordIndex * 32 ) ) & cellMask;
//
//		uint cellThreadBit = 1 << cellThreadIndex;
//		if ( cellVisibility & cellThreadBit )
//		{
//			uint cellLowerBits = cellVisibility & ( cellThreadBit - 1 );
//			uint localIndex = countbits( cellLowerBits );
//
//			uint cellIndex = cellTotalDecalCount + localIndex;
//			uint globalIndex = cellOffsetToFirstDecalIndex + cellIndex;
//			if ( globalIndex < maxDecalIndices )
//			{
//				outDecalVolumeIndices[globalIndex] = decalIndex;
//			}
//		}
//
//		uint cellDecalCount = countbits( cellVisibility );
//		cellTotalDecalCount += cellDecalCount;
//
//		// wait until all accesses to sharedVisibility are complete
//		GroupMemoryBarrierWithGroupSync();
//
//		if ( threadIndex == 0 )
//		{
//			sharedVisibility[0] = 0;
//			sharedVisibility[1] = 0;
//		}
//
//		GroupMemoryBarrierWithGroupSync();
//
//		iGlobalDecalBase += numThreadsPerCell;
//	}
//	while ( /*numThreadsPerCell == 64 &&*/ iGlobalDecalBase < passDecalCount32 );
//
//	DecalVolume_OutputCellIndirection( cellThreadIndex, cellXYZ, flatCellIndex, cellTotalDecalCount, cellOffsetToFirstDecalIndex, numCellsXYZ );
//}

#endif // #else // #if DECAL_VOLUME_CLUSTER_GCN