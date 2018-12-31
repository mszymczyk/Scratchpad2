#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	//DecalVisibility1 = {
	//	ComputeProgram = "DecalVisibility1";
	//}

	//DecalVisibility11 = {
	//	ComputeProgram = "DecalVisibility11";
	//}


	//DecalVisibility = {
	//	ComputeProgram = "DecalVisibility";
	//}

	//CountDecalsPerCell = {
	//	ComputeProgram = "CountDecalsPerCell";
	//}

	//LinkedListFromBits = {
	//	ComputeProgram = "LinkedListFromBits";
	//}
	//ListFromBits = {
	//	ComputeProgram = "ListFromBits";
	//}

	//SinglePassLinkedList = {
	//	ComputeProgram = "SinglePassLinkedList";
	//}

	//Heatmap = {
	//	VertexProgram = "HeatmapVp";
	//	FragmentProgram = "HeatmapFp";
	//}

	HeatmapTile = {
		VertexProgram = "HeatmapVp";
		FragmentProgram = "HeatmapTileFp";
	}

	DecalVolumesAccum = {
		VertexProgram = "DecalVolumesAccumVp";
		FragmentProgram = "DecalVolumesAccumFp";
	}

};
#endif // FX_PASSES
#endif // FX_HEADER

#include "PassConstants.h"
//#include "gpuClusteringConstants.h"
#include "cs_decal_volume_cshared.hlsl"

StructuredBuffer<uint> inDecalsPerCell REGISTER_T( DECAL_VOLUME_IN_DECALS_PER_CELL_BINDING );

