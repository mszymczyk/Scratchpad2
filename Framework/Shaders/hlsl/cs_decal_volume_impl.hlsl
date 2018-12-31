#if !DECAL_VOLUME_CLUSTER_LAST_PASS

#define DECAL_VOLUME_CLUSTER_WORD_COUNT (DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP / 32)

groupshared uint sharedWordVisibility[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedVisibleCount[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedGroupOffset;
groupshared uint offsetToFirstDecalIndex;


void DecalVisibilityGeneric( uint3 cellThreadID, uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint maxDecalsPerCell, uint prevPassOffsetToFirstDecalIndex, int intersectionMethod )
{
	uint cellThreadIndex = cellThreadID.x;

	//uint frustumDecalCount = decalCountInFrustum.x;

//#if DECAL_VOLUME_CLUSTER_FIRST_PASS
//	// nDecals passed in constant
//	uint decalCount = frustumDecalCount;
//#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
//	//uint prevPassOffsetToFirstDecalIndex = prevPassFlatCellIndex * prevPassMaxDecalsPerCell;
//	//uint decalCount = inDecalCountPerCell[prevPassFlatCellIndex];
//#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

	if ( cellThreadIndex == 0 )
	{
		sharedGroupOffset = 0;

		//uint offsetToFirstDecalIndex = flatCellIndex * maxDecalsPerCell;
		uint nSlotsToAlloc = min( passDecalCount, maxDecalsPerCell );
		InterlockedAdd( outMemAlloc[0], nSlotsToAlloc, offsetToFirstDecalIndex );
	}

	if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
	{
		sharedWordVisibility[cellThreadIndex] = 0;
	}

	GroupMemoryBarrierWithGroupSync();

	uint numWords = ( passDecalCount + 32 - 1 ) / 32;
	numWords = spadAlignU32_2( numWords, DECAL_VOLUME_CLUSTER_WORD_COUNT );

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

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	offsetToFirstDecalIndex += numCellsXYZ.x * numCellsXYZ.y * numCellsXYZ.z;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

	//if ( cellX < numCellsXYZ.x && cellY < numCellsXYZ.y )
	//{
		Frustum frustum;
		buildFrustum( frustum, numCellsXYZ, uint3( cellX, cellY, cellZ ), tanHalfFov.zw, ViewMatrix, nearFar.x, nearFar.z );

		if ( intersectionMethod == 0 )
			frustum.twoTests = false;
		else
			frustum.twoTests = true;

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
				const DecalVolume dv = inDecalVolumes[decalIndex];
				intersects = TestDecalVolumeFrustum( dv, frustum ) ? 1 : 0;
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
				if ( cellIndex < maxDecalsPerCell )
				{
					outDecalsPerCell[offsetToFirstDecalIndex + cellIndex] = decalIndex;
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
	//}

	if ( cellThreadIndex == 0 )
	{
#if DECAL_VOLUME_CLUSTER_LAST_PASS

		outDecalsPerCell[flatCellIndex] = DecalVolume_PackHeader( min( sharedGroupOffset, maxDecalsPerCell ), offsetToFirstDecalIndex );

#else // DECAL_VOLUME_CLUSTER_LAST_PASS

		//outDecalCountPerCell[flatCellIndex] = min( sharedGroupOffset, maxDecalsPerCell );

		if ( sharedGroupOffset > 0 )
		{
			CellIndirection ci;
			//ci.parentCellIndex = flatCellIndex;
			ci.offsetToFirstDecalIndex = offsetToFirstDecalIndex;
			ci.decalCount = min( sharedGroupOffset, maxDecalsPerCell );

#if DECAL_VOLUME_CLUSTERING_3D
			// Could use append buffer
			uint cellIndirectionIndex;
			InterlockedAdd( outCellIndirectionCount[0], 8, cellIndirectionIndex );

			for ( uint i = 0; i < 8; ++i )
			{
				uint slice = i / 4;
				uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
				uint tile = i % 4;
				uint row = tile / 2;
				uint col = tile % 2;
				ci.cellIndex = (cellZ * 2 + slice) * sliceSize * 4 + ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;

				outDecalCellIndirection[cellIndirectionIndex + i] = ci;
			}
#else // #if DECAL_VOLUME_CLUSTERING_3D
			// Could use append buffer
			uint cellIndirectionIndex;
			InterlockedAdd( outCellIndirectionCount[0], 4, cellIndirectionIndex );

			for ( uint i = 0; i < 4; ++i )
			{
				uint row = i / 2;
				uint col = i % 2;
				ci.cellIndex = ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;

				outDecalCellIndirection[cellIndirectionIndex + i] = ci;
			}
#endif // #else // #if DECAL_VOLUME_CLUSTERING_3D
		}
#endif // #else // DECAL_VOLUME_CLUSTER_LAST_PASS
	}
}

#endif // #if !DECAL_VOLUME_CLUSTER_LAST_PASS

#if DECAL_VOLUME_CLUSTER_LAST_PASS

void DecalVisibilityOnThreadPerCell( uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint maxDecalsPerCell, uint prevPassOffsetToFirstDecalIndex, int intersectionMethod )
{
	//uint frustumDecalCount = decalCountInFrustum.x;

	//uint prevPassOffsetToFirstDecalIndex = prevPassFlatCellIndex * prevPassMaxDecalsPerCell;
	//uint decalCount = inDecalCountPerCell[prevPassFlatCellIndex];

	//uint offsetToFirstDecalIndex = flatCellIndex * maxDecalsPerCell;

	uint nSlotsToAlloc = min( passDecalCount, maxDecalsPerCell );
	uint offsetToFirstDecalIndex;
	InterlockedAdd( outMemAlloc[0], nSlotsToAlloc, offsetToFirstDecalIndex );

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

	offsetToFirstDecalIndex += numCellsXYZ.x * numCellsXYZ.y * numCellsXYZ.z;

	Frustum frustum;
	buildFrustum( frustum, numCellsXYZ, uint3( cellX, cellY, cellZ ), tanHalfFov.zw, ViewMatrix, nearFar.x, nearFar.z );

	if ( intersectionMethod == 0 )
		frustum.twoTests = false;
	else
		frustum.twoTests = true;

	uint localIndex = 0;
	for ( uint iGlobalDecalBase = 0; iGlobalDecalBase < passDecalCount; iGlobalDecalBase += 1 )
	{
		// every thread calculates intersection with one decal
		uint index = iGlobalDecalBase;
		uint decalIndex = inDecalsPerCell[prevPassOffsetToFirstDecalIndex + index];

		// Compare against frustum number of decals
		const DecalVolume dv = inDecalVolumes[decalIndex];
		uint intersects = TestDecalVolumeFrustum( dv, frustum ) ? 1 : 0;

		if ( intersects && localIndex < maxDecalsPerCell )
		{
			outDecalsPerCell[offsetToFirstDecalIndex + localIndex] = decalIndex;
			localIndex += 1;
		}
	}

	//localIndex = 0;
	outDecalsPerCell[flatCellIndex] = DecalVolume_PackHeader( min( localIndex, maxDecalsPerCell ), offsetToFirstDecalIndex );
}

#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS
