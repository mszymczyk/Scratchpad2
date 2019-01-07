
groupshared uint offsetToFirstDecalIndex[DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS];
groupshared uint sharedVisibility;

void DecalVisibilitySubWord( uint numThreadsPerCell, bool cellValid, uint3 cellThreadID, uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint maxDecalsPerCell, uint prevPassOffsetToFirstDecalIndex, int intersectionMethod )
{
	uint threadIndex = cellThreadID.x; // warp/wave index
	uint localCellIndex = cellThreadID.x / numThreadsPerCell;
	uint cellThreadIndex = cellThreadID.x % numThreadsPerCell;

	uint sharedGroupOffset = 0;

	if ( threadIndex == 0 )
	{
		sharedVisibility = 0;
	}

	if ( cellThreadIndex == 0 )
	{
		uint nSlotsToAlloc = min( passDecalCount, maxDecalsPerCell );
		InterlockedAdd( outMemAlloc[0], nSlotsToAlloc, offsetToFirstDecalIndex[localCellIndex] );
	}

	GroupMemoryBarrierWithGroupSync();

	uint cellOffsetToFirstDecalIndex = offsetToFirstDecalIndex[localCellIndex];

#if DECAL_VOLUME_CLUSTERING_3D
	uint3 numCellsXYZ = cellCountA.xyz;
	//uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
	//uint cellZ = flatCellIndex / sliceSize;
	//uint tileIndex = flatCellIndex % sliceSize;
	//uint cellX = tileIndex % numCellsXYZ.x;
	//uint cellY = tileIndex / numCellsXYZ.x;
	uint3 cellXYZ = DecalVolume_DecodeCell( flatCellIndex );
	uint cellX = cellXYZ.x;
	uint cellY = cellXYZ.y;
	uint cellZ = cellXYZ.z;
#else // #if DECAL_VOLUME_CLUSTERING_3D
	uint3 numCellsXYZ = uint3( cellCountA.xy, 1 );
	uint cellX = flatCellIndex % numCellsXYZ.x;
	uint cellY = flatCellIndex / numCellsXYZ.x;
	uint cellZ = 0;
#endif // #if DECAL_VOLUME_CLUSTERING_3D

	uint clusterSize = DecalVolume_CellCountCurrentPass();

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	cellOffsetToFirstDecalIndex += numCellsXYZ.x * numCellsXYZ.y * numCellsXYZ.z;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

#if INTERSECTION_METHOD == 0
	Frustum frustum;
	buildFrustum( frustum, numCellsXYZ, uint3( cellX, cellY, cellZ ), tanHalfFov.zw, ViewMatrix, nearFar.x, nearFar.z );

	if ( intersectionMethod == 0 )
		frustum.twoTests = false;
	else
		frustum.twoTests = true;
#else // #if INTERSECTION_METHOD == 0
	FrustumClipSpace frustum;
	buildFrustumClip( frustum, numCellsXYZ, uint3( cellX, cellY, cellZ ), nearFar.x, nearFar.z );
#endif // #if INTERSECTION_METHOD == 0

	uint iGlobalDecalBase = 0;
	//uint passDecalCount32 = spadAlignU32_2( passDecalCount, numThreadsPerCell );
	//for ( uint iGlobalDecalBase = 0; iGlobalDecalBase < passDecalCount32; ++numThreadsPerCell )
	//do
	//{

		// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint decalIndex = cellThreadIndex < passDecalCount ? iGlobalDecalBase + cellThreadIndex : 0xffffffff;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint index = iGlobalDecalBase + cellThreadIndex;
		uint decalIndex = index < passDecalCount ? inDecalsPerCell[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

		// Compare against frustum number of decals
		uint intersects = 0;
		if ( cellValid && decalIndex < frustumDecalCount )
		{
#if INTERSECTION_METHOD == 0
			const DecalVolume dv = inDecalVolumes[decalIndex];
			intersects = TestDecalVolumeFrustum( dv, frustum );
#else // #if INTERSECTION_METHOD == 0
			const DecalVolumeTest dv = inDecalVolumesTest[decalIndex];
			intersects = TestDecalVolumeFrustumClipSpace( dv, frustum );
#endif // #else // #if INTERSECTION_METHOD == 0
			if ( intersects )
			{
				uint bitValue = intersects << threadIndex;
				InterlockedOr( sharedVisibility, bitValue );
			}
		}

		GroupMemoryBarrierWithGroupSync();

		uint firstCellIndex = localCellIndex * numThreadsPerCell;
		uint cellMask = ( 1 << numThreadsPerCell ) - 1;
		uint cellVisibility = ( sharedVisibility >> firstCellIndex ) & cellMask;
		uint cellDecalCount = countbits( cellVisibility );

		uint cellThreadBit = 1 << cellThreadIndex;
		if ( cellVisibility & cellThreadBit )
		{
			uint cellLowerBits = cellVisibility & ( cellThreadBit - 1 );
			uint localIndex = countbits( cellLowerBits );

			uint cellIndex = sharedGroupOffset + localIndex;
			if ( cellIndex < maxDecalsPerCell )
			{
				outDecalsPerCell[cellOffsetToFirstDecalIndex + cellIndex] = decalIndex;
			}
		}

		sharedGroupOffset += cellDecalCount;

		//if ( threadIndex == 0 )
		//{
		//	sharedVisibility = 0;
		//}

		//GroupMemoryBarrierWithGroupSync();

		//iGlobalDecalBase += numThreadsPerCell;
	//} while ( numThreadsPerCell == 32 && iGlobalDecalBase < passDecalCount32 );


	if ( cellThreadIndex == 0 )
	{
#if DECAL_VOLUME_CLUSTER_LAST_PASS

		//outDecalsPerCell[flatCellIndex] = DecalVolume_PackHeader( min( sharedGroupOffset, maxDecalsPerCell ), cellOffsetToFirstDecalIndex );
		uint flatCellIndex2 = DecalVolume_GetCellFlatIndex( cellXYZ, cellCountA.xyz );
		outDecalsPerCell[flatCellIndex2] = DecalVolume_PackHeader( min( sharedGroupOffset, maxDecalsPerCell ), cellOffsetToFirstDecalIndex );

#else // DECAL_VOLUME_CLUSTER_LAST_PASS

		if ( sharedGroupOffset > 0 )
		{
			CellIndirection ci;
			ci.offsetToFirstDecalIndex = cellOffsetToFirstDecalIndex;
			ci.decalCount = min( sharedGroupOffset, maxDecalsPerCell );

#if DECAL_VOLUME_CLUSTER_BUCKETS
			uint np2 = RoundUpToPowerOfTwo( min(sharedGroupOffset, 32) );
			uint cellSlot = firstbitlow( np2 );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
			uint cellSlot = 0;
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS

#if DECAL_VOLUME_CLUSTERING_3D
			// Could use append buffer
			uint cellIndirectionIndex;
			InterlockedAdd( outCellIndirectionCount[cellSlot], 8, cellIndirectionIndex );

#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION
			ci.cellIndex = flatCellIndex;
			outDecalCellIndirection[cellIndirectionIndex / 8 + cellSlot * clusterSize * 8] = ci;
#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION
			for ( uint i = 0; i < 8; ++i )
			{
				uint slice = i / 4;
				uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
				uint tile = i % 4;
				uint row = tile / 2;
				uint col = tile % 2;
				ci.cellIndex = ( cellZ * 2 + slice ) * sliceSize * 4 + ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;
				ci.cellIndex = DecalVolume_EncodeCell( uint3( cellX * 2 + col, cellY * 2 + row, cellZ * 2 + slice ) );

				outDecalCellIndirection[cellIndirectionIndex + i + cellSlot * clusterSize * 8] = ci;
			}
#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION

#else // #if DECAL_VOLUME_CLUSTERING_3D
			// Could use append buffer
			uint cellIndirectionIndex;
			InterlockedAdd( outCellIndirectionCount[cellSlot], 4, cellIndirectionIndex );

			for ( uint i = 0; i < 4; ++i )
			{
				uint row = i / 2;
				uint col = i % 2;
				ci.cellIndex = ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;

				outDecalCellIndirection[cellIndirectionIndex + i + cellSlot * clusterSize * 4] = ci;
			}
#endif // #else // #if DECAL_VOLUME_CLUSTERING_3D
		}
#endif // #else // DECAL_VOLUME_CLUSTER_LAST_PASS
	}
}


void DecalVisibilitySubWordLoop( uint numThreadsPerCell, bool cellValid, uint3 cellThreadID, uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint maxDecalsPerCell, uint prevPassOffsetToFirstDecalIndex, int intersectionMethod )
{
	uint threadIndex = cellThreadID.x; // warp/wave index
	uint localCellIndex = cellThreadID.x / numThreadsPerCell;
	uint cellThreadIndex = cellThreadID.x % numThreadsPerCell;

	uint sharedGroupOffset = 0;

	if ( threadIndex == 0 )
	{
		sharedVisibility = 0;
	}

	if ( cellThreadIndex == 0 )
	{
		uint nSlotsToAlloc = min( passDecalCount, maxDecalsPerCell );
		InterlockedAdd( outMemAlloc[0], nSlotsToAlloc, offsetToFirstDecalIndex[localCellIndex] );
	}

	GroupMemoryBarrierWithGroupSync();

	uint cellOffsetToFirstDecalIndex = offsetToFirstDecalIndex[localCellIndex];

#if DECAL_VOLUME_CLUSTERING_3D
	uint3 numCellsXYZ = cellCountA.xyz;
	//uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
	//uint cellZ = flatCellIndex / sliceSize;
	//uint tileIndex = flatCellIndex % sliceSize;
	//uint cellX = tileIndex % numCellsXYZ.x;
	//uint cellY = tileIndex / numCellsXYZ.x;
	uint3 cellXYZ = DecalVolume_DecodeCell( flatCellIndex );
	uint cellX = cellXYZ.x;
	uint cellY = cellXYZ.y;
	uint cellZ = cellXYZ.z;
#else // #if DECAL_VOLUME_CLUSTERING_3D
	uint3 numCellsXYZ = uint3( cellCountA.xy, 1 );
	uint cellX = flatCellIndex % numCellsXYZ.x;
	uint cellY = flatCellIndex / numCellsXYZ.x;
	uint cellZ = 0;
#endif // #if DECAL_VOLUME_CLUSTERING_3D

	uint clusterSize = DecalVolume_CellCountCurrentPass();

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	cellOffsetToFirstDecalIndex += numCellsXYZ.x * numCellsXYZ.y * numCellsXYZ.z;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

#if INTERSECTION_METHOD == 0
	Frustum frustum;
	buildFrustum( frustum, numCellsXYZ, uint3( cellX, cellY, cellZ ), tanHalfFov.zw, ViewMatrix, nearFar.x, nearFar.z );

	if ( intersectionMethod == 0 )
		frustum.twoTests = false;
	else
		frustum.twoTests = true;
#else // #if INTERSECTION_METHOD == 0
	FrustumClipSpace frustum;
	buildFrustumClip( frustum, numCellsXYZ, uint3( cellX, cellY, cellZ ), nearFar.x, nearFar.z );
#endif // #else // #if INTERSECTION_METHOD == 0

	uint iGlobalDecalBase = 0;
	uint passDecalCount32 = spadAlignU32_2( passDecalCount, numThreadsPerCell );
	//for ( uint iGlobalDecalBase = 0; iGlobalDecalBase < passDecalCount32; ++numThreadsPerCell )
	do
	{

		// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint decalIndex = cellThreadIndex < passDecalCount ? iGlobalDecalBase + cellThreadIndex : 0xffffffff;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint index = iGlobalDecalBase + cellThreadIndex;
		uint decalIndex = index < passDecalCount ? inDecalsPerCell[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

		// Compare against frustum number of decals
		uint intersects = 0;
		//if ( cellValid && decalIndex < frustumDecalCount )
		if ( decalIndex < frustumDecalCount )
		{
#if INTERSECTION_METHOD == 0
			const DecalVolume dv = inDecalVolumes[decalIndex];
			intersects = TestDecalVolumeFrustum( dv, frustum );
#else // #if INTERSECTION_METHOD == 0
			const DecalVolumeTest dv = inDecalVolumesTest[decalIndex];
			intersects = TestDecalVolumeFrustumClipSpace( dv, frustum );
#endif // #else // #if INTERSECTION_METHOD == 0
			if ( intersects )
			{
				uint bitValue = intersects << threadIndex;
				InterlockedOr( sharedVisibility, bitValue );
			}
		}

		GroupMemoryBarrierWithGroupSync();

		uint firstCellIndex = localCellIndex * numThreadsPerCell;
		uint cellMask = numThreadsPerCell == 32 ? 0xffffffff : ( ( 1 << numThreadsPerCell ) - 1 );
		uint cellVisibility = ( sharedVisibility >> firstCellIndex ) & cellMask;
		uint cellDecalCount = countbits( cellVisibility );

		uint cellThreadBit = 1 << cellThreadIndex;
		if ( cellVisibility & cellThreadBit )
		{
			uint cellLowerBits = cellVisibility & ( cellThreadBit - 1 );
			uint localIndex = countbits( cellLowerBits );

			uint cellIndex = sharedGroupOffset + localIndex;
			if ( cellIndex < maxDecalsPerCell )
			{
				outDecalsPerCell[cellOffsetToFirstDecalIndex + cellIndex] = decalIndex;
			}
		}

		// wait until all accesses to sharedVisibility are complete
		GroupMemoryBarrierWithGroupSync();

		sharedGroupOffset += cellDecalCount;

		if ( threadIndex == 0 )
		{
			sharedVisibility = 0;
		}

		GroupMemoryBarrierWithGroupSync();

		iGlobalDecalBase += numThreadsPerCell;
	} while ( numThreadsPerCell == 32 && iGlobalDecalBase < passDecalCount32 );


	//sharedGroupOffset = 5;

	if ( cellThreadIndex == 0 )
	{
#if DECAL_VOLUME_CLUSTER_LAST_PASS

		//outDecalsPerCell[flatCellIndex] = DecalVolume_PackHeader( min( sharedGroupOffset, maxDecalsPerCell ), cellOffsetToFirstDecalIndex );
		uint flatCellIndex2 = DecalVolume_GetCellFlatIndex( cellXYZ, cellCountA.xyz );
		outDecalsPerCell[flatCellIndex2] = DecalVolume_PackHeader( min( sharedGroupOffset, maxDecalsPerCell ), cellOffsetToFirstDecalIndex );

#else // DECAL_VOLUME_CLUSTER_LAST_PASS

		if ( sharedGroupOffset > 0 )
		{
			CellIndirection ci;
			ci.offsetToFirstDecalIndex = cellOffsetToFirstDecalIndex;
			ci.decalCount = min( sharedGroupOffset, maxDecalsPerCell );

#if DECAL_VOLUME_CLUSTER_BUCKETS
			uint np2 = RoundUpToPowerOfTwo( min( sharedGroupOffset, 32 ) );
			uint cellSlot = firstbitlow( np2 );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
			uint cellSlot = 0;
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS

#if DECAL_VOLUME_CLUSTERING_3D
			// Could use append buffer
			uint cellIndirectionIndex;
			InterlockedAdd( outCellIndirectionCount[cellSlot], 8, cellIndirectionIndex );

#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION
			ci.cellIndex = flatCellIndex;
			outDecalCellIndirection[cellIndirectionIndex / 8 + cellSlot * clusterSize * 8] = ci;
#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION
			for ( uint i = 0; i < 8; ++i )
			{
				uint slice = i / 4;
				uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
				uint tile = i % 4;
				uint row = tile / 2;
				uint col = tile % 2;
				ci.cellIndex = ( cellZ * 2 + slice ) * sliceSize * 4 + ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;
				ci.cellIndex = DecalVolume_EncodeCell( uint3( cellX * 2 + col, cellY * 2 + row, cellZ * 2 + slice ) );

				outDecalCellIndirection[cellIndirectionIndex + i + cellSlot * clusterSize * 8] = ci;
			}
#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION

#else // #if DECAL_VOLUME_CLUSTERING_3D
			// Could use append buffer
			uint cellIndirectionIndex;
			InterlockedAdd( outCellIndirectionCount[cellSlot], 4, cellIndirectionIndex );

			for ( uint i = 0; i < 4; ++i )
			{
				uint row = i / 2;
				uint col = i % 2;
				ci.cellIndex = ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;

				outDecalCellIndirection[cellIndirectionIndex + i + cellSlot * clusterSize * 4] = ci;
			}
#endif // #else // #if DECAL_VOLUME_CLUSTERING_3D
		}
#endif // #else // DECAL_VOLUME_CLUSTER_LAST_PASS
	}
}
