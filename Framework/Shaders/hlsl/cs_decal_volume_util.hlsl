StructuredBuffer<DecalVolume> inDecalVolumes           REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS;
StructuredBuffer<DecalVolumeTest> inDecalVolumesTest   REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_TEST;
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

struct Frustum
{
	// left, right, bottom, top, near, far
	float4 planes[6];
	float3 frustumCorners[8];
	// left, right, bottom, top, near, far
	float clipSpacePlanes[6];
};


void DecalVolume_ExtractFrustumPlanesDxRhs( out float4 planes[6], float4x4 vp )
{
	planes[0] = vp[0] + vp[3]; // left
	planes[1] = -vp[0] + vp[3]; // right
	planes[2] = vp[1] + vp[3]; // bottom
	planes[3] = -vp[1] + vp[3]; // top
	planes[4] = vp[2]; // near     + vp[3] omitted for near plane // near
	planes[5] = -vp[2] + vp[3]; // far

	for ( int i = 0; i < 6; ++i )
	{
		float lenRcp = 1.0f / length( planes[i].xyz );
		planes[i] *= lenRcp;
	}
}


float3 PlanesIntersect( float4 p1, float4 p2, float4 p3 )
{
	float denom = dot( p1.xyz, cross( p2.xyz, p3.xyz ) );
	return rcp( -denom ) * (
		cross( p2.xyz, p3.xyz ) * p1.w +
		cross( p3.xyz, p1.xyz ) * p2.w +
		cross( p1.xyz, p2.xyz ) * p3.w );
}


void DecalVolume_ExtractFrustumCorners( out float3 frustumCorners[8], float4 frustumPlanes[6] )
{
	frustumCorners[0] = PlanesIntersect( frustumPlanes[0], frustumPlanes[2], frustumPlanes[4] );
	frustumCorners[1] = PlanesIntersect( frustumPlanes[0], frustumPlanes[2], frustumPlanes[5] );
	frustumCorners[2] = PlanesIntersect( frustumPlanes[0], frustumPlanes[3], frustumPlanes[4] );
	frustumCorners[3] = PlanesIntersect( frustumPlanes[0], frustumPlanes[3], frustumPlanes[5] );
	frustumCorners[4] = PlanesIntersect( frustumPlanes[1], frustumPlanes[2], frustumPlanes[4] );
	frustumCorners[5] = PlanesIntersect( frustumPlanes[1], frustumPlanes[2], frustumPlanes[5] );
	frustumCorners[6] = PlanesIntersect( frustumPlanes[1], frustumPlanes[3], frustumPlanes[4] );
	frustumCorners[7] = PlanesIntersect( frustumPlanes[1], frustumPlanes[3], frustumPlanes[5] );
}


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


void DecalVolume_BuildSubFrustumWorldSpace( out Frustum frustum, const float3 cellCount, const float3 cellCountF, const float3 cellCountRcp, float3 cellIndex, float2 tanHalfFovRcp, float4x4 viewMatrix, float nearPlane, float farPlane, float farPlaneOverNearPlane )
{
	frustum = (Frustum)0;

#if DECAL_VOLUME_CLUSTER_3D
	float n = DecalVolume_CalculateSplit( nearPlane, farPlane, farPlaneOverNearPlane, cellIndex.z, cellCountRcp.z );
	float f = DecalVolume_CalculateSplit( nearPlane, farPlane, farPlaneOverNearPlane, cellIndex.z + 1.0f, cellCountRcp.z );
#else // #if DECAL_VOLUME_CLUSTER_3D
	float n = nearPlane;
	float f = farPlane;
#endif // #else // #if DECAL_VOLUME_CLUSTER_3D

	float nmf = 1.0f / ( n - f );
	float a = f * nmf;
	float b = n * f * nmf;

	float tileScaleX = cellCountF.x;
	float tileScaleY = cellCountF.y;

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

	DecalVolume_ExtractFrustumPlanesDxRhs( frustum.planes, viewProj );
	DecalVolume_ExtractFrustumCorners( frustum.frustumCorners, frustum.planes );
}


