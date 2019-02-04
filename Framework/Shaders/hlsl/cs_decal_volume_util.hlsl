StructuredBuffer<DecalVolumeScaled> inDecalVolumes           REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS;
StructuredBuffer<DecalVolumeClipSpace> inDecalVolumesTest   REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_TEST;
StructuredBuffer<uint> inDecalVolumesCount             REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_COUNT;
StructuredBuffer<uint> inDecalVolumeIndices            REGISTER_BUFFER_DECAL_VOLUME_IN_DECAL_INDICES;
StructuredBuffer<CellIndirection> inCellIndirection    REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION;
StructuredBuffer<uint> inCellIndirectionCount          REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT;


RWStructuredBuffer<CellIndirection> outCellIndirection REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION;
RWStructuredBuffer<uint> outCellIndirectionCount       REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION_COUNT;
RWStructuredBuffer<uint> outDecalVolumeIndicesCount    REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES_COUNT;
RWByteAddressBuffer outIndirectArgs                    REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS;
RWStructuredBuffer<uint> outDecalVolumeIndices         REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES;

Texture2D<float2> inMinMaxDepth						   REGISTER_TEXTURE_DECAL_VOLUME_IN_DEPTH;

StructuredBuffer<GroupToBucket> inGroupToBucket        REGISTER_BUFFER_DECAL_VOLUME_IN_GROUP_TO_BUCKET;
RWStructuredBuffer<GroupToBucket> outGroupToBucket     REGISTER_BUFFER_DECAL_VOLUME_OUT_GROUP_TO_BUCKET;

struct OrientedBoundingBox
{
	float3 center;
	float3 axes[3];
	float3 halfSize;
};

struct FrustumFace
{
	float3 center;
	float3 axes[2];
};

struct Frustum
{
	// left, right, bottom, top, near, far
	float4 planes[6];
	float3 frustumCorners[8];
	// left, right, bottom, top, near, far
	float clipSpacePlanes[6];

	FrustumFace faces[2];
};


float DecalVolume_CalculateSplitLog( float nearPlane, float farPlaneOverNearPlane, float cellIndexZ, float cellCountZRcp )
{
	return nearPlane * pow( abs( farPlaneOverNearPlane ), cellIndexZ * cellCountZRcp );
}


float DecalVolume_CalculateSplitUniform( float nearPlane, float farPlane, float cellIndexZ, float cellCountZRcp )
{
	return lerp( nearPlane, farPlane, cellIndexZ * cellCountZRcp );
}


float DecalVolume_CalculateSplit( float nearPlane, float farPlane, float farPlaneOverNearPlane, float cellIndexZ, float cellCountZRcp )
{
#if DECAL_VOLUME_CLUSTER_3D_UNIFORMZ
	return DecalVolume_CalculateSplitUniform( nearPlane, farPlane, cellIndexZ, cellCountZRcp );
#else // #if DECAL_VOLUME_CLUSTER_3D_UNIFORMZ
	return DecalVolume_CalculateSplitLog( nearPlane, farPlaneOverNearPlane, cellIndexZ, cellCountZRcp );
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D_UNIFORMZ
}


float3 WorldPositionFromScreenCoords( float3 eyeAxis[3], float3 eyeOffset, float2 screenCoords, float depth )
{
	float3 eyeRay = eyeAxis[0] * screenCoords.xxx +
		eyeAxis[1] * screenCoords.yyy +
		eyeAxis[2];

	return eyeOffset + eyeRay * depth;
}


#ifndef USE_OBB_FRUSTUM_EARLY_ACCEPT
#define USE_OBB_FRUSTUM_EARLY_ACCEPT		1
#endif

#ifndef USE_OBB_FRUSTUM_FACE_AXES
#define USE_OBB_FRUSTUM_FACE_AXES			0
#endif

#ifndef USE_OBB_FRUSTUM_EDGE_CROSSES
#define USE_OBB_FRUSTUM_EDGE_CROSSES		1
#endif


