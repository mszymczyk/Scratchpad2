#if DECAL_VOLUME_CLUSTER_FIRST_PASS
#error Can't be used in first pass
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS

void DecalVisibilityOnThreadPerCell( uint flatCellIndex, uint passDecalCount, uint frustumDecalCount, uint maxDecalsPerCell, uint prevPassOffsetToFirstDecalIndex, int intersectionMethod )
{
	uint nSlotsToAlloc = min( passDecalCount, maxDecalsPerCell );
	uint offsetToFirstDecalIndex;
	InterlockedAdd( outMemAlloc[0], nSlotsToAlloc, offsetToFirstDecalIndex );

#if DECAL_VOLUME_CLUSTERING_3D
	uint3 numCellsXYZ = cellCountA.xyz;
	//uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
	//uint cellZ = flatCellIndex / sliceSize;
	//uint tileIndex = flatCellIndex % sliceSize;
	//uint cellX = tileIndex % numCellsXYZ.x;
	//uint cellY = tileIndex / numCellsXYZ.x;
	uint3 cellXYZ = DecalVolume_DecodeCell( flatCellIndex );
	uint cellX = cellXYZ.x;
	uint cellY = cellXYZ.y;
	uint cellZ = cellXYZ.z;
#else // #if DECAL_VOLUME_CLUSTERING_3D
	uint3 numCellsXYZ = uint3( cellCountA.xy, 1 );
	uint cellX = flatCellIndex % numCellsXYZ.x;
	uint cellY = flatCellIndex / numCellsXYZ.x;
	uint cellZ = 0;
#endif // #if DECAL_VOLUME_CLUSTERING_3D

	uint clusterSize = DecalVolume_CellCountCurrentPass();

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	offsetToFirstDecalIndex += numCellsXYZ.x * numCellsXYZ.y * numCellsXYZ.z;
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS

#if INTERSECTION_METHOD == 0
	Frustum frustum;
	buildFrustum( frustum, numCellsXYZ, uint3( cellX, cellY, cellZ ), tanHalfFov.zw, ViewMatrix, nearFar.x, nearFar.z );

	if ( intersectionMethod == 0 )
		frustum.twoTests = false;
	else
		frustum.twoTests = true;
#else // #if INTERSECTION_METHOD == 0
	FrustumClipSpace frustum;
	buildFrustumClip( frustum, numCellsXYZ, uint3( cellX, cellY, cellZ ), nearFar.x, nearFar.z );
#endif // #else // #if INTERSECTION_METHOD == 0

	uint localIndex = 0;
	for ( uint iGlobalDecalBase = 0; iGlobalDecalBase < passDecalCount; iGlobalDecalBase += 1 )
	{
		// every thread calculates intersection with one decal
		uint index = iGlobalDecalBase;
		uint decalIndex = inDecalsPerCell[prevPassOffsetToFirstDecalIndex + index];

		// Compare against frustum number of decals
#if INTERSECTION_METHOD == 0
		const DecalVolume dv = inDecalVolumes[decalIndex];
		uint intersects = TestDecalVolumeFrustum( dv, frustum ) ? 1 : 0;
#else // #if INTERSECTION_METHOD == 0
		const DecalVolumeTest dv = inDecalVolumesTest[decalIndex];
		uint intersects = TestDecalVolumeFrustumClipSpace( dv, frustum );
#endif // #else // #if INTERSECTION_METHOD == 0
		if ( intersects && localIndex < maxDecalsPerCell )
		{
			outDecalsPerCell[offsetToFirstDecalIndex + localIndex] = decalIndex;
			localIndex += 1;
		}
	}

#if DECAL_VOLUME_CLUSTER_LAST_PASS
	
	//outDecalsPerCell[flatCellIndex] = DecalVolume_PackHeader( min( localIndex, maxDecalsPerCell ), offsetToFirstDecalIndex );
	uint flatCellIndex2 = DecalVolume_GetCellFlatIndex( cellXYZ, cellCountA.xyz );
	outDecalsPerCell[flatCellIndex2] = DecalVolume_PackHeader( min( localIndex, maxDecalsPerCell ), offsetToFirstDecalIndex );

#else // #if DECAL_VOLUME_CLUSTER_LAST_PASS

	if ( localIndex > 0 )
	{
		CellIndirection ci;
		ci.offsetToFirstDecalIndex = offsetToFirstDecalIndex;
		ci.decalCount = min( localIndex, maxDecalsPerCell );

#if DECAL_VOLUME_CLUSTER_BUCKETS
		uint np2 = RoundUpToPowerOfTwo( min( localIndex, 32 ) );
		uint cellSlot = firstbitlow( np2 );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
		uint cellSlot = 0;
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS

#if DECAL_VOLUME_CLUSTERING_3D
		// Could use append buffer
		uint cellIndirectionIndex;
		InterlockedAdd( outCellIndirectionCount[cellSlot], 8, cellIndirectionIndex );

#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION
		ci.cellIndex = flatCellIndex;
		outDecalCellIndirection[cellIndirectionIndex / 8 + cellSlot * clusterSize * 8] = ci;
#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION
		for ( uint i = 0; i < 8; ++i )
		{
			uint slice = i / 4;
			uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
			uint tile = i % 4;
			uint row = tile / 2;
			uint col = tile % 2;
			ci.cellIndex = ( cellZ * 2 + slice ) * sliceSize * 4 + ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;
			ci.cellIndex = DecalVolume_EncodeCell( uint3( cellX * 2 + col, cellY * 2 + row, cellZ * 2 + slice ) );

			outDecalCellIndirection[cellIndirectionIndex + i + cellSlot * clusterSize * 8] = ci;
		}
#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION

#else // #if DECAL_VOLUME_CLUSTERING_3D
		// Could use append buffer
		uint cellIndirectionIndex;
		InterlockedAdd( outCellIndirectionCount[cellSlot], 4, cellIndirectionIndex );

		for ( uint i = 0; i < 4; ++i )
		{
			uint row = i / 2;
			uint col = i % 2;
			ci.cellIndex = ( cellY * 2 + row ) * numCellsXYZ.x * 2 + cellX * 2 + col;

			outDecalCellIndirection[cellIndirectionIndex + i + cellSlot * clusterSize * 4] = ci;
		}
#endif // #else // #if DECAL_VOLUME_CLUSTERING_3D
	}


#endif // #else // #if DECAL_VOLUME_CLUSTER_LAST_PASS
}