//StructuredBuffer<DecalVolume> inDecalVolumes REGISTER_T( DECAL_VOLUME_IN_DECALS_BINDING );
//
//RWStructuredBuffer<uint> decalLinkedList REGISTER_U( DECAL_VOLUME_OUT_DECAL_LIST );
//RWStructuredBuffer<uint> decalLinkedListCounter REGISTER_U( DECAL_VOLUME_OUT_DECAL_LIST_COUNTER );
//
//StructuredBuffer<uint> inDecalLinkedList REGISTER_T( DECAL_VOLUME_IN_DECAL_LIST );
//
//RWStructuredBuffer<uint> outDecalVisibility REGISTER_U( DECAL_VOLUME_OUT_DECAL_VISIBILITY_BINDING );
//StructuredBuffer<uint> decalVisibility REGISTER_T( DECAL_VOLUME_IN_DECAL_VISIBILITY_BINDING );
//StructuredBuffer<uint> decalVisibility1 REGISTER_T( DECAL_VOLUME_IN_DECAL_VISIBILITY1_BINDING );
//
//RWStructuredBuffer<uint> outDecalCountPerCell REGISTER_U( DECAL_VOLUME_OUT_DECAL_COUNT_PER_CELL );
//StructuredBuffer<uint> decalCountPerCell REGISTER_T( DECAL_VOLUME_IN_DECAL_COUNT_PER_CELL );
//
//RWStructuredBuffer<uint> outDecalVisibilityList REGISTER_U( DECAL_VOLUME_OUT_DECAL_VISIBILITY_BINDING );
//RWStructuredBuffer<uint> outDecalVisibilityListCountPerCell REGISTER_U( DECAL_VOLUME_OUT_DECAL_VISIBILITY_COUNT_BINDING );
//
//
//struct Frustum
//{
//	// left, right, bottom, top, near, far
//	float4 planes[6];
//};
//
//
//void extractFrustumPlanes( out float4 planes[6], float4x4 vp )
//{
//	//float lengthInv;
//
//	planes[0] = vp[0] + vp[3]; // left
//	planes[1] = -vp[0] + vp[3]; // right
//	planes[2] = vp[1] + vp[3]; // bottom
//	planes[3] = -vp[1] + vp[3]; // top
//	planes[4] = vp[2] + vp[3]; // near
//	planes[5] = -vp[2] + vp[3]; // far
//
//	for ( int i = 0; i < 6; ++i )
//	{
//		float lenRcp = 1.0f / length( planes[i].xyz );
//		planes[i] *= lenRcp;
//	}
//
//	//planes[4].xyz = -planes[4].xyz;
//	//planes[5].xyz = -planes[5].xyz;
//}
//
//
//void buildFrustum( out Frustum frustum, const uint3 subdiv, uint3 cellIndex, float4x4 baseProj, float4x4 viewMatrix, float nearPlane, float farPlane )
//{
//	cellIndex.y = subdiv.y - cellIndex.y - 1;
//
//	//frustum = (Frustum)0;
//	float n = nearPlane * pow( farPlane / nearPlane, (float)cellIndex.z / subdiv.z );
//	float f = nearPlane * pow( farPlane / nearPlane, (float)(cellIndex.z + 1) / subdiv.z );
//	float a = f / ( n - f );
//	float b = n * f / ( n - f );
//
//	const float scaleX = 1.0f / subdiv.x;
//	const float scaleY = 1.0f / subdiv.y;
//
//	float tileScaleX = 1 / scaleX;
//	float tileScaleY = 1 / scaleY;
//
//	uint subFrustumX = cellIndex.x;
//	uint subFrustumY = cellIndex.y;
//
//	float tileBiasX = subFrustumX * 2 - tileScaleX + 1;
//	float tileBiasY = subFrustumY * 2 - tileScaleY + 1;
//	float4 c0 = float4( baseProj[0][0] * tileScaleX, 0, 0, 0 );
//	float4 c1 = float4( 0, baseProj[1][1] * tileScaleY, 0, 0 );
//	//float4 c2 = float4( tileBiasX, tileBiasY, baseProj[2][2], baseProj[2][3] );
//	//float4 c3 = float4( 0, 0, baseProj[3][2], 0 );
//	float4 c2 = float4( tileBiasX, tileBiasY, a, -1 );
//	float4 c3 = float4( 0, 0, b, 0 );
//	float4x4 subProj = float4x4( c0, c1, c2, c3 );
//
//	//float4x4 viewProj = mul( subProj, viewMatrix );
//	float4x4 viewProj = mul( transpose(subProj), viewMatrix );
//	//float4x4 viewProj = baseProj;// *viewMatrix;
//	//float4x4 viewProj = mul( baseProj, viewMatrix );
//
//	//extractFrustumPlanes( frustum.planes, transpose( viewProj ) );
//	extractFrustumPlanes( frustum.planes, viewProj );
//}
//
//
//// Real-Time Rendering, 3rd Edition - 16.10.1, 16.14.3 (p. 755, 777)
//// pico warning!!!! picoViewFrustum has planes pointing inwards
//// this test assumes opposite
//// to use it with picoViewFrustum one has to change test from if ( s > e ) to if ( s + e < 0 )
//uint frustumOBBIntersectSimpleOptimized( float4 frustumPlanes[6], float3 boxPosition, float3 boxHalfSize, float3 boxX, float3 boxY, float3 boxZ )
//{
//	[unroll]
//	for ( int i = 0; i < 6; ++i )
//	{
//		float3 n = frustumPlanes[i].xyz;
//		float e = boxHalfSize.x*abs( dot( n, boxX ) )
//			    + boxHalfSize.y*abs( dot( n, boxY ) )
//			    + boxHalfSize.z*abs( dot( n, boxZ ) );
//		float s = dot( boxPosition, n ) + frustumPlanes[i].w;
//		//if ( s > e )
//		if ( s + e < 0 )
//			return 0;
//	}
//	return 1;
//}
//
//
//uint TestDecalVolumeFrustum( in DecalVolume dv, in Frustum frustum )
//{
//	return frustumOBBIntersectSimpleOptimized( frustum.planes, dv.position.xyz, dv.halfSize.xyz, dv.x.xyz, dv.y.xyz, dv.z.xyz );
//	//return 1;
//}
//
//
//uint PackListNode( uint decalIndex, uint nextNodeIndex )
//{
//	return ( decalIndex & 0xfff ) | ( nextNodeIndex << 12 );
//}
//
//
//void UnpackListNode( uint packedListNode, out uint decalIndex, out uint nextNodeIndex )
//{
//	decalIndex = packedListNode & 0xfff;
//	nextNodeIndex = packedListNode >> 12;
//}
//
//uint PackHeader( uint decalCount, uint offsetToFirstDecalIndex )
//{
//	return ( decalCount & 0xfff ) | ( (offsetToFirstDecalIndex / 4) << 12 );
//}
//
//
//void UnpackHeader( uint packedHeader, out uint decalCount, out uint offsetToFirstDecalIndex )
//{
//	decalCount = packedHeader & 0xfff;
//	offsetToFirstDecalIndex = packedHeader >> 12;
//	offsetToFirstDecalIndex *= 4;
//}
//
////[numthreads( 64, 1, 1 )]
////void Cluster0( uint3 dtid : SV_DispatchThreadID, uint3 subFrustum : SV_GroupID )
////{
////	Frustum frustum = (Frustum)0;
////
////	if ( dtid.x < nDecals )
////	{
////		//const uint subdivX = 2;
////		//const uint subdivY = 2;
////		//const float scaleX = 1.0f / subdivX;
////		//const float scaleY = 1.0f / subdivY;
////
////		//float tileScaleX = 1 / scaleX;
////		//float tileScaleY = 1 / scaleY;
////
////		uint subFrustumIndex = subFrustum.y;
////		//uint subFrustumX = subFrustumIndex / 2;
////		//uint subFrustumY = subFrustumIndex % 2;
////
////		//float tileBiasX = subFrustumX * 2 - tileScaleX + 1;
////		//float tileBiasY = subFrustumY * 2 - tileScaleY + 1;
////		//float4 c0 = float4( BaseProj[0][0] * tileScaleX, 0, 0, 0 );
////		//float4 c1 = float4( 0, BaseProj[1][1] * tileScaleY, 0, 0 );
////		//float4 c2 = float4( tileBiasX, tileBiasY, BaseProj[2][2], BaseProj[2][3] );
////		//float4 c3 = float4( 0, 0, BaseProj[3][2], 0 );
////		//float4x4 subProj = float4x4( c0, c1, c2, c3 );
////
////		//float4x4 viewProj = subProj * ViewMatrix;
////
////		//float4 frustumPlanes[6];
////		//extractFrustumPlanes( frustumPlanes, transpose( viewProj ) );
////		buildFrustum( frustum, uint3( 2, 2, 1 ), uint3( subFrustum.y / 2, subFrustum.y % 2, 1 ), BaseProjMatrix, ViewMatrix, nearFar.x, nearFar.y );
////
////		DecalVolume dv = inDecalVolumes[dtid.x];
////
////		uint intersects = frustumOBBIntersectSimpleOptimized( frustum.planes, dv.position.xyz, dv.halfSize.xyz, dv.x.xyz, dv.y.xyz, dv.z.xyz );
////		
////		uint outIndex = nDecals64 * subFrustumIndex;
////		outVisibility[outIndex] = intersects;
////	}
////}
//
//// cellID index of a cluster cell
//// cellThread - thread within cell
//
////groupshared uint decalVisible[NUM_THREADS_PER_CELL];
////groupshared uint decalVisibleSum[NUM_THREADS_PER_CELL];
//
//#define DECAL_VOLUME_VISIBILITY1_WORD_COUNT	( NUM_THREADS_PER_CELL_VISIBILITY1 / 32 )
//#define DECAL_WORD_PADDING	1
//groupshared uint decalWordsVisibility1[DECAL_VOLUME_VISIBILITY1_WORD_COUNT * DECAL_WORD_PADDING];
//
//
//#define DECAL_VOLUME_CLUSTER_WORD_COUNT	( NUM_THREADS_PER_CELL_VISIBILITY / 32 )
//#define DECAL_WORD_PADDING	1
//groupshared uint decalWordsVisibility[DECAL_VOLUME_CLUSTER_WORD_COUNT * DECAL_WORD_PADDING];
//
//
//uint GetClusterFlatIndex( uint3 cellID )
//{
//	return ( cellID.z * DECAL_VOLUME_CLUSTER_CELLS_X * DECAL_VOLUME_CLUSTER_CELLS_Y + cellID.y * DECAL_VOLUME_CLUSTER_CELLS_X + cellID.x );
//}
//
//uint GetClusterFlatIndex1( uint3 cellID )
//{
//	return ( cellID.z * DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_X_1 * DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_Y_1 + cellID.y * DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_X_1 + cellID.x );
//}
//
//
//[numthreads( NUM_THREADS_PER_CELL_VISIBILITY1, 1, 1 )]
//void DecalVisibility1( uint3 cellThreadID : SV_GroupThreadID, uint3 cellIDOrig : SV_GroupID )
//{
//	uint cellThreadIndex = cellThreadID.x;
//
//	if ( cellThreadIndex < DECAL_VOLUME_VISIBILITY1_WORD_COUNT )
//	{
//		uint iWord = cellThreadIndex;
//		decalWordsVisibility1[iWord * DECAL_WORD_PADDING] = 0;
//	}
//
//	GroupMemoryBarrierWithGroupSync();
//
//	const uint nDecalsInFrustum = nDecals;
//	const uint numWords = nDecalWords;
//	const uint numWordsPerIter = NUM_THREADS_PER_CELL_VISIBILITY1 / 32;
//	const uint3 cellID = cellIDOrig;
//
//	Frustum frustum;
//	buildFrustum( frustum, uint3( DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_X_1, DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_Y_1, DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_Z_1 ), cellID, BaseProjMatrix, ViewMatrix, nearFar.x, nearFar.y );
//
//	for ( uint iGlobalWord = 0; iGlobalWord < numWords; iGlobalWord += numWordsPerIter )
//	{
//		uint threadWordIndex = cellThreadIndex / 32;
//		uint globalWordIndex = iGlobalWord + threadWordIndex;
//
//		uint decalIndex = globalWordIndex * 32 + cellThreadIndex;
//		const DecalVolume dv = inDecalVolumes[decalIndex];
//		uint intersects = ( decalIndex < nDecalsInFrustum ) && TestDecalVolumeFrustum( dv, frustum );
//		if ( intersects )
//		{
//			uint bitIndex = cellThreadIndex - threadWordIndex * 32;
//			uint bitValue = intersects << bitIndex;
//			InterlockedOr( decalWordsVisibility1[threadWordIndex * DECAL_WORD_PADDING], bitValue );
//		}
//
//		GroupMemoryBarrierWithGroupSync();
//
//		if ( cellThreadIndex < DECAL_VOLUME_VISIBILITY1_WORD_COUNT )
//		{
//			uint flatCellIndex = GetClusterFlatIndex1( cellID ) * numWords;
//			uint iWord = cellThreadIndex;
//			outDecalVisibility[flatCellIndex + iGlobalWord + iWord] = decalWordsVisibility1[iWord];
//			//outDecalVisibility[flatCellIndex + iGlobalWord + iWord] = 1;
//			decalWordsVisibility1[iWord * DECAL_WORD_PADDING] = 0;
//		}
//
//		GroupMemoryBarrierWithGroupSync();
//	}
//}
//
//
////groupshared uint decalVisible1[NUM_THREADS_PER_CELL_VISIBILITY1];
//groupshared uint sharedGroupOffset;
//groupshared uint decalVisibleCount1[DECAL_VOLUME_VISIBILITY1_WORD_COUNT];
//
//[numthreads( NUM_THREADS_PER_CELL_VISIBILITY1, 1, 1 )]
//void DecalVisibility11( uint3 cellThreadID : SV_GroupThreadID, uint3 cellIDOrig : SV_GroupID )
//{
//	uint cellThreadIndex = cellThreadID.x;
//
//	if ( cellThreadIndex == 0 )
//	{
//		sharedGroupOffset = 0;
//	}
//
//	if ( cellThreadIndex < DECAL_VOLUME_VISIBILITY1_WORD_COUNT )
//	{
//		uint iWord = cellThreadIndex;
//		decalWordsVisibility1[iWord * DECAL_WORD_PADDING] = 0;
//	}
//
//	GroupMemoryBarrierWithGroupSync();
//
//	const uint nDecalsInFrustum = nDecals;
//	const uint numWords = nDecalWords;
//	const uint numWordsPerIter = NUM_THREADS_PER_CELL_VISIBILITY1 / 32;
//	const uint3 cellID = cellIDOrig;
//
//	uint flatCellIndex = GetClusterFlatIndex1( cellID );
//	const uint maxDecalsPerCell = 128;
//	uint baseGlobalOffset = flatCellIndex * maxDecalsPerCell;
//
//	Frustum frustum;
//	buildFrustum( frustum, uint3( DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_X_1, DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_Y_1, DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_Z_1 ), cellID, BaseProjMatrix, ViewMatrix, nearFar.x, nearFar.y );
//
//	for ( uint iGlobalWord = 0; iGlobalWord < numWords; iGlobalWord += numWordsPerIter )
//	{
//		uint threadWordIndex = cellThreadIndex / 32;
//		//uint globalWordIndex = iGlobalWord + threadWordIndex;
//
//		// every thread calculates intersection with one decal
//		uint decalIndex = iGlobalWord * 32 + cellThreadIndex;
//		const DecalVolume dv = inDecalVolumes[decalIndex];
//		uint intersects = ( decalIndex < nDecalsInFrustum ) && TestDecalVolumeFrustum( dv, frustum );
//		uint bitIndex = cellThreadIndex - threadWordIndex * 32;
//		if ( intersects )
//		{
//			uint bitValue = intersects << bitIndex;
//			InterlockedOr( decalWordsVisibility1[threadWordIndex * DECAL_WORD_PADDING], bitValue );
//		}
//
//		GroupMemoryBarrierWithGroupSync();
//
//		// calculate compacted index / prefix sum
//		decalVisibleCount1[threadWordIndex] = countbits( decalWordsVisibility1[threadWordIndex] );
//		//if ( threadWordIndex > 0 )
//		//{
//		//	decalVisibleCount1[threadWordIndex] += decalVisibleCount1[0];
//		//}
//
//		GroupMemoryBarrierWithGroupSync();
//
//		uint wordBaseIndex;
//		if ( threadWordIndex == 0 )
//			wordBaseIndex = 0;
//		else
//			wordBaseIndex = decalVisibleCount1[threadWordIndex-1];
//
//		uint word = decalWordsVisibility1[threadWordIndex];
//		uint threadBit = 1 << bitIndex;
//		if ( word & threadBit )
//		{
//			uint maskedWord = word & ( threadBit - 1 );
//			uint localIndex = countbits( maskedWord );
//
//			uint cellIndex = sharedGroupOffset + wordBaseIndex + localIndex;
//			if ( cellIndex < maxDecalsPerCell )
//			{
//				outDecalVisibilityList[baseGlobalOffset + cellIndex] = iGlobalWord * 32 + cellThreadIndex;
//				//outDecalVisibilityList[baseGlobalOffset + cellThreadIndex] = globalWordIndex * 32 + cellThreadIndex;
//			}
//		}
//
//		if ( cellThreadIndex == 0 )
//		{
//			uint nDecalsThisIter = 0;
//			for ( uint iWord = 0; iWord < numWordsPerIter; ++iWord )
//			{
//				nDecalsThisIter += decalVisibleCount1[iWord];
//				decalWordsVisibility1[iWord] = 0;
//			}
//
//			sharedGroupOffset += nDecalsThisIter;
//		}
//
//		GroupMemoryBarrierWithGroupSync();
//	}
//
//	if ( cellThreadIndex == 0 )
//	{
//		outDecalVisibilityListCountPerCell[flatCellIndex] = min( sharedGroupOffset, maxDecalsPerCell );
//	}
//}
//
////
////void DecalVisibilityGeneric( uint3 cellThreadID, uint3 cellID, const uint wordCount, inout uint sharedWordVisibility[], inout uint sharedVisibleCount[]
////	, RWStructuredBuffer<uint> outDecalVisibilityList, RWStructuredBuffer<uint> outDecalVisibilityListCountPerCell )
////{
////	uint cellThreadIndex = cellThreadID.x;
////
////	if ( cellThreadIndex == 0 )
////	{
////		sharedGroupOffset = 0;
////	}
////
////	if ( cellThreadIndex < wordCount )
////	{
////		uint iWord = cellThreadIndex;
////		sharedWordVisibility[iWord * DECAL_WORD_PADDING] = 0;
////	}
////
////	GroupMemoryBarrierWithGroupSync();
////
////	const uint nDecalsInFrustum = nDecals;
////	const uint numWords = nDecalWords;
////	const uint numWordsPerIter = NUM_THREADS_PER_CELL_VISIBILITY1 / 32;
////
////	uint flatCellIndex = GetClusterFlatIndex1( cellID );
////	const uint maxDecalsPerCell = 128;
////	uint baseGlobalOffset = flatCellIndex * maxDecalsPerCell;
////
////	Frustum frustum;
////	buildFrustum( frustum, uint3( DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_X_1, DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_Y_1, DECAL_VOLUME_FRUSTUM_GRID_NUM_CELLS_Z_1 ), cellID, BaseProjMatrix, ViewMatrix, nearFar.x, nearFar.y );
////
////	for ( uint iGlobalWord = 0; iGlobalWord < numWords; iGlobalWord += numWordsPerIter )
////	{
////		uint threadWordIndex = cellThreadIndex / 32;
////		//uint globalWordIndex = iGlobalWord + threadWordIndex;
////
////		// every thread calculates intersection with one decal
////		uint decalIndex = iGlobalWord * 32 + cellThreadIndex;
////		const DecalVolume dv = inDecalVolumes[decalIndex];
////		uint intersects = ( decalIndex < nDecalsInFrustum ) && TestDecalVolumeFrustum( dv, frustum );
////		uint bitIndex = cellThreadIndex - threadWordIndex * 32;
////		if ( intersects )
////		{
////			uint bitValue = intersects << bitIndex;
////			InterlockedOr( sharedWordVisibility[threadWordIndex * DECAL_WORD_PADDING], bitValue );
////		}
////
////		GroupMemoryBarrierWithGroupSync();
////
////		// calculate compacted index / prefix sum
////		sharedVisibleCount[threadWordIndex] = countbits( sharedWordVisibility[threadWordIndex] );
////		//if ( threadWordIndex > 0 )
////		//{
////		//	decalVisibleCount1[threadWordIndex] += decalVisibleCount1[0];
////		//}
////
////		GroupMemoryBarrierWithGroupSync();
////
////		uint wordBaseIndex;
////		if ( threadWordIndex == 0 )
////			wordBaseIndex = 0;
////		else
////			wordBaseIndex = decalVisibleCount1[threadWordIndex - 1];
////
////		uint word = sharedWordVisibility[threadWordIndex];
////		uint threadBit = 1 << bitIndex;
////		if ( word & threadBit )
////		{
////			uint maskedWord = word & ( threadBit - 1 );
////			uint localIndex = countbits( maskedWord );
////
////			uint cellIndex = sharedGroupOffset + wordBaseIndex + localIndex;
////			if ( cellIndex < maxDecalsPerCell )
////			{
////				outDecalVisibilityList[baseGlobalOffset + cellIndex] = iGlobalWord * 32 + cellThreadIndex;
////				//outDecalVisibilityList[baseGlobalOffset + cellThreadIndex] = globalWordIndex * 32 + cellThreadIndex;
////			}
////		}
////
////		if ( cellThreadIndex == 0 )
////		{
////			uint nDecalsThisIter = 0;
////			for ( uint iWord = 0; iWord < numWordsPerIter; ++iWord )
////			{
////				nDecalsThisIter += sharedVisibleCount[iWord];
////				sharedWordVisibility[iWord] = 0;
////			}
////
////			sharedGroupOffset += nDecalsThisIter;
////		}
////
////		GroupMemoryBarrierWithGroupSync();
////	}
////
////	if ( cellThreadIndex == 0 )
////	{
////		outDecalVisibilityListCountPerCell[flatCellIndex] = min( sharedGroupOffset, maxDecalsPerCell );
////	}
////}
//
//
////[numthreads( NUM_THREADS_PER_CELL, 1, 1 )]
////void DecalVisibility( uint3 cellThreadID : SV_GroupThreadID, uint3 cellIDOrig : SV_GroupID )
////{
////	uint cellThreadIndex = cellThreadID.x;
////
////	//if ( cellThreadIndex == 0 )
////	//{
////	//	for ( uint iWord = 0; iWord < DECAL_WORD_COUNT; ++iWord )
////	//	{
////	//		decalWords[iWord] = 0;
////	//	}
////	//}
////	if ( cellThreadIndex < DECAL_WORD_COUNT )
////	{
////		uint iWord = cellThreadIndex;
////		decalWords[iWord] = 0;
////	}
////
////	GroupMemoryBarrierWithGroupSync();
////
////	const uint nDecalsInFrustum = nDecals;
////	uint decalGroupIndex = cellIDOrig.x % nDecalGroups;
////	uint decalIndex = decalGroupIndex * NUM_THREADS_PER_CELL + cellThreadIndex;
////
////	uint3 cellID;
////	cellID.x = cellIDOrig.x / nDecalGroups;
////	cellID.y = cellIDOrig.y;
////	cellID.z = cellIDOrig.z;
////
////	Frustum frustum;
////	buildFrustum( frustum, uint3( DECAL_VOLUME_CLUSTER_CELLS_X, DECAL_VOLUME_CLUSTER_CELLS_Y, DECAL_VOLUME_CLUSTER_CELLS_Z ), cellID, BaseProjMatrix, ViewMatrix, nearFar.x, nearFar.y );
////
////	const DecalVolume dv = inDecalVolumes[decalIndex];
////	uint intersects = ( decalIndex < nDecalsInFrustum ) && TestDecalVolumeFrustum( dv, frustum );
////	//uint intersects = decalIndex < nDecalsInFrustum;
////	//uint intersects = TestDecalVolumeFrustum( dv, frustum );
////
////	uint wordIndex = cellThreadIndex / 32;
////	uint bitIndex = cellThreadIndex - wordIndex * 32;
////	uint bitValue = intersects << bitIndex;
////	InterlockedOr( decalWords[wordIndex], bitValue );
////
////	GroupMemoryBarrierWithGroupSync();
////
////	//if ( cellThreadIndex == 0 )
////	//{
////	//	uint flatCellIndex = GetClusterFlatIndex( cellID ) * nDecalGroups * DECAL_WORD_COUNT;
////	//	uint groupOffset = decalGroupIndex * DECAL_WORD_COUNT;
////
////	//	for ( uint iWord = 0; iWord < DECAL_WORD_COUNT; ++iWord )
////	//	{
////	//		outDecalVisibility[flatCellIndex + groupOffset + iWord] = decalWords[iWord];
////	//		//outDecalVisibility[flatCellIndex + groupOffset + iWord] = 0;
////	//	}
////	//}
////
////	if ( cellThreadIndex < DECAL_WORD_COUNT )
////	{
////		uint flatCellIndex = GetClusterFlatIndex( cellID ) * nDecalGroups * DECAL_WORD_COUNT;
////		uint groupOffset = decalGroupIndex * DECAL_WORD_COUNT;
////
////		uint iWord = cellThreadIndex;
////		outDecalVisibility[flatCellIndex + groupOffset + iWord] = decalWords[iWord];
////		//outDecalVisibility[flatCellIndex + groupOffset + iWord] = 1;
////	}
////}
//
//
////[numthreads( NUM_THREADS_PER_CELL_VISIBILITY, 1, 1 )]
////void DecalVisibility( uint3 cellThreadID : SV_GroupThreadID, uint3 cellIDOrig : SV_GroupID )
////{
////	uint cellThreadIndex = cellThreadID.x;
////
////	//if ( cellThreadIndex == 0 )
////	//{
////	//	for ( uint iWord = 0; iWord < DECAL_WORD_COUNT; ++iWord )
////	//	{
////	//		decalWords[iWord] = 0;
////	//	}
////	//}
////	if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
////	{
////		uint iWord = cellThreadIndex;
////		decalWordsVisibility[iWord] = 0;
////	}
////
////	//decalVisible[cellThreadIndex] = 0;
////
////	GroupMemoryBarrierWithGroupSync();
////
////	const uint nDecalsInFrustum = nDecals;
////	uint decalGroupIndex = cellIDOrig.x % nDecalGroups;
////	uint decalIndex = decalGroupIndex * NUM_THREADS_PER_CELL_VISIBILITY + cellThreadIndex;
////	const uint numWords = nDecalWords;
////	const uint threadWordIndex = cellThreadIndex / 32;
////
////	uint3 cellID;
////	cellID.x = cellIDOrig.x / nDecalGroups;
////	cellID.y = cellIDOrig.y;
////	cellID.z = cellIDOrig.z;
////
////	const uint3 cellID1 = cellID / DECAL_VOLUME_FRUSTUM_GRID_SCALE_1;
////	uint flatCellIndex1 = GetClusterFlatIndex1( cellID1 ) * numWords;
////
////	uint word1 = decalVisibility1[flatCellIndex1 + decalGroupIndex * DECAL_VOLUME_CLUSTER_WORD_COUNT + threadWordIndex];
////
////	if ( word1 != 0 )
////	{
////		Frustum frustum;
////		buildFrustum( frustum, uint3( DECAL_VOLUME_CLUSTER_CELLS_X, DECAL_VOLUME_CLUSTER_CELLS_Y, DECAL_VOLUME_CLUSTER_CELLS_Z ), cellID, BaseProjMatrix, ViewMatrix, nearFar.x, nearFar.y );
////
////		const DecalVolume dv = inDecalVolumes[decalIndex];
////		uint intersects = ( decalIndex < nDecalsInFrustum ) && TestDecalVolumeFrustum( dv, frustum );
////		//uint intersects = decalIndex < nDecalsInFrustum;
////		//uint intersects = TestDecalVolumeFrustum( dv, frustum );
////
////		uint wordIndex = cellThreadIndex / 32;
////		uint bitIndex = cellThreadIndex - wordIndex * 32;
////		uint bitValue = intersects << bitIndex;
////		InterlockedOr( decalWordsVisibility[wordIndex], bitValue );
////		//decalWordsVisibility[wordIndex] |= bitValue;
////		//decalVisible[cellThreadIndex] = bitValue;
////	}
////
////	GroupMemoryBarrierWithGroupSync();
////
////
////
////	//if ( cellThreadIndex == 0 )
////	//{
////	//	uint flatCellIndex = GetClusterFlatIndex( cellID ) * nDecalGroups * DECAL_WORD_COUNT;
////	//	uint groupOffset = decalGroupIndex * DECAL_WORD_COUNT;
////
////	//	for ( uint iWord = 0; iWord < DECAL_WORD_COUNT; ++iWord )
////	//	{
////	//		outDecalVisibility[flatCellIndex + groupOffset + iWord] = decalWords[iWord];
////	//		//outDecalVisibility[flatCellIndex + groupOffset + iWord] = 0;
////	//	}
////	//}
////
////	if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT && decalWordsVisibility[cellThreadIndex] )
////	{
////		uint flatCellIndex = GetClusterFlatIndex( cellID ) * numWords;
////		//uint groupOffset = decalGroupIndex * DECAL_WORD_COUNT;
////
////		uint iWord = cellThreadIndex;
////		outDecalVisibility[flatCellIndex + decalGroupIndex * DECAL_VOLUME_CLUSTER_WORD_COUNT + iWord] = decalWordsVisibility[iWord];
////		//outDecalVisibility[flatCellIndex + decalGroupIndex * DECAL_VOLUME_CLUSTER_WORD_COUNT + iWord] = 1;
////	}
////
//////#if NUM_THREADS_PER_CELL > 32
//////	if ( cellThreadIndex < 32 )
//////		decalVisible[cellThreadIndex] |= decalVisible[cellThreadIndex + 32];
//////#endif // #if NUM_THREADS_PER_CELL_DECAL_COUNT > 32
//////
//////	if ( cellThreadIndex < 16 )
//////		decalVisible[cellThreadIndex] |= decalVisible[cellThreadIndex + 16];
//////
//////	if ( cellThreadIndex < 8 )
//////		decalVisible[cellThreadIndex] |= decalVisible[cellThreadIndex + 8];
//////
//////	if ( cellThreadIndex < 4 )
//////		decalVisible[cellThreadIndex] |= decalVisible[cellThreadIndex + 4];
//////
//////	if ( cellThreadIndex < 2 )
//////		decalVisible[cellThreadIndex] |= decalVisible[cellThreadIndex + 2];
//////
//////	if ( cellThreadIndex < 1 )
//////	{
//////		decalVisible[cellThreadIndex] |= decalVisible[cellThreadIndex + 1];
//////		
//////		uint flatCellIndex = GetClusterFlatIndex( cellID ) * numWords;
//////		uint iWord = cellThreadIndex;
//////		outDecalVisibility[flatCellIndex + decalGroupIndex * DECAL_WORD_COUNT + iWord] = decalVisible[0];
//////	}
////}
//
//
//[numthreads( NUM_THREADS_PER_CELL_VISIBILITY, 1, 1 )]
//void DecalVisibility( uint3 cellThreadID : SV_GroupThreadID, uint3 cellIDOrig : SV_GroupID )
//{
//	uint cellThreadIndex = cellThreadID.x;
//
//	if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT )
//	{
//		uint iWord = cellThreadIndex;
//		decalWordsVisibility[iWord * DECAL_WORD_PADDING] = 0;
//	}
//
//	GroupMemoryBarrierWithGroupSync();
//
//	const uint nDecalsInFrustum = nDecals;
//	const uint numWords = nDecalWords;
//	const uint numWordsPerIter = NUM_THREADS_PER_CELL_VISIBILITY / 32;
//	const uint3 cellID = cellIDOrig;
//	uint flatCellIndex = GetClusterFlatIndex( cellID ) * numWords;
//
//	Frustum frustum;
//	buildFrustum( frustum, uint3( DECAL_VOLUME_CLUSTER_CELLS_X, DECAL_VOLUME_CLUSTER_CELLS_Y, DECAL_VOLUME_CLUSTER_CELLS_Z ), cellID, BaseProjMatrix, ViewMatrix, nearFar.x, nearFar.y );
//
//	const uint3 cellID1 = cellID / DECAL_VOLUME_FRUSTUM_GRID_SCALE_1;
//	uint flatCellIndex1 = GetClusterFlatIndex1( cellID1 ) * numWords;
//
//	for ( uint iGlobalWord = 0; iGlobalWord < numWords; iGlobalWord += numWordsPerIter )
//	{
//		uint threadWordIndex = cellThreadIndex / 32;
//		uint globalWordIndex = iGlobalWord + threadWordIndex;
//
//		uint word1 = decalVisibility1[flatCellIndex1 + iGlobalWord + threadWordIndex];
//		if ( word1 != 0 )
//		{
//			uint decalIndex = globalWordIndex * 32 + cellThreadIndex;
//			const DecalVolume dv = inDecalVolumes[decalIndex];
//			uint intersects = ( decalIndex < nDecalsInFrustum ) && TestDecalVolumeFrustum( dv, frustum );
//			if ( intersects )
//			{
//				uint bitIndex = cellThreadIndex - threadWordIndex * 32;
//				uint bitValue = intersects << bitIndex;
//				InterlockedOr( decalWordsVisibility[threadWordIndex * DECAL_WORD_PADDING], bitValue );
//			}
//		}
//
//		GroupMemoryBarrierWithGroupSync();
//
//		if ( cellThreadIndex < DECAL_VOLUME_CLUSTER_WORD_COUNT && decalWordsVisibility[cellThreadIndex] )
//		{
//			uint iWord = cellThreadIndex;
//			outDecalVisibility[flatCellIndex + iGlobalWord + iWord] = decalWordsVisibility[iWord];
//			//outDecalVisibility[flatCellIndex + iGlobalWord + iWord] = 1;
//			decalWordsVisibility[iWord * DECAL_WORD_PADDING] = 0;
//		}
//
//		GroupMemoryBarrierWithGroupSync();
//	}
//}
//
//
//groupshared uint decalCellCount[NUM_THREADS_PER_CELL_DECAL_COUNT];
//
//[numthreads( NUM_THREADS_PER_CELL_DECAL_COUNT, 1, 1 )]
//void CountDecalsPerCell( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
//{
//	uint cellThreadIndex = cellThreadID.x;
//	uint numWords = nDecalWords;
//	uint flatCellIndex = GetClusterFlatIndex( cellID );
//	uint firstCellWord = flatCellIndex * numWords;
//
//	uint nWordsPerThread = (numWords + NUM_THREADS_PER_CELL_DECAL_COUNT - 1) / NUM_THREADS_PER_CELL_DECAL_COUNT;
//	uint firstWordIndex = cellThreadIndex * nWordsPerThread;
//
//	uint nDecalsVisible = 0;
//	for ( uint iWord = firstWordIndex; iWord < firstWordIndex + nWordsPerThread; ++iWord )
//	{
//		uint word = decalVisibility[firstCellWord + iWord];
//		nDecalsVisible += countbits( word );
//	}
//
//	decalCellCount[cellThreadIndex] = nDecalsVisible;
//
//	GroupMemoryBarrierWithGroupSync();
//
//#if NUM_THREADS_PER_CELL_DECAL_COUNT > 32
//	if ( cellThreadIndex < 32 )
//		decalCellCount[cellThreadIndex] += decalCellCount[cellThreadIndex + 32];
//#endif // #if NUM_THREADS_PER_CELL_DECAL_COUNT > 32
//
//	if ( cellThreadIndex < 16 )
//		decalCellCount[cellThreadIndex] += decalCellCount[cellThreadIndex + 16];
//
//	if ( cellThreadIndex < 8 )
//		decalCellCount[cellThreadIndex] += decalCellCount[cellThreadIndex + 8];
//
//	if ( cellThreadIndex < 4 )
//		decalCellCount[cellThreadIndex] += decalCellCount[cellThreadIndex + 4];
//
//	if ( cellThreadIndex < 2 )
//		decalCellCount[cellThreadIndex] += decalCellCount[cellThreadIndex + 2];
//
//	if ( cellThreadIndex < 1 )
//	{
//		decalCellCount[cellThreadIndex] += decalCellCount[cellThreadIndex + 1];
//		outDecalCountPerCell[flatCellIndex] = min( decalCellCount[0], DECAL_VOLUME_MAX_DECALS_PER_CELL );
//	}
//}
//
//groupshared uint sharedBaseGlobalOffset;
//groupshared uint sharedCellOffset;
//
//[numthreads( NUM_THREADS_PER_CELL_LINKED_LIST_FROM_BITS, 1, 1 )]
//void ListFromBits( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
//{
//	const uint nDecalsInFrustum = nDecals;
//	uint cellThreadIndex = cellThreadID.x;
//
//	uint flatCellIndex = GetClusterFlatIndex( cellID );
//	uint headNodeIndex = flatCellIndex;
//	uint firstNodeAddress = INVALID_DECAL_VOLUME_LIST_NODE_INDEX;
//	uint prevNodeDecalIndex = INVALID_DECAL_VOLUME_INDEX;
//	uint prevNodeAddress = INVALID_DECAL_VOLUME_LIST_NODE_INDEX;
//
//	uint totalVisibleDecals = 0;
//
//	uint nWords = ( nDecalsInFrustum + 32 - 1 ) / 32;
//
//	uint decalCount = decalCountPerCell[flatCellIndex];
//
//	if ( cellThreadIndex == 0 )
//	{
//		sharedCellOffset = 0;
//		InterlockedAdd( decalLinkedListCounter[0], decalCount, sharedBaseGlobalOffset );
//	}
//
//	GroupMemoryBarrierWithGroupSync();
//
//	uint baseGlobalOffset = sharedBaseGlobalOffset + HEADER_LINKED_LIST_NODES;
//
//	if ( baseGlobalOffset + decalCount <= MAX_LINKED_LIST_NODES )
//	{
//#if NUM_THREADS_PER_CELL_LINKED_LIST_FROM_BITS == 32
//		for ( uint iWord = 0; iWord < nWords; ++iWord )
//		{
//			uint word = decalVisibility[flatCellIndex * nWords + iWord];
//
//			if ( word == 0 )
//			{
//				continue;
//			}
//
//			uint threadBit = 1 << cellThreadIndex;
//			if ( word & threadBit )
//			{
//				uint maskedWord = word & ( threadBit - 1 );
//				uint localIndex = countbits( maskedWord );
//
//				decalLinkedList[baseGlobalOffset + sharedCellOffset + localIndex] = iWord * 32 + cellThreadIndex;
//			}
//
//			if ( cellThreadIndex == 0 )
//			{
//				uint wordDecalCount = countbits( word );
//				sharedCellOffset += wordDecalCount;
//			}
//
//			GroupMemoryBarrierWithGroupSync();
//		}
//#endif // #if NUM_THREADS_PER_CELL_LINKED_LIST_FROM_BITS == 32
//
////#if NUM_THREADS_PER_CELL_LINKED_LIST_FROM_BITS == 64
////		const uint nWordsPerIter = NUM_THREADS_PER_CELL_LINKED_LIST_FROM_BITS / 32;
////		for ( uint iWord = 0; iWord < nWords; iWord += nWordsPerIter )
////		{
////			uint threadWordIndex = cellThreadIndex / 32;
////			uint wordIndex = iWord + threadWordIndex;
////			uint word = decalVisibility[flatCellIndex * nWords + wordIndex];
////			if ( word == 0 )
////			{
////				continue;
////			}
////
////			uint threadBitIndex = cellThreadIndex - threadWordIndex * 32;
////			uint threadBitValue = 1 << threadBitIndex;
////			if ( word & threadBitValue )
////			{
////				uint maskedWord = word & ( threadBitValue - 1 );
////				uint localIndex = countbits( maskedWord );
////
////				decalLinkedList[baseGlobalOffset + sharedCellOffset + localIndex] = wordIndex * 32 + cellThreadIndex;
////			}
////
////			if ( cellThreadIndex == 0 )
////			{
////				uint wordDecalCount = countbits( word );
////				sharedCellOffset += wordDecalCount;
////			}
////
////			GroupMemoryBarrierWithGroupSync();
////		}
////#endif // #if NUM_THREADS_PER_CELL_LINKED_LIST_FROM_BITS == 64
//	}
//
//	if ( cellThreadIndex == 0 )
//	{
//		//decalLinkedList[headNodeIndex] = PackListNode( sharedCellOffset, baseGlobalOffset );
//		decalLinkedList[headNodeIndex] = PackHeader( sharedCellOffset, baseGlobalOffset );
//		//decalLinkedList[headNodeIndex] = baseGlobalOffset;
//	}
//}
//
//
////[numthreads( NUM_THREADS_PER_CELL, 1, 1 )]
////void SinglePassLinkedList( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
////{
////	//if ( cellID.z > 0 )
////	//	return;
////
////	//cellID.y = DECAL_VOLUME_CLUSTER_CELLS_Y - cellID.y - 1;
////
////	//const uint nDecalsInFrustum = 1024;
////	//const uint nDecalsInFrustum = ( nDecals + NUM_THREADS_PER_CELL - 1 ) / NUM_THREADS_PER_CELL;
////	const uint nDecalsInFrustum = nDecals;
////	const uint nDecalsInFrustum64 = nDecals64;
////	uint cellThreadIndex = cellThreadID.x;
////
////	Frustum frustum;// = (Frustum)0;
////
////	buildFrustum( frustum, uint3( DECAL_VOLUME_CLUSTER_CELLS_X, DECAL_VOLUME_CLUSTER_CELLS_Y, DECAL_VOLUME_CLUSTER_CELLS_Z ), cellID, BaseProjMatrix, ViewMatrix, nearFar.x, nearFar.y );
////
////	uint headNodeIndex = GetClusterFlatIndex( cellID );
////	uint firstNodeAddress = INVALID_DECAL_VOLUME_LIST_NODE_INDEX;
////	uint prevNodeDecalIndex = INVALID_DECAL_VOLUME_INDEX;
////	uint prevNodeAddress = INVALID_DECAL_VOLUME_LIST_NODE_INDEX;
////
////	bool runTest = true;
////	uint totalVisibleDecals = 0;
////	uint largestOffset = 0;
////
////	for ( uint iDecal = 0; iDecal < nDecalsInFrustum64 /*&& cellOutputLocalOffset < MAX_DECALS_PER_CELL*/; iDecal += NUM_THREADS_PER_CELL )
////	{
////		[branch]
////		if ( runTest )
////		{
////			uint decalIndex = iDecal + cellThreadIndex;
////			const DecalVolume dv = inDecalVolumes[decalIndex];
////			uint intersects = (decalIndex < nDecalsInFrustum) && TestDecalVolumeFrustum( dv, frustum );
////			//uint intersects = decalIndex < nDecalsInFrustum;
////			//uint intersects = TestDecalVolumeFrustum( dv, frustum );
////			decalVisible[cellThreadIndex] = intersects;
////			decalVisibleSum[cellThreadIndex] = intersects;
////		}
////
////		GroupMemoryBarrierWithGroupSync();
////
////		if ( cellThreadIndex < 32 )
////			decalVisibleSum[cellThreadIndex] += decalVisibleSum[cellThreadIndex + 32];
////
////		if ( cellThreadIndex < 16 )
////			decalVisibleSum[cellThreadIndex] += decalVisibleSum[cellThreadIndex + 16];
////
////		if ( cellThreadIndex < 8 )
////			decalVisibleSum[cellThreadIndex] += decalVisibleSum[cellThreadIndex + 8];
////
////		if ( cellThreadIndex < 4 )
////			decalVisibleSum[cellThreadIndex] += decalVisibleSum[cellThreadIndex + 4];
////
////		if ( cellThreadIndex < 2 )
////			decalVisibleSum[cellThreadIndex] += decalVisibleSum[cellThreadIndex + 2];
////
////		if ( cellThreadIndex < 1 )
////			decalVisibleSum[cellThreadIndex] += decalVisibleSum[cellThreadIndex + 1];
////
////
////		if ( cellThreadIndex == 0 && runTest )
////		{
////			uint nVisibleDecals = decalVisibleSum[0];
////			totalVisibleDecals + nVisibleDecals;
////
////			[branch]
////			if ( nVisibleDecals )
////			{
////				uint baseGlobalOffset;
////				InterlockedAdd( decalLinkedListCounter[0], nVisibleDecals, baseGlobalOffset );
////				baseGlobalOffset += HEADER_LINKED_LIST_NODES;
////				largestOffset = max( largestOffset, baseGlobalOffset );
////				uint globalOffset = baseGlobalOffset;
////				uint localOffset = 0;
////
////				//for ( uint iOutput = 0; iOutput < NUM_THREADS_PER_CELL && globalOffset < MAX_LINKED_LIST_NODES; ++iOutput )
////				//{
////				//	if ( decalVisible[iOutput] )
////				//	{
////				//		uint decalIndex = iDecal + iOutput;
////				//		uint nodeAddress = baseGlobalOffset + localOffset;
////
////				//		if ( prevNodeDecalIndex == INVALID_DECAL_VOLUME_INDEX )
////				//		{
////				//			prevNodeDecalIndex = decalIndex;
////				//			prevNodeAddress = nodeAddress;
////				//			firstNodeAddress = nodeAddress;
////				//		}
////				//		else
////				//		{
////				//			decalLinkedList[prevNodeAddress] = PackListNode( prevNodeDecalIndex, nodeAddress );
////				//			prevNodeDecalIndex = decalIndex;
////				//			prevNodeAddress = nodeAddress;
////				//		}
////
////				//		globalOffset += 1;
////				//		localOffset += 1;
////				//	}
////				//}
////
////				runTest = globalOffset < MAX_LINKED_LIST_NODES;
////			}
////		}
////	}
////
////	if ( cellThreadIndex == 0 )
////	{
////		//decalLinkedList[headNodeIndex] = PackListNode( totalVisibleDecals, firstNodeAddress );
////		decalLinkedList[headNodeIndex] = PackListNode( largestOffset, firstNodeAddress );
////		if ( prevNodeDecalIndex != INVALID_DECAL_VOLUME_INDEX )
////		{
////			decalLinkedList[prevNodeAddress] = PackListNode( prevNodeDecalIndex, INVALID_DECAL_VOLUME_LIST_NODE_INDEX );
////		}
////		//decalLinkedList[headNodeIndex] = PackListNode( 0, headNodeIndex + HEADER_LINKED_LIST_NODES );
////		//decalLinkedList[headNodeIndex + HEADER_LINKED_LIST_NODES] = PackListNode( 1, INVALID_DECAL_VOLUME_LIST_NODE_INDEX );
////
////		//uint firstIndex = headNodeIndex * 4 * 6;
////
////		//for ( uint i = 0; i < 6; ++i )
////		//{
////		//	decalLinkedList[firstIndex + i * 4 + 0] = asuint( frustum.planes[i].x );
////		//	decalLinkedList[firstIndex + i * 4 + 1] = asuint( frustum.planes[i].y );
////		//	decalLinkedList[firstIndex + i * 4 + 2] = asuint( frustum.planes[i].z );
////		//	decalLinkedList[firstIndex + i * 4 + 3] = asuint( frustum.planes[i].w );
////		//}
////	}
////}