void DecalVolume_GetFrustumClusterFaces( out FrustumFace faces[2], float2 cellSize, float3 cellCount, float3 cellCountF, float3 cellCountRcp, float3 cellIndex, float2 tanHalfFov, float nearPlane, float farPlane, float farPlaneOverNearPlane, bool farClip = false )
{
	// clip-space (-1,1) position of the view ray through the centroid of the cluster frustum projected on screen
	float2 uv = ( cellIndex.xy + 0.5f ) * cellCountRcp.xy;
	// inverted y, tile (0,0) is in left-top corner
	uv = uv * float2( 2.0f, -2.0f ) - float2( 1.0f, -1.0f );

	// view-space depth of the near and far planes for the cluster frustum
#if DECAL_VOLUME_CLUSTER_3D
	float depth0 = DecalVolume_CalculateSplit( nearPlane, farPlane, farPlaneOverNearPlane, cellIndex.z, cellCountRcp.z );
	float depth1 = DecalVolume_CalculateSplit( nearPlane, farPlane, farPlaneOverNearPlane, cellIndex.z + 1.0f, cellCountRcp.z );
#else // #if DECAL_VOLUME_CLUSTER_3D
	float depth0 = nearPlane;
	float depth1 = farPlane;
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D

	// screen-space half size of the projected frustum
	//float2 projHalfSize = ( 1.0f * float2( 32.0f, 32.0f ) ) / float2( 1920, 1080 );
	//float2 projHalfSize = cellSize * 0.5f; // incorrect
	float2 projHalfSize = cellSize;

	//float3 eyeAxis[3];
	//eyeAxis[0] = float3( 1, 0, 0 ) * tanHalfFov.x;
	//eyeAxis[1] = float3( 0, 1, 0 ) * tanHalfFov.y;
	//eyeAxis[2] = float3( 0, 0, -1 );
	//float3 eyeOffset = float3( 0, 0, 0 );
	float3 eyeAxis[3];
	eyeAxis[0] = dvEyeAxisX.xyz;
	eyeAxis[1] = dvEyeAxisY.xyz;
	eyeAxis[2] = dvEyeAxisZ.xyz;
	float3 eyeOffset = dvEyeOffset.xyz;

	faces[0].center = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv, depth0 );
	faces[0].axes[0] = eyeAxis[0] * projHalfSize.xxx * depth0;
	faces[0].axes[1] = eyeAxis[1] * projHalfSize.yyy * depth0;

	faces[1].center = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv, depth1 );
	faces[1].axes[0] = eyeAxis[0] * projHalfSize.xxx * depth1;
	faces[1].axes[1] = eyeAxis[1] * projHalfSize.yyy * depth1;

	float2 uv00 = cellIndex.xy * cellCountRcp.xy;
	float2 uv10 = ( cellIndex.xy + float2( 1, 0.5f ) ) * cellCountRcp.xy;
	float2 uv01 = ( cellIndex.xy + float2( 0.5f, 1 ) ) * cellCountRcp.xy;

	float3 c100 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( float2( uv10 ) * 2 - float2( 1, 1 ) ) * float2( 1, -1 ), depth0 );
	float3 c101 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( float2( uv10 ) * 2 - float2( 1, 1 ) ) * float2( 1, -1 ), depth1 );
	float3 c010 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( float2( uv01 ) * 2 - float2( 1, 1 ) ) * float2( 1, -1 ), depth0 );
	float3 c011 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( float2( uv01 ) * 2 - float2( 1, 1 ) ) * float2( 1, -1 ), depth1 );

	//faces[0].axes[0] = ( c100 - faces[0].center );
	//faces[0].axes[1] = ( c010 - faces[0].center );
	//faces[1].axes[0] = ( c101 - faces[1].center );
	//faces[1].axes[1] = ( c011 - faces[1].center );
}


float3 GetTriangleAxis( const in float3 a, const in float3 b, const in float3 c )
{
	float3 ab = b - a;
	float3 ac = c - a;
	return cross( ac, ab );
}


float3 GetFrustumVertex( const in FrustumFace frustumFaces[2], int vertIndex )
{
	int sx = vertIndex & 1;
	int sy = ( vertIndex >> 1 ) & 1;
	int iz = vertIndex >> 2;

	//return frustumFaces[iz].center + frustumFaces[iz].axes[0] * sx + frustumFaces[iz].axes[1] * sy;
	float sxn = sx * 2.0f - 1.0f;
	float syn = sy * 2.0f - 1.0f;
	return frustumFaces[iz].center + frustumFaces[iz].axes[0] * (float)sxn + frustumFaces[iz].axes[1] * (float)syn;
}


float3 GetFrustumAxis( const in FrustumFace frustumFaces[2], int axisIndex )
{
	// NOTE: These if statements are meant to be evaluated and removed at compile time after loop unrolling.
	//       The idea is to avoid storing frustumAxes in registers. Maybe worth???

	if ( axisIndex == 0 ) // z
		return cross( frustumFaces[0].axes[0], frustumFaces[0].axes[1] );
	if ( axisIndex == 1 ) // x1
		return cross( frustumFaces[0].axes[0], GetFrustumVertex( frustumFaces, 4 ) - GetFrustumVertex( frustumFaces, 0 ) );
	if ( axisIndex == 2 ) // y1
		return cross( frustumFaces[0].axes[1], GetFrustumVertex( frustumFaces, 4 ) - GetFrustumVertex( frustumFaces, 0 ) );
	if ( axisIndex == 3 ) // x2
		return cross( frustumFaces[0].axes[0], GetFrustumVertex( frustumFaces, 7 ) - GetFrustumVertex( frustumFaces, 3 ) );
	if ( axisIndex == 4 ) // y2
		return cross( frustumFaces[0].axes[1], GetFrustumVertex( frustumFaces, 7 ) - GetFrustumVertex( frustumFaces, 3 ) );

	return float3( 0, 0, 1 );
}


bool AreIntervalsDisjoint( const in float2 a, const in float2 b )
{
	return ( a.y < b.x ) || ( b.y < a.x );
}


void ExtendIntervalWithValue( const float x, inout float2 inOutInterval )
{
	if ( x < inOutInterval.x )
	{
		inOutInterval.x = x;
	}
	if ( x > inOutInterval.y )
	{
		inOutInterval.y = x;
	}
}


void ExtendIntervalWithInterval( const float2 v, inout float2 inOutInterval )
{
	if ( v.x < inOutInterval.x )
	{
		inOutInterval.x = v.x;
	}
	if ( v.y > inOutInterval.y )
	{
		inOutInterval.y = v.y;
	}
}


float2 GetObbProjectedInterval( const in OrientedBoundingBox obb, const in float3 axis )
{
	const float centerProjectionOBB = dot( obb.center, axis );

	// TODO: the halfSize can be premultiplied into the obb.axis vectors to save some computation. I'm not sure if that will break other code that relies on this header though...

	const float extentsProjectionOBB
		= abs( dot( obb.axes[0], axis ) * obb.halfSize.x )
		+ abs( dot( obb.axes[1], axis ) * obb.halfSize.y )
		+ abs( dot( obb.axes[2], axis ) * obb.halfSize.z );

	return float2( centerProjectionOBB - extentsProjectionOBB, centerProjectionOBB + extentsProjectionOBB );
}


float2 GetFrustumFaceProjectedInterval( const in FrustumFace ff, const in float3 axis )
{
	const float centerProjectionFF = dot( ff.center, axis );

	const float extentsProjectionFF
		= abs( dot( ff.axes[0], axis ) )
		+ abs( dot( ff.axes[1], axis ) );

	return float2( centerProjectionFF - extentsProjectionFF, centerProjectionFF + extentsProjectionFF );
}


float2 GetFrustumProjectedInterval( const in FrustumFace frustumFaces[2], const in float3 axis )
{
	float2 outInterval = GetFrustumFaceProjectedInterval( frustumFaces[0], axis );
	ExtendIntervalWithInterval( GetFrustumFaceProjectedInterval( frustumFaces[1], axis ), outInterval );
	return outInterval;
}


bool R_AreFrustumObbProjectedIntervalsDisjoint( const in OrientedBoundingBox obb, const in FrustumFace frustumFaces[2], const in float3 axis )
{
	const float2 obbInterval = GetObbProjectedInterval( obb, axis );
	float2 frustumInterval = GetFrustumProjectedInterval( frustumFaces, axis );
	return AreIntervalsDisjoint( frustumInterval, obbInterval );
}


int IsAinB( const in float2 a, const in float2 b )
{
	return ( b.x <= a.x ) && ( a.y <= b.y ) ? 1 : 0;
}


bool R_AreFrustumObbProjectedIntervalsDisjointMask( const in OrientedBoundingBox obb, const in FrustumFace frustumFaces[2], const in float3 axis, inout int containmentMask )
{
	const float2 obbInterval = GetObbProjectedInterval( obb, axis );
	float2 frustumInterval = GetFrustumProjectedInterval( frustumFaces, axis );

	containmentMask = ( containmentMask << 1 ) | IsAinB( frustumInterval, obbInterval );
	return AreIntervalsDisjoint( frustumInterval, obbInterval );
}