// Real-Time Rendering, 3rd Edition - 16.10.1, 16.14.3 (p. 755, 777)
uint DecalVolume_FrustumOBBIntersectOptimized( float4 frustumPlanes[6], float3 boxPosition, float3 boxHalfSize, float3 boxX, float3 boxY, float3 boxZ )
{
	//[unroll]
	for ( int i = 0; i < 6; ++i )
	{
		float3 n = frustumPlanes[i].xyz;
		float e = boxHalfSize.x*abs( dot( n, boxX ) )
			+ boxHalfSize.y*abs( dot( n, boxY ) )
			+ boxHalfSize.z*abs( dot( n, boxZ ) );
		float s = dot( boxPosition, n ) + frustumPlanes[i].w;
		if ( s + e < 0 ) // or s > e, depending if planes point inward or outward, here normals point inward
			return 0;
	}

	return 1;
}


// Less false positives, great if near and far frustum planes are compact.
// http://www.iquilezles.org/www/articles/frustumcorrect/frustumcorrect.htm
bool DecalVolume_FrustumOBBIntersectTwoway( float4 frustumPlanes[6], float3 frustumCorners[8], float4 boxPlanes[6], float3 boxPosition, float3 boxHalfSize, float3 boxX, float3 boxY, float3 boxZ )
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


struct OrientedBoundingBox
{
	float3 center;
	float3 x_axis;
	float3 y_axis;
	float3 z_axis;
	float3 halfSize;
};


float2 GetFrustumProjectedInterval( const in float3 frustumVertices[8], const in float3 axis )
{
	const float projection0 = dot( frustumVertices[0], axis );
	float2 outInterval = float2( projection0, projection0 );

	[unroll]
	for ( uint vertexIndex = 1; vertexIndex < 8; vertexIndex++ )
	{
		const float projection = dot( frustumVertices[vertexIndex], axis );

		outInterval.x = min( outInterval.x, projection );
		outInterval.y = max( outInterval.y, projection );
	}

	return outInterval;
}


float2 GetObbProjectedInterval( const in OrientedBoundingBox obb, const in float3 axis )
{
	const float centerProjection = dot( obb.center, axis );

	const float extentsProjection = abs( dot( obb.x_axis, axis ) * obb.halfSize.x )
		+ abs( dot( obb.y_axis, axis ) * obb.halfSize.y )
		+ abs( dot( obb.z_axis, axis ) * obb.halfSize.z );

	return float2( centerProjection - extentsProjection, centerProjection + extentsProjection );
}


bool R_AreFrustumObbProjectedIntervalsDisjoint( const in OrientedBoundingBox obb, const float3 frustumVertices[8], const float3 axis )
{
	const float2 obbInterval = GetObbProjectedInterval( obb, axis );
	const float2 frustumInterval = GetFrustumProjectedInterval( frustumVertices, axis );

	return ( frustumInterval.y < obbInterval.x ) || ( obbInterval.y < frustumInterval.x );
}


// Subroutine of TestFrustumObbIntersectionSAT()
bool IsFrustumEdgeVsBoxAxesProjectionDisjoint( const in OrientedBoundingBox obb, const in float3 frustumVertices[8], const float3 frustumAxis )
{
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumVertices, cross( frustumAxis, obb.x_axis ) ) )
	{
		return true;
	}
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumVertices, cross( frustumAxis, obb.y_axis ) ) )
	{
		return true;
	}
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumVertices, cross( frustumAxis, obb.z_axis ) ) )
	{
		return true;
	}
	return false;
}


// Frustum Obb Intersection
//
// Use a Separating Axis Test (SAT) to determine if there is an intersection.
// Two convex volumes do not intersect if there is any axis over which projections of the volumes are separate.
// The separating axes for convex polytope must be one of the face normals of each shape or the cross products between the edges of the shapes.
// We test each of these in turn.
//
bool TestFrustumObbIntersectionSAT( const in OrientedBoundingBox obb, const in float3 frustumVertices[8], const in float3 frustumAxes[5] )
{
	// Test axes of frustum planes (count is 5 as near and far planes share an axis)
	[unroll]
	for ( uint axisIndex = 0; axisIndex < 5; axisIndex++ )
	{
		if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumVertices, frustumAxes[axisIndex] ) )
		{
			return false;
		}
	}

	// Test box axes
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumVertices, obb.x_axis ) )
	{
		return false;
	}
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumVertices, obb.y_axis ) )
	{
		return false;
	}
	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumVertices, obb.z_axis ) )
	{
		return false;
	}

	// Test each frustum edge crossed with each box axis

	// Test view corner axes (view Z direction)
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumVertices, frustumVertices[0] - frustumVertices[4] ) )
	{
		return false;
	}
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumVertices, frustumVertices[1] - frustumVertices[5] ) )
	{
		return false;
	}
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumVertices, frustumVertices[2] - frustumVertices[6] ) )
	{
		return false;
	}
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumVertices, frustumVertices[3] - frustumVertices[7] ) )
	{
		return false;
	}

	// Test view axes (view X and Y axes)
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumVertices, frustumVertices[0] - frustumVertices[1] ) )
	{
		return false;
	}
	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumVertices, frustumVertices[0] - frustumVertices[2] ) )
	{
		return false;
	}

	return true;
}


