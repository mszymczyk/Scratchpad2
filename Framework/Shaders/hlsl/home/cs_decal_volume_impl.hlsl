
#define DECAL_VOLUME_CLUSTER_WORD_COUNT (DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP / 32)

groupshared uint sharedWordVisibility[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedVisibleCount[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedGroupOffset;

void DecalVisibilityGeneric( uint3 cellThreadID, uint flatCellIndex, uint prevPassFlatCellIndex, uint maxDecalsPerCell, uint prevPassMaxDecalsPerCell )
{
//#if DECAL_VOLUME_CLUSTER_LAST_PASS
//	return;
//#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

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

	//uint flatCellIndex = DecalVolume_GetCellFlatIndex( cellID, numGridCells );
	//uint frustumDecalCount = tileAndDecalCounts.w;
	uint frustumDecalCount = decalCountInFrustum.x;

#if DECAL_VOLUME_CLUSTER_FIRST_PASS
	// nDecals passed in constant
	uint decalCount = frustumDecalCount;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
	//uint prevPassFlatCellIndex = DecalVolume_GetCellFlatIndex( cellID / 2, numGridCells / 2 );
	uint prevPassOffsetToFirstDecalIndex = prevPassFlatCellIndex * prevPassMaxDecalsPerCell;
	uint decalCount = inDecalCountPerCell[prevPassFlatCellIndex];
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

	uint numWords = ( decalCount + 32 - 1 ) / 32;
	
	uint offsetToFirstDecalIndex = flatCellIndex * maxDecalsPerCell;

	uint2 numCellsXY = cellCountA.xy;

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	offsetToFirstDecalIndex += numCellsXY.x * numCellsXY.y;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

	uint tileX = flatCellIndex % numCellsXY.x;
	uint tileY = flatCellIndex / numCellsXY.x;

	if ( tileX < numCellsXY.x && tileY < numCellsXY.y )
	{

		Frustum frustum;
		buildFrustum( frustum, uint3( numCellsXY.xy, 1 ), uint3( tileX, tileY, 0 ), tanHalfFov.zw, ViewMatrix, nearFar.x, nearFar.z );
		//buildFrustum( frustum, uint3( 1, 1, 1 ), uint3( 0, 0, 0 ), tanHalfFov.zw, ViewMatrix, nearFar.x, nearFar.z );

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
#if DECAL_TILING_PASS_NO == 3
				intersects = 1;
#endif // #if DECAL_TILING_PASS_NO == 3
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
//#if DECAL_TILING_PASS_NO == 3
//					outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = iGlobalWord * 32 + cellThreadIndex;
//#else // 
					outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = decalIndex;
//#endif // #if DECAL_TILING_PASS_NO == 3
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

	}

	if ( cellThreadIndex == 0 )
	{
#if DECAL_VOLUME_CLUSTER_LAST_PASS
		outDecalsPerCell[flatCellIndex] = DecalVolume_PackHeader( min( sharedGroupOffset, maxDecalsPerCell ), offsetToFirstDecalIndex );
#else // DECAL_VOLUME_CLUSTER_LAST_PASS
		outDecalCountPerCell[flatCellIndex] = min( sharedGroupOffset, maxDecalsPerCell );

		if ( sharedGroupOffset > 0 )
		{
			uint indirectDispatchArgOffset = 0;// tileAndDecalCounts.z;
			uint cellIndirectionIndex;
			InterlockedAdd( outCellIndirectionCount[0], 4, cellIndirectionIndex );

			CellIndirection ci;
			ci.parentCellIndex = flatCellIndex;

			for ( uint i = 0; i < 4; ++i )
			{
				uint row = i / 2;
				uint col = i % 2;
				ci.cellIndex = ( tileY * 2 + row ) * numCellsXY.x * 2 + tileX * 2 + col;

//#if DECAL_TILING_PASS_NO == 1
//				ci.parentCellIndex = tileX;
//				ci.cellIndex = tileY;
//#endif // #if DECAL_TILING_PASS_NO == 1

				outDecalCellIndirection[cellIndirectionIndex + i] = ci;
			}
		}
#endif // #else // DECAL_VOLUME_CLUSTER_LAST_PASS
	}
}
