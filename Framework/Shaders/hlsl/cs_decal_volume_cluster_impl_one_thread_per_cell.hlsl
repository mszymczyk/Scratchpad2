#if DECAL_VOLUME_CLUSTER_FIRST_PASS
#error Can't be used in first pass
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

void DecalVisibilityOneThreadPerCell( uint encodedCellXYZ, uint passDecalCount, uint frustumDecalCount, uint prevPassOffsetToFirstDecalIndex )
{
	// every thread processes one cell

	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
	float3 numCellsXYZRcp = DecalVolume_CellCountXYZRcp();
	uint cellCount = DecalVolume_CellCountCurrentPass();
	uint3 cellXYZ = DecalVolume_DecodeCellCoord( encodedCellXYZ );
	uint maxDecalIndices = DecalVolume_GetMaxOutDecalIndices();

	uint offsetToFirstDecalIndex;
	InterlockedAdd( outDecalVolumeIndicesCount[0], passDecalCount, offsetToFirstDecalIndex );

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	offsetToFirstDecalIndex += cellCount;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

	Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, DecalVolume_CellCountXYZ_Float(), numCellsXYZRcp, cellXYZ );

	uint localIndex = 0;
	for ( uint iGlobalDecalBase = 0; iGlobalDecalBase < passDecalCount; iGlobalDecalBase += 1 )
	{
		// every thread calculates intersection with one decal
		uint index = iGlobalDecalBase;
		uint decalIndex = inDecalVolumeIndices[prevPassOffsetToFirstDecalIndex + index];

		uint intersects = DecalVolume_TestFrustum( frustum, decalIndex );

		uint globalIndex = offsetToFirstDecalIndex + localIndex;
		if ( intersects && globalIndex < maxDecalIndices )
		{
			outDecalVolumeIndices[globalIndex] = decalIndex;
			localIndex += 1;
		}
	}

	// Every thread outputs data
	DecalVolume_OutputCellIndirection( cellXYZ, encodedCellXYZ, localIndex, offsetToFirstDecalIndex, numCellsXYZ );
}