struct vs_output
{
	float4 hpos			: SV_POSITION;
};

vs_output HeatmapVp( uint vertexId : SV_VertexID )
{
	vs_output OUT = (vs_output)0;

	if ( vertexId == 0 )
	{
		OUT.hpos = float4( -1, -1, 0, 1 );
	}
	else if ( vertexId == 1 )
	{
		OUT.hpos = float4( 3, -1, 0, 1 );
	}
	else if ( vertexId == 2 )
	{
		OUT.hpos = float4( -1, 3, 0, 1 );
	}

	return OUT;
}

float3 GetColorMap( uint count )
{
	float3 black =	float3( 0.0, 0.0, 0.0 );
	float3 blue =	float3( 0.0, 0.0, 1.0 );
	float3 cyan =	float3( 0.0, 1.0, 1.0 );
	float3 green =	float3( 0.0, 1.0, 0.0 );
	float3 yellow = float3( 1.0, 1.0, 0.0 );
	float3 red =	float3( 1.0, 0.0, 0.0 );

	if ( count == 0 )
	{
		return 0;
	}
	else if ( count == 1 )
	{
		return blue;
	}
	else if ( count == 2 )
	{
		return cyan;
	}
	else if ( count == 3 )
	{
		return green;
	}
	else if ( count == 4 )
	{
		return yellow;
	}
	else
	{
		return red;
	}

}

