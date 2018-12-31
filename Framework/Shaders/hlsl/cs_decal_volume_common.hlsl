#include "cs_decal_volume_cshared.hlsl"

StructuredBuffer<DecalVolume> inDecalVolumes REGISTER_T( DECAL_VOLUME_IN_DECALS_BINDING );
StructuredBuffer<uint> inDecalVolumesCount REGISTER_T( DECAL_VOLUME_IN_DECALS_COUNT_BINDING );
//#if DECAL_TILING_PASS_NO != 0 && DECAL_VOLUME_CLUSTERING_PASS_NO != 0
//StructuredBuffer<uint> inDecalCountPerCell REGISTER_T( DECAL_VOLUME_IN_COUNT_PER_CELL_BINDING );
StructuredBuffer<uint> inDecalsPerCell REGISTER_T( DECAL_VOLUME_IN_DECALS_PER_CELL_BINDING );
StructuredBuffer<CellIndirection> inCellIndirection REGISTER_T( DECAL_VOLUME_IN_CELL_INDIRECTION_BINDING );
//#endif // #if DECAL_TILING_PASS_NO != 0 && DECAL_VOLUME_CLUSTERING_PASS_NO != 0


//#if DECAL_TILING_PASS_NO != DECAL_VOLUME_TILING_LAST_PASS
//RWStructuredBuffer<uint> outDecalCountPerCell REGISTER_U( DECAL_VOLUME_OUT_COUNT_PER_CELL_BINDING );
RWStructuredBuffer<CellIndirection> outDecalCellIndirection REGISTER_U( DECAL_VOLUME_OUT_CELL_INDIRECTION_BINDING );
RWStructuredBuffer<uint> outCellIndirectionCount REGISTER_U( DECAL_VOLUME_OUT_CELL_INDIRECTION_COUNT_BINDING );
RWStructuredBuffer<uint> outMemAlloc REGISTER_U( DECAL_VOLUME_OUT_MEM_ALLOC_BINDING );
//#endif // #if DECAL_TILING_PASS_NO != 2

StructuredBuffer<uint> inCellIndirectionCount REGISTER_T( DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT_BINDING );
RWByteAddressBuffer outIndirectArgs REGISTER_U( DECAL_VOLUME_OUT_INDIRECT_ARGS_BINDING );

RWStructuredBuffer<uint> outDecalsPerCell REGISTER_U( DECAL_VOLUME_OUT_DECALS_PER_CELL_BINDING );


struct Frustum
{
	// left, right, bottom, top, near, far
	float4 planes[6];

	float3 frustumCorners[8];

	bool twoTests;
};


void extractFrustumPlanes( out float4 planes[6], float4x4 vp )
{
	planes[0] = vp[0] + vp[3]; // left
	planes[1] = -vp[0] + vp[3]; // right
	planes[2] = vp[1] + vp[3]; // bottom
	planes[3] = -vp[1] + vp[3]; // top
	planes[4] = vp[2] + vp[3]; // near
	planes[5] = -vp[2] + vp[3]; // far

	for ( int i = 0; i < 6; ++i )
	{
		float lenRcp = 1.0f / length( planes[i].xyz );
		planes[i] *= lenRcp;
	}
}

float3 planesIntersect( float4 p1, float4 p2, float4 p3 )
{
	float denom = dot( p1.xyz, cross( p2.xyz, p3.xyz ) );
	return rcp( -denom ) * (
		cross( p2.xyz, p3.xyz ) * p1.w +
		cross( p3.xyz, p1.xyz ) * p2.w +
		cross( p1.xyz, p2.xyz ) * p3.w );
}

void extractFrustumCorners( out float3 frustumCorners[8], float4 frustumPlanes[6] )
{
	frustumCorners[0] = planesIntersect( frustumPlanes[0], frustumPlanes[2], frustumPlanes[4] );
	frustumCorners[1] = planesIntersect( frustumPlanes[0], frustumPlanes[2], frustumPlanes[5] );
	frustumCorners[2] = planesIntersect( frustumPlanes[0], frustumPlanes[3], frustumPlanes[4] );
	frustumCorners[3] = planesIntersect( frustumPlanes[0], frustumPlanes[3], frustumPlanes[5] );
	frustumCorners[4] = planesIntersect( frustumPlanes[1], frustumPlanes[2], frustumPlanes[4] );
	frustumCorners[5] = planesIntersect( frustumPlanes[1], frustumPlanes[2], frustumPlanes[5] );
	frustumCorners[6] = planesIntersect( frustumPlanes[1], frustumPlanes[3], frustumPlanes[4] );
	frustumCorners[7] = planesIntersect( frustumPlanes[1], frustumPlanes[3], frustumPlanes[5] );
}

