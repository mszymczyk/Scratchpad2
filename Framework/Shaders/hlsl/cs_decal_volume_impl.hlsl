
#define DECAL_VOLUME_CLUSTER_WORD_COUNT (DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP / 32)

groupshared uint sharedWordVisibility[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedVisibleCount[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedGroupOffset;
groupshared uint offsetToFirstDecalIndex;


void DecalVisibilityGeneric( uint3 cellThreadID, uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint prevPassOffsetToFirstDecalIndex )
{
	uint cellThreadIndex = cellThreadID.x;

	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
	uint cellCount = DecalVolume_CellCountCurrentPass();
	uint3 cellXYZ = DecalVolume_DecodeCellCoord( flatCellIndex );
	uint maxDecalIndices = DecalVolume_GetMaxOutDecalIndices();

	if ( cellThreadIndex == 0 )
	{
		sharedGroupOffset = 0;

		InterlockedAdd( outMemAlloc[0], passDecalCount, offsetToFirstDecalIndex );

#if DECAL_VOLUME_CLUSTER_LAST_PASS
		offsetToFirstDecalIndex += cellCount;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS
	}

	if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
	{
		sharedWordVisibility[cellThreadIndex] = 0;
	}

	GroupMemoryBarrierWithGroupSync();

	Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, cellXYZ );

	uint numWords = ( passDecalCount + 32 - 1 ) / 32;
	numWords = spadAlignU32_2( numWords, DECAL_VOLUME_CLUSTER_WORD_COUNT );

	for ( uint iGlobalWord = 0; iGlobalWord < numWords; iGlobalWord += DECAL_VOLUME_CLUSTER_WORD_COUNT )
	{
		uint threadWordIndex = cellThreadIndex / 32;
		uint bitIndex = cellThreadIndex - threadWordIndex * 32;

		// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint decalIndex = iGlobalWord * 32 + cellThreadIndex;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint index = iGlobalWord * 32 + cellThreadIndex;
		uint decalIndex = index < passDecalCount ? inDecalsPerCell[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

		// Compare against frustum number of decals
		uint intersects = 0;
		if ( decalIndex < frustumDecalCount )
		{
			intersects = DecalVolume_TestFrustum( frustum, decalIndex );

			if ( intersects )
			{
				uint bitValue = intersects << bitIndex;
				InterlockedOr( sharedWordVisibility[threadWordIndex], bitValue );
			}
		}

		GroupMemoryBarrierWithGroupSync();

		if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
		{
			sharedVisibleCount[cellThreadIndex] = countbits( sharedWordVisibility[cellThreadIndex] );
		}

		GroupMemoryBarrierWithGroupSync();

#if DECAL_VOLUME_CLUSTER_WORD_COUNT > 1
		if ( cellThreadIndex == 0 )
		{
			// Very naive way of calculating prefix sum
			[unroll]
			for ( uint iWord = 1; iWord < DECAL_VOLUME_CLUSTER_WORD_COUNT; ++iWord )
			{
				sharedVisibleCount[iWord] += sharedVisibleCount[iWord - 1];
			}
		}

		GroupMemoryBarrierWithGroupSync();
#endif // #if DECAL_VOLUME_CLUSTER_WORD_COUNT > 1

#if DECAL_VOLUME_CLUSTER_WORD_COUNT > 1
		uint wordBaseIndex;
		if ( threadWordIndex == 0 )
			wordBaseIndex = 0;
		else
			wordBaseIndex = sharedVisibleCount[threadWordIndex - 1];
#else // #if DECAL_VOLUME_CLUSTER_WORD_COUNT > 1
		uint wordBaseIndex = 0;
#endif // #if DECAL_VOLUME_CLUSTER_WORD_COUNT > 1

		uint word = sharedWordVisibility[threadWordIndex];
		uint threadBit = 1 << bitIndex;
		if ( word & threadBit )
		{
			uint maskedWord = word & ( threadBit - 1 );
			uint localIndex = countbits( maskedWord );

			uint cellIndex = sharedGroupOffset + wordBaseIndex + localIndex;
			uint globalIndex = offsetToFirstDecalIndex + cellIndex;
			if ( globalIndex < maxDecalIndices )
			{
				outDecalsPerCell[globalIndex] = decalIndex;
			}
		}

		GroupMemoryBarrierWithGroupSync();

		if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
		{
			sharedWordVisibility[cellThreadIndex] = 0;
		}

		if ( cellThreadIndex == 0 )
		{
			sharedGroupOffset += sharedVisibleCount[DECAL_VOLUME_CLUSTER_WORD_COUNT - 1];
		}

		GroupMemoryBarrierWithGroupSync();
	}

	DecalVolume_OutputCellIndirection( cellThreadIndex, cellXYZ, flatCellIndex, sharedGroupOffset, offsetToFirstDecalIndex, numCellsXYZ );
}