// Subroutine of TestFrustumObbIntersectionSAT()
bool IsFrustumEdgeVsBoxAxesProjectionDisjoint( const in OrientedBoundingBox obb, const in FrustumFace frustumFaces[2], const float3 frustumEdgeVertexA, const in float3 frustumEdgeVertexB )
{
	const float3 frustumEdgeDir = frustumEdgeVertexA - frustumEdgeVertexB;

	[loop]
	for ( uint axisIndex = 0; axisIndex < 3; axisIndex++ )
	{
		//if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, cross( frustumEdgeDir, obb.axes[0] ) ) )
		if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, cross( frustumEdgeDir, obb.axes[axisIndex] ) ) )
		{
			return true;
		}
	}

	return false;
}


// Frustum Obb Intersection
//
// Use a Separating Axis Test (SAT) to determine if there is an intersection.
// Two convex volumes do not intersect if there is any axis over which projections of the volumes are separate.
// The separating axes for convex polytope must be one of the face normals of each shape or the cross products between the edges of the shapes.
// We test each of these in turn.

bool TestFrustumObbIntersectionSAT( const in OrientedBoundingBox obb, const in FrustumFace frustumFaces[2] )
{
	/// Test box axes
	// these are cheap to evaluate, and are orthogonal
	// also, there is potential to early out, so do first
	int containmentMask = 0;

	[unroll]
	for ( uint axisIndex = 0; axisIndex < 3; axisIndex++ )
	{
#if USE_OBB_FRUSTUM_EARLY_ACCEPT
		if ( R_AreFrustumObbProjectedIntervalsDisjointMask( obb, frustumFaces, obb.axes[axisIndex], containmentMask ) ) return false;
#else
		if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, obb.axes[axisIndex] ) ) return false;
#endif
	}

	if ( containmentMask == 7 )
		return true;

	/// Test other axes. we want to check axes that are as different from each other as possible first to get early rejections
	/// this means that some of the checks are interleaved

	// ROUND 1
#if USE_OBB_FRUSTUM_FACE_AXES
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, obb.center - frustumFaces[0].center ) ) return false; // Frustum face center to OBB center
#endif

	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 0 ) ) ) return false; // Frustum plane
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 1 ) ) ) return false; // Frustum plane
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 2 ) ) ) return false; // Frustum plane

#if USE_OBB_FRUSTUM_EDGE_CROSSES
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 0 ), GetFrustumVertex( frustumFaces, 1 ) ) ) return false; // Edge cross product
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 0 ), GetFrustumVertex( frustumFaces, 2 ) ) ) return false; // Edge cross product
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 0 ), GetFrustumVertex( frustumFaces, 4 ) ) ) return false; // Edge cross product
#endif

	// ROUND 2
#if USE_OBB_FRUSTUM_FACE_AXES
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, obb.center - frustumFaces[1].center ) ) return false; // Frustum face center to OBB center
#endif

	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 3 ) ) ) return false; // Frustum plane
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 4 ) ) ) return false; // Frustum plane

#if USE_OBB_FRUSTUM_EDGE_CROSSES
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 3 ), GetFrustumVertex( frustumFaces, 7 ) ) ) return false; // Edge cross product
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 1 ), GetFrustumVertex( frustumFaces, 5 ) ) ) return false; // Edge cross product
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 2 ), GetFrustumVertex( frustumFaces, 6 ) ) ) return false; // Edge cross product
#endif

	return true;
}


uint DecalVolume_TestFrustumWorldSpaceSATOpt( in DecalVolumeScaled dv, in Frustum frustum )
{
	OrientedBoundingBox obb;
	obb.center = dv.position;
	obb.halfSize = float3( 1, 1, 1 );
	obb.axes[0] = dv.x;
	obb.axes[1] = dv.y;
	obb.axes[2] = dv.z;

	return TestFrustumObbIntersectionSAT( obb, frustum.faces ) ? 1 : 0;
}


void DecalVolume_GetCornersClipSpace( DecalVolumeClipSpace dv, out float4 dvCornersXYW[8] )
{
#if DECAL_VOLUME_USE_XYW_CORNERS

	float3 ex = dv.v5 - dv.v4;
	float3 ey = dv.v7 - dv.v4;
	float3 v1 = dv.v0 + ex;

	dvCornersXYW[0].xyw = dv.v0.xyz;
	dvCornersXYW[1].xyw = v1;
	dvCornersXYW[2].xyw = ( v1 + ey );
	dvCornersXYW[3].xyw = ( dv.v0 + ey );

	dvCornersXYW[4].xyw = dv.v4;
	dvCornersXYW[5].xyw = dv.v5;
	dvCornersXYW[6].xyw = ( dv.v5 + ey );
	dvCornersXYW[7].xyw = dv.v7;

#else // #if DECAL_VOLUME_USE_XYW_CORNERS

	float4 ex = dv.v5 - dv.v4;
	float4 ey = dv.v7 - dv.v4;
	float4 v1 = dv.v0 + ex;

	dvCornersXYW[0] = dv.v0;
	dvCornersXYW[1] = v1;
	dvCornersXYW[2] = ( v1 + ey );
	dvCornersXYW[3] = ( dv.v0 + ey );

	dvCornersXYW[4] = dv.v4;
	dvCornersXYW[5] = dv.v5;
	dvCornersXYW[6] = ( dv.v5 + ey );
	dvCornersXYW[7] = dv.v7;

#endif // #else // #if DECAL_VOLUME_USE_XYW_CORNERS
}


void DecalVolume_GetCornersClipSpace2( DecalVolumeScaled dv, out float4 dvCornersXYW[8] )
{
	float3 center = dv.position;
	float3 xs = dv.x;
	float3 ys = dv.y;
	float3 zs = dv.z;

	float3 v0 = center - xs - ys + zs;
	float3 v4 = center - xs - ys - zs;
	float3 v5 = center + xs - ys - zs;
	float3 v7 = center - xs + ys - zs;

	float3 v1 = center + xs - ys + zs;
	float3 v2 = center + xs + ys + zs;
	float3 v3 = center - xs + ys + zs;
	float3 v6 = center + xs + ys - zs;

#if DECAL_VOLUME_USE_XYW_CORNERS

	DecalVolumeClipSpace dvt;
	dvt.v0 = mul( dvViewProjMatrix, float4( v0, 1 ) ).xyw;
	dvt.v4 = mul( dvViewProjMatrix, float4( v4, 1 ) ).xyw;
	dvt.v5 = mul( dvViewProjMatrix, float4( v5, 1 ) ).xyw;
	dvt.v7 = mul( dvViewProjMatrix, float4( v7, 1 ) ).xyw;

#else // #if DECAL_VOLUME_USE_XYW_CORNERS

	DecalVolumeClipSpace dvt;
	dvt.v0 = mul( dvViewProjMatrix, float4( v0, 1 ) );
	dvt.v4 = mul( dvViewProjMatrix, float4( v4, 1 ) );
	dvt.v5 = mul( dvViewProjMatrix, float4( v5, 1 ) );
	dvt.v7 = mul( dvViewProjMatrix, float4( v7, 1 ) );

	//dvt.v1 = mul( dvViewProjMatrix, float4( v1, 1 ) );
	//dvt.v2 = mul( dvViewProjMatrix, float4( v2, 1 ) );
	//dvt.v3 = mul( dvViewProjMatrix, float4( v3, 1 ) );
	//dvt.v6 = mul( dvViewProjMatrix, float4( v6, 1 ) );

#endif // #else // #if DECAL_VOLUME_USE_XYW_CORNERS

	DecalVolume_GetCornersClipSpace( dvt, dvCornersXYW );
}


#define USE_Z_01 0


void DecalVolume_BuildSubFrustumClipSpace( out Frustum frustum, const float3 cellCount, const float3 numCellsXYZF, const float3 cellCountRcp, float3 cellIndex, float nearPlane, float farPlane, float farPlaneOverNearPlane )
{
	frustum = (Frustum)0;

#if DECAL_VOLUME_CLUSTER_3D
	float n = DecalVolume_CalculateSplit( nearPlane, farPlane, farPlaneOverNearPlane, cellIndex.z, cellCountRcp.z );
	float f = DecalVolume_CalculateSplit( nearPlane, farPlane, farPlaneOverNearPlane, cellIndex.z + 1.0f, cellCountRcp.z );
#else // #if DECAL_VOLUME_CLUSTER_3D

//#if DECAL_VOLUME_CLUSTER_USE_MIN_MAX_DEPTH
//	float2 tileMinMaxDepth = inMinMaxDepth.Load( int3( cellIndex.xy, 0 ), 0 );
//	const float tileMinDepth = tileMinMaxDepth.r;
//	// mszymczyk: increase tileMaxDepth slightly so small decals aren't culled when far from camera
//	// TODO: fix this temp hack, it affects culling efficiency, more tiles pass test
//	const float tileMaxDepth = tileMinMaxDepth.g + 0.0002f;
//	float n = nearPlane / tileMaxDepth; // note reverse Z
//	float f = nearPlane / tileMinDepth; // note reverse Z
//#else // #if DECAL_VOLUME_CLUSTER_USE_MIN_MAX_DEPTH
	float n = nearPlane;
	float f = farPlane;
//#endif // #else // #if DECAL_VOLUME_CLUSTER_USE_MIN_MAX_DEPTH

#endif // #else // #if DECAL_VOLUME_CLUSTER_3D

	frustum.clipSpacePlanes[0] = -1 + ( 2.0f * cellCountRcp.x ) * ( cellIndex.x );
	frustum.clipSpacePlanes[1] = -1 + ( 2.0f * cellCountRcp.x ) * ( cellIndex.x + 1 );
	frustum.clipSpacePlanes[2] =  1 - ( 2.0f * cellCountRcp.y ) * ( cellIndex.y + 1 );
	frustum.clipSpacePlanes[3] =  1 - ( 2.0f * cellCountRcp.y ) * ( cellIndex.y );
	frustum.clipSpacePlanes[4] =  n;
	frustum.clipSpacePlanes[5] =  f;

#if USE_Z_01
	nearPlane = 4;
	float farPlane = 1000;
	float nmf = 1.0f / ( nearPlane - farPlane );
	float a = farPlane * nmf;
	float b = nearPlane * farPlane * nmf;

	frustum.clipSpacePlanes[4] = ( -n * a + b ) / n;
	frustum.clipSpacePlanes[5] = ( -f * a + b ) / f;
#endif // #if USE_Z_01
}


// Real-Time Rendering 4th edition
// https://fgiesen.wordpress.com/2010/10/17/view-frustum-culling/
uint DecalVolume_TestFrustumClipSpace( in DecalVolumeClipSpace dvt, in DecalVolumeScaled dv, in Frustum frustum )
{
	float4 corners[8];
#if DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE
	DecalVolume_GetCornersClipSpace( dvt, corners );
#else // DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE
	DecalVolume_GetCornersClipSpace2( dv, corners );
#endif // #else // DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE

	float left = frustum.clipSpacePlanes[0];
	float right = frustum.clipSpacePlanes[1];
	float bottom = frustum.clipSpacePlanes[2];
	float top = frustum.clipSpacePlanes[3];
	float near = frustum.clipSpacePlanes[4];
	float far = frustum.clipSpacePlanes[5];

	bool allOutsideLeft = true;
	bool allOutsideRight = true;
	bool allOutsideBottom = true;
	bool allOutsideTop = true;
	bool allOutsideNear = true;
	bool allOutsideFar = true;

	for ( uint iCorner = 0; iCorner < 8; ++iCorner )
	{
		float4 c = corners[iCorner];
		float x = c.x;
		float y = c.y;
		float z = c.z;
		float w = c.w;

		allOutsideLeft = allOutsideLeft && ( x < left * w );
		allOutsideRight = allOutsideRight && ( x > right * w );

		allOutsideBottom = allOutsideBottom && ( y < bottom * w );
		allOutsideTop = allOutsideTop && ( y > top * w );

#if USE_Z_01
		allOutsideNear = allOutsideNear && ( z < near * w );
		allOutsideFar = allOutsideFar && ( z > far * w );
#else // #if USE_Z_01
		allOutsideNear = allOutsideNear && ( w < near );
		allOutsideFar = allOutsideFar && ( w > far );
#endif // #else // #if USE_Z_01
	}

	bool anyOutside = false
		|| allOutsideLeft
		|| allOutsideRight
		|| allOutsideBottom
		|| allOutsideTop
		|| allOutsideNear
		|| allOutsideFar
		;

	return anyOutside ? 0 : 1;
}


Frustum DecalVolume_BuildFrustum( const uint3 numCellsXYZ, const float3 numCellsXYZF, const float3 numCellsXYZRcp, uint3 cellXYZ )
{
	Frustum outFrustum = (Frustum)0;

#if DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2

	DecalVolume_BuildSubFrustumClipSpace( outFrustum, numCellsXYZ, numCellsXYZF, numCellsXYZRcp, cellXYZ, dvNearFar.x, dvNearFar.y, dvNearFar.z );

#else // #if DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2

	DecalVolume_GetFrustumClusterFaces( outFrustum.faces, dvCellSize.xy, numCellsXYZ, numCellsXYZF, numCellsXYZRcp, cellXYZ, dvTanHalfFov.xy, dvNearFar.x, dvNearFar.y, dvNearFar.z );

#endif // #else // #if DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE

	return outFrustum;
}


