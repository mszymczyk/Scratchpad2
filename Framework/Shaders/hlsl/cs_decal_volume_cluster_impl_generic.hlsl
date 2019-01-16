
#if DECAL_VOLUME_CLUSTER_GCN

#if DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP != 64
#error this variant works only on group size 64
#endif // #if DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP != 64

groupshared uint sharedOffsetToFirstDecalIndex;

void DecalVisibilityGeneric( uint3 groupThreadID, uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint prevPassOffsetToFirstDecalIndex )
{
	// every thread group processes one cell

	uint groupThreadIndex = groupThreadID.x;

	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
	float3 numCellsXYZRcp = DecalVolume_CellCountXYZRcp();
	uint cellCount = DecalVolume_CellCountCurrentPass();
	uint3 cellXYZ = DecalVolume_DecodeCellCoord( flatCellIndex );
	uint maxDecalIndices = DecalVolume_GetMaxOutDecalIndices();

	uint cellDecalCount = 0; // doesn't need to be in groupshared, all threads have the same value

	if ( groupThreadIndex == 0 )
	{
		uint nIndicesToAlloc = passDecalCount;
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		nIndicesToAlloc = DecalVolume_GetMaxOutDecalIndicesPerCell();
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		InterlockedAdd( outDecalVolumeIndicesCount[0], nIndicesToAlloc, sharedOffsetToFirstDecalIndex );

#if DECAL_VOLUME_CLUSTER_LAST_PASS
		sharedOffsetToFirstDecalIndex += cellCount;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS
	}

	//GroupMemoryBarrierWithGroupSync(); // not needed, group size is 64

	Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, numCellsXYZRcp, cellXYZ );

	// Make sure that all threads execute the loop
	// Looks like putting Ballot in a branch will confuse fxc, leading to cluster/decal flickering
	uint passDecalCountAligned = AlignPowerOfTwo( passDecalCount, DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP );
	for ( uint iGlobalDecalBase = 0; iGlobalDecalBase < passDecalCountAligned; iGlobalDecalBase += DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP )
	{
		uint iGlobalDecal = iGlobalDecalBase + groupThreadIndex;

		// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint decalIndex = iGlobalDecal;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint decalIndex = iGlobalDecal < passDecalCount ? inDecalVolumeIndices[prevPassOffsetToFirstDecalIndex + iGlobalDecal] : 0xffffffff;
#endif // #else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

		// Compare against frustum number of decals
		uint intersects = 0;
		if ( decalIndex < frustumDecalCount )
		{
			intersects = DecalVolume_TestFrustum( frustum, decalIndex );
		}

		ulong visibleMask = BallotMask( intersects );
		uint visibleCount = CountSetBits64( visibleMask );
		uint localIndex = MaskBitCnt( visibleMask );

		uint dstIndex = sharedOffsetToFirstDecalIndex + cellDecalCount + localIndex;
		if ( intersects && dstIndex < maxDecalIndices )
		{
			outDecalVolumeIndices[dstIndex] = decalIndex;
		}

		cellDecalCount += visibleCount;
	}

	if ( groupThreadIndex == 0 )
	{
		// One output per all threads
		DecalVolume_OutputCellIndirection( cellXYZ, flatCellIndex, cellDecalCount, sharedOffsetToFirstDecalIndex, numCellsXYZ );
	}
}

#else // #if DECAL_VOLUME_CLUSTER_GCN

#define DECAL_VOLUME_CLUSTER_WORD_COUNT (DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP / 32)

groupshared uint sharedWordVisibility[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedVisibleCount[DECAL_VOLUME_CLUSTER_WORD_COUNT];
groupshared uint sharedGroupOffset;
groupshared uint sharedOffsetToFirstDecalIndex;


void DecalVisibilityGeneric( uint3 groupThreadID, uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint prevPassOffsetToFirstDecalIndex )
{
	// every thread group processes one cell

	uint groupThreadIndex = groupThreadID.x;

	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
	float3 numCellsXYZRcp = DecalVolume_CellCountXYZRcp();
	uint cellCount = DecalVolume_CellCountCurrentPass();
	uint3 cellXYZ = DecalVolume_DecodeCellCoord( flatCellIndex );
	uint maxDecalIndices = DecalVolume_GetMaxOutDecalIndices();

	if ( groupThreadIndex == 0 )
	{
		sharedGroupOffset = 0;

		uint nIndicesToAlloc = passDecalCount;
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		nIndicesToAlloc = DecalVolume_GetMaxOutDecalIndicesPerCell();
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		InterlockedAdd( outDecalVolumeIndicesCount[0], nIndicesToAlloc, sharedOffsetToFirstDecalIndex );

#if DECAL_VOLUME_CLUSTER_LAST_PASS
		sharedOffsetToFirstDecalIndex += cellCount;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS
	}

	if ( groupThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
	{
		sharedWordVisibility[groupThreadIndex] = 0;
	}

	GroupMemoryBarrierWithGroupSync();

	Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, numCellsXYZRcp, cellXYZ );

	uint numWords = ( passDecalCount + 32 - 1 ) / 32;
	numWords = AlignPowerOfTwo( numWords, DECAL_VOLUME_CLUSTER_WORD_COUNT );

	for ( uint iGlobalWord = 0; iGlobalWord < numWords; iGlobalWord += DECAL_VOLUME_CLUSTER_WORD_COUNT )
	{
		uint threadWordIndex = groupThreadIndex / 32;
		uint bitIndex = groupThreadIndex - threadWordIndex * 32;

		// every thread calculates intersection with one decal
#if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint decalIndex = iGlobalWord * 32 + groupThreadIndex;
#else // #if DECAL_VOLUME_CLUSTER_FIRST_PASS
		uint index = iGlobalWord * 32 + groupThreadIndex;
		uint decalIndex = index < passDecalCount ? inDecalVolumeIndices[prevPassOffsetToFirstDecalIndex + index] : 0xffffffff;
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

		if ( groupThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
		{
			sharedVisibleCount[groupThreadIndex] = countbits( sharedWordVisibility[groupThreadIndex] );
		}

		GroupMemoryBarrierWithGroupSync();

#if DECAL_VOLUME_CLUSTER_WORD_COUNT > 1
		if ( groupThreadIndex == 0 )
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
			uint globalIndex = sharedOffsetToFirstDecalIndex + cellIndex;
			if ( globalIndex < maxDecalIndices )
			{
				outDecalVolumeIndices[globalIndex] = decalIndex;
			}
		}

		GroupMemoryBarrierWithGroupSync();

		if ( groupThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
		{
			sharedWordVisibility[groupThreadIndex] = 0;
		}

		if ( groupThreadIndex == 0 )
		{
			sharedGroupOffset += sharedVisibleCount[DECAL_VOLUME_CLUSTER_WORD_COUNT - 1];
		}

		GroupMemoryBarrierWithGroupSync();
	}

	if ( groupThreadIndex == 0 )
	{
		// One output per all threads
		DecalVolume_OutputCellIndirection( cellXYZ, flatCellIndex, sharedGroupOffset, sharedOffsetToFirstDecalIndex, numCellsXYZ );
	}
}

#endif // #else // #if DECAL_VOLUME_CLUSTER_GCN