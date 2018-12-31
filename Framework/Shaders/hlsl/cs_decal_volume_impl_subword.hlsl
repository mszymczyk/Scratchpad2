
#define DECAL_VOLUME_WORD_SIZE DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL

groupshared uint offsetToFirstDecalIndex[DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP];
groupshared uint sharedVisibility;

uint RoundUpToPowerOfTwo( uint v )
{
	v--;
	v |= v >> 1;
	v |= v >> 2;
	v |= v >> 4;
	v |= v >> 8;
	v |= v >> 16;
	v++;

	return v;
}


void DecalVisibilitySubWord( uint3 cellThreadID, uint flatCellIndex, uint decalCount, uint maxDecalsPerCell, uint prevPassOffsetToFirstDecalIndex, int intersectionMethod )
{
	//uint cellThreadIndex = cellThreadID.x;
	uint threadIndex = cellThreadID.x; // warp/wave index
	uint localCellIndex = cellThreadID.x / DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL;
	uint cellThreadIndex = cellThreadID.x % DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL;

	uint frustumDecalCount = decalCountInFrustum.x;

	//#if DECAL_VOLUME_CLUSTER_FIRST_PASS
	//	// nDecals passed in constant
	//	uint decalCount = frustumDecalCount;
	//#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
	//	//uint prevPassOffsetToFirstDecalIndex = prevPassFlatCellIndex * prevPassMaxDecalsPerCell;
	//	//uint decalCount = inDecalCountPerCell[prevPassFlatCellIndex];
	//#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
	uint sharedGroupOffset = 0;

	if ( threadIndex == 0 )
	{
		sharedVisibility = 0;
	}

	if ( cellThreadIndex == 0 )
	{
		sharedGroupOffset = 0;

		uint nSlotsToAlloc = min( decalCount, maxDecalsPerCell );
		InterlockedAdd( outMemAlloc[0], nSlotsToAlloc, offsetToFirstDecalIndex[localCellIndex] );
	}

	GroupMemoryBarrierWithGroupSync();

	uint cellOffsetToFirstDecalIndex = offsetToFirstDecalIndex[localCellIndex];

	//uint numWords = ( decalCount + DECAL_VOLUME_WORD_SIZE - 1 ) / DECAL_VOLUME_WORD_SIZE;

#if DECAL_VOLUME_CLUSTERING_3D
	uint3 numCellsXYZ = cellCountA.xyz;
	uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
	uint cellZ = flatCellIndex / sliceSize;
	uint tileIndex = flatCellIndex % sliceSize;
	uint cellX = tileIndex % numCellsXYZ.x;
	uint cellY = tileIndex / numCellsXYZ.x;
#else // #if DECAL_VOLUME_CLUSTERING_3D
	uint3 numCellsXYZ = uint3( cellCountA.xy, 1 );
	uint cellX = flatCellIndex % numCellsXYZ.x;
	uint cellY = flatCellIndex / numCellsXYZ.x;
	uint cellZ = 0;
#endif // #if DECAL_VOLUME_CLUSTERING_3D

	uint clusterSize = numCellsXYZ.x * numCellsXYZ.y * numCellsXYZ.z;

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	offsetToFirstDecalIndex += numCellsXYZ.x * numCellsXYZ.y * numCellsXYZ.z;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

	Frustum frustum;
	buildFrustum( frustum, numCellsXYZ, uint3( cellX, cellY, cellZ ), tanHalfFov.zw, ViewMatrix, nearFar.x, nearFar.z );

	if ( intersectionMethod == 0 )
		frustum.twoTests = false;
	else
		frustum.twoTests = true;

	//for ( uint iGlobalWord = 0; iGlobalWord < numWords; iGlobalWord += DECAL_VOLUME_CLUSTER_WORD_COUNT )
	//for ( uint iGlobalDecalBase = 0; iGlobalDecalBase < decalCount; iGlobalDecalBase += DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL )
	uint iGlobalDecalBase = 0;
	//{
		// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint decalIndex = cellThreadIndex < decalCount ? iGlobalDecalBase + cellThreadIndex : 0xffffffff;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint index = iGlobalDecalBase + cellThreadIndex;
		uint decalIndex = index < decalCount ? inDecalsPerCell[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

		// Compare against frustum number of decals
		uint intersects = 0;
		if ( decalIndex < frustumDecalCount )
		{
			const DecalVolume dv = inDecalVolumes[decalIndex];
			intersects = TestDecalVolumeFrustum( dv, frustum );
			if ( intersects )
			{
				uint bitValue = intersects << threadIndex;
				InterlockedOr( sharedVisibility, bitValue );
			}
		}

		GroupMemoryBarrierWithGroupSync();

		uint firstCellIndex = localCellIndex * DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL;
		uint cellMask = ( 1 << DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL ) - 1;
		uint cellVisibility = sharedVisibility >> firstCellIndex;
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

		if ( threadIndex == 0 )
		{
			sharedVisibility = 0;
		}

		GroupMemoryBarrierWithGroupSync();
	//}

	if ( cellThreadIndex == 0 )
	{
#if DECAL_VOLUME_CLUSTER_LAST_PASS

		outDecalsPerCell[flatCellIndex] = DecalVolume_PackHeader( min( sharedGroupOffset, maxDecalsPerCell ), cellOffsetToFirstDecalIndex );

#else // DECAL_VOLUME_CLUSTER_LAST_PASS

		if ( sharedGroupOffset > 0 )
		{
			CellIndirection ci;
			ci.offsetToFirstDecalIndex = cellOffsetToFirstDecalIndex;
			ci.decalCount = min( sharedGroupOffset, maxDecalsPerCell );

			uint np2 = RoundUpToPowerOfTwo( sharedGroupOffset );
			uint cellSlot = firstbitlow( np2 );

#if DECAL_VOLUME_CLUSTERING_3D
			// Could use append buffer
			uint cellIndirectionIndex;
			InterlockedAdd( outCellIndirectionCount[cellSlot], 8, cellIndirectionIndex );

			for ( uint i = 0; i < 8; ++i )
			{
				uint slice = i / 4;
				uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
				uint tile = i % 4;
				uint row = tile / 2;
				uint col = tile % 2;
				ci.cellIndex = ( cellZ * 2 + slice ) * sliceSize * 4 + ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;

				outDecalCellIndirection[cellIndirectionIndex + i + cellSlot * clusterSize] = ci;
			}
#else // #if DECAL_VOLUME_CLUSTERING_3D
			// Could use append buffer
			uint cellIndirectionIndex;
			InterlockedAdd( outCellIndirectionCount[cellSlot], 4, cellIndirectionIndex );

			for ( uint i = 0; i < 4; ++i )
			{
				uint row = i / 2;
				uint col = i % 2;
				ci.cellIndex = ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;

				outDecalCellIndirection[cellIndirectionIndex + i + cellSlot * clusterSize] = ci;
			}
#endif // #else // #if DECAL_VOLUME_CLUSTERING_3D
		}
#endif // #else // DECAL_VOLUME_CLUSTER_LAST_PASS
	}
}
