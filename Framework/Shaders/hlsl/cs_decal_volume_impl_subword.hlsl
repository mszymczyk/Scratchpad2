
groupshared uint offsetToFirstDecalIndex[DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS];
groupshared uint sharedVisibility;

void DecalVisibilitySubWord( uint numThreadsPerCell, bool cellValid, uint3 cellThreadID, uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint maxDecalsPerCell, uint prevPassOffsetToFirstDecalIndex )
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

	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
	uint cellCount = DecalVolume_CellCountCurrentPass();
	uint3 cellXYZ = DecalVolume_DecodeCellCoord( flatCellIndex );

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	cellOffsetToFirstDecalIndex += numCellsXYZ.x * numCellsXYZ.y * numCellsXYZ.z;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

	Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, cellXYZ );

	uint iGlobalDecalBase = 0;

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
		intersects = DecalVolume_TestFrustum( frustum, decalIndex );

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

	DecalVolume_OutputCellIndirection( cellThreadIndex, cellXYZ, flatCellIndex, sharedGroupOffset, cellOffsetToFirstDecalIndex, numCellsXYZ );
}


void DecalVisibilitySubWordLoop( uint numThreadsPerCell, bool cellValid, uint3 cellThreadID, uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint maxDecalsPerCell, uint prevPassOffsetToFirstDecalIndex )
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

	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
	uint cellCount = DecalVolume_CellCountCurrentPass();
	uint3 cellXYZ = DecalVolume_DecodeCellCoord( flatCellIndex );

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	cellOffsetToFirstDecalIndex += cellCount;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

	Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, cellXYZ );

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
			intersects = DecalVolume_TestFrustum( frustum, decalIndex );

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

	DecalVolume_OutputCellIndirection( cellThreadIndex, cellXYZ, flatCellIndex, sharedGroupOffset, cellOffsetToFirstDecalIndex, numCellsXYZ );
}
