
#define DECAL_VOLUME_CLUSTER_WORD_COUNT (DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP / 32)

groupshared uint sharedWordVisibility[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedVisibleCount[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedGroupOffset;

void DecalVisibilityGeneric( uint3 cellThreadID, uint3 cellID, uint3 numGridCells, uint maxDecalsPerCell, uint prevPassMaxDecalsPerCell )
{
	uint cellThreadIndex = cellThreadID.x;

	if ( cellThreadIndex == 0 )
	{
		sharedGroupOffset = 0;
	}

	if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
	{
		uint iWord = cellThreadIndex;
		sharedWordVisibility[iWord] = 0;
	}

	GroupMemoryBarrierWithGroupSync();

	uint flatCellIndex = DecalVolume_GetCellFlatIndex( cellID, numGridCells );

#if DECAL_VOLUME_CLUSTER_FIRST_PASS
	// nDecals passed in constant
	uint decalCount = frustumDecalCount;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
	uint prevPassFlatCellIndex = DecalVolume_GetCellFlatIndex( cellID / 2, numGridCells / 2 );
	uint prevPassOffsetToFirstDecalIndex = prevPassFlatCellIndex * prevPassMaxDecalsPerCell;
	uint decalCount = inDecalCountPerCell[prevPassFlatCellIndex];
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

	uint numWords = ( decalCount + 32 - 1 ) / 32;
	
	uint offsetToFirstDecalIndex = flatCellIndex * maxDecalsPerCell;

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	offsetToFirstDecalIndex += DECAL_VOLUME_CLUSTER_HEADER_CELLS_COUNT;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

	Frustum frustum;
	buildFrustum( frustum, numGridCells, cellID, tanHalfFov.zw, ViewMatrix, nearFar.x, nearFar.z );

	for ( uint iGlobalWord = 0; iGlobalWord < numWords; iGlobalWord += DECAL_VOLUME_CLUSTER_WORD_COUNT )
	{
		uint threadWordIndex = cellThreadIndex / 32;
		uint bitIndex = cellThreadIndex - threadWordIndex * 32;

		// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint decalIndex = iGlobalWord * 32 + cellThreadIndex;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint index = iGlobalWord * 32 + cellThreadIndex;
		uint decalIndex = index < decalCount ? inDecalsPerCell[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

		// Compare against frustum number of decals
		if ( decalIndex < frustumDecalCount )
		{
			const DecalVolume dv = inDecalVolumes[decalIndex];
			uint intersects = TestDecalVolumeFrustum( dv, frustum );
			if ( intersects )
			{
				uint bitValue = intersects << bitIndex;
				InterlockedOr( sharedWordVisibility[threadWordIndex], bitValue );
			}
		}

		GroupMemoryBarrierWithGroupSync();

		// calculate compacted index / prefix sum
		if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
		{
			sharedVisibleCount[cellThreadIndex] = countbits( sharedWordVisibility[cellThreadIndex] );
		}

		GroupMemoryBarrierWithGroupSync();

		if ( cellThreadIndex == 0 )
		{
			// Very naive way of calculating prefix sum
			for ( uint iWord = 1; iWord < DECAL_VOLUME_CLUSTER_WORD_COUNT; ++iWord )
			{
				sharedVisibleCount[iWord] += sharedVisibleCount[iWord - 1];
			}
		}

		GroupMemoryBarrierWithGroupSync();

		uint wordBaseIndex;
		if ( threadWordIndex == 0 )
			wordBaseIndex = 0;
		else
			wordBaseIndex = sharedVisibleCount[threadWordIndex - 1];

		uint word = sharedWordVisibility[threadWordIndex];
		uint threadBit = 1 << bitIndex;
		if ( word & threadBit )
		{
			uint maskedWord = word & ( threadBit - 1 );
			uint localIndex = countbits( maskedWord );

			uint cellIndex = sharedGroupOffset + wordBaseIndex + localIndex;
			if ( cellIndex < maxDecalsPerCell )
			{
				outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = decalIndex;
			}
		}

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

	if ( cellThreadIndex == 0 )
	{
#if DECAL_VOLUME_CLUSTER_LAST_PASS
		outDecalsPerCell[flatCellIndex] = DecalVolume_PackHeader( min( sharedGroupOffset, maxDecalsPerCell ), offsetToFirstDecalIndex );
#else // DECAL_VOLUME_CLUSTER_LAST_PASS
		outDecalCountPerCell[flatCellIndex] = min( sharedGroupOffset, maxDecalsPerCell );
#endif // #else // DECAL_VOLUME_CLUSTER_LAST_PASS
	}
}