//float4 HeatmapFp( in vs_output IN ) : SV_Target
//{
//	uint2 pixelCoord = IN.hpos.xy;
//	float2 pixelCoordNormalized = pixelCoord * renderTargetSize.zw;
//	uint2 screenTile = uint2( pixelCoordNormalized * float2( DECAL_VOLUME_CLUSTER_CELLS_X, DECAL_VOLUME_CLUSTER_CELLS_Y ) );
//
//	uint decalCount = 0;
//
//	for ( uint slice = 0; slice < DECAL_VOLUME_CLUSTER_CELLS_Z; ++slice )
//	{
//		uint3 cellID = uint3( screenTile, slice );
//		uint clusterIndex = DecalVolume_GetCellFlatIndex( cellID, uint3( DECAL_VOLUME_CLUSTER_CELLS_X, DECAL_VOLUME_CLUSTER_CELLS_Y, DECAL_VOLUME_CLUSTER_CELLS_Z ) );
//
//		//uint node = inDecalLinkedList[clusterIndex];
//		//uint decalIndex;
//		//uint nextNodeIndex;
//		//UnpackListNode( node, decalIndex, nextNodeIndex );
//
//		//uint index = 0;
//		//while ( nextNodeIndex != INVALID_DECAL_VOLUME_LIST_NODE_INDEX && index < 5 )
//		//{
//		//	index += 1;
//		//	node = inDecalLinkedList[nextNodeIndex];
//		//	decalIndex;
//		//	nextNodeIndex;
//		//	UnpackListNode( node, decalIndex, nextNodeIndex );
//
//		//	decalCount += 1;
//		//}
//
//		uint node = inDecalsPerCell[clusterIndex];
//		uint cellDecalCount;
//		uint offsetToFirstDecalIndex;
//		DecalVolume_UnpackHeader( node, cellDecalCount, offsetToFirstDecalIndex );
//
//		decalCount += cellDecalCount;
//	}
//
//	float3 color = GetColorMap( decalCount );
//
//	//return float4( 1, 0, 0, 1 );
//	return float4( color, 0.25f );
//	//if ( screenTile.x & 1 )
//	//	return float4( 1, 0, 0, 1 );
//	//else
//	//	return float4( 0, 1, 0, 1 );
//}


