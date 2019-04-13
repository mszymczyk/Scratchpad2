#include "Gfx_pch.h"
#include "ViewFrustum.h"

#if defined(_MSC_VER) && defined(_DEBUG)
#define new _DEBUG_NEW
#endif
//
//
//inline const Vector3 unprojectNormalized( const Vector3& screenPos01, const Matrix4& inverseMatrix )
//{
//	// z maps to  <-1,1>
//	//
//	const floatInVec one( 1.0f );
//	Vector4 hpos = Vector4( screenPos01, one );
//	hpos = mulPerElem( hpos, Vector4( 2.0f ) ) - Vector4( one );
//	Vector4 worldPos = inverseMatrix * hpos;
//	worldPos /= worldPos.getW();
//	return worldPos.getXYZ();
//}
//
//inline const Vector3 unprojectNormalizedDx( const Vector3& screenPos01, const Matrix4& inverseMatrix )
//{
//	// z maps to <0,1>
//	//
//	const floatInVec one( 1.0f );
//	const floatInVec zer( 0.0f );
//	Vector4 hpos = Vector4( screenPos01, one );
//	hpos = mulPerElem( hpos, Vector4( 2.0f, 2.0f, 1.0f, 1.0f ) ) - Vector4( one, one, zer, zer );
//	Vector4 worldPos = inverseMatrix * hpos;
//	worldPos /= worldPos.getW();
//	return worldPos.getXYZ();
//}

void extractFrustumCorners( Vector3 dst[8], const Matrix4& viewProjection, bool dxStyleZProjection )
{
	const Matrix4 vpInv = inverse( viewProjection );

	const Vector3 leftUpperNear = Vector3( 0, 1, 0 );
	const Vector3 leftUpperFar = Vector3( 0, 1, 1 );
	const Vector3 leftLowerNear = Vector3( 0, 0, 0 );
	const Vector3 leftLowerFar = Vector3( 0, 0, 1 );

	const Vector3 rightLowerNear = Vector3( 1, 0, 0 );
	const Vector3 rightLowerFar = Vector3( 1, 0, 1 );
	const Vector3 rightUpperNear = Vector3( 1, 1, 0 );
	const Vector3 rightUpperFar = Vector3( 1, 1, 1 );

	if (dxStyleZProjection)
	{
		dst[0] = unprojectNormalizedDx( leftUpperNear, vpInv );
		dst[1] = unprojectNormalizedDx( leftUpperFar, vpInv );
		dst[2] = unprojectNormalizedDx( leftLowerNear, vpInv );
		dst[3] = unprojectNormalizedDx( leftLowerFar, vpInv );

		dst[4] = unprojectNormalizedDx( rightLowerNear, vpInv );
		dst[5] = unprojectNormalizedDx( rightLowerFar, vpInv );
		dst[6] = unprojectNormalizedDx( rightUpperNear, vpInv );
		dst[7] = unprojectNormalizedDx( rightUpperFar, vpInv );
	}
	else
	{
		dst[0] = unprojectNormalized( leftUpperNear, vpInv );
		dst[1] = unprojectNormalized( leftUpperFar, vpInv );
		dst[2] = unprojectNormalized( leftLowerNear, vpInv );
		dst[3] = unprojectNormalized( leftLowerFar, vpInv );

		dst[4] = unprojectNormalized( rightLowerNear, vpInv );
		dst[5] = unprojectNormalized( rightLowerFar, vpInv );
		dst[6] = unprojectNormalized( rightUpperNear, vpInv );
		dst[7] = unprojectNormalized( rightUpperFar, vpInv );
	}
}

inline void toSoa( Vector4& xxxx, Vector4& yyyy, Vector4& zzzz, Vector4& wwww,
	const Vector4& vec0, const Vector4& vec1, const Vector4& vec2, const Vector4& vec3 )
{
	Vector4 tmp0, tmp1, tmp2, tmp3;
	tmp0 = Vector4( vec_mergeh( vec0.get128(), vec2.get128() ) );
	tmp1 = Vector4( vec_mergeh( vec1.get128(), vec3.get128() ) );
	tmp2 = Vector4( vec_mergel( vec0.get128(), vec2.get128() ) );
	tmp3 = Vector4( vec_mergel( vec1.get128(), vec3.get128() ) );
	xxxx = Vector4( vec_mergeh( tmp0.get128(), tmp1.get128() ) );
	yyyy = Vector4( vec_mergel( tmp0.get128(), tmp1.get128() ) );
	zzzz = Vector4( vec_mergeh( tmp2.get128(), tmp3.get128() ) );
	wwww = Vector4( vec_mergel( tmp2.get128(), tmp3.get128() ) );
}

inline void toAos( Vector4& vec0, Vector4& vec1, Vector4& vec2, Vector4& vec3,
	const Vector4& xxxx, const Vector4& yyyy, const Vector4& zzzz, const Vector4& wwww )
{
	vec0 = Vector4( xxxx.getX(), yyyy.getX(), zzzz.getX(), wwww.getX() );
	vec1 = Vector4( xxxx.getY(), yyyy.getY(), zzzz.getY(), wwww.getY() );
	vec2 = Vector4( xxxx.getZ(), yyyy.getZ(), zzzz.getZ(), wwww.getZ() );
	vec3 = Vector4( xxxx.getW(), yyyy.getW(), zzzz.getW(), wwww.getW() );
}

void extractFrustumPlanes( Vector4 planes[6], const Matrix4& vp )
{
	floatInVec lengthInv;

	// each plane must be normalized, normalization formula is quite self explanatory

	planes[0] = vp.getRow( 0 ) + vp.getRow( 3 );
	lengthInv = floatInVec( 1.0f ) / length( planes[0].getXYZ() );
	planes[0] = Vector4( planes[0].getXYZ() * lengthInv, planes[0].getW() * lengthInv );

	planes[1] = -vp.getRow( 0 ) + vp.getRow( 3 );
	lengthInv = floatInVec( 1.0f ) / length( planes[1].getXYZ() );
	planes[1] = Vector4( planes[1].getXYZ() * lengthInv, planes[1].getW() * lengthInv );

	planes[2] = vp.getRow( 1 ) + vp.getRow( 3 );
	lengthInv = floatInVec( 1.0f ) / length( planes[2].getXYZ() );
	planes[2] = Vector4( planes[2].getXYZ() * lengthInv, planes[2].getW() * lengthInv );

	planes[3] = -vp.getRow( 1 ) + vp.getRow( 3 );
	lengthInv = floatInVec( 1.0f ) / length( planes[3].getXYZ() );
	planes[3] = Vector4( planes[3].getXYZ() * lengthInv, planes[3].getW() * lengthInv );

	planes[4] = vp.getRow( 2 ) + vp.getRow( 3 );
	lengthInv = floatInVec( 1.0f ) / length( planes[4].getXYZ() );
	planes[4] = Vector4( planes[4].getXYZ() * lengthInv, planes[4].getW() * lengthInv );

	planes[5] = -vp.getRow( 2 ) + vp.getRow( 3 );
	lengthInv = floatInVec( 1.0f ) / length( planes[5].getXYZ() );
	planes[5] = Vector4( planes[5].getXYZ() * lengthInv, planes[5].getW() * lengthInv );
}

ViewFrustum extractFrustum( const Matrix4& vp, bool dxStyleProjection )
{
	// http://www.lighthouse3d.com/opengl/viewfrustum/index.php?clipspace
	//
	ViewFrustum f;

	extractFrustumPlanes( f.planes, vp );

	f.planes[ViewFrustum::ePlane_ext0] = f.planes[ViewFrustum::ePlane_near];
	f.planes[ViewFrustum::ePlane_ext1] = f.planes[ViewFrustum::ePlane_far];

	toSoa( f.xPlaneLRBT, f.yPlaneLRBT, f.zPlaneLRBT, f.wPlaneLRBT,
		f.planes[0], f.planes[1], f.planes[2], f.planes[3] );
	toSoa( f.xPlaneNFNF, f.yPlaneNFNF, f.zPlaneNFNF, f.wPlaneNFNF,
		f.planes[4], f.planes[5], f.planes[6], f.planes[7] );

	extractFrustumCorners( f.corners, vp, dxStyleProjection );

	return f;
}

