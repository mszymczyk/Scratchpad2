
#define DECAL_VOLUME_CLUSTER_WORD_COUNT (DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP / 32)

//#if DECAL_VOLUME_CLUSTER_FIRST_PASS
//#if DECAL_VOLUME_CLUSTER_WORD_COUNT != 4
//#error wtf
//#endif // 
//#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

groupshared uint sharedWordVisibility[DECAL_VOLUME_CLUSTER_WORD_COUNT];
//groupshared uint sharedVisibility[DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP];
//groupshared uint sharedDecalIndex[DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP];
groupshared uint sharedVisibleCount[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedGroupOffset;


void DecalVisibilityGeneric( uint3 cellThreadID, uint flatCellIndex, uint prevPassFlatCellIndex, uint maxDecalsPerCell, uint prevPassMaxDecalsPerCell )
{
	uint cellThreadIndex = cellThreadID.x;

	if ( cellThreadIndex == 0 )
	{
		sharedGroupOffset = 0;
	}

	//if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
	//{
	//	uint iWord = cellThreadIndex;
	//	sharedWordVisibility[iWord] = 0;
	//}

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
	numWords = spadAlignU32_2( numWords, DECAL_VOLUME_CLUSTER_WORD_COUNT );
	//uint numWords = 2;
	
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
//#if DECAL_VOLUME_CLUSTER_FIRST_PASS
//			if ( cellThreadIndex < 2 )
//#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
			if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
//#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
			{
				sharedWordVisibility[cellThreadIndex] = 0;
			}

			GroupMemoryBarrierWithGroupSync();

			uint threadWordIndex = cellThreadIndex / 32;
			uint bitIndex = cellThreadIndex - threadWordIndex * 32;
			//uint bitIndex = cellThreadIndex % 32;

			// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
			uint decalIndex = iGlobalWord * 32 + cellThreadIndex;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
			uint index = iGlobalWord * 32 + cellThreadIndex;
			uint decalIndex = index < decalCount ? inDecalsPerCell[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

			//sharedDecalIndex[cellThreadIndex] = decalIndex;

			// Compare against frustum number of decals
			uint intersects = 0;
			if ( decalIndex < frustumDecalCount )
			{
				const DecalVolume dv = inDecalVolumes[decalIndex];
				intersects = /*decalIndex < frustumDecalCount &&*/ TestDecalVolumeFrustum( dv, frustum ) ? 1 : 0;
//#if DECAL_TILING_PASS_NO == 0
				//intersects = 1;
//#endif // #if DECAL_TILING_PASS_NO == 0
				if ( intersects )
				{
					uint bitValue = intersects << bitIndex;
					//uint origValue;
					InterlockedOr( sharedWordVisibility[threadWordIndex], bitValue );// , origValue );
				}
			}

			//GroupMemoryBarrierWithGroupSync();

			//uint bitValue = intersects << bitIndex;
			////uint origValue;
			//InterlockedOr( sharedWordVisibility[threadWordIndex], bitValue );//, origValue );

			//if ( intersects )
			//	sharedVisibility[cellThreadIndex] = 1;// intersects << bitIndex;
			//else
			//	sharedVisibility[cellThreadIndex] = 0;
			//sharedVisibility[cellThreadIndex] = intersects;

			//GroupMemoryBarrierWithGroupSync();

			//if ( cellThreadIndex == 0 )
			//{
			//	[unroll]
			//	for ( uint iWord = 0; iWord < DECAL_VOLUME_CLUSTER_WORD_COUNT; ++iWord )
			//	{
			//		uint word = 0;

			//		for ( uint iBit = 0; iBit < 32; ++iBit )
			//		{
			//			uint bitValue = sharedVisibility[iWord * 32 + iBit] != 0;
			//			word |= bitValue << iBit;
			//			//word |= sharedVisibility[iWord * 32 + iBit];
			//		}

			//		sharedWordVisibility[iWord] = word;
			//	}
			//}

//#if DECAL_VOLUME_CLUSTER_WORD_COUNT > 1
//			if ( cellThreadIndex < 32 )
//				sharedVisibility[cellThreadIndex] |= sharedVisibility[cellThreadIndex + 32];
//#endif // #if DECAL_VOLUME_CLUSTER_WORD_COUNT > 1
//
//			if ( cellThreadIndex < 16 )
//				sharedVisibility[cellThreadIndex] |= sharedVisibility[cellThreadIndex + 16];
//
//			if ( cellThreadIndex < 8 )
//				sharedVisibility[cellThreadIndex] |= sharedVisibility[cellThreadIndex + 8];
//
//			if ( cellThreadIndex < 4 )
//				sharedVisibility[cellThreadIndex] |= sharedVisibility[cellThreadIndex + 4];
//
//#if DECAL_VOLUME_CLUSTER_WORD_COUNT == 2
//			if ( cellThreadIndex < 2 )
//				sharedVisibility[cellThreadIndex] |= sharedVisibility[cellThreadIndex + 2];
//#endif // #if DECAL_VOLUME_CLUSTER_WORD_COUNT == 2
//
//#if DECAL_VOLUME_CLUSTER_WORD_COUNT == 1
//			if ( cellThreadIndex < 1 )
//				sharedVisibility[cellThreadIndex] |= sharedVisibility[cellThreadIndex + 1];
//#endif // #if DECAL_VOLUME_CLUSTER_WORD_COUNT == 1
//
//			GroupMemoryBarrierWithGroupSync();
//
//			if ( cellThreadIndex == 0 )
//			{
//				[unroll]
//				for ( uint iWord = 0; iWord < DECAL_VOLUME_CLUSTER_WORD_COUNT; ++iWord )
//				{
//					sharedWordVisibility[iWord] = sharedVisibility[iWord];
//				}
//			}

			GroupMemoryBarrierWithGroupSync();

			// calculate compacted index / prefix sum
//#if DECAL_VOLUME_CLUSTER_FIRST_PASS
//			if ( cellThreadIndex < 2 )
//#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
			if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
//#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
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
				//for ( uint iWord = 1; iWord < 2; ++iWord )
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
				if ( cellIndex < maxDecalsPerCell )
				{
					//outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = decalIndex;
					//outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = sharedDecalIndex[cellThreadIndex];
					outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = decalIndex;
				}
			}


			//uint word = sharedWordVisibility[threadWordIndex];
			//if ( bitIndex == 0 )
			//{
			//	for ( uint iBit = 0; iBit < 32; ++iBit )
			//	{
			//		uint threadBit = 1 << iBit;
			//		uint maskedWord = word & ( threadBit - 1 );
			//		uint localIndex = countbits( maskedWord );

			//		if ( word & threadBit )
			//		{
			//			uint cellIndex = sharedGroupOffset + wordBaseIndex + localIndex;
			//			if ( cellIndex < maxDecalsPerCell )
			//			{
			//				outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = sharedDecalIndex[threadWordIndex * 32 + iBit];
			//			}
			//		}
			//	}
			//}

//#if DECAL_VOLUME_CLUSTER_FIRST_PASS
//			if ( cellThreadIndex == DECAL_VOLUME_CLUSTER_WORD_COUNT * 32 - 1 )
//			//if ( cellThreadIndex == 127 )
//#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
//			if ( cellThreadIndex == 0 )
//#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
//			{
//				uint localIndex = 0;
//				[unroll]
//				for ( uint iWord = 0; iWord < DECAL_VOLUME_CLUSTER_WORD_COUNT; ++iWord )
//				{
//					for ( uint iBit = 0; iBit < 32; ++iBit )
//					{
//						if ( sharedWordVisibility[iWord] & (1 << iBit)  )
//						{
//							uint cellIndex = sharedGroupOffset + localIndex;
//							if ( cellIndex < maxDecalsPerCell )
//							{
//								outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = sharedDecalIndex[iWord * 32 + iBit];
//								localIndex += 1;
//							}
//						}
//					}
//				}
//			}

			//if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
			//{
			//	uint iWord = cellThreadIndex;
			//	uint wordBaseIndex;
			//	if ( iWord == 0 )
			//		wordBaseIndex = 0;
			//	else
			//		wordBaseIndex = sharedVisibleCount[iWord - 1];

			//	//uint localIndex = 0;
			//	uint word = sharedWordVisibility[iWord];

			//	for ( uint iBit = 0; iBit < 32; ++iBit )
			//	{
			//		uint threadBit = 1 << iBit;
			//		uint maskedWord = word & ( threadBit - 1 );
			//		uint localIndex = countbits( maskedWord );

			//		if ( word & threadBit )
			//		{
			//			uint cellIndex = sharedGroupOffset + wordBaseIndex + localIndex;
			//			if ( cellIndex < maxDecalsPerCell )
			//			{
			//				outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = sharedDecalIndex[iWord * 32 + iBit];
			//				//localIndex += 1;
			//			}
			//		}
			//	}
			//}

			GroupMemoryBarrierWithGroupSync();

			if ( cellThreadIndex == 0 )
			//if ( cellThreadIndex == DECAL_VOLUME_CLUSTER_WORD_COUNT * 32 - 1 )
			{
//#if DECAL_VOLUME_CLUSTER_FIRST_PASS
//				sharedGroupOffset += sharedVisibleCount[2 - 1];
//#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
				sharedGroupOffset += sharedVisibleCount[DECAL_VOLUME_CLUSTER_WORD_COUNT - 1];
//#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

				//[unroll]
				//for ( uint iWord = 0; iWord < DECAL_VOLUME_CLUSTER_WORD_COUNT; ++iWord )
				//{
				//	sharedGroupOffset += countbits( sharedWordVisibility[iWord] );
				//	//sharedWordVisibility[iWord] = 0;
				//}

			}

			GroupMemoryBarrierWithGroupSync();
		}
	}

	if ( cellThreadIndex == 0 )
	//if ( cellThreadIndex == DECAL_VOLUME_CLUSTER_WORD_COUNT * 32 - 1 )
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

			//uint cellIndirectionIndex = flatCellIndex * 4;

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