uint DecalVolume_TestFrustum( const Frustum frustum, uint decalIndex )
{
	uint intersects;

#if DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2

	const DecalVolumeClipSpace dvt = inDecalVolumesTest[decalIndex];
	const DecalVolumeScaled dv = inDecalVolumes[decalIndex];
	intersects = DecalVolume_TestFrustumClipSpace( dvt, dv, frustum );

#else // #if DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2

	const DecalVolumeScaled dv = inDecalVolumes[decalIndex];
	intersects = DecalVolume_TestFrustumWorldSpaceSATOpt( dv, frustum );

#endif // #else // #if DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2

	return intersects;
}


uint AlignPowerOfTwo( uint value, uint alignment )
{
	alignment--;
	return ( ( value + alignment ) & ~alignment );
}


// divider must be power of two
uint ModuloPowerOfTwo( uint x, uint divider )
{
	return x & ( divider - 1 );
}

uint RoundUpToPowerOfTwo( uint v )
{
	v--;
	v |= v >> 1;
	v |= v >> 2;
	v |= v >> 4;
	v |= v >> 8;
	v |= v >> 16;
	v++;

	return v;
}


uint DecalVolume_GetMaxOutDecalIndices()
{
	return dvPassLimits.x;
}


uint DecalVolume_GetMaxOutDecalIndicesPerCell()
{
	return dvPassLimits.y;
}


uint DecalVolume_GetMaxCurrentOutCellIndirectionsPerBucket()
{
	return dvPassLimits.z;
}


uint DecalVolume_GetMaxPrevOutCellIndirections()
{
	return dvPassLimits.w;
}


uint DecalVolume_GetBucketIndex()
{
	return dvBuckets.x;
}


