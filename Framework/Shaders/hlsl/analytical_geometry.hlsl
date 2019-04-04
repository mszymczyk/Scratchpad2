#ifndef ANALYTICAL_GEOMETRY_HLSL
#define ANALYTICAL_GEOMETRY_HLSL

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

#ifndef USE_OBB_FRUSTUM_EARLY_ACCEPT
#define USE_OBB_FRUSTUM_EARLY_ACCEPT		1
#endif

#ifndef USE_OBB_FRUSTUM_FACE_AXES
#define USE_OBB_FRUSTUM_FACE_AXES			1
#endif

#ifndef USE_OBB_FRUSTUM_EDGE_CROSSES
#define USE_OBB_FRUSTUM_EDGE_CROSSES		1
#endif


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

#endif // #ifndef ANALYTICAL_GEOMETRY_HLSL