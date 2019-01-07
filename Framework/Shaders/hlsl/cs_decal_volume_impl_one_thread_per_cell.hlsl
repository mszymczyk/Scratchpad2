#if DECAL_VOLUME_CLUSTER_FIRST_PASS
#error Can't be used in first pass
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

void DecalVisibilityOnThreadPerCell( uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint maxDecalsPerCell, uint prevPassOffsetToFirstDecalIndex )
{
	uint nSlotsToAlloc = min( passDecalCount, maxDecalsPerCell );
	uint offsetToFirstDecalIndex;
	InterlockedAdd( outMemAlloc[0], nSlotsToAlloc, offsetToFirstDecalIndex );

	uint3 numCellsXYZ = DecalVolume_CellCountXYZ();
	uint cellCount = DecalVolume_CellCountCurrentPass();
	uint3 cellXYZ = DecalVolume_DecodeCellCoord( flatCellIndex );

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	offsetToFirstDecalIndex += cellCount;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

	Frustum frustum = DecalVolume_BuildFrustum( numCellsXYZ, cellXYZ );

	uint localIndex = 0;
	for ( uint iGlobalDecalBase = 0; iGlobalDecalBase < passDecalCount; iGlobalDecalBase += 1 )
	{
		// every thread calculates intersection with one decal
		uint index = iGlobalDecalBase;
		uint decalIndex = inDecalsPerCell[prevPassOffsetToFirstDecalIndex + index];

		uint intersects = DecalVolume_TestFrustum( frustum, decalIndex );

		if ( intersects && localIndex < maxDecalsPerCell )
		{
			outDecalsPerCell[offsetToFirstDecalIndex + localIndex] = decalIndex;
			localIndex += 1;
		}
	}

	DecalVolume_OutputCellIndirection( 0, cellXYZ, flatCellIndex, localIndex, offsetToFirstDecalIndex, numCellsXYZ );
}