uint DecalVolume_TestFrustumWorldSpace( in DecalVolume dv, in Frustum frustum, bool twoTests )
{
	float4 boxPlanes[6];
	boxPlanes[0] = float4( dv.x.xyz, -dot( dv.position.xyz - dv.x.xyz*dv.halfSize.x, dv.x.xyz ) );
	boxPlanes[1] = float4( -dv.x.xyz, -dot( dv.position.xyz + dv.x.xyz*dv.halfSize.x, -dv.x.xyz ) );
	boxPlanes[2] = float4( dv.y.xyz, -dot( dv.position.xyz - dv.y.xyz*dv.halfSize.y, dv.y.xyz ) );
	boxPlanes[3] = float4( -dv.y.xyz, -dot( dv.position.xyz + dv.y.xyz*dv.halfSize.y, -dv.y.xyz ) );
	boxPlanes[4] = float4( dv.z.xyz, -dot( dv.position.xyz - dv.z.xyz*dv.halfSize.z, dv.z.xyz ) );
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

	if ( twoTests )
	{
		return DecalVolume_FrustumOBBIntersectTwoway( frustum.planes, frustum.frustumCorners, boxPlanes, dv.position.xyz, dv.halfSize.xyz, dv.x.xyz, dv.y.xyz, dv.z.xyz );
	}
	else
	{
		return DecalVolume_FrustumOBBIntersectOptimized( frustum.planes, dv.position.xyz, dv.halfSize.xyz, dv.x.xyz, dv.y.xyz, dv.z.xyz );
	}
}


uint DecalVolume_TestFrustumWorldSpaceSAT( in DecalVolume dv, in Frustum frustum )
{
	OrientedBoundingBox obb;
	obb.center = dv.position;
	obb.halfSize = dv.halfSize;
	obb.x_axis = dv.x;
	obb.y_axis = dv.y;
	obb.z_axis = dv.z;

	float3 frustumAxes[5];
	for ( uint i = 0; i < 5; ++i )
	{
		frustumAxes[i] = frustum.planes[i].xyz;
	}

	return TestFrustumObbIntersectionSAT( obb, frustum.frustumCorners, frustumAxes ) ? 1 : 0;
}


void DecalVolume_GetCornersClipSpace( DecalVolumeTest dv, out float4 dvCornersXYW[8] )
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

	//dvCornersXYW[1] = dv.v1;
	//dvCornersXYW[2] = dv.v2;
	//dvCornersXYW[3] = dv.v3;
	//dvCornersXYW[6] = dv.v6;

#endif // #else // #if DECAL_VOLUME_USE_XYW_CORNERS
}