uint3 DecalVolume_CellCountXYZ()
{
#if DECAL_VOLUME_CLUSTER_3D
	return dvCellCount.xyz;
#else // #if DECAL_VOLUME_CLUSTER_3D
	return uint3( dvCellCount.xy, 1 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D
}


float3 DecalVolume_CellCountXYZ_Float()
{
#if DECAL_VOLUME_CLUSTER_3D
	return dvCellCountF.xyz;
#else // #if DECAL_VOLUME_CLUSTER_3D
	return uint3( dvCellCountF.xy, 1 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D
}


float3 DecalVolume_CellCountXYZRcp()
{
#if DECAL_VOLUME_CLUSTER_3D
	return dvCellCountRcp.xyz;
#else // #if DECAL_VOLUME_CLUSTER_3D
	return float3( dvCellCountRcp.xy, 1 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D
}


uint DecalVolume_CellCountCurrentPass()
{
#if DECAL_VOLUME_CLUSTER_3D
	return dvCellCount.w;
#else // #if DECAL_VOLUME_CLUSTER_3D
	return dvCellCount.w;
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D
}


uint DecalVolume_EncodeCell3D( uint3 cellXYZ )
{
	return ( cellXYZ.x << 20 ) | ( cellXYZ.y << 8 ) | cellXYZ.z;
}


uint3 DecalVolume_DecodeCell3D( uint flatCellIndex )
{
	return uint3( flatCellIndex >> 20, ( flatCellIndex >> 8 ) & 0xfff, flatCellIndex & 0xff );
}


uint DecalVolume_EncodeCell2D( uint2 cellXYZ )
{
	return ( cellXYZ.x << 16 ) | cellXYZ.y;
}


uint2 DecalVolume_DecodeCell2D( uint flatCellIndex )
{
	return uint2( flatCellIndex >> 16, flatCellIndex & 0xffff );
}


uint DecalVolume_EncodeCellCoord( uint3 cellXYZ )
{
#if DECAL_VOLUME_CLUSTER_3D
	return DecalVolume_EncodeCell3D( cellXYZ );
#else // #if DECAL_VOLUME_CLUSTER_3D
	return DecalVolume_EncodeCell2D( cellXYZ.xy );
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D
}


uint3 DecalVolume_DecodeCellCoord( uint flatCellIndex )
{
#if DECAL_VOLUME_CLUSTER_3D
	return DecalVolume_DecodeCell3D( flatCellIndex );
#else // #if DECAL_VOLUME_CLUSTER_3D
	return uint3( DecalVolume_DecodeCell2D( flatCellIndex ), 0 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D
}


void DecalVolume_UnpackGroupToBucket( GroupToBucket gtb, out uint bucket, out uint firstGroup )
{
	bucket = gtb.packedBucketAndFirstGroup & 0xf;
	firstGroup = gtb.packedBucketAndFirstGroup >> 4;
}


void DecalVolume_PackGroupToBucket( uint bucket, uint firstGroup, out GroupToBucket gtb )
{
	gtb.packedBucketAndFirstGroup = bucket | ( firstGroup << 4 );
}


void DecalVolume_OutputCellIndirection( uint3 cellXYZ, uint encodedCellXYZ, uint cellDecalCount, uint offsetToFirstDecalIndex, uint3 numCellsXYZ )
{
#if DECAL_VOLUME_CLUSTER_LAST_PASS

	if ( cellDecalCount > 0 )
	{
#if DECAL_VOLUME_CLUSTER_3D
		uint flatCellIndex = DecalVolume_GetCellFlatIndex3D( cellXYZ, dvCellCount.xyz );
#else // #if DECAL_VOLUME_CLUSTER_3D
		uint flatCellIndex = DecalVolume_GetCellFlatIndex2D( cellXYZ.xy, dvCellCount.xy );
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D

		// offsetToFirstDecalIndex -= DecalVolume_CellCountCurrentPass(); // don't subtract it so respective addition can be removed when drawing
		outDecalVolumeIndices[flatCellIndex] = DecalVolume_PackHeader( cellDecalCount, offsetToFirstDecalIndex );
	}

#else // DECAL_VOLUME_CLUSTER_LAST_PASS

	if ( cellDecalCount > 0 )
	{
		uint maxCellIndirectionsPerBucket = DecalVolume_GetMaxCurrentOutCellIndirectionsPerBucket();
		uint flatCellCount = DecalVolume_CellCountCurrentPass();

		CellIndirection ci;
		ci.offsetToFirstDecalIndex = offsetToFirstDecalIndex;
		ci.decalCount = cellDecalCount;

#if DECAL_VOLUME_CLUSTER_BUCKETS
		uint np2 = min( RoundUpToPowerOfTwo( cellDecalCount ), 64 ); // 64 == 1 << (DECAL_VOLUME_CLUSTER_MAX_BUCKETS-1)
		uint cellSlot = firstbitlow( np2 );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
		uint cellSlot = 0;
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS

#if DECAL_VOLUME_CLUSTER_3D

		// Could use counter/GDS
		uint cellIndirectionIndex;
		InterlockedAdd( outCellIndirectionCount[cellSlot], 8, cellIndirectionIndex );

		if ( cellIndirectionIndex / 8 < maxCellIndirectionsPerBucket )
		{

#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
			ci.cellIndex = encodedCellXYZ;
			outCellIndirection[safe_mad24( cellSlot, maxCellIndirectionsPerBucket, cellIndirectionIndex / 8 )] = ci;
#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
			for ( uint i = 0; i < 8; ++i )
			{
				uint slice = i / 4;
				uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
				uint tile = i % 4;
				uint row = tile / 2;
				uint col = tile % 2;
				ci.cellIndex = DecalVolume_EncodeCell3D( uint3( safe_mad24( cellXYZ.x, 2, col ), safe_mad24( cellXYZ.y, 2, row ), safe_mad24( cellXYZ.z, 2, slice ) ) );

				outCellIndirection[cellIndirectionIndex + i + cellSlot * maxCellIndirectionsPerBucket * 8] = ci;
			}
#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

		}

#else // #if DECAL_VOLUME_CLUSTER_3D

		// Could use counter/GDS
		uint cellIndirectionIndex;
		InterlockedAdd( outCellIndirectionCount[cellSlot], 4, cellIndirectionIndex );

		if ( cellIndirectionIndex / 4 < maxCellIndirectionsPerBucket )
		{

#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
			ci.cellIndex = encodedCellXYZ;
			outCellIndirection[safe_mad24( cellSlot, maxCellIndirectionsPerBucket, cellIndirectionIndex / 4 )] = ci;
#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

			for ( uint i = 0; i < 4; ++i )
			{
				uint row = i / 2;
				uint col = i % 2;
				ci.cellIndex = DecalVolume_EncodeCell2D( uint2( safe_mad24( cellXYZ.x, 2, col ), safe_mad24( cellXYZ.y, 2, row ) ) );

				outCellIndirection[cellIndirectionIndex + i + cellSlot * flatCellCount * 4] = ci;
			}

#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

		}

#endif // #else // #if DECAL_VOLUME_CLUSTER_3D
	}
#endif // #else // DECAL_VOLUME_CLUSTER_LAST_PASS
}