float4 HeatmapTileFp( in vs_output IN ) : SV_Target
{
	uint2 pixelCoord = IN.hpos.xy;
	float2 pixelCoordNormalized = pixelCoord * renderTargetSize.zw;
	uint2 screenTile = min( uint2( pixelCoordNormalized * float2( cellCountA.xy ) ), cellCountA.xy - 1 );

	uint decalCount = 0;

	for ( uint slice = 0; slice < cellCountA.z; ++slice )
	{
		uint3 cellID = uint3( screenTile, slice );
		uint clusterIndex = DecalVolume_GetCellFlatIndex( cellID, uint3( cellCountA.xy, 1 ) );

		//uint node = inDecalLinkedList[clusterIndex];
		//uint decalIndex;
		//uint nextNodeIndex;
		//UnpackListNode( node, decalIndex, nextNodeIndex );

		//uint index = 0;
		//while ( nextNodeIndex != INVALID_DECAL_VOLUME_LIST_NODE_INDEX && index < 5 )
		//{
		//	index += 1;
		//	node = inDecalLinkedList[nextNodeIndex];
		//	decalIndex;
		//	nextNodeIndex;
		//	UnpackListNode( node, decalIndex, nextNodeIndex );

		//	decalCount += 1;
		//}

		uint node = inDecalsPerCell[clusterIndex];
		uint cellDecalCount;
		uint offsetToFirstDecalIndex;
		DecalVolume_UnpackHeader( node, cellDecalCount, offsetToFirstDecalIndex );

		decalCount += cellDecalCount;
	}

	float3 color = GetColorMap( decalCount );

	//return float4( 1, 0, 0, 1 );
	return float4( color, 0.25f );
	//if ( screenTile.x & 1 )
	//	return float4( 1, 0, 0, 1 );
	//else
	//	return float4( 0, 1, 0, 1 );
}


vs_output DecalVolumesAccumVp( uint vertexId : SV_VertexID, float3 position : POSITION )
{
	vs_output OUT;

	float4 positionWorld = mul( World, float4( position, 1 ) );

	OUT.hpos = mul( ViewProjection, positionWorld );

	return OUT;
}


float4 DecalVolumesAccumFp( in vs_output IN ) : SV_Target
{
	float v = 0.25f;
	return float4( v.xxxx );
	//return float4( 1, 0, 0, 1 );
}