void DecalVolume_GetCornersClipSpace2( DecalVolume dv, out float4 dvCornersXYW[8] )
{
	float3 center = dv.position;
	float3 xs = dv.x * dv.halfSize.x;
	float3 ys = dv.y * dv.halfSize.y;
	float3 zs = dv.z * dv.halfSize.z;

	float3 v0 = center - xs - ys + zs;
	float3 v4 = center - xs - ys - zs;
	float3 v5 = center + xs - ys - zs;
	float3 v7 = center - xs + ys - zs;

	float3 v1 = center + xs - ys + zs;
	float3 v2 = center + xs + ys + zs;
	float3 v3 = center - xs + ys + zs;
	float3 v6 = center + xs + ys - zs;

#if DECAL_VOLUME_USE_XYW_CORNERS

	DecalVolumeTest dvt;
	dvt.v0 = mul( dvViewProjMatrix, float4( v0, 1 ) ).xyw;
	dvt.v4 = mul( dvViewProjMatrix, float4( v4, 1 ) ).xyw;
	dvt.v5 = mul( dvViewProjMatrix, float4( v5, 1 ) ).xyw;
	dvt.v7 = mul( dvViewProjMatrix, float4( v7, 1 ) ).xyw;

#else // #if DECAL_VOLUME_USE_XYW_CORNERS

	DecalVolumeTest dvt;
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

#if DECAL_VOLUME_CLUSTER_USE_MIN_MAX_DEPTH
	float2 tileMinMaxDepth = inMinMaxDepth.Load( int3( cellIndex.xy, 0 ), 0 );
	const float tileMinDepth = tileMinMaxDepth.r;
	// mszymczyk: increase tileMaxDepth slightly so small decals aren't culled when far from camera
	// TODO: fix this temp hack, it affects culling efficiency, more tiles pass test
	const float tileMaxDepth = tileMinMaxDepth.g + 0.0002f;
	float n = nearPlane / tileMaxDepth; // note reverse Z
	float f = nearPlane / tileMinDepth; // note reverse Z
#else // #if DECAL_VOLUME_CLUSTER_USE_MIN_MAX_DEPTH
	float n = nearPlane;
	float f = farPlane;
#endif // #else // #if DECAL_VOLUME_CLUSTER_USE_MIN_MAX_DEPTH

#endif // #else // #if DECAL_VOLUME_CLUSTER_3D

	frustum.clipSpacePlanes[0] = -1 + ( 2.0f * cellCountRcp.x ) * ( cellIndex.x );
	frustum.clipSpacePlanes[1] = -1 + ( 2.0f * cellCountRcp.x ) * ( cellIndex.x + 1 );
	frustum.clipSpacePlanes[2] = 1 - ( 2.0f * cellCountRcp.y ) * ( cellIndex.y + 1 );
	frustum.clipSpacePlanes[3] = 1 - ( 2.0f * cellCountRcp.y ) * ( cellIndex.y );
	frustum.clipSpacePlanes[4] = n;
	frustum.clipSpacePlanes[5] = f;

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
uint DecalVolume_TestFrustumClipSpace( in DecalVolumeTest dvt, in DecalVolume dv, in Frustum frustum )
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

#if DECAL_VOLUME_INTERSECTION_METHOD == 0
	DecalVolume_BuildSubFrustumWorldSpace( outFrustum, numCellsXYZ, numCellsXYZF, numCellsXYZRcp, cellXYZ, dvTanHalfFov.zw, dvViewMatrix, dvNearFar.x, dvNearFar.y, dvNearFar.z );
#elif DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2
	DecalVolume_BuildSubFrustumClipSpace( outFrustum, numCellsXYZ, numCellsXYZF, numCellsXYZRcp, cellXYZ, dvNearFar.x, dvNearFar.y, dvNearFar.z );
#else // #elif DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2
	DecalVolume_BuildSubFrustumWorldSpace( outFrustum, numCellsXYZ, numCellsXYZF, numCellsXYZRcp, cellXYZ, dvTanHalfFov.zw, dvViewMatrix, dvNearFar.x, dvNearFar.y, dvNearFar.z );
#endif // #else // #elif DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE

	return outFrustum;
}


uint DecalVolume_TestFrustum( const Frustum frustum, uint decalIndex )
{
	uint intersects;

#if DECAL_VOLUME_INTERSECTION_METHOD == 0
	const DecalVolume dv = inDecalVolumes[decalIndex];
	intersects = DecalVolume_TestFrustumWorldSpace( dv, frustum, false );
#elif DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2
	const DecalVolumeTest dvt = inDecalVolumesTest[decalIndex];
	const DecalVolume dv = inDecalVolumes[decalIndex];
	intersects = DecalVolume_TestFrustumClipSpace( dvt, dv, frustum );
#else // #elif DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2
	const DecalVolume dv = inDecalVolumes[decalIndex];
	intersects = DecalVolume_TestFrustumWorldSpaceSAT( dv, frustum );
#endif // #else // #elif DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE || DECAL_VOLUME_INTERSECTION_METHOD == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2

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