//void buildFrustum( out Frustum frustum, const uint3 subdiv, uint3 cellIndex, float4x4 baseProj, float4x4 viewMatrix, float nearPlane, float farPlane )
//{
//	float n = nearPlane * pow( farPlane / nearPlane, (float)cellIndex.z / subdiv.z );
//	float f = nearPlane * pow( farPlane / nearPlane, (float)(cellIndex.z + 1) / subdiv.z );
//	float a = f / ( n - f );
//	float b = n * f / ( n - f );
//
//	float tileScaleX = subdiv.x;
//	float tileScaleY = subdiv.y;
//
//	uint subFrustumX = cellIndex.x;
//	uint subFrustumY = cellIndex.y;
//
//	float tileBiasX = subFrustumX * 2 - tileScaleX + 1;
//	float tileBiasY = subFrustumY * 2 - tileScaleY + 1;
//
//	float4x4 subProj = {
//		baseProj[0][0] * tileScaleX,		0,									tileBiasX,			0,
//		0,									baseProj[1][1] * -tileScaleY,		tileBiasY,			0,
//		0,									0,									a,					b,
//		0,									0,									-1,					0
//	};
//	float4x4 viewProj = mul( subProj, viewMatrix );
//
//	extractFrustumPlanes( frustum.planes, viewProj );
//}


void buildFrustum( out Frustum frustum, const uint3 cellCount, uint3 cellIndex, float2 tanHalfFovRcp, float4x4 viewMatrix, float nearPlane, float farPlaneOverNearPlane )
{
	float n = nearPlane * pow( abs(farPlaneOverNearPlane), (float)cellIndex.z / cellCount.z );
	float f = nearPlane * pow( abs(farPlaneOverNearPlane), (float)( cellIndex.z + 1 ) / cellCount.z );
	//float n = 1;
	//float f = 20;
	float nmf = 1.0f / ( n - f );
	float a = f * nmf;
	float b = n * f * nmf;

	float tileScaleX = cellCount.x;
	float tileScaleY = cellCount.y;

	uint subFrustumX = cellIndex.x;
	uint subFrustumY = cellIndex.y;

	float tileBiasX = subFrustumX * 2 - tileScaleX + 1;
	float tileBiasY = subFrustumY * 2 - tileScaleY + 1;

	float4x4 subProj = {
		tanHalfFovRcp.x * tileScaleX,		0,									tileBiasX,			0,
		0,									tanHalfFovRcp.y * -tileScaleY,		tileBiasY,			0,
		0,									0,									a,					b,
		0,									0,									-1,					0
	};
	float4x4 viewProj = mul( subProj, viewMatrix );

	extractFrustumPlanes( frustum.planes, viewProj );
	extractFrustumCorners( frustum.frustumCorners, frustum.planes );

	frustum.twoTests = true;
}


// Real-Time Rendering, 3rd Edition - 16.10.1, 16.14.3 (p. 755, 777)
// pico warning!!!! picoViewFrustum has planes pointing inwards
// this test assumes opposite
// to use it with picoViewFrustum one has to change test from if ( s > e ) to if ( s + e < 0 )
uint frustumOBBIntersectSimpleOptimized( float4 frustumPlanes[6], float3 boxPosition, float3 boxHalfSize, float3 boxX, float3 boxY, float3 boxZ )
{
	//[unroll]
	for ( int i = 0; i < 6; ++i )
	{
		float3 n = frustumPlanes[i].xyz;
		float e = boxHalfSize.x*abs( dot( n, boxX ) )
				+ boxHalfSize.y*abs( dot( n, boxY ) )
				+ boxHalfSize.z*abs( dot( n, boxZ ) );
		float s = dot( boxPosition, n ) + frustumPlanes[i].w;
		if ( s + e < 0 )
			return 0;
	}

	return 1;
}

// TODO: False negatives when using it in tiledDecalCulling.
bool frustumOBBIntersectOptimized( float4 frustumPlanes[6], float3 frustumCorners[8], float4 boxPlanes[6], float3 boxPosition, float3 boxHalfSize, float3 boxX, float3 boxY, float3 boxZ )
{
	//UNROLL
	for ( int i = 0; i < 6; ++i )
	{
		float3 n = frustumPlanes[i].xyz;
		float e = boxHalfSize.x*abs( dot( n, boxX ) )
				+ boxHalfSize.y*abs( dot( n, boxY ) )
				+ boxHalfSize.z*abs( dot( n, boxZ ) );
		float s = dot( boxPosition, n ) + frustumPlanes[i].w;
		//BRANCH
		//if ( s > e )
		if ( s + e < 0 )
			return 0;
	}

	for ( int ii = 0; ii < 6; ++ii )
	{
		int outside = 0;
		//UNROLL
		for ( int j = 0; j < 8; ++j )
			outside += dot( boxPlanes[ii], float4( frustumCorners[j], 1.0 ) ) < 0.0 ? 1 : 0;
		//BRANCH
		if ( outside == 8 )
			return 0;
	}

	return 1;
}

// Less false positives, great if near and far frustum planes are compact.
// http://www.iquilezles.org/www/articles/frustumcorrect/frustumcorrect.htm
bool frustumOBBIntersect( float4 frustumPlanes[6], float3 frustumCorners[8], float4 boxPlanes[6], float3 boxCorners[8] )
{
	for ( int i = 0; i < 6; ++i )
	{
		int outside = 0;
		//UNROLL
		for ( int j = 0; j < 8; ++j )
			outside += dot( frustumPlanes[i], float4(boxCorners[j], 1.0) ) < 0.0 ? 1 : 0;
		//BRANCH
		if ( outside == 8 )
			return 0;
	}
	for ( int ii = 0; ii < 6; ++ii )
	{
		int outside = 0;
		//UNROLL
		for ( int j = 0; j < 8; ++j )
			outside += dot( boxPlanes[ii], float4(frustumCorners[j], 1.0) ) < 0.0 ? 1 : 0;
		//BRANCH
		if ( outside == 8 )
			return 0;
	}
	return 1;
}


uint TestDecalVolumeFrustum( in DecalVolume dv, in Frustum frustum )
{
	float4 boxPlanes[6];
	boxPlanes[0] = float4(  dv.x.xyz, -dot( dv.position.xyz - dv.x.xyz*dv.halfSize.x,  dv.x.xyz ) );
	boxPlanes[1] = float4( -dv.x.xyz, -dot( dv.position.xyz + dv.x.xyz*dv.halfSize.x, -dv.x.xyz ) );
	boxPlanes[2] = float4(  dv.y.xyz, -dot( dv.position.xyz - dv.y.xyz*dv.halfSize.y,  dv.y.xyz ) );
	boxPlanes[3] = float4( -dv.y.xyz, -dot( dv.position.xyz + dv.y.xyz*dv.halfSize.y, -dv.y.xyz ) );
	boxPlanes[4] = float4(  dv.z.xyz, -dot( dv.position.xyz - dv.z.xyz*dv.halfSize.z,  dv.z.xyz ) );
	boxPlanes[5] = float4( -dv.z.xyz, -dot( dv.position.xyz + dv.z.xyz*dv.halfSize.z, -dv.z.xyz ) );

	float3 boxCorners[8];
	boxCorners[0] = dv.position.xyz + dv.x.xyz*dv.halfSize.x + dv.y.xyz*dv.halfSize.y + dv.z.xyz*dv.halfSize.z;
	boxCorners[1] = dv.position.xyz - dv.x.xyz*dv.halfSize.x + dv.y.xyz*dv.halfSize.y + dv.z.xyz*dv.halfSize.z;
	boxCorners[2] = dv.position.xyz + dv.x.xyz*dv.halfSize.x - dv.y.xyz*dv.halfSize.y + dv.z.xyz*dv.halfSize.z;
	boxCorners[3] = dv.position.xyz - dv.x.xyz*dv.halfSize.x - dv.y.xyz*dv.halfSize.y + dv.z.xyz*dv.halfSize.z;
	boxCorners[4] = dv.position.xyz + dv.x.xyz*dv.halfSize.x + dv.y.xyz*dv.halfSize.y - dv.z.xyz*dv.halfSize.z;
	boxCorners[5] = dv.position.xyz - dv.x.xyz*dv.halfSize.x + dv.y.xyz*dv.halfSize.y - dv.z.xyz*dv.halfSize.z;
	boxCorners[6] = dv.position.xyz + dv.x.xyz*dv.halfSize.x - dv.y.xyz*dv.halfSize.y - dv.z.xyz*dv.halfSize.z;
	boxCorners[7] = dv.position.xyz - dv.x.xyz*dv.halfSize.x - dv.y.xyz*dv.halfSize.y - dv.z.xyz*dv.halfSize.z;

	//return frustumOBBIntersect( frustum.planes, frustum.frustumCorners, boxPlanes, boxCorners );

	if ( frustum.twoTests )
	{
		return frustumOBBIntersectOptimized( frustum.planes, frustum.frustumCorners, boxPlanes, dv.position.xyz, dv.halfSize.xyz, dv.x.xyz, dv.y.xyz, dv.z.xyz );
	}
	else
	{
		return frustumOBBIntersectSimpleOptimized( frustum.planes, dv.position.xyz, dv.halfSize.xyz, dv.x.xyz, dv.y.xyz, dv.z.xyz );
	}
}


inline uint spadAlignU32_2( uint value, uint alignment )
{
	alignment--;
	return ( ( value + alignment ) & ~alignment );
}