#define USE_OBB_FRUSTUM_EARLY_ACCEPT 1
#define USE_OBB_FRUSTUM_FACE_AXES 0
#define USE_OBB_FRUSTUM_EDGE_CROSSES 1 // full test


float3 GetTriangleAxis( const HLSL_in float3 a, const HLSL_in float3 b, const HLSL_in float3 c )
{
	float3 ab = b - a;
	float3 ac = c - a;
	return cross( ac, ab );
}


float3 GetFrustumAxis( const HLSL_in FrustumFace frustumFaces[2], int axisIndex )
{
	// NOTE: These if statements are meant to be evaluated and removed at compile time after loop unrolling.
	//       The idea is to avoid storing frustumAxes HLSL_in registers. Maybe worth???

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


bool AreIntervalsDisjoint( const HLSL_in float2 a, const HLSL_in float2 b )
{
	return ( a.y < b.x ) || ( b.y < a.x );
}


void ExtendIntervalWithValue( const float x, HLSL_inout float2 HLSL_CPP_inout inOutInterval )
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


void ExtendIntervalWithInterval( const float2 v, HLSL_inout float2 HLSL_CPP_inout inOutInterval )
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


float2 GetObbProjectedInterval( const HLSL_in OrientedBoundingBox obb, const HLSL_in float3 axis )
{
	const float centerProjectionOBB = dot( obb.center, axis );

	// TODO: the halfSize can be premultiplied into the obb.axis vectors to save some computation. I'm not sure if that will break other code that relies on this header though...

	const float extentsProjectionOBB
		= abs( dot( obb.axes[0], axis ) * obb.halfSize.x )
		+ abs( dot( obb.axes[1], axis ) * obb.halfSize.y )
		+ abs( dot( obb.axes[2], axis ) * obb.halfSize.z );

	return float2( centerProjectionOBB - extentsProjectionOBB, centerProjectionOBB + extentsProjectionOBB );
}


float2 GetFrustumFaceProjectedInterval( const HLSL_in FrustumFace ff, const HLSL_in float3 axis )
{
	const float centerProjectionFF = dot( ff.center, axis );

	const float extentsProjectionFF
		= abs( dot( ff.axes[0], axis ) )
		+ abs( dot( ff.axes[1], axis ) );

	return float2( centerProjectionFF - extentsProjectionFF, centerProjectionFF + extentsProjectionFF );
}


float2 GetFrustumProjectedInterval( const HLSL_in FrustumFace frustumFaces[2], const HLSL_in float3 axis )
{
	float2 outInterval = GetFrustumFaceProjectedInterval( frustumFaces[0], axis );
	ExtendIntervalWithInterval( GetFrustumFaceProjectedInterval( frustumFaces[1], axis ), outInterval );
	return outInterval;
}


bool R_AreFrustumObbProjectedIntervalsDisjoint( const HLSL_in OrientedBoundingBox obb, const HLSL_in FrustumFace frustumFaces[2], const HLSL_in float3 axis )
{
	const float2 obbInterval = GetObbProjectedInterval( obb, axis );
	float2 frustumInterval = GetFrustumProjectedInterval( frustumFaces, axis );
	return AreIntervalsDisjoint( frustumInterval, obbInterval );
}


int IsAinB( const HLSL_in float2 a, const HLSL_in float2 b )
{
	return ( b.x <= a.x ) && ( a.y <= b.y ) ? 1 : 0;
}


bool R_AreFrustumObbProjectedIntervalsDisjointMask( const HLSL_in OrientedBoundingBox obb, const HLSL_in FrustumFace frustumFaces[2], const HLSL_in float3 axis, HLSL_inout int containmentMask )
{
	const float2 obbInterval = GetObbProjectedInterval( obb, axis );
	float2 frustumInterval = GetFrustumProjectedInterval( frustumFaces, axis );

	containmentMask = ( containmentMask << 1 ) | IsAinB( frustumInterval, obbInterval );
	return AreIntervalsDisjoint( frustumInterval, obbInterval );
}


// Subroutine of TestFrustumObbIntersectionSAT()
bool IsFrustumEdgeVsBoxAxesProjectionDisjoint( const HLSL_in OrientedBoundingBox obb, const HLSL_in FrustumFace frustumFaces[2], const float3 frustumEdgeVertexA, const HLSL_in float3 frustumEdgeVertexB )
{
	const float3 frustumEdgeDir = frustumEdgeVertexA - frustumEdgeVertexB;

	HLSL_LOOP
	for ( uint axisIndex = 0; axisIndex < 3; axisIndex++ )
	{
		if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, cross( frustumEdgeDir, obb.axes[0] ) ) )
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
// We test each of these HLSL_in turn.

bool TestFrustumObbIntersectionSAT( const HLSL_in OrientedBoundingBox obb, const HLSL_in FrustumFace frustumFaces[2] )
{
	/// Test box axes
	// these are cheap to evaluate, and are orthogonal
	// also, there is potential to early out, so do first
	int containmentMask = 0;

	HLSL_UNROLL
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

void GetFrustumClusterFaces( HLSL_out FrustumFace faces[2], float3 eyeAxis[3], float3 eyeOffset, float2 cellSize, float3 cellCount, float3 cellCountF, float3 cellCountRcp, float3 cellIndex, float2 tanHalfFov, float nearPlane, float farPlane, float farPlaneOverNearPlane, bool farClip )
{
	// clip-space (-1,1) position of the view ray through the centroid of the cluster frustum projected on screen
	float2 uv = ( cellIndex.xy + float2( 0.5f, 0.5f ) ) * cellCountRcp.xy;
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
	//float3 eyeAxis[3];
	//eyeAxis[0] = dvEyeAxisX.xyz;
	//eyeAxis[1] = dvEyeAxisY.xyz;
	//eyeAxis[2] = dvEyeAxisZ.xyz;
	//float3 eyeOffset = dvEyeOffset.xyz;

	faces[0].center = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv, depth0 );
	faces[0].axes[0] = eyeAxis[0] * projHalfSize.xxx * depth0;
	faces[0].axes[1] = eyeAxis[1] * projHalfSize.yyy * depth0;

	faces[1].center = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv, depth1 );
	faces[1].axes[0] = eyeAxis[0] * projHalfSize.xxx * depth1;
	faces[1].axes[1] = eyeAxis[1] * projHalfSize.yyy * depth1;

	float2 uv00 = cellIndex.xy * cellCountRcp.xy;
	float2 uv10 = ( cellIndex.xy + float2( 1, 0.5f ) ) * cellCountRcp.xy;
	float2 uv01 = ( cellIndex.xy + float2( 0.5f, 1 ) ) * cellCountRcp.xy;

	float3 c100 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( float2( uv10 ) * 2.0f - float2( 1, 1 ) ) * float2( 1, -1 ), depth0 );
	float3 c101 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( float2( uv10 ) * 2.0f - float2( 1, 1 ) ) * float2( 1, -1 ), depth1 );
	float3 c010 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( float2( uv01 ) * 2.0f - float2( 1, 1 ) ) * float2( 1, -1 ), depth0 );
	float3 c011 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( float2( uv01 ) * 2.0f - float2( 1, 1 ) ) * float2( 1, -1 ), depth1 );

	//faces[0].axes[0] = ( c100 - faces[0].center );
	//faces[0].axes[1] = ( c010 - faces[0].center );
	//faces[1].axes[0] = ( c101 - faces[1].center );
	//faces[1].axes[1] = ( c011 - faces[1].center );
}                