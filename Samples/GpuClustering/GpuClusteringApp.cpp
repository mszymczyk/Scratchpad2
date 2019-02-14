#include "GpuClustering_pch.h"
#include "GpuclusteringApp.h"
#include <AppBase/Input.h>
#include <Gfx\Dx11/Dx11DeviceStates.h>
#include <Gfx\DebugDraw.h>
#include <random>
#include <Imgui\imgui_include.h>
#include <Util\Bits.h>
#include <Gfx\Math\HLSLEmulation.h>
#include <Gfx\Math\ViewFrustum.h>

namespace spad
{
	const float testFrustumNearPlane = 4.0f;

	float calcZ( float nearPlane, float farPlane, uint zIndex, uint zMax )
	{
		float n = nearPlane * pow( farPlane / nearPlane, (float)zIndex / zMax );
		return n;
	}

	float calcZ2( float nearPlane, float farPlane, uint zIndex, uint zMax )
	{
		//float n = nearPlane * pow( farPlane / nearPlane, (float)zIndex / zMax );
		float n = nearPlane + ( farPlane - nearPlane ) * (float)zIndex / (float)zMax;
		return n;
	}
	
	void buildFrustumClip( float clipSpacePlanes[6], uint cellCountX, uint cellCountY, uint cellCountZ, uint cellIndexX, uint cellIndexY, uint cellIndexZ, float nearPlane, float farPlaneOverNearPlane )
	{
		float n = nearPlane * pow( abs( farPlaneOverNearPlane ), (float)( cellIndexZ     ) / cellCountZ );
		float f = nearPlane * pow( abs( farPlaneOverNearPlane ), (float)( cellIndexZ + 1 ) / cellCountZ );

		clipSpacePlanes[0] = -1 + ( 2.0f / cellCountX ) * ( cellIndexX );
		clipSpacePlanes[1] = -1 + ( 2.0f / cellCountX ) * ( cellIndexX + 1 );
		clipSpacePlanes[2] = 1 - ( 2.0f / cellCountY ) * ( cellIndexY + 1 );
		clipSpacePlanes[3] = 1 - ( 2.0f / cellCountY ) * ( cellIndexY );
		clipSpacePlanes[4] = n;
		clipSpacePlanes[5] = f;

#if USE_Z_01
		nearPlane = 4;
		float farPlane = 1000;
		float nmf = 1.0f / ( nearPlane - farPlane );
		float a = farPlane * nmf;
		float b = nearPlane * farPlane * nmf;

		//float z01_2 = ( -zLog * a + b ) / zLog;
		frustum.clipSpacePlanes[4] = ( -n * a + b ) / n;
		frustum.clipSpacePlanes[5] = ( -f * a + b ) / f;
#endif // #if USE_Z_01
	}

	// This produces a reversed clip depth perspective matrix, i.e. clip depth = 0 at the far clip plane and clip depth = 1 at the near clip plane.
	Matrix4 InfinitePerspectiveMatrix( float tanHalfFovX, float tanHalfFovY, float zNear )
	{
		SPAD_ASSERT( zNear > 0 );
		SPAD_ASSERT( tanHalfFovX > 0 );
		SPAD_ASSERT( tanHalfFovY > 0 );

		Matrix4 mtx;
		memset( &mtx, 0, sizeof( mtx ) );

		mtx[0][0] = 1.0f / tanHalfFovX;
		mtx[1][1] = 1.0f / tanHalfFovY;
		mtx[2][3] = -1.0f;
		mtx[3][2] = zNear;

		return mtx;
	}

	Matrix4 InfinitePerspectiveMatrix2( float fovyRadians, float aspect, float zNear )
	{
		float tanHalfFovX = tanf( fovyRadians * 0.5f );
		return InfinitePerspectiveMatrix( tanHalfFovX, tanHalfFovX / aspect, zNear );
	}


	Vector3 WorldPositionFromScreenCoords3( const Vector3 eyeAxis[3], const Vector3 &eyeOffset, float screenCoordsX, float screenCoordsY, float depth )
	{
		Vector3 eyeRay = eyeAxis[0] * screenCoordsX +
			eyeAxis[1] * screenCoordsY +
			eyeAxis[2];

		return eyeOffset + eyeRay * depth;
	}

	Vector3 WorldPositionFromScreenCoords2( const Vector3 eyeAxis[3], const Vector3 &eyeOffset, const Vector3 &screenCoordsAndLinearDepth )
	{
		Vector3 eyeRay = eyeAxis[0] * screenCoordsAndLinearDepth.getX() +
			eyeAxis[1] * screenCoordsAndLinearDepth.getY() +
			eyeAxis[2];

		return eyeOffset + eyeRay * screenCoordsAndLinearDepth.getZ();
	}

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

		if ( dxStyleZProjection )
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


	void extractFrustumCornersReverseInfiniteProjection( Vector3 dst[8], const Vector3 eyeAxis[3], const Vector3 &eyeOffset, float nearPlane, float farPlane )
	{
		Vector3 corners[8] = {
			Vector3( -1, 1, nearPlane ),
			Vector3( -1, 1, farPlane ),

			Vector3( -1, -1, nearPlane ),
			Vector3( -1, -1, farPlane ),

			Vector3( 1, -1, nearPlane ),
			Vector3( 1, -1, farPlane ),

			Vector3( 1, 1, nearPlane ),
			Vector3( 1, 1, farPlane )
		};

		for ( uint i = 0; i < 8; ++i )
		{
			dst[i] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, corners[i] );
		}
	}


	void extractSubFrustumCornersReverseInfiniteProjection( Vector3 dst[8], const Vector3 eyeAxis[3], const Vector3 &eyeOffset, const Vector3 &subFrustumPos, const Vector3 &subFrustumSize, float nearPlane, float farPlane )
	{
		floatInVec n( nearPlane );
		floatInVec f( farPlane );

		Vector3 corners[8] = {
			Vector3( subFrustumPos.getX(), subFrustumPos.getY() + subFrustumSize.getY(), n ),
			Vector3( subFrustumPos.getX(), subFrustumPos.getY() + subFrustumSize.getY(), f ),

			Vector3( subFrustumPos.getX(), subFrustumPos.getY(), n ),
			Vector3( subFrustumPos.getX(), subFrustumPos.getY(), f ),

			Vector3( subFrustumPos.getX() + subFrustumSize.getX(), subFrustumPos.getY(), n ),
			Vector3( subFrustumPos.getX() + subFrustumSize.getX(), subFrustumPos.getY(), f ),

			Vector3( subFrustumPos.getX() + subFrustumSize.getX(), subFrustumPos.getY() + subFrustumSize.getY(), n ),
			Vector3( subFrustumPos.getX() + subFrustumSize.getX(), subFrustumPos.getY() + subFrustumSize.getY(), f )
		};

		for ( uint i = 0; i < 8; ++i )
		{
			dst[i] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, corners[i] );
		}
	}


	void extractFrustumPlanes( Vector4 planes[6], const Matrix4& vp )
	{
		planes[0] = vp.getRow( 0 ) + vp.getRow( 3 ); // left
		planes[1] = -vp.getRow( 0 ) + vp.getRow( 3 ); // right
		planes[2] = vp.getRow( 1 ) + vp.getRow( 3 ); // bottom
		planes[3] = -vp.getRow( 1 ) + vp.getRow( 3 ); //  top
		planes[4] = vp.getRow( 2 ) + vp.getRow( 3 ); // near
		planes[5] = -vp.getRow( 2 ) + vp.getRow( 3 ); // far

		for ( int i = 0; i < 6; ++i )
		{
			floatInVec lengthRcp = floatInVec( 1.0f ) / length( planes[i].getXYZ() );
			planes[i] *= lengthRcp;
		}
	}

	void extractFrustumPlanesDxRhs( Vector4 planes[6], const Matrix4& vp )
	{
		planes[0] = vp.getRow( 0 ) + vp.getRow( 3 ); // left
		planes[1] = -vp.getRow( 0 ) + vp.getRow( 3 ); // right
		planes[2] = vp.getRow( 1 ) + vp.getRow( 3 ); // bottom
		planes[3] = -vp.getRow( 1 ) + vp.getRow( 3 ); //  top
		planes[4] =  vp.getRow( 2 );// +vp.getRow( 3 ); // near
		planes[5] = -vp.getRow( 2 ) + vp.getRow( 3 ); // far

		for ( int i = 0; i < 6; ++i )
		{
			floatInVec lengthRcp = floatInVec( 1.0f ) / length( planes[i].getXYZ() );
			planes[i] *= lengthRcp;
		}
	}

	void buildSubFrustum( Vector4 frustumPlanes[6], uint cellCountX, uint cellCountY, uint cellCountZ, uint cellIndexX, uint cellIndexY, uint cellIndexZ, float tanHalfFovRcpX, float tanHalfFovRcpY, float nearPlane, float farPlaneOverNearPlane )
	{
		float n = nearPlane * pow( abs( farPlaneOverNearPlane ), (float)( cellIndexZ     ) / cellCountZ );
		float f = nearPlane * pow( abs( farPlaneOverNearPlane ), (float)( cellIndexZ + 1 ) / cellCountZ );
		//float n = 1;
		//float f = 20;
		float nmf = 1.0f / ( n - f );
		float a = f * nmf;
		float b = n * f * nmf;

		float tileScaleX = static_cast<float>( cellCountX );
		float tileScaleY = static_cast<float>( cellCountY );

		uint subFrustumX = cellIndexX;
		uint subFrustumY = cellIndexY;

		float tileBiasX = subFrustumX * 2 - tileScaleX + 1;
		float tileBiasY = subFrustumY * 2 - tileScaleY + 1;

		Matrix4 subProj = {
			Vector4( tanHalfFovRcpX * tileScaleX,		0,									tileBiasX,			0 ),
			Vector4( 0,									tanHalfFovRcpY * -tileScaleY,		tileBiasY,			0 ),
			Vector4( 0,									0,									a,					b ),
			Vector4( 0,									0,									-1,					0 )
		};

		extractFrustumPlanesDxRhs( frustumPlanes, transpose( subProj ) );
	}

	uint TestDecalVolumeFrustumClipSpace( const Vector4 corners[8], const float clipSpacePlanes[6] )
	{
		float left        = clipSpacePlanes[0];
		float right       = clipSpacePlanes[1];
		float bottom      = clipSpacePlanes[2];
		float top         = clipSpacePlanes[3];
		float nearPlane   = clipSpacePlanes[4];
		float farPlane    = clipSpacePlanes[5];

		bool allOutsideLeft = true;
		bool allOutsideRight = true;
		bool allOutsideBottom = true;
		bool allOutsideTop = true;
		bool allOutsideNear = true;
		bool allOutsideFar = true;

		for ( uint iCorner = 0; iCorner < 8; ++iCorner )
		{
			Vector4 c = corners[iCorner];
			float x = c.getX().getAsFloat();
			float y = c.getY().getAsFloat();
#if USE_Z_01
			float z = c.getZ().getAsFloat();
#endif // #if USE_Z_01
			float w = c.getW().getAsFloat();

			allOutsideLeft = allOutsideLeft && ( x < left * w );
			allOutsideRight = allOutsideRight && ( x > right * w );

			allOutsideBottom = allOutsideBottom && ( y < bottom * w );
			allOutsideTop = allOutsideTop && ( y > top * w );

#if USE_Z_01
			allOutsideNear = allOutsideNear && ( z < nearPlane * w );
			allOutsideFar = allOutsideFar && ( z > farPlane * w );
#else // #if USE_Z_01
			allOutsideNear = allOutsideNear && ( w < nearPlane );
			allOutsideFar = allOutsideFar && ( w > farPlane );
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


	//struct FrustumFace
	//{
	//	Vector3 center;
	//	Vector3 axes[2];
	//};

	//
	//float AdjustViewSpaceGridDepthFactor( const float z )
	//{
	//	// This should match the c version of this function
	//	//return z * z; // This should be the inverse of AdjustViewSpaceGridDepthFactorInverse()
	//	return z;
	//}

	//Vector3 GetPositionInFrustum( const Vector3 inLerpFactors, const Vector3 frustumVertices[8] )
	//{
	//	const Vector3 lerpFactors = Vector3( inLerpFactors.getX().getAsFloat(), inLerpFactors.getY().getAsFloat(), AdjustViewSpaceGridDepthFactor( inLerpFactors.getZ().getAsFloat() ) );
	//	const Vector3 invLerpFactors = Vector3( 1.0f, 1.0f, 1.0f ) - lerpFactors;

	//	Vector3 outPosition;

	//	outPosition = frustumVertices[0] * ( invLerpFactors.getX().getAsFloat() * invLerpFactors.getY().getAsFloat() * invLerpFactors.getZ().getAsFloat() );
	//	outPosition += frustumVertices[1] * ( lerpFactors.getX().getAsFloat() *    invLerpFactors.getY().getAsFloat() * invLerpFactors.getZ().getAsFloat() );
	//	outPosition += frustumVertices[2] * ( invLerpFactors.getX().getAsFloat() * lerpFactors.getY().getAsFloat()    * invLerpFactors.getZ().getAsFloat() );
	//	outPosition += frustumVertices[3] * ( lerpFactors.getX().getAsFloat() *    lerpFactors.getY().getAsFloat()    * invLerpFactors.getZ().getAsFloat() );

	//	outPosition += frustumVertices[4] * ( invLerpFactors.getX().getAsFloat() * invLerpFactors.getY().getAsFloat() * lerpFactors.getZ().getAsFloat() );
	//	outPosition += frustumVertices[5] * ( lerpFactors.getX().getAsFloat() *    invLerpFactors.getY().getAsFloat() * lerpFactors.getZ().getAsFloat() );
	//	outPosition += frustumVertices[6] * ( invLerpFactors.getX().getAsFloat() * lerpFactors.getY().getAsFloat()    * lerpFactors.getZ().getAsFloat() );
	//	outPosition += frustumVertices[7] * ( lerpFactors.getX().getAsFloat() *    lerpFactors.getY().getAsFloat()    * lerpFactors.getZ().getAsFloat() );

	//	return outPosition;
	//}

	//void GetViewSpaceFrustumFaces( const Vector3 cellCountRcp, const Vector3 cellCoords, const Vector3 frustumVertices[8], FrustumFace outFrustumFaces[2], bool /*farPlaneUnbounded*/ )
	//{
	//	//const float3 cellSize = float3( REFLECTION_PROBE_GRID_CELL_SIZE_X, REFLECTION_PROBE_GRID_CELL_SIZE_Y, REFLECTION_PROBE_GRID_CELL_SIZE_Z );
	//	//const float3 cellSizeExtended = float3( REFLECTION_PROBE_GRID_CELL_SIZE_X, REFLECTION_PROBE_GRID_CELL_SIZE_Y, REFLECTION_PROBE_GRID_CELL_SIZE_Z * ( farPlaneUnbounded ? MAX_REFLECTION_CULL_RANGE : 1.0f ) );
	//	const Vector3 cellSize = cellCountRcp;
	//	const Vector3 cellSizeExtended = cellSize;
	//	const Vector3 base = mulPerElem( Vector3( cellCoords ), cellSize );

	//	// TODO: pass data in a nicer way to simplify the computations below: origin + screen_x_at_1 + screen_y_at_1 + z_axis + z_near_far

	//	for ( int i = 0; i < 2; i++ )
	//	{
	//		Vector3 center = GetPositionInFrustum( base + mulPerElem( cellSizeExtended, Vector3( 0.5f, 0.5f, (float)i ) ), frustumVertices );
	//		outFrustumFaces[i].center = center;
	//		outFrustumFaces[i].axes[0] = center - GetPositionInFrustum( base + mulPerElem( cellSizeExtended, Vector3( 1.0f, 0.5f, (float)i ) ), frustumVertices );
	//		outFrustumFaces[i].axes[1] = center - GetPositionInFrustum( base + mulPerElem( cellSizeExtended, Vector3( 0.5f, 1.0f, (float)i ) ), frustumVertices );
	//	}
	//}

	//void GetFrustumCorners( const Vector3 eyeAxis[3], const Vector3 &eyeOffset, float depth0, float depth1, Vector3 frustumCorners[8] )
	//{
	//	float left = -1;
	//	float right = 1;

	//	frustumCorners[0] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, -1, depth0 ) );
	//	frustumCorners[1] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, -1, depth0 ) );
	//	frustumCorners[2] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, 1, depth0 ) );
	//	frustumCorners[3] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, 1, depth0 ) );

	//	frustumCorners[4] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, -1, depth1 ) );
	//	frustumCorners[5] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, -1, depth1 ) );
	//	frustumCorners[6] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, 1, depth1 ) );
	//	frustumCorners[7] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, 1, depth1 ) );
	//}

	//void DecalVolume_GetFrustumClusterFaces( FrustumFace faces[2], const Vector3 cellCount, const Vector3 cellCountRcp, Vector3 cellIndex, Vector4 tanHalfFov, float nearPlane, float farPlane, float /*farPlaneOverNearPlane*/, bool /*farClip = false*/ )
	//{
	//	// clip-space (-1,1) position of the view ray through the centroid of the cluster frustum projected on screen
	//	//float2 uv = ( ( float2( clusterXYZ.xy ) + 0.5f ) * g_sceneConstants.frustumGridClusterSize.xy + 0.5f ) / g_sceneConstants.frustumGridLightParams.zw;
	//	Vector3 uv = mulPerElem( cellIndex + Vector3( 0.5f ), cellCountRcp );
	//	//uv = uv * float2( -2.0f, -2.0f ) + float2( 1.0f, 1.0f );
	//	//uv = uv * float2( 2.0f, 2.0f ) - float2( 1.0f, 1.0f );
	//	uv = mulPerElem( uv, Vector3( 2.0f ) ) - Vector3( 1.0f );
	//	//uv.y = -uv.y;

	//	//float2 uv00 = cellIndex.xy * cellCountRcp.xy;
	//	//float2 uv10 = (cellIndex.xy + float2(1,0)) * cellCountRcp.xy;

	//	//// view-space depth of the near and far planes for the cluster frustum
	//	//float depth0 = VolumeZPosToDepth( float( clusterXYZ.z ) * ( 1.0f / float( FRUSTUM_GRID_CLUSTER_SIZE_Z ) ), g_sceneConstants.volumetricDepth );
	//	//float depth1 = ( farClip || ( clusterXYZ.z < FRUSTUM_GRID_CLUSTER_SIZE_Z - 1 ) ) ? VolumeZPosToDepth( float( clusterXYZ.z + 1 ) * ( 1.0f / float( FRUSTUM_GRID_CLUSTER_SIZE_Z ) ), g_sceneConstants.volumetricDepth ) : FRUSTUM_GRID_CLUSTERING_MAX_DEPTH;
	//	//#if DECAL_VOLUME_CLUSTER_3D
	//	//	float depth0 = nearPlane * pow( abs( farPlaneOverNearPlane ), (float)( cellIndex.z     ) * cellCountRcp.z );
	//	//	float depth1 = nearPlane * pow( abs( farPlaneOverNearPlane ), (float)( cellIndex.z + 1 ) * cellCountRcp.z );
	//	//#else // #if DECAL_VOLUME_CLUSTER_3D
	//	float depth0 = nearPlane;
	//	float depth1 = farPlane;
	//	//float depth0 = farPlane;
	//	//float depth1 = nearPlane;
	//	//#endif // #else // #if DECAL_VOLUME_CLUSTER_3D


	//	// screen-space half size of the projected frustum
	//	//float2 projHalfSize = 0.5f * frustumGridClusterSize.xy / frustumGridLightParams.zw;
	//	//float2 projHalfSize = ( 0.5f * float2( 32.0f, 32.0f ) ) / float2( 1920, 1080 );
	//	//float2 projHalfSize = ( 0.5f * float2( cellCount.xy ) ) / float2( 1920, 1080 );
	//	//float2 projHalfSize = 0.5f * 1.0f / 32.0f;// ( 0.5f * float2( cellCount.xy ) ) / float2( 1024, 1024 );
	//	//float2 projHalfSize = ( 1.0f * float2( cellCount.xy ) ) / float2( 1024, 1024 );
	//	//float2 projHalfSize = 0.5f * cellCountRcp.xy;
	//	//projHalfSize.y *= 2;
	//	//projHalfSize *= 0.01f;
	//	//Vector3 projHalfSize( 0.5f * 1.0f / 32.0f );
	//	Vector3 projHalfSize( 0.5f );

	//	Vector3 eyeAxis[3];
	//	eyeAxis[0] = Vector3( 1, 0, 0 ) * tanHalfFov.getX();
	//	eyeAxis[1] = Vector3( 0, 1, 0 ) * tanHalfFov.getY();
	//	eyeAxis[2] = Vector3( 0, 0, -1 );
	//	Vector3 eyeOffset = Vector3( 0, 0, 0 );

	//	faces[0].center = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv.getX().getAsFloat(), uv.getY().getAsFloat(), depth0 );
	//	faces[0].axes[0] = eyeAxis[0] * projHalfSize.getX() * depth0;
	//	faces[0].axes[1] = eyeAxis[1] * projHalfSize.getY() * depth0;

	//	faces[1].center = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv.getX().getAsFloat(), uv.getY().getAsFloat(), depth1 );
	//	faces[1].axes[0] = eyeAxis[0] * projHalfSize.getX() * depth1;
	//	faces[1].axes[1] = eyeAxis[1] * projHalfSize.getY() * depth1;

	//	Vector3 uv00 = mulPerElem( cellIndex, cellCountRcp );
	//	Vector3 uv10 = mulPerElem( cellIndex + Vector3( 1, 0, 0 ), cellCountRcp );
	//	Vector3 uv01 = mulPerElem( cellIndex + Vector3( 0, 1, 0 ), cellCountRcp );

	//	//Vector3 c000 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv00.getX().getAsFloat(), uv00.getY().getAsFloat(), depth0 );
	//	Vector3 c100 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv10.getX().getAsFloat(), uv10.getY().getAsFloat(), depth0 );
	//	//Vector3 c001 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv00.getX().getAsFloat(), uv00.getY().getAsFloat(), depth1 );
	//	Vector3 c101 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv10.getX().getAsFloat(), uv10.getY().getAsFloat(), depth1 );

	//	Vector3 c010 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv01.getX().getAsFloat(), uv01.getY().getAsFloat(), depth0 );
	//	Vector3 c011 = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, uv01.getX().getAsFloat(), uv01.getY().getAsFloat(), depth1 );

	//	//faces[0].axes[0] = c100 - c000;
	//	//faces[0].axes[1] = c100 - c000;
	//	//faces[1].axes[0] = c101 - c001;
	//	//faces[1].axes[1] = c101 - c001;
	//	//faces[0].axes[0] = c100 - faces[0].center;
	//	//faces[0].axes[1] = c100 - faces[0].center;
	//	//faces[1].axes[0] = c101 - faces[1].center;
	//	//faces[1].axes[1] = c101 - faces[1].center;
	//	faces[0].axes[0] = c100 - faces[0].center;
	//	faces[0].axes[1] = c010 - faces[0].center;
	//	faces[1].axes[0] = c101 - faces[1].center;
	//	faces[1].axes[1] = c011 - faces[1].center;


	//	//float left = -1;
	//	//float right = 1;

	//	//frustumCorners[0] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, -1, depth0 ) );
	//	//frustumCorners[1] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, -1, depth0 ) );
	//	//frustumCorners[2] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, 1, depth0 ) );
	//	//frustumCorners[3] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, 1, depth0 ) );

	//	//frustumCorners[4] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, -1, depth1 ) );
	//	//frustumCorners[5] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, -1, depth1 ) );
	//	//frustumCorners[6] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, 1, depth1 ) );
	//	//frustumCorners[7] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, 1, depth1 ) );

	//	//GetViewSpaceFrustumFaces( cellCountRcp, cellIndex, frustumCorners, faces, false );
	//}

	//Vector3 GetFrustumVertex( const FrustumFace frustumFaces[2], int vertIndex )
	//{
	//	int sx = vertIndex & 1;
	//	int sy = ( vertIndex >> 1 ) & 1;
	//	int iz = vertIndex >> 2;

	//	//return frustumFaces[iz].center + frustumFaces[iz].axes[0] * (float)sx + frustumFaces[iz].axes[1] * (float)sy;

	//	float sxn = sx * 2.0f - 1.0f;
	//	float syn = sy * 2.0f - 1.0f;
	//	return frustumFaces[iz].center + frustumFaces[iz].axes[0] * (float)sxn + frustumFaces[iz].axes[1] * (float)syn;
	//}


	//Vector3 GetFrustumAxis( const FrustumFace frustumFaces[2], int axisIndex )
	//{
	//	// NOTE: These if statements are meant to be evaluated and removed at compile time after loop unrolling.
	//	//       The idea is to avoid storing frustumAxes in registers. Maybe worth???

	//	if ( axisIndex == 0 ) // z
	//		return cross( frustumFaces[0].axes[0], frustumFaces[0].axes[1] );
	//	if ( axisIndex == 1 ) // x1
	//		return cross( frustumFaces[0].axes[0], GetFrustumVertex( frustumFaces, 4 ) - GetFrustumVertex( frustumFaces, 0 ) );
	//	if ( axisIndex == 2 ) // y1
	//		return cross( frustumFaces[0].axes[1], GetFrustumVertex( frustumFaces, 4 ) - GetFrustumVertex( frustumFaces, 0 ) );
	//	if ( axisIndex == 3 ) // x2
	//		return cross( frustumFaces[0].axes[0], GetFrustumVertex( frustumFaces, 7 ) - GetFrustumVertex( frustumFaces, 3 ) );
	//	if ( axisIndex == 4 ) // y2
	//		return cross( frustumFaces[0].axes[1], GetFrustumVertex( frustumFaces, 7 ) - GetFrustumVertex( frustumFaces, 3 ) );

	//	return Vector3( 0, 0, 1 );
	//}

	//bool AreIntervalsDisjoint( const Float2 a, const Float2 b )
	//{
	//	return ( a.y < b.x ) || ( b.y < a.x );
	//}


	//void ExtendIntervalWithValue( const float x, Float2 &inOutInterval )
	//{
	//	if ( x < inOutInterval.x )
	//	{
	//		inOutInterval.x = x;
	//	}
	//	if ( x > inOutInterval.y )
	//	{
	//		inOutInterval.y = x;
	//	}
	//}


	//void ExtendIntervalWithInterval( const Float2 v, Float2 &inOutInterval )
	//{
	//	if ( v.x < inOutInterval.x )
	//	{
	//		inOutInterval.x = v.x;
	//	}
	//	if ( v.y > inOutInterval.y )
	//	{
	//		inOutInterval.y = v.y;
	//	}
	//}

	struct OrientedBoundingBox2
	{
		Vector3 center;
		Vector3 axes[3];
		Vector3 halfSize;
	};

	//Float2 GetObbProjectedInterval( const OrientedBoundingBox obb, const Vector3 axis )
	//{
	//	const float centerProjectionOBB = dot( obb.center, axis ).getAsFloat();

	//	// TODO: the halfSize can be premultiplied into the obb.axis vectors to save some computation. I'm not sure if that will break other code that relies on this header though...

	//	const float extentsProjectionOBB
	//		= fabs( dot( obb.axes[0], axis ).getAsFloat() * obb.halfSize.getX().getAsFloat() )
	//		+ fabs( dot( obb.axes[1], axis ).getAsFloat() * obb.halfSize.getY().getAsFloat() )
	//		+ fabs( dot( obb.axes[2], axis ).getAsFloat() * obb.halfSize.getZ().getAsFloat() );

	//	return Float2( centerProjectionOBB - extentsProjectionOBB, centerProjectionOBB + extentsProjectionOBB );
	//}

	//Float2 GetFrustumFaceProjectedInterval( const FrustumFace ff, const Vector3 axis )
	//{
	//	const float centerProjectionFF = dot( ff.center, axis ).getAsFloat();

	//	const float extentsProjectionFF
	//		= fabs( dot( ff.axes[0], axis ).getAsFloat() )
	//		+ fabs( dot( ff.axes[1], axis ).getAsFloat() );

	//	return Float2( centerProjectionFF - extentsProjectionFF, centerProjectionFF + extentsProjectionFF );
	//}


	//Float2 GetFrustumProjectedInterval( const FrustumFace frustumFaces[2], const Vector3 axis )
	//{
	//	Float2 outInterval = GetFrustumFaceProjectedInterval( frustumFaces[0], axis );
	//	ExtendIntervalWithInterval( GetFrustumFaceProjectedInterval( frustumFaces[1], axis ), outInterval );
	//	return outInterval;

	//	//Vector3 frustumCorners2[8];
	//	//for ( int i = 0; i < 8; ++i )
	//	//{
	//	//	frustumCorners2[i] = GetFrustumVertex( frustumFaces, i );
	//	//}

	//	//const float projection0 = dot( frustumCorners2[0], axis ).getAsFloat();
	//	//Float2 outInterval = Float2( projection0, projection0 );

	//	//for ( uint vertexIndex = 1; vertexIndex < 8; vertexIndex++ )
	//	//{
	//	//	const float projection = dot( frustumCorners2[vertexIndex], axis ).getAsFloat();

	//	//	outInterval.x = minOfPair( outInterval.x, projection );
	//	//	outInterval.y = maxOfPair( outInterval.y, projection );
	//	//}

	//	//return outInterval;

	//}

	//bool R_AreFrustumObbProjectedIntervalsDisjoint( const OrientedBoundingBox obb, const FrustumFace frustumFaces[2], const Vector3 axis )
	//{
	//	const Float2 obbInterval = GetObbProjectedInterval( obb, axis );
	//	Float2 frustumInterval = GetFrustumProjectedInterval( frustumFaces, axis );
	//	return AreIntervalsDisjoint( frustumInterval, obbInterval );
	//}

	//bool TestFrustumObbIntersectionSAT( const OrientedBoundingBox obb, const FrustumFace frustumFaces[2] )
	//{
	//	/// Test box axes
	//	// these are cheap to evaluate, and are orthogonal
	//	// also, there is potential to early out, so do first
	//	//int containmentMask = 0;

	//	//[unroll]
	//	for ( uint axisIndex = 0; axisIndex < 3; axisIndex++ )
	//	{
	////#if USE_OBB_FRUSTUM_EARLY_ACCEPT
	////		if ( R_AreFrustumObbProjectedIntervalsDisjointMask( obb, frustumFaces, obb.axes[axisIndex], containmentMask ) ) return false;
	////#else
	//		if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, obb.axes[axisIndex] ) ) return false;
	////#endif
	//	}

	//	//if ( containmentMask == 7 )
	//	//	return true;

	//	/// Test other axes. we want to check axes that are as different from each other as possible first to get early rejections
	//	/// this means that some of the checks are interleaved

	////	// ROUND 1
	////#if USE_OBB_FRUSTUM_FACE_AXES
	////	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, obb.center - frustumFaces[0].center ) ) return false; // Frustum face center to OBB center
	////#endif
	////
	//	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 0 ) ) ) return false; // Frustum plane
	//	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 1 ) ) ) return false; // Frustum plane
	//	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 2 ) ) ) return false; // Frustum plane

	////#if USE_OBB_FRUSTUM_EDGE_CROSSES
	////	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 0 ), GetFrustumVertex( frustumFaces, 1 ) ) ) return false; // Edge cross product
	////	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 0 ), GetFrustumVertex( frustumFaces, 2 ) ) ) return false; // Edge cross product
	////	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 0 ), GetFrustumVertex( frustumFaces, 4 ) ) ) return false; // Edge cross product
	////#endif

	////	// ROUND 2
	////#if USE_OBB_FRUSTUM_FACE_AXES
	////	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, obb.center - frustumFaces[1].center ) ) return false; // Frustum face center to OBB center
	////#endif

	//	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 3 ) ) ) return false; // Frustum plane
	//	if ( R_AreFrustumObbProjectedIntervalsDisjoint( obb, frustumFaces, GetFrustumAxis( frustumFaces, 4 ) ) ) return false; // Frustum plane

	////#if USE_OBB_FRUSTUM_EDGE_CROSSES
	////	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 3 ), GetFrustumVertex( frustumFaces, 7 ) ) ) return false; // Edge cross product
	////	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 1 ), GetFrustumVertex( frustumFaces, 5 ) ) ) return false; // Edge cross product
	////	if ( IsFrustumEdgeVsBoxAxesProjectionDisjoint( obb, frustumFaces, GetFrustumVertex( frustumFaces, 2 ), GetFrustumVertex( frustumFaces, 6 ) ) ) return false; // Edge cross product
	////#endif

	//	return true;
	//}


	//void FrustumTest( const Vector3 cellCount, const Vector3 cellCountRcp, Vector3 cellIndex, Vector4 tanHalfFov, float nearPlane, float farPlane )
	//{
	//	Vector3 frustumCorners[8];
	//	FrustumFace faces[2];

	//	Vector3 eyeAxis[3];
	//	eyeAxis[0] = Vector3( 1, 0, 0 ) * tanHalfFov.getX();
	//	eyeAxis[1] = Vector3( 0, 1, 0 ) * tanHalfFov.getY();
	//	eyeAxis[2] = Vector3( 0, 0, -1 );
	//	Vector3 eyeOffset = Vector3( 0, 0, 0 );

	//	GetFrustumCorners( eyeAxis, eyeOffset, nearPlane, farPlane, frustumCorners );
	//	GetViewSpaceFrustumFaces( cellCountRcp, cellIndex, frustumCorners, faces, false );

	//	Vector3 frustumCorners2[8];
	//	for ( int i = 0; i < 8; ++i )
	//	{
	//		frustumCorners2[i] = GetFrustumVertex( faces, i );
	//	}

	//	OrientedBoundingBox obb;
	//	obb.center = Vector3( 0, 0, -20 );
	//	//obb.axes[0] = Vector3::xAxis();
	//	//obb.axes[1] = Vector3::yAxis();
	//	//obb.axes[2] = Vector3::zAxis();
	//	Matrix4 rot = Matrix4::rotationZYX( Vector3( 0, 0, deg2rad( -45.0f ) ) );
	//	obb.axes[0] = rot.getCol0().getXYZ();
	//	obb.axes[1] = rot.getCol1().getXYZ();
	//	obb.axes[2] = rot.getCol2().getXYZ();
	//	obb.halfSize = Vector3( 4, 1, 1 ) * floatInVec( 1.572f );

	//	bool test = TestFrustumObbIntersectionSAT( obb, faces );
	//	test = TestFrustumObbIntersectionSAT( obb, faces );
	//}

	union MyUint64
	{
		struct
		{
			uint low;
			uint hi;
		};
		uint64_t quad;
	};

	MyUint64 MyUint64_Add( MyUint64 a, MyUint64 b )
	{
		MyUint64 r;
		r.low = a.low + b.low;
		uint carry = r.low < a.low || r.low < b.low;
		r.hi = a.hi + b.hi + carry;
		return r;
	}

	MyUint64 MyUint64_Sub( MyUint64 a, MyUint64 b )
	{
		MyUint64 r;
		r.low = a.low - b.low;
		uint borrow = a.low < b.low;
		r.hi = a.hi - b.hi - borrow;
		return r;
	}

	float4 ExtractTanHalfFov( const Matrix4& projMatrix )
	{
		float4 tanHalfFov;

		tanHalfFov.x = 1.0f / projMatrix.getElem( 0, 0 ).getAsFloat();
		tanHalfFov.y = 1.0f / projMatrix.getElem( 1, 1 ).getAsFloat();
		tanHalfFov.z = projMatrix.getElem( 0, 0 ).getAsFloat();
		tanHalfFov.w = projMatrix.getElem( 1, 1 ).getAsFloat();

		return tanHalfFov;
	}

	void FrustumTest( const Matrix4 &projMatrix )
	{
		float4 tanHalfFov = ExtractTanHalfFov( projMatrix );

		//Vector3 cellCount = Vector3( 4, 4, 1 );
		//Vector3 cellCountRcp = divPerElem( Vector3( 1.0f ), cellCount );
		//FrustumTest( cellCount, cellCountRcp, Vector3( 0, 3, 0 ), tanHalfFov, 4.0f, 1000.0f );
		
		float depth0 = 4.0f;
		float depth1 = 1000.0f;

		float3 eyeAxis[3];
		eyeAxis[0] = float3( 1, 0, 0 ) * tanHalfFov.x;
		eyeAxis[1] = float3( 0, 1, 0 ) * tanHalfFov.y;
		eyeAxis[2] = float3( 0, 0, -1 );
		float3 eyeOffset = float3( 0, 0, 0 );


		float left = -1;
		float right = 1;
		float top = 1;
		float bottom = -1;

		float3 frustumCorners[16];
		//float3 frustumCornersFromFaces[8];

		frustumCorners[0] = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( left, bottom ), depth0 );
		frustumCorners[1] = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( right, bottom ), depth0 );
		frustumCorners[2] = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( left, top ), depth0 );
		frustumCorners[3] = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( right, top ), depth0 );

		frustumCorners[4] = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( left, bottom ), depth1 );
		frustumCorners[5] = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( right, bottom ), depth1 );
		frustumCorners[6] = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( left, top ), depth1 );
		frustumCorners[7] = WorldPositionFromScreenCoords( eyeAxis, eyeOffset, float2( right, top ), depth1 );

		//float2 cellSize = float2( 32.0f / 1920.0f, 32.0f / 1080.0f );
		float2 cellSize = float2( 1, 1 );
		float3 cellCount = float3( 1, 1, 1 );
		float3 cellIndex = float3( 0, 0, 0 );

		FrustumFace faces[2];
		GetFrustumClusterFaces( faces, eyeAxis, eyeOffset, cellSize, cellCount, cellCount, 1.0f / cellCount, cellIndex, tanHalfFov.xy, depth0, depth1, depth1 / depth0 );

		for ( uint i = 0; i < 8; ++i )
		{
			frustumCorners[i + 8] = GetFrustumVertex( faces, i );
		}

		bool3 eq[8];
		for ( uint i = 0; i < 8; ++i )
		{
			eq[i] = equal( frustumCorners[i], frustumCorners[i + 8] );
		}
	}

	bool SettingsTestApp::StartUp()
	{
		uint numThreadsPerCell = 32;
		uint32_t cellMask = ( (uint32_t)1 << numThreadsPerCell );
		cellMask -= 1;

		{
			MyUint64 a, b;
			a.low = 0xffffffff;
			a.hi = 0;
			b.low = 0xffffffff;
			b.hi = 0;

			MyUint64 ra = MyUint64_Add( a, b );
			uint64_t rar = a.quad + b.quad;
			rar = rar;

			MyUint64 rs = MyUint64_Sub( ra, a );
			uint64_t rsr = ra.quad - a.quad;
			rsr = rsr;
		}
		//for ( uint i = 0; i < 4; ++i )
		//{
		//	uint row = i / 2;
		//	uint col = i % 2;
		//	uint tileX = 0;
		//	uint tileY = 0;
		//	uint cellIndex = ( tileY * 2 + row ) * 2 + tileX * 2 + col;

		//	std::cout << "tile " << cellIndex << std::endl;
		//}

		//for ( uint i = 0; i < 8; ++i )
		//{
		//	uint slice = i / 4;
		//	uint tile = i % 4;
		//	uint row = tile / 2;
		//	uint col = tile % 2;
		//	uint tileX = 0;
		//	uint tileY = 0;
		//	uint cellZ = 0;
		//	uint cellIndex = (cellZ * 2 + slice) * 4 + ( tileY * 2 + row ) * 2 + tileX * 2 + col;

		//	std::cout << "tile " << cellIndex << std::endl;
		//}

		//for ( uint iThread = 0; iThread < 64; ++iThread )
		//{
		//	uint wordIndex = iThread / 32;
		//	uint bitIndex = iThread - wordIndex * 32;
		//	uint val0 = 0 << bitIndex;
		//	uint val1 = 1 << bitIndex;

		//	std::cout << "iThread: " << iThread << ", wordIndex: " << wordIndex << ", bitIndex: " << bitIndex << ", val0: " << val0 << ", val1: " << val1 << std::endl;
		//}

		//uint np2 = NextPowerOfTwo( 1 );
		//np2 = NextPowerOfTwo( 2 );
		//np2 = NextPowerOfTwo( 2 );

		//float nearPlane = testFrustumNearPlane;
		//float farPlane = testFrustumFarPlane;
		float nearPlane = testFrustumNearPlane;
		float farPlane = decalVolumeFarPlane_;

		//FrustumFace 

		const float aspect = (float)dx11_->getBackBufferWidth() / (float)dx11_->getBackBufferHeight();
		//viewMatrixForCamera_ = ( Matrix4::lookAt( Point3( 5, 5, 0 ), Point3( 0, 0, -5 ), Vector3::yAxis() ) );
		//view_ = Matrix4::lookAt( Point3( 0, 0, -5 ), Point3( 0, 0, 0 ), Vector3::yAxis() );
		//projMatrixForCamera_ = perspectiveProjectionDxStyle( deg2rad( 60.0f ), aspect, 4.0f, decalVolumeFarPlane_ );
		projMatrixForCamera_ = InfinitePerspectiveMatrix2( deg2rad( 60.0f ), aspect, 4.0f );

		FrustumTest( projMatrixForCamera_ );

		float n = testFrustumNearPlane;
		float f = decalVolumeFarPlane_;
		float nmf = 1.0f / ( n - f );
		float a = f * nmf;
		float b = n * f * nmf;

		for ( uint i = 0; i < 25; ++i )
		{
			float zLog = calcZ( nearPlane, farPlane, i, 24 );
			float zUniform = calcZ2( nearPlane, farPlane, i, 24 );

			Vector4 v = projMatrixForCamera_ * Vector4( 0, 0, -zLog, 1.0f );
			float z01 = v.getZ().getAsFloat() / v.getW().getAsFloat();

			float z01_2 = ( -zLog * a + b ) / zLog;

			std::cout << "z log: " << zLog << "   z uni: " << zUniform << "    z log 01: " << z01 << ", " << z01_2 << std::endl;
		}

		for ( uint i = 0; i < 6; ++i )
		{
			float zLog = calcZ( nearPlane, farPlane, i, 6 );
			float zUniform = calcZ2( nearPlane, farPlane, i, 6 );
			std::cout << "z log: " << zLog << "   z uni: " << zUniform << std::endl;
		}

		std::vector<uint> vec = { 1, 2, 3, 4 };

		for ( uint i = 0; i < 4; ++i )
		{
			std::cout << vec[i] << " ";
		}
		std::cout << std::endl;

		//std::vector<uint> prefixSum( vec.size() );
		//prefixSum[0] = vec[0];
		//for ( uint i = 1; i < 4; ++i )
		//{
		//	prefixSum[i] = vec[i] + prefixSum[i-1];
		//}
		for ( uint i = 1; i < 4; ++i )
		{
			vec[i] += vec[i - 1];
		}

		for ( uint i = 0; i < 4; ++i )
		{
			std::cout << vec[i] << " ";
		}

		//uint word = ( 1 << 5 ) | ( 1 << 4 ) | ( 1 << 3 );
		//uint threadBit = 4;
		//uint threadBitMask = (1 << threadBit) - 1;
		//uint maskedWord = word & threadBitMask;
		//uint bitcount0 = numberOfSetBits( word );
		//uint bitcount1 = numberOfSetBits( maskedWord );

		//uint headNodeAddress = 0;
		//uint prevNodeDecalIndex = INVALID_DECAL_VOLUME_INDEX;
		//uint prevNodeAddress = 0;
		//uint firstNodeAddress = INVALID_DECAL_VOLUME_LIST_NODE_INDEX;

		//std::vector<uint> nodes( 5 );

		//for ( uint i = 1; i < 5; ++i )
		//{
		//	uint decalIndex = i * 2;
		//	uint nodeAddress = i;

		//	if ( prevNodeDecalIndex == INVALID_DECAL_VOLUME_INDEX )
		//	{
		//		prevNodeDecalIndex = decalIndex;
		//		prevNodeAddress = nodeAddress;
		//		firstNodeAddress = nodeAddress;
		//	}
		//	else
		//	{
		//		//std::cout << "di " << prevNodeDecalIndex << ", nni " << prevNodeAddress << std::endl;
		//		nodes[prevNodeAddress] = PackListNode( prevNodeDecalIndex, nodeAddress );
		//		prevNodeDecalIndex = decalIndex;
		//		prevNodeAddress = nodeAddress;
		//	}
		//}

		//nodes[headNodeAddress] = PackListNode( INVALID_DECAL_VOLUME_INDEX, firstNodeAddress );
		//nodes[prevNodeAddress] = PackListNode( prevNodeDecalIndex, INVALID_DECAL_VOLUME_LIST_NODE_INDEX );
		
		//for ( uint node : nodes )
		//{
		//	uint decalIndex;
		//	uint nextNodeIndex;
		//	UnpackListNode( node, decalIndex, nextNodeIndex );
		//	std::cout << "di " << decalIndex<< ", nni " << nextNodeIndex << std::endl;
		//}

		ID3D11Device* dxDevice = dx11_->getDevice();

		mainDS_.Initialize( dxDevice, dx11_->getBackBufferWidth(), dx11_->getBackBufferHeight(), 1, DXGI_FORMAT_D24_UNORM_S8_UINT, 1, 0, true );

		//gpuClusteringShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\gpuClustering.hlslc_packed" );
		decalVolumeRenderingShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\decal_volume_rendering.hlslc_packed" );
		decalVolumeCullShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\cs_decal_volume_culling.hlslc_packed" );

		passConstants_.Initialize( dx11_->getDevice() );
		objectConstants_.Initialize( dx11_->getDevice() );
		decalVolumeRenderingConstants_.Initialize( dx11_->getDevice() );
		decalVolumeCullConstants_.Initialize( dx11_->getDevice() );

		vertices_.Initialize( dxDevice, 64 * 1024 );

		//testFrustumView = Matrix4::identity();
		//testFrustumProj = perspectiveProjectionDxStyle( deg2rad( 60.0f ), (float)testRtWidth / (float)testRtHeight, testFrustumNearPlane, testFrustumFarPlane );

		//GenDecalVolumes( dxDevice, testFrustumProj * testFrustumView );

		//decalVolumesGPU_.Initialize( dxDevice, maxDecalVolumes, g_decalVolumes, true, false, false );

		StartUpBox();
		StartUpAxes();

		SceneReset();

		//tiling_ = DecalVolumeTilingStartUp();
		tiling_ = DecalVolumeClusteringStartUp( false );
		clustering_ = DecalVolumeClusteringStartUp( true );

		return true;
	}

	void SettingsTestApp::ShutDown()
	{
		ClearDecalVolumes();
	}

	void SettingsTestApp::StartUpBox()
	{
		D3D11_BUFFER_DESC bufferDesc;
		ZeroMemory( &bufferDesc, sizeof( bufferDesc ) );
		bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
		bufferDesc.ByteWidth = sizeof( Vector4 ) * 8;
		bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;

		Vector4 pos[8];
		pos[0] = Vector4( -0.5f, -0.5f, 0.5f, 1 );
		pos[1] = Vector4( 0.5f, -0.5f, 0.5f, 1 );
		pos[2] = Vector4( 0.5f, 0.5f, 0.5f, 1 );
		pos[3] = Vector4( -0.5f, 0.5f, 0.5f, 1 );

		pos[4] = Vector4( -0.5f, -0.5f, -0.5f, 1 );
		pos[5] = Vector4( 0.5f, -0.5f, -0.5f, 1 );
		pos[6] = Vector4( 0.5f, 0.5f, -0.5f, 1 );
		pos[7] = Vector4( -0.5f, 0.5f, -0.5f, 1 );

		D3D11_SUBRESOURCE_DATA initData;
		initData.pSysMem = pos;
		initData.SysMemPitch = 0;
		initData.SysMemSlicePitch = 0;
		DXCall( dx11_->getDevice()->CreateBuffer( &bufferDesc, &initData, &boxVertexBuffer_ ) );

		u16 indices[36];
		u16 *idx = indices;

		// front
		idx[0] = 0;		idx[1] = 1;		idx[2] = 2;		idx += 3;
		idx[0] = 0;		idx[1] = 2;		idx[2] = 3;		idx += 3;

		// right
		idx[0] = 1;		idx[1] = 5;		idx[2] = 6;		idx += 3;
		idx[0] = 1;		idx[1] = 6;		idx[2] = 2;		idx += 3;

		// back
		idx[0] = 5;		idx[1] = 4;		idx[2] = 7;		idx += 3;
		idx[0] = 5;		idx[1] = 7;		idx[2] = 6;		idx += 3;

		// left
		idx[0] = 4;		idx[1] = 0;		idx[2] = 3;		idx += 3;
		idx[0] = 4;		idx[1] = 3;		idx[2] = 7;		idx += 3;

		// top
		idx[0] = 3;		idx[1] = 2;		idx[2] = 6;		idx += 3;
		idx[0] = 3;		idx[1] = 6;		idx[2] = 7;		idx += 3;

		// bottom
		idx[0] = 4;		idx[1] = 5;		idx[2] = 1;		idx += 3;
		idx[0] = 4;		idx[1] = 1;		idx[2] = 0;		idx += 3;

		ZeroMemory( &bufferDesc, sizeof( bufferDesc ) );
		bufferDesc.ByteWidth = sizeof( u16 ) * 36;
		bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;

		initData.pSysMem = indices;
		DXCall( dx11_->getDevice()->CreateBuffer( &bufferDesc, &initData, &boxIndexBuffer_ ) );

		boxIndirectArgs_.Initialize( dx11_->getDevice(), 5, nullptr, false, true, false, true );
	}

	void SettingsTestApp::StartUpAxes()
	{
		D3D11_BUFFER_DESC bufferDesc;
		ZeroMemory( &bufferDesc, sizeof( bufferDesc ) );
		bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
		bufferDesc.ByteWidth = sizeof( Vector4 ) * 6;
		bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;

		Vector4 pos[6];
		pos[0] = Vector4( 0, 0, 0, 1 );
		pos[1] = Vector4( 1, 0, 0, 1 );

		pos[2] = Vector4( 0, 0, 0, 1 );
		pos[3] = Vector4( 0, 1, 0, 1 );

		pos[4] = Vector4( 0, 0, 0, 1 );
		pos[5] = Vector4( 0, 0, 1, 1 );

		D3D11_SUBRESOURCE_DATA initData;
		initData.pSysMem = pos;
		initData.SysMemPitch = 0;
		initData.SysMemSlicePitch = 0;
		DXCall( dx11_->getDevice()->CreateBuffer( &bufferDesc, &initData, &axesVertexBuffer_ ) );

		axesIndirectArgs_.Initialize( dx11_->getDevice(), 4, nullptr, false, true, false, true );
	}

	void SettingsTestApp::UpdateCamera( const Timer& timer )
	{
		const float dt = timer.getDeltaSeconds();

		Matrix4 world = inverse( viewMatrixForCamera_ );
		AppBase::UpdateCamera( world, dt * 5.0f );
		viewMatrixForCamera_ = inverse( world );
	}

	// Real-Time Rendering, 3rd Edition - 16.10.1, 16.14.3 (p. 755, 777)
	// pico warning!!!! picoViewFrustum has planes pointing inwards
	// this test assumes opposite
	// to use it with picoViewFrustum one has to change test from if ( s > e ) to if ( s + e < 0 )
	uint frustumOBBIntersectSimpleOptimized( const Vector4 frustumPlanes[6], const Vector4 &boxPosition, const Vector4 &boxHalfSize, const Vector4 &boxX, const Vector4 &boxY, const Vector4 &boxZ )
	{
		for ( int i = 0; i < 6; ++i )
		{
			Vector3 n = frustumPlanes[i].getXYZ();
			float e = boxHalfSize.getX().getAsFloat() * fabsf( dot( n, boxX.getXYZ() ).getAsFloat() )
					+ boxHalfSize.getY().getAsFloat() * fabsf( dot( n, boxY.getXYZ() ).getAsFloat() )
					+ boxHalfSize.getZ().getAsFloat() * fabsf( dot( n, boxZ.getXYZ() ).getAsFloat() );
			float s = dot( boxPosition.getXYZ(), n ).getAsFloat() + frustumPlanes[i].getW().getAsFloat();
			//if ( s > e )
			if ( s + e < 0 )
				return 0;
		}
		return 1;
	}

	void DebugDrawFrustum( const Matrix4 &viewProj, u32 colorABGR, bool enableDepth )
	{
		Vector3 frustumCorners[8];
		extractFrustumCorners( frustumCorners, viewProj, true );

		const float width = 4;

		// lines along z axis
		//
		debugDraw::AddLineWS( frustumCorners[0], frustumCorners[1], colorABGR, width, enableDepth );
		debugDraw::AddLineWS( frustumCorners[2], frustumCorners[3], colorABGR, width, enableDepth );
		debugDraw::AddLineWS( frustumCorners[4], frustumCorners[5], colorABGR, width, enableDepth );
		debugDraw::AddLineWS( frustumCorners[6], frustumCorners[7], colorABGR, width, enableDepth );

		// near plane
		//
		debugDraw::AddLineWS( frustumCorners[0], frustumCorners[2], colorABGR, width, enableDepth );
		debugDraw::AddLineWS( frustumCorners[2], frustumCorners[4], colorABGR, width, enableDepth );
		debugDraw::AddLineWS( frustumCorners[4], frustumCorners[6], colorABGR, width, enableDepth );
		debugDraw::AddLineWS( frustumCorners[6], frustumCorners[0], colorABGR, width, enableDepth );

		// far plane
		//
		debugDraw::AddLineWS( frustumCorners[1], frustumCorners[3], colorABGR, width, enableDepth );
		debugDraw::AddLineWS( frustumCorners[3], frustumCorners[5], colorABGR, width, enableDepth );
		debugDraw::AddLineWS( frustumCorners[5], frustumCorners[7], colorABGR, width, enableDepth );
		debugDraw::AddLineWS( frustumCorners[7], frustumCorners[1], colorABGR, width, enableDepth );
	}

	//uint GetClusterFlatIndex( uint cellX, uint cellY, uint cellZ )
	//{
	//	return ( cellZ * DECAL_VOLUME_CLUSTER_CELLS_X * DECAL_VOLUME_CLUSTER_CELLS_Y + cellY * DECAL_VOLUME_CLUSTER_CELLS_X + cellX );
	//}

	//void SettingsTestApp::RenderFrustum()
	//{
	//	//const float cameraNearPlane = 1.0f;
	//	//const float cameraFarPlane = 20.0f;

	//	//Matrix4 view = Matrix4::identity();
	//	////view = Matrix4::lookAt( Point3( 0, 0, 0 ), Point3( -5, 0, 0 ), Vector3::yAxis() );

	//	//Matrix4 proj = perspectiveProjectionDxStyle( deg2rad( 60.0f ), 1.0f, cameraNearPlane, cameraFarPlane );

	//	Matrix4 viewProj = testFrustumProj * testFrustumView;

	//	Vector3 frustumCorners[8];
	//	extractFrustumCorners( frustumCorners, viewProj, true );

	//	DebugDrawFrustum( viewProj, 0xffffffff, true );

	//	Vector4 frustumPlanes[6];
	//	extractFrustumPlanes( frustumPlanes, viewProj );

	//	//debugDraw::AddPlaneWS( frustumPlanes[4], 1, 1, 3, 3, 0xffffffff );

	//	constexpr u32 nSplits = FRUSTUM_GRID_NUM_Z;
	//	float splitNear[nSplits];
	//	float splitFar[nSplits];

	//	float nearPlaneForSubdiv = testFrustumNearPlane;
	//	float farPlaneForSubdiv = testFrustumFarPlane;

	//	float weight = 1.0f;
	//	float ratio = farPlaneForSubdiv / nearPlaneForSubdiv;

	//	splitNear[0] = nearPlaneForSubdiv;

	//	for ( u32 i = 1; i < nSplits; ++i )
	//	{
	//		float si = i / (float)nSplits;

	//		float logDistance = nearPlaneForSubdiv * powf( ratio, si );
	//		float uniformDistance = nearPlaneForSubdiv + ( farPlaneForSubdiv - nearPlaneForSubdiv )*si;

	//		// lerp between log and uniform distances
	//		//
	//		splitNear[i] = weight * logDistance + ( 1 - weight )*uniformDistance;
	//		splitFar[i - 1] = splitNear[i];
	//	}

	//	splitFar[nSplits-1] = farPlaneForSubdiv;

	//	Matrix4 cameraWorld = inverse( testFrustumView );

	//	for ( u32 iSlice = 0; iSlice < nSplits; ++iSlice )
	//	{
	//		const floatInVec cascadeNear( splitNear[iSlice] );
	//		const floatInVec cascadeNear0( splitNear[0] );
	//		const floatInVec cascadeFar( splitFar[iSlice] );

	//		Vector3 sliceCorners[4];

	//		for ( u32 i = 0; i < 4; ++i )
	//		{
	//			Vector3 frustRayN = normalize( frustumCorners[i * 2 + 1] - frustumCorners[i * 2 + 0] );

	//			//floatInVec cosAlpha = dot( frustRayN, -Vector3::zAxis() );
	//			floatInVec cosAlpha = dot( frustRayN, -cameraWorld.getCol2().getXYZ() );

	//			floatInVec edgeNear = cascadeNear / cosAlpha;
	//			//floatInVec edgeFar = cascadeFar / cosAlpha;
	//			sliceCorners[i] = frustRayN * edgeNear;
	//			//sliceCorners[i] = frustRayN * edgeFar;
	//		}

	//		constexpr u32 sliceColorABGR = 0xffff00ff;
	//		constexpr float width = 1.0f;
	//		constexpr bool enableDepth = true;

	//		debugDraw::AddLineWS( sliceCorners[0], sliceCorners[1], sliceColorABGR, width, enableDepth );
	//		debugDraw::AddLineWS( sliceCorners[1], sliceCorners[2], sliceColorABGR, width, enableDepth );
	//		debugDraw::AddLineWS( sliceCorners[2], sliceCorners[3], sliceColorABGR, width, enableDepth );
	//		debugDraw::AddLineWS( sliceCorners[3], sliceCorners[0], sliceColorABGR, width, enableDepth );
	//	}

	//	constexpr u32 subdivX = FRUSTUM_GRID_NUM_X;
	//	constexpr u32 subdivY = FRUSTUM_GRID_NUM_Y;

	//	//const Matrix4 baseProj = proj;
	//	constexpr float scaleX = 1.0f / subdivX;
	//	constexpr float scaleY = 1.0f / subdivY;

	//	float xOffs = scaleX - 1;
	//	float yOffs = scaleY - 1;
	//	//float zOffs = 0;

	//	float tileScaleX = 1 / scaleX;// *0.5f;
	//	float tileScaleY = 1 / scaleY;// *0.5f;

	//	Matrix4 subSc = Matrix4::scale( Vector3( 1.0f / scaleX, 1.0f / scaleY, 1.0f ) );

	//	std::vector<uint> decalLinkedList( MAX_LINKED_LIST_NODES, 0xffffffff );
	//	uint atomicCounter = 0;

	//	for ( u32 iZ = 0; iZ < nSplits; ++iZ )
	//	{
	//		Matrix4 baseProj = perspectiveProjectionDxStyle( deg2rad( 60.0f ), 1.0f, splitNear[iZ], splitFar[iZ] );
	//		Matrix4 baseProj2 = perspectiveProjectionDxStyle( deg2rad( 60.0f ), 1.0f, testFrustumNearPlane, testFrustumFarPlane );

	//		for ( u32 iY = 0; iY < subdivY; ++iY )
	//		{
	//			for ( u32 iX = 0; iX < subdivX; ++iX )
	//			{
	//				Matrix4 subTr = Matrix4::translation( Vector3( -xOffs, -yOffs, 0 ) );
	//				Matrix4 subProj = subSc * subTr * baseProj;

	//				//// TODO: Move to CPU?
	//				//// Calculate relevant matrix columns for this subfrustum.
	//				//float2 tileScale = float2( renderTargetSizeX, renderTargetSizeY ) * rcp( float2( 2 * TILE_SIZE_X, 2 * TILE_SIZE_Y ) );
	//				//float2 tileBias = float2( tileCoords.xy ) - tileScale;
	//				//float4 c1 = float4( proj_._11 * tileScale.x, 0.0f, tileBias.x, 0.0f );
	//				//float4 c2 = float4( 0.0f, -proj_._22 * tileScale.y, tileBias.y, 0.0f );
	//				//float4 c4 = float4( 0.0f, 0.0f, proj_._34, 0.0f );
	//				float tileBiasX = iX * 2 - tileScaleX + 1;
	//				float tileBiasY = iY * 2 - tileScaleY + 1;
	//				Vector4 c0( baseProj.getElem(0, 0).getAsFloat() * tileScaleX, 0, 0, 0 );
	//				Vector4 c1( 0, baseProj.getElem(1, 1).getAsFloat() * tileScaleY, 0, 0 );
	//				Vector4 c2( tileBiasX, tileBiasY, baseProj.getElem( 2, 2 ).getAsFloat(), baseProj.getElem(2, 3).getAsFloat() );
	//				Vector4 c3( 0, 0, baseProj.getElem( 3, 2 ).getAsFloat(), 0 );
	//				Matrix4 subProj2( c0, c1, c2, c3 );

	//				//float biasZ = splitNear[iZ] / testFrustumFarPlane;
	//				//float scaleZ = (splitFar[iZ] - splitNear[iZ]) / testFrustumFarPlane;
	//				//float biasZ = (float)iZ / (float)FRUSTUM_GRID_NUM_Z;
	//				//float scaleZ = splitFar[iZ] - splitNear[iZ];
	//				//float scaleZ = 1.0f / FRUSTUM_GRID_NUM_Z;
	//				float n = splitNear[iZ];
	//				float f = splitFar[iZ];
	//				float a = f / ( n - f );
	//				float b = n * f / ( n - f );
	//				Vector4 c02( baseProj2.getElem( 0, 0 ).getAsFloat() * tileScaleX, 0, 0, 0 );
	//				Vector4 c12( 0, baseProj2.getElem( 1, 1 ).getAsFloat() * tileScaleY, 0, 0 );
	//				//Vector4 c22( tileBiasX, tileBiasY, baseProj2.getElem( 2, 2 ).getAsFloat() * scaleZ - biasZ, baseProj2.getElem( 2, 3 ).getAsFloat() );
	//				//Vector4 c32( 0, 0, baseProj2.getElem( 3, 2 ).getAsFloat() * scaleZ, 0 );
	//				Vector4 c22( tileBiasX, tileBiasY, a, -1 );
	//				Vector4 c32( 0, 0, b, 0 );
	//				Matrix4 subProj3( c02, c12, c22, c32 );

	//				Matrix4 subViewProj = subProj2 * testFrustumView;

	//				//DebugDrawFrustum( subViewProj, ( iX & 1 ) ? 0xff00ff00 : 0xff008000, true );
	//				extractFrustumPlanes( frustumPlanes, subViewProj );

	//				uint headNodeIndex = GetClusterFlatIndex( iX, iY, iZ );
	//				uint firstNodeAddress = INVALID_DECAL_VOLUME_LIST_NODE_INDEX;
	//				uint prevNodeDecalIndex = INVALID_DECAL_VOLUME_INDEX;
	//				uint prevNodeAddress = INVALID_DECAL_VOLUME_LIST_NODE_INDEX;

	//				//if ( iZ == 0 && iX == 0 && iY == 0 )
	//				//{
	//				//	uint decalCount = 0;

	//					for ( uint iDecal = 0; iDecal < maxDecalVolumes; ++iDecal )
	//					{
	//						const DecalVolume &dv = g_decalVolumes[iDecal];
	//						uint intersection = frustumOBBIntersectSimpleOptimized( frustumPlanes, dv.position, dv.halfSize, dv.x, dv.y, dv.z );
	//						//decalCount += intersection;

	//						if ( intersection )
	//						{
	//							atomicCounter += 1;
	//							uint baseGlobalOffset = atomicCounter - 1;
	//							baseGlobalOffset += HEADER_LINKED_LIST_NODES;

	//							uint decalIndex = iDecal;
	//							uint nodeAddress = baseGlobalOffset;

	//							if ( prevNodeDecalIndex == INVALID_DECAL_VOLUME_INDEX )
	//							{
	//								prevNodeDecalIndex = decalIndex;
	//								prevNodeAddress = nodeAddress;
	//								firstNodeAddress = nodeAddress;
	//							}
	//							else
	//							{
	//								decalLinkedList[prevNodeAddress] = PackListNode( prevNodeDecalIndex, nodeAddress );
	//								prevNodeDecalIndex = decalIndex;
	//								prevNodeAddress = nodeAddress;
	//							}
	//						}
	//					}

	//					decalLinkedList[headNodeIndex] = PackListNode( INVALID_DECAL_VOLUME_INDEX, firstNodeAddress );
	//					if ( prevNodeDecalIndex != INVALID_DECAL_VOLUME_INDEX )
	//					{
	//						decalLinkedList[prevNodeAddress] = PackListNode( prevNodeDecalIndex, INVALID_DECAL_VOLUME_LIST_NODE_INDEX );
	//					}

	//				//	if ( decalCount > 0 )
	//				//	{
	//				//		std::cout << "decalCount " << decalCount << std::endl;
	//				//	}
	//				//}
	//				//frustumOBBIntersectSimpleOptimized

	//				xOffs += scaleX * 2;
	//			}

	//			xOffs = scaleX - 1;
	//			yOffs += scaleY * 2;
	//		}

	//		yOffs = scaleY - 1;
	//	}

	//	decalVolumesLinkedListCPU_.DeInitialize();
	//	decalVolumesLinkedListCPU_.Initialize( dx11_->getDevice(), decalLinkedList.size(), decalLinkedList.data(), true, false, false );
	//}

	//void SettingsTestApp::RenderFrustum2()
	//{
	//	//const float cameraNearPlane = 1.0f;
	//	//const float cameraFarPlane = 20.0f;

	//	//Matrix4 view = Matrix4::identity();
	//	////view = Matrix4::lookAt( Point3( 0, 0, 0 ), Point3( -5, 0, 0 ), Vector3::yAxis() );

	//	//Matrix4 proj = perspectiveProjectionDxStyle( deg2rad( 60.0f ), 1.0f, cameraNearPlane, cameraFarPlane );

	//	Matrix4 viewProj = testFrustumProj * testFrustumView;

	//	Vector3 frustumCorners[8];
	//	extractFrustumCorners( frustumCorners, viewProj, true );

	//	DebugDrawFrustum( viewProj, 0xffffffff, true );

	//	//Vector4 frustumPlanes[6];
	//	//extractFrustumPlanes( frustumPlanes, viewProj );

	//	////debugDraw::AddPlaneWS( frustumPlanes[4], 1, 1, 3, 3, 0xffffffff );

	//	//constexpr u32 nSplits = 2;
	//	//float splitNear[nSplits];
	//	//float splitFar[nSplits];

	//	//float nearPlaneForSubdiv = testFrustumNearPlane;
	//	//float farPlaneForSubdiv = testFrustumFarPlane;

	//	//float weight = 1.0f;
	//	//float ratio = farPlaneForSubdiv / nearPlaneForSubdiv;

	//	//splitNear[0] = nearPlaneForSubdiv;

	//	//for ( u32 i = 1; i < nSplits; ++i )
	//	//{
	//	//	float si = i / (float)nSplits;

	//	//	float logDistance = nearPlaneForSubdiv * powf( ratio, si );
	//	//	float uniformDistance = nearPlaneForSubdiv + ( farPlaneForSubdiv - nearPlaneForSubdiv )*si;

	//	//	// lerp between log and uniform distances
	//	//	//
	//	//	splitNear[i] = weight * logDistance + ( 1 - weight )*uniformDistance;
	//	//	splitFar[i - 1] = splitNear[i];
	//	//}

	//	//splitFar[nSplits - 1] = farPlaneForSubdiv;

	//	//Matrix4 cameraWorld = inverse( testFrustumView );

	//	//for ( u32 iSlice = 0; iSlice < nSplits; ++iSlice )
	//	//{
	//	//	const floatInVec cascadeNear( splitNear[iSlice] );
	//	//	const floatInVec cascadeNear0( splitNear[0] );
	//	//	const floatInVec cascadeFar( splitFar[iSlice] );

	//	//	Vector3 sliceCorners[4];

	//	//	for ( u32 i = 0; i < 4; ++i )
	//	//	{
	//	//		Vector3 frustRayN = normalize( frustumCorners[i * 2 + 1] - frustumCorners[i * 2 + 0] );

	//	//		//floatInVec cosAlpha = dot( frustRayN, -Vector3::zAxis() );
	//	//		floatInVec cosAlpha = dot( frustRayN, -cameraWorld.getCol2().getXYZ() );

	//	//		floatInVec edgeNear = cascadeNear / cosAlpha;
	//	//		//floatInVec edgeFar = cascadeFar / cosAlpha;
	//	//		sliceCorners[i] = frustRayN * edgeNear;
	//	//		//sliceCorners[i] = frustRayN * edgeFar;
	//	//	}

	//	//	constexpr u32 sliceColorABGR = 0xffff00ff;
	//	//	constexpr float width = 1.0f;
	//	//	constexpr bool enableDepth = true;

	//	//	debugDraw::AddLineWS( sliceCorners[0], sliceCorners[1], sliceColorABGR, width, enableDepth );
	//	//	debugDraw::AddLineWS( sliceCorners[1], sliceCorners[2], sliceColorABGR, width, enableDepth );
	//	//	debugDraw::AddLineWS( sliceCorners[2], sliceCorners[3], sliceColorABGR, width, enableDepth );
	//	//	debugDraw::AddLineWS( sliceCorners[3], sliceCorners[0], sliceColorABGR, width, enableDepth );
	//	//}

	//	//constexpr u32 subdivX = 4;
	//	//constexpr u32 subdivY = 2;

	//	////const Matrix4 baseProj = proj;
	//	//constexpr float scaleX = 1.0f / subdivX;
	//	//constexpr float scaleY = 1.0f / subdivY;

	//	//float xOffs = scaleX - 1;
	//	//float yOffs = scaleY - 1;
	//	////float zOffs = 0;

	//	//float tileScaleX = 1 / scaleX;// *0.5f;
	//	//float tileScaleY = 1 / scaleY;// *0.5f;

	//	//Matrix4 subSc = Matrix4::scale( Vector3( 1.0f / scaleX, 1.0f / scaleY, 1.0f ) );

	//	////std::vector<uint> decalLinkedList( MAX_LINKED_LIST_NODES, 0xffffffff );
	//	////uint atomicCounter = 0;

	//	//for ( u32 iZ = 0; iZ < nSplits; ++iZ )
	//	//{
	//	//	Matrix4 baseProj = perspectiveProjectionDxStyle( deg2rad( 60.0f ), 1.0f, splitNear[iZ], splitFar[iZ] );
	//	//	Matrix4 baseProj2 = perspectiveProjectionDxStyle( deg2rad( 60.0f ), 1.0f, testFrustumNearPlane, testFrustumFarPlane );

	//	//	for ( u32 iY = 0; iY < subdivY; ++iY )
	//	//	{
	//	//		for ( u32 iX = 0; iX < subdivX; ++iX )
	//	//		{
	//	//			Matrix4 subTr = Matrix4::translation( Vector3( -xOffs, -yOffs, 0 ) );
	//	//			Matrix4 subProj = subSc * subTr * baseProj;

	//	//			//// TODO: Move to CPU?
	//	//			//// Calculate relevant matrix columns for this subfrustum.
	//	//			//float2 tileScale = float2( renderTargetSizeX, renderTargetSizeY ) * rcp( float2( 2 * TILE_SIZE_X, 2 * TILE_SIZE_Y ) );
	//	//			//float2 tileBias = float2( tileCoords.xy ) - tileScale;
	//	//			//float4 c1 = float4( proj_._11 * tileScale.x, 0.0f, tileBias.x, 0.0f );
	//	//			//float4 c2 = float4( 0.0f, -proj_._22 * tileScale.y, tileBias.y, 0.0f );
	//	//			//float4 c4 = float4( 0.0f, 0.0f, proj_._34, 0.0f );
	//	//			float tileBiasX = iX * 2 - tileScaleX + 1;
	//	//			float tileBiasY = iY * 2 - tileScaleY + 1;
	//	//			Vector4 c0( baseProj.getElem( 0, 0 ).getAsFloat() * tileScaleX, 0, 0, 0 );
	//	//			Vector4 c1( 0, baseProj.getElem( 1, 1 ).getAsFloat() * tileScaleY, 0, 0 );
	//	//			Vector4 c2( tileBiasX, tileBiasY, baseProj.getElem( 2, 2 ).getAsFloat(), baseProj.getElem( 2, 3 ).getAsFloat() );
	//	//			Vector4 c3( 0, 0, baseProj.getElem( 3, 2 ).getAsFloat(), 0 );
	//	//			Matrix4 subProj2( c0, c1, c2, c3 );

	//	//			//float biasZ = splitNear[iZ] / testFrustumFarPlane;
	//	//			//float scaleZ = (splitFar[iZ] - splitNear[iZ]) / testFrustumFarPlane;
	//	//			//float biasZ = (float)iZ / (float)FRUSTUM_GRID_NUM_Z;
	//	//			//float scaleZ = splitFar[iZ] - splitNear[iZ];
	//	//			//float scaleZ = 1.0f / FRUSTUM_GRID_NUM_Z;
	//	//			float n = splitNear[iZ];
	//	//			float f = splitFar[iZ];
	//	//			float a = f / ( n - f );
	//	//			float b = n * f / ( n - f );
	//	//			Vector4 c02( baseProj2.getElem( 0, 0 ).getAsFloat() * tileScaleX, 0, 0, 0 );
	//	//			Vector4 c12( 0, baseProj2.getElem( 1, 1 ).getAsFloat() * tileScaleY, 0, 0 );
	//	//			//Vector4 c22( tileBiasX, tileBiasY, baseProj2.getElem( 2, 2 ).getAsFloat() * scaleZ - biasZ, baseProj2.getElem( 2, 3 ).getAsFloat() );
	//	//			//Vector4 c32( 0, 0, baseProj2.getElem( 3, 2 ).getAsFloat() * scaleZ, 0 );
	//	//			Vector4 c22( tileBiasX, tileBiasY, a, -1 );
	//	//			Vector4 c32( 0, 0, b, 0 );
	//	//			Matrix4 subProj3( c02, c12, c22, c32 );

	//	//			Matrix4 subViewProj = subProj2 * testFrustumView;

	//	//			extractFrustumPlanes( frustumPlanes, subViewProj );

	//	//			xOffs += scaleX * 2;
	//	//		}

	//	//		xOffs = scaleX - 1;
	//	//		yOffs += scaleY * 2;
	//	//	}

	//	//	yOffs = scaleY - 1;
	//	//}
	//}

	//static inline Vector3 projPoint( const Matrix4& viewProj, const Vector3& pos )
	//{
	//	Vector4 hpos = viewProj * Point3( pos );
	//	Vector3 projPos = hpos.getXYZ() / hpos.getW();
	//	return projPos;
	//}

	void SettingsTestApp::KeyPressed( uint key, bool shift, bool alt, bool ctrl )
	{
		(void)shift;
		(void)alt;
		(void)ctrl;

		if ( key == 'R' || key == 'r' )
		{
			//meshShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\mesh.hlslc_packed" );
			//gpuClusteringShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\gpuClustering.hlslc_packed" );
			decalVolumeRenderingShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\decal_volume_rendering.hlslc_packed" );
			decalVolumeCullShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\cs_decal_volume_culling.hlslc_packed" );
			tiling_->shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\cs_decal_volume_tiling.hlslc_packed" );
			clustering_->shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\cs_decal_volume_clustering.hlslc_packed" );
		}
	}

	void SettingsTestApp::UpdateAndRender( const Timer& timer )
	{
		fpsCounter_.update(timer);

		Dx11DeviceContext& immediateContextWrapper = dx11_->getImmediateContextWrapper();
		ID3D11DeviceContext* immediateContext = immediateContextWrapper.context;
		immediateContext->ClearState();

		dx11_->SetBackBufferRT();
		// Set default render targets
		ID3D11RenderTargetView* rtviews[1] = { dx11_->getBackBufferRTV() };
		immediateContext->OMSetRenderTargets( 1, rtviews, mainDS_.dsv_ );

		// Setup the viewport
		D3D11_VIEWPORT vp;
		vp.Width = static_cast<float>( dx11_->getBackBufferWidth() );
		vp.Height = static_cast<float>( dx11_->getBackBufferHeight() );
		vp.MinDepth = 0.0f;
		vp.MaxDepth = 1.0f;
		vp.TopLeftX = 0;
		vp.TopLeftY = 0;
		immediateContext->RSSetViewports( 1, &vp );

		const float clearColor[] = { 0.2f, 0.2f, 0.2f, 1 };
		immediateContext->ClearRenderTargetView( dx11_->getBackBufferRTV(), clearColor );
		//immediateContext->ClearDepthStencilView( mainDS_.dsv_, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 1, 0 );
		immediateContext->ClearDepthStencilView( mainDS_.dsv_, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 0, 0 );

		immediateContext->RSSetState( RasterizerStates::BackFaceCull() );
		//immediateContext->OMSetDepthStencilState( DepthStencilStates::DepthWriteEnabled(), 0 );
		immediateContext->OMSetDepthStencilState( DepthStencilStates::ReverseDepthWriteEnabled(), 0 );

		UpdateCamera( timer );

		//float rtWidth = (float)dx11_->getBackBufferWidth();
		//float rtHeight = (float)dx11_->getBackBufferHeight();
		const float aspect = (float)dx11_->getBackBufferWidth() / (float)dx11_->getBackBufferHeight();
		//Matrix4 view = ( Matrix4::lookAt( Point3( 10, 10, 10 ), Point3( 0, 0, 0 ), Vector3::yAxis() ) );
		//Matrix4 proj = perspectiveProjectionDxStyle( deg2rad( 60.0f ), aspect, 0.1f, 100 );
		//projMatrixForCamera_ = perspectiveProjectionDxStyle( deg2rad( 60.0f ), aspect, 4.0f, decalVolumeFarPlane_ );
		projMatrixForCamera_ = InfinitePerspectiveMatrix2( deg2rad( 60.0f ), aspect, 4.0f );

		if ( appMode_ == Tiling || appMode_ == Clustering )
		{
			viewMatrixForDecalVolumes_ = Matrix4::identity();
			projMatrixForDecalVolumes_ = ProjMatrixForDecalVolumes();

			CullDecalVolumes( immediateContextWrapper );

			if ( appMode_ == Tiling )
				//DecalVolumeTilingRun( immediateContextWrapper );
				DecalVolumeClusteringRun( immediateContextWrapper, *tiling_ );
			else if ( appMode_ == Clustering )
				DecalVolumeClusteringRun( immediateContextWrapper, *clustering_ );
		}
		else if ( appMode_ == Scene )
		{
			viewMatrixForDecalVolumes_ = viewMatrixForCamera_;
			//projMatrixForDecalVolumes_ = ProjMatrixForDecalVolumes();
			projMatrixForDecalVolumes_ = projMatrixForCamera_;

			CullDecalVolumes( immediateContextWrapper );

			ModelRender( immediateContextWrapper );

			immediateContext->OMSetRenderTargets( 1, rtviews, nullptr );

			DownsampleDepth( immediateContextWrapper );

			//DecalVolumeClusteringRun( immediateContextWrapper, *clustering_ );
			DecalVolumeClusteringRun( immediateContextWrapper, *tiling_ );
		}

		//RenderFrustum2();
		//RenderFrustum3();

		//DebugDrawDecalVolumes();

		//debugDraw::AddLineWS( Vector3( 0, 0, 0 ), Vector3( 1, 0, 0 ), 0xff0000ff, 1.0f, false );
		//debugDraw::AddLineWS( Vector3( 0, 0, 0 ), Vector3( 0, 1, 0 ), 0xff00ff00, 1.0f, false );
		//debugDraw::AddLineWS( Vector3( 0, 0, 0 ), Vector3( 0, 0, 1 ), 0xffff0000, 1.0f, false );

		//DrawDecalBoxes( immediateContextWrapper );
		//DrawScreenSpaceGrid( immediateContextWrapper );

		//ModelStartUp();
		//GenDecalVolumesModel();
		//ModelRender( immediateContextWrapper );

		DrawBoxesAndAxesFillIndirectArgs( immediateContextWrapper );
		DrawDecalBoxes( immediateContextWrapper );
		DrawDecalAxes( immediateContextWrapper );
		//DrawDecalFarPlane( immediateContextWrapper );

		DrawClusteringHeatmap( immediateContextWrapper );
		DrawDepth( immediateContextWrapper );

		Vector4 plane( 0, 1, 0, 0 );
		debugDraw::AddPlaneWS( plane, 6, 6, 6, 6, 0xff0000ff, 1, false );
		debugDraw::AddAxes( Vector3( 0.0f ), Vector3(3.0f), Matrix3::identity(), 1.0f );

		debugDraw::DontTouchThis::Draw( immediateContextWrapper, viewMatrixForCamera_, projMatrixForCamera_, dx11_->getBackBufferWidth(), dx11_->getBackBufferHeight() );
		debugDraw::DontTouchThis::Clear();
	}

	void SettingsTestApp::UpdateImGui( const Timer& /*timer*/ )
	{
		Vector3 cameraPos = inverse( viewMatrixForCamera_ ).getTranslation();
		ImGui::Text( "Camera pos [%3.3f %3.3f %3.3f]", cameraPos.getX().getAsFloat(), cameraPos.getY().getAsFloat(), cameraPos.getZ().getAsFloat() );

		if ( ImGui::SliderInt( "Max decal volumes", &maxDecalVolumes_, 1, 16 * 1024 ) )
		{
			//tiling_ = DecalVolumeTilingStartUp();
			tiling_ = DecalVolumeClusteringStartUp( false );
			clustering_ = DecalVolumeClusteringStartUp( true );

			if ( appMode_ == Scene )
				GenDecalVolumesModel();
			else if ( appMode_ == Tiling || appMode_ == Clustering )
				GenDecalVolumesRandom();
		}

		{
			const char* items[] = { "Exernal camera", "Gpu heatmap", "Cpu heatmap", "Decal Volumes Accum", "Depth Buffer" };
			ImGui::Combo( "View", reinterpret_cast<int*>( &currentView_ ), items, IM_ARRAYSIZE( items ) );
			if ( currentView_ == DepthBuffer )
			{
				ImGui::SliderInt( "Depth mip", &depthBufferMip_, 0, 5 );
				ImGui::Checkbox( "Show min depth", &depthBufferShowMin_ );
			}
		}

		ImGui::Text( "Num decals %u / %u / %u", decalVolumesCulledCount_, numDecalVolumes_, maxDecalVolumes_ );

		if ( ImGui::SliderFloat( "Decal volume grid far plane", &decalVolumeFarPlane_, 5.0f, 10000.0f ) )
		{
		}

		if ( appMode_ == Scene )
		{
			if ( ImGui::CollapsingHeader( "Scene", nullptr, ImGuiTreeNodeFlags_DefaultOpen ) )
			{
				const char* items[] = { "Solid", "Wireframe" };
				ImGui::Combo( "Render mode", reinterpret_cast<int*>( &sceneRenderMode_ ), items, IM_ARRAYSIZE( items ) );

				if ( ImGui::SliderFloat( "Area threshold", &decalVolumesAreaThreshold_, 0.0f, 500.0f ) )
				{
					GenDecalVolumesModel();
				}

				if ( ImGui::SliderFloat( "Decal volume scale", &decalVolumesModelScale_, 0.001f, 2.0f ) )
				{
					GenDecalVolumesModel();
				}
			}
		}
		else if ( appMode_ == Tiling || appMode_ == Clustering )
		{
			if ( ImGui::CollapsingHeader( "Random", nullptr, ImGuiTreeNodeFlags_DefaultOpen ) )
			{
				if ( ImGui::SliderFloat( "Decal volume scale", &decalVolumesRandomScale_, 0.01f, 20.0f ) )
				{
					GenDecalVolumesRandom();
				}
			}
		}

		{
			const char* items[] = {
				"1920_1080",
				"1280_720",
				"3840_2160",
				"4096_4096",
				"2048_2048",
				"1024_1024",
				"512_512",
				"128_128",
				"64_64",
			};

			if ( ImGui::Combo( "RT Size", reinterpret_cast<int*>( &rtSize_ ), items, IM_ARRAYSIZE( items ) ) )
			{
				//tiling_ = DecalVolumeTilingStartUp();
				tiling_ = DecalVolumeClusteringStartUp( false );
				clustering_ = DecalVolumeClusteringStartUp( true );
			}
		}

		if ( appMode_ == Tiling || appMode_ == Scene )
		{
			const char* items[] = { "512x512", "256x256", "128x128", "64x64", "48x48", "32x32", "16x16", "8x8" };
			if ( ImGui::Combo( "Tile size (tiling)", reinterpret_cast<int*>( &tileSizeForTiling_ ), items, IM_ARRAYSIZE( items ) ) )
			{
				//tiling_ = DecalVolumeTilingStartUp();
				tiling_ = DecalVolumeClusteringStartUp( false );
			}

			if ( ImGui::SliderInt( "Num passes (tiling)", &numPassesForTiling_, 1, 6 ) )
			{
				//tiling_ = DecalVolumeTilingStartUp();
				tiling_ = DecalVolumeClusteringStartUp( false );
			}
		}
		else
		{
			const char* items[] = { "512x512", "256x256", "128x128", "64x64", "48x48", "32x32", "16x16", "8x8" };
			if ( ImGui::Combo( "Tile size (clustering)", reinterpret_cast<int*>( &tileSizeForClustering_ ), items, IM_ARRAYSIZE( items ) ) )
			{
				clustering_ = DecalVolumeClusteringStartUp( true );
			}

			if ( ImGui::SliderInt( "Num passes (clustering)", &numPassesForClustering_, 1, 6 ) )
			{
				clustering_ = DecalVolumeClusteringStartUp( true );
			}
		}

		if ( appMode_ == Tiling || appMode_ == Scene )
		{
			const DecalVolumeClusteringPass &p = tiling_->passes_.back();
			ImGui::Text( "Num decals in all cells %u / %u", p.stats.numDecalsInAllCells, p.maxDecalIndices );
			ImGuiPrintClusteringInfo( *tiling_ );
		}
		else if ( appMode_ == Clustering || appMode_ == Scene )
		{
			const DecalVolumeClusteringPass &p = clustering_->passes_.back();
			ImGui::Text( "Num decals in all cells %u / %u", p.stats.numDecalsInAllCells, p.maxDecalIndices );
			ImGuiPrintClusteringInfo( *clustering_ );
		}

		if ( tiling_->needsReset_ )
		{
			//tiling_ = DecalVolumeTilingStartUp();
			tiling_ = DecalVolumeClusteringStartUp( false );
		}

		if ( clustering_->needsReset_ )
		{
			clustering_ = DecalVolumeClusteringStartUp( true );
		}
	}

	void SettingsTestApp::RenderFrustum3()
	{
		Vector4 tanHalfFov;
		tanHalfFov.setX( floatInVec( 1.0f ) / projMatrixForDecalVolumes_.getElem( 0, 0 ) );
		tanHalfFov.setY( floatInVec( 1.0f ) / projMatrixForDecalVolumes_.getElem( 1, 1 ) );
		tanHalfFov.setZ( projMatrixForDecalVolumes_.getElem( 0, 0 ) );
		tanHalfFov.setW( projMatrixForDecalVolumes_.getElem( 1, 1 ) );

		//Vector3 cellCount = Vector3( 4, 4, 1 );
		//Vector3 cellCountRcp = divPerElem( Vector3( 1.0f ), cellCount );
		//FrustumTest( cellCount, cellCountRcp, Vector3( 0, 3, 0 ), tanHalfFov, 4.0f, 1000.0f );

		Vector3 eyeAxis[3];
		eyeAxis[0] = Vector3( 1, 0, 0 ) * tanHalfFov.getX();
		eyeAxis[1] = Vector3( 0, 1, 0 ) * tanHalfFov.getY();
		eyeAxis[2] = Vector3( 0, 0, -1 );
		Vector3 eyeOffset = Vector3( 0, 0, 0 );

		float depth0 = 4;
		float depth1 = 1000;
		Vector3 frustumCorners[8];

		float sxRcp = 1.0f / 4.0f;
		float syRcp = 1.0f / 4.0f;

		for ( uint y = 0; y < 4; ++y )
		{
			for ( uint x = 0; x < 4; ++x )
			{
				float uvx = x * sxRcp;
				float uvy = y * syRcp;

				float left = uvx * 2 - 1;
				float right = (uvx + sxRcp) * 2 - 1;
				float bottom = uvy * 2 - 1;
				float top = ( uvy + syRcp ) * 2 - 1;

				frustumCorners[0] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, bottom, depth0 ) );
				frustumCorners[1] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, bottom, depth0 ) );
				frustumCorners[2] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, top, depth0 ) );
				frustumCorners[3] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, top, depth0 ) );

				frustumCorners[4] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, bottom, depth1 ) );
				frustumCorners[5] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, bottom, depth1 ) );
				frustumCorners[6] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( left, top, depth1 ) );
				frustumCorners[7] = WorldPositionFromScreenCoords2( eyeAxis, eyeOffset, Vector3( right, top, depth1 ) );

				debugDraw::AddLineWS( frustumCorners[0], frustumCorners[1], 0xffffffff, 1.0f, false );
				debugDraw::AddLineWS( frustumCorners[1], frustumCorners[3], 0xffffffff, 1.0f, false );
				debugDraw::AddLineWS( frustumCorners[3], frustumCorners[2], 0xffffffff, 1.0f, false );
				debugDraw::AddLineWS( frustumCorners[2], frustumCorners[0], 0xffffffff, 1.0f, false );

				debugDraw::AddLineWS( frustumCorners[0], frustumCorners[4], 0xffffffff, 1.0f, false );
				debugDraw::AddLineWS( frustumCorners[1], frustumCorners[5], 0xffffffff, 1.0f, false );
				debugDraw::AddLineWS( frustumCorners[2], frustumCorners[6], 0xffffffff, 1.0f, false );
				debugDraw::AddLineWS( frustumCorners[3], frustumCorners[7], 0xffffffff, 1.0f, false );
			}
		}

		OrientedBoundingBox2 obb;
		obb.center = Vector3( 0, 0, -20 );
		//obb.axes[0] = Vector3::xAxis();
		//obb.axes[1] = Vector3::yAxis();
		//obb.axes[2] = Vector3::zAxis();
		Matrix4 rot = Matrix4::rotationZYX( Vector3( 0, 0, deg2rad( -45.0f ) ) );
		obb.axes[0] = rot.getCol0().getXYZ();
		obb.axes[1] = rot.getCol1().getXYZ();
		obb.axes[2] = rot.getCol2().getXYZ();
		obb.halfSize = Vector3( 4, 1, 1 ) * floatInVec( 1.572f );

		Vector3 x = obb.axes[0] * obb.halfSize.getX();
		Vector3 y = obb.axes[1] * obb.halfSize.getY();
		Vector3 z = obb.axes[2] * obb.halfSize.getZ();

		Vector3 bc[8];
		bc[0] = obb.center - x - y + z;
		bc[1] = obb.center + x - y + z;
		bc[2] = obb.center - x + y + z;
		bc[3] = obb.center + x + y + z;

		bc[4] = obb.center - x - y - z;
		bc[5] = obb.center + x - y - z;
		bc[6] = obb.center - x + y - z;
		bc[7] = obb.center + x + y - z;

		uint color = 0xff0000ff;
		debugDraw::AddLineWS( bc[0], bc[1], color, 1.0f, false );
		debugDraw::AddLineWS( bc[1], bc[3], color, 1.0f, false );
		debugDraw::AddLineWS( bc[3], bc[2], color, 1.0f, false );
		debugDraw::AddLineWS( bc[2], bc[0], color, 1.0f, false );

		debugDraw::AddLineWS( bc[4], bc[5], color, 1.0f, false );
		debugDraw::AddLineWS( bc[5], bc[7], color, 1.0f, false );
		debugDraw::AddLineWS( bc[7], bc[6], color, 1.0f, false );
		debugDraw::AddLineWS( bc[6], bc[4], color, 1.0f, false );

		debugDraw::AddLineWS( bc[1], bc[5], color, 1.0f, false );
		debugDraw::AddLineWS( bc[3], bc[7], color, 1.0f, false );

		debugDraw::AddLineWS( bc[0], bc[4], color, 1.0f, false );
		debugDraw::AddLineWS( bc[2], bc[6], color, 1.0f, false );
	}


	u32 GetMipMapCountFromDimesions( u32 mipW, u32 mipH, u32 mipD )
	{
		//unsigned int max=(imageWidth>imageHeight)?imageWidth:imageHeight;
		//max=(max>imageDepth)?max:imageDepth;
		u32 max = maxOfTriple( (i32)mipW, (i32)mipH, (i32)mipD );
		u16 i = 0;

		while ( max > 0 )
		{
			max >>= 1;
			i++;
		}

		return i;
	}

	void SettingsTestApp::SceneReset()
	{
		if ( appMode_ == Tiling || appMode_ == Clustering )
		{
			viewMatrixForCamera_ = ( Matrix4::lookAt( Point3( 5, 5, 0 ), Point3( 0, 0, -5 ), Vector3::yAxis() ) );
			viewMatrixForDecalVolumes_ = Matrix4::identity();
			projMatrixForDecalVolumes_ = ProjMatrixForDecalVolumes();

			GenDecalVolumesRandom();
		}
		else if ( appMode_ == Scene )
		{
			//viewMatrixForCamera_ = Matrix4::identity();
			viewMatrixForCamera_ = Matrix4::lookAt( Point3( 90, 20, -4 ), Point3( 0, 30, -4 ), Vector3::yAxis() );
			viewMatrixForDecalVolumes_ = viewMatrixForCamera_;
			projMatrixForDecalVolumes_ = projMatrixForCamera_;

			uint rtWidth, rtHeight;
			GetRenderTargetSize( rtWidth, rtHeight );

			uint nMips = GetMipMapCountFromDimesions( rtWidth, rtHeight, 1 );

			clusterDS_.DeInitialize();
			clusterDS_.Initialize( dx11_->getDevice(), rtWidth, rtHeight, 1, DXGI_FORMAT_R16G16_FLOAT, nMips, 1, false, nullptr, true );

			ModelStartUp();
			GenDecalVolumesModel();
		}

		//Matrix4 proj = InfinitePerspectiveMatrix(
		//	1.0f / projMatrixForDecalVolumes_.getElem( 0, 0 ).getAsFloat(),
		//	1.0f / projMatrixForDecalVolumes_.getElem( 1, 1 ).getAsFloat(),
		//	testFrustumNearPlane
		//);

		//Vector4 projMatrixParams = Vector4(
		//	  proj.getElem( 0, 0 )
		//	, proj.getElem( 1, 1 )
		//	, proj.getElem( 2, 2 )
		//	, proj.getElem( 3, 2 )
		//);

		//float linearDepth = projMatrixParams.w / (nonLinearDepth + projMatrixParams.z);
		// float linearDepth = testFrustumNearPlane / nonLinearDepth; // for InfinitePerspectiveMatrix

	}

	void SettingsTestApp::ModelStartUp()
	{
		// Lazy startup
		if ( !sceneModel_.Meshes().empty() )
		{
			return;
		}

		sceneModel_.CreateWithAssimp( dx11_->getDevice(), "Assets\\Models\\Sponza\\Sponza.fbx", 0.1f );
		//meshShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\mesh.hlslc_packed" );
	}

	void SettingsTestApp::ModelRender( Dx11DeviceContext& deviceContext )
	{
		ID3D11DeviceContext *const context = deviceContext.context;

		const HlslShaderPass* fxPass = decalVolumeRenderingShader_->getPass( "ModelDiffuse" );;
		fxPass->setVS( deviceContext.context );
		fxPass->setPS( deviceContext.context );

		if ( sceneRenderMode_ == Solid )
		{
			deviceContext.context->RSSetState( RasterizerStates::BackFaceCull() );
		}
		else if ( sceneRenderMode_ == Wireframe )
		{
			deviceContext.context->RSSetState( RasterizerStates::WireframeBackFaceCull() );
		}
		else
		{
			SPAD_NOT_IMPLEMENTED;
		}

		//deviceContext.context->OMSetDepthStencilState( DepthStencilStates::DepthWriteEnabled(), 0 );
		deviceContext.context->OMSetDepthStencilState( DepthStencilStates::ReverseDepthWriteEnabled(), 0 );

		passConstants_.data.View = ToFloat4x4( viewMatrixForCamera_ );
		passConstants_.data.ViewProjection = ToFloat4x4( projMatrixForCamera_ * viewMatrixForCamera_ );
		passConstants_.updateGpu( deviceContext.context );
		passConstants_.setVS( deviceContext.context, 0 );

		Matrix4 world = Matrix4::identity();
		objectConstants_.data.World = ToFloat4x4( world );
		objectConstants_.data.WorldIT = ToFloat4x4( transpose( affineInverse( world ) ) );
		objectConstants_.updateGpu( deviceContext.context );
		objectConstants_.setVS( deviceContext.context, 1 );

		context->PSSetSamplers( REGISTER_SAMPLER_DIFFUSE_SAMPLER, 1, &SamplerStates::anisotropic );

		Dx11InputLayoutCache& inputLayoutCache = deviceContext.inputLayoutCache;

		const Model &model = sceneModel_;

		for ( u32 meshIdx = 0; meshIdx < model.Meshes().size(); ++meshIdx )
		{
			const Mesh& mesh = model.Meshes()[meshIdx];

			// Set the vertices and indices
			ID3D11Buffer* vertexBuffers[1] = { mesh.VertexBuffer() };
			u32 vertexStrides[1] = { mesh.VertexStride() };
			u32 offsets[1] = { 0 };
			context->IASetVertexBuffers( 0, 1, vertexBuffers, vertexStrides, offsets );
			context->IASetIndexBuffer( mesh.IndexBuffer(), mesh.IndexBufferFormat(), 0 );
			context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );

			// Set the input layout
			//context->IASetInputLayout( meshData.InputLayouts[meshIdx] );
			inputLayoutCache.setInputLayout( context, mesh.InputElementsHash(), fxPass->vsInputSignatureHash_
				, mesh.InputElements(), mesh.NumInputElements(), reinterpret_cast<const u8*>( fxPass->vsInputSignature_->GetBufferPointer() ), (u32)fxPass->vsInputSignature_->GetBufferSize() );

			// Draw all parts
			for ( size_t partIdx = 0; partIdx < mesh.MeshParts().size(); ++partIdx )
			{
				const MeshPart& part = mesh.MeshParts()[partIdx];
				const MeshMaterial& material = model.Materials()[part.MaterialIdx];

				ID3D11ShaderResourceView* psTextures[1] = {
					material.DiffuseMap
				};

				context->PSSetShaderResources( REGISTER_TEXTURE_DIFFUSE_TEXTURE, 1, psTextures );
				context->DrawIndexed( part.IndexCount, part.IndexStart, 0 );
			}
		}
	}

	void SettingsTestApp::CullDecalVolumes( Dx11DeviceContext& deviceContext )
	{
		deviceContext.BeginMarker( "CullDecalVolumes" );

		decalVolumesCulledCountGPU_.clearUAVUint( deviceContext.context, 0 );

		if ( numDecalVolumes_ == 0 )
		{
			deviceContext.EndMarker();
			return;
		}

		const HlslShaderPass& fxPass = *decalVolumeCullShader_->getPass( "cs_decal_volume_culling" );
		fxPass.setCS( deviceContext.context );

		Vector4 frustumPlanes[6];
		Matrix4 viewProj = projMatrixForDecalVolumes_ * viewMatrixForDecalVolumes_;
		extractFrustumPlanes( frustumPlanes, viewProj );

		decalVolumeCullConstants_.data.ViewProjMatrix = viewProj;
		decalVolumeCullConstants_.data.frustumPlane0 = frustumPlanes[0];
		decalVolumeCullConstants_.data.frustumPlane1 = frustumPlanes[1];
		decalVolumeCullConstants_.data.frustumPlane2 = frustumPlanes[2];
		decalVolumeCullConstants_.data.frustumPlane3 = frustumPlanes[3];
		decalVolumeCullConstants_.data.frustumPlane4 = frustumPlanes[4];
		decalVolumeCullConstants_.data.frustumPlane5 = frustumPlanes[5];
		decalVolumeCullConstants_.data.numDecalsToCull[0] = numDecalVolumes_;
		decalVolumeCullConstants_.data.numDecalsToCull[1] = 0;
		decalVolumeCullConstants_.data.numDecalsToCull[2] = 0;
		decalVolumeCullConstants_.data.numDecalsToCull[3] = 0;
		decalVolumeCullConstants_.updateGpu( deviceContext.context );
		decalVolumeCullConstants_.setCS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS );

		decalVolumesGPU_.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS );
		decalVolumesCulledGPU_.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS );
		decalVolumesCulledCountGPU_.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS_COUNT );
		decalVolumesTestCulledGPU_.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS_TEST );

		uint nGroupsX = ( numDecalVolumes_ + DECAL_VOLUME_CULL_NUM_THREADS_PER_GROUP - 1 ) / DECAL_VOLUME_CULL_NUM_THREADS_PER_GROUP;
		deviceContext.context->Dispatch( nGroupsX, 1, 1 );

		deviceContext.UnbindCSUAVs();

		//const u32 *numDecalsVisible = decalVolumesCulledCountGPU_.CPUReadbackStart( deviceContext.context );
		//decalVolumesCulledCount_ = *numDecalsVisible;
		//decalVolumesCulledCountGPU_.CPUReadbackEnd( deviceContext.context );

		deviceContext.EndMarker();
	}

	void SettingsTestApp::DownsampleDepth( Dx11DeviceContext& deviceContext )
	{
		deviceContext.BeginMarker( "DownsampleDepth" );

		const HlslShaderPass* fxPass = decalVolumeCullShader_->getPass( "cs_copy_depth" );
		fxPass->setCS( deviceContext.context );

		Vector4 projMatrixParams = Vector4(
			  projMatrixForDecalVolumes_.getElem( 0, 0 )
			, projMatrixForDecalVolumes_.getElem( 1, 1 )
			, projMatrixForDecalVolumes_.getElem( 2, 2 )
			, projMatrixForDecalVolumes_.getElem( 3, 2 )
		);

		decalVolumeCullConstants_.data.dvcRenderTargetSize = Vector4( (float)clusterDS_.width_, (float)clusterDS_.height_, 1.0f / (float)clusterDS_.width_, 1.0f / (float)clusterDS_.height_ );
		decalVolumeCullConstants_.data.dvcProjMatrixParams = projMatrixParams;
		decalVolumeCullConstants_.updateGpu( deviceContext.context );
		decalVolumeCullConstants_.setCS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS );

		deviceContext.setCS_SRV( REGISTER_TEXTURE_DECAL_VOLUME_IN_DEPTH, mainDS_.srv_ );
		deviceContext.context->CSSetSamplers( REGISTER_SAMPLER_DECAL_VOLUME_IN_DEPTH, 1, &SamplerStates::point );
		deviceContext.setCS_UAV( REGISTER_TEXTURE_DECAL_VOLUME_OUT_DEPTH, clusterDS_.GetUAV( 0, 0 ) );

		uint nGroupsX = ( clusterDS_.width_ + 8 - 1 ) / 8;
		uint nGroupsY = ( clusterDS_.height_ + 8 - 1 ) / 8;
		deviceContext.context->Dispatch( nGroupsX, nGroupsY, 1 );

		deviceContext.UnbindCSUAVs();

		fxPass = decalVolumeCullShader_->getPass( "cs_downsample_depth" );
		fxPass->setCS( deviceContext.context );

		uint w = clusterDS_.width_ / 2;
		uint h = clusterDS_.height_ / 2;
		for ( uint iMip = 1; iMip < 6; ++iMip )
		{
			deviceContext.setCS_SRV( REGISTER_TEXTURE_DECAL_VOLUME_IN_DEPTH, clusterDS_.GetSRV( 0, iMip - 1 ) );
			deviceContext.setCS_UAV( REGISTER_TEXTURE_DECAL_VOLUME_OUT_DEPTH, clusterDS_.GetUAV( 0, iMip ) );

			nGroupsX = ( w + 8 - 1 ) / 8;
			nGroupsY = ( h + 8 - 1 ) / 8;
			deviceContext.context->Dispatch( nGroupsX, nGroupsY, 1 );

			deviceContext.UnbindCSUAVs();

			w = maxOfPair( w / 2, 1U );
			h = maxOfPair( h / 2, 1U );
		}

		deviceContext.EndMarker();
	}

	// Heron's Formula
	float TriangleAreaFromSides( float a, float b, float c )
	{
		const float s = ( a + b + c ) * 0.5f;
		float A = sqrtf( s * (s - a) * (s - b) * (s - c) );
		return A;
	}

	void GetBoxCorners( const Vector4& center, const Vector4 &xs, const Vector4 &ys, const Vector4 &zs, Vector4 outVertices[8] )
	{
		outVertices[0] = center - xs - ys + zs;
		outVertices[1] = center + xs - ys + zs;
		outVertices[2] = center + xs + ys + zs;
		outVertices[3] = center - xs + ys + zs;

		outVertices[4] = center - xs - ys - zs;
		outVertices[5] = center + xs - ys - zs;
		outVertices[6] = center + xs + ys - zs;
		outVertices[7] = center - xs + ys - zs;
	}

	void GetBoxCorners2( const Vector4& v4, const Vector4 &v5, const Vector4 &v7, const Vector4 &v0, Vector4 outVertices[8] )
	{
		Vector4 ex = v5 - v4;
		Vector4 ey = v7 - v4;

		Vector4 v1 = v0 + ex;

		outVertices[0] = v0;
		outVertices[1] = v1;
		outVertices[2] = v1 + ey;
		outVertices[3] = v0 + ey;

		outVertices[4] = v4;
		outVertices[5] = v5;
		outVertices[6] = v5 + ey;
		outVertices[7] = v7;
	}

	void SettingsTestApp::GenDecalVolumesRandom()
	{
		ClearDecalVolumes();

		uint initValue = 0;
		decalVolumesCulledCountGPU_.Initialize( dx11_->getDevice(), 1, &initValue, false, true, true );

		if ( maxDecalVolumes_ == 0 )
		{
			return;
		}

		Matrix4 viewProj = projMatrixForDecalVolumes_ * viewMatrixForDecalVolumes_;

		//Matrix4 proj = InfinitePerspectiveMatrix(
		//	1.0f / projMatrixForDecalVolumes_.getElem( 0, 0 ).getAsFloat(),
		//	1.0f / projMatrixForDecalVolumes_.getElem( 1, 1 ).getAsFloat(),
		//	testFrustumNearPlane
		//);

		//viewProj = proj * viewMatrixForDecalVolumes_;

		//Vector4 pp = viewProj * Vector4( 0, 0, testFrustumNearPlane, 1 );
		//pp.setXYZ( pp.getXYZ() / pp.getW() );

		Matrix4 viewProjInv = inverse( viewProj );

		std::default_random_engine generator( 1973U );
		std::uniform_real_distribution<float> distribution( 0, 1 );

		decalVolumesCPU_ = reinterpret_cast<DecalVolumeScaled*>( spadMallocAligned( sizeof( DecalVolumeScaled ) * maxDecalVolumes_, alignof( DecalVolumeScaled ) ) );
		numDecalVolumes_ = maxDecalVolumes_;

		Vector4 clipPoints[24];

		Vector4 tanHalfFov;
		tanHalfFov.setX( floatInVec( 1.0f ) / projMatrixForDecalVolumes_.getElem( 0, 0 ) );
		tanHalfFov.setY( floatInVec( 1.0f ) / projMatrixForDecalVolumes_.getElem( 1, 1 ) );
		tanHalfFov.setZ( projMatrixForDecalVolumes_.getElem( 0, 0 ) );
		tanHalfFov.setW( projMatrixForDecalVolumes_.getElem( 1, 1 ) );

		Vector3 eyeAxis[3] = { Vector3::xAxis() * tanHalfFov.getX(), Vector3::yAxis() * tanHalfFov.getY(), -Vector3::zAxis() };
		Vector3 eyeOffset = Vector3( 0.0f );

		Vector3 frustumCorners[8];
		extractFrustumCornersReverseInfiniteProjection( frustumCorners, eyeAxis, eyeOffset, testFrustumNearPlane, decalVolumeFarPlane_ );

		float subfrustumSubdiv = 2;
		Vector3 subfrustumSizeRcp( 1.0f / subfrustumSubdiv );
		extractSubFrustumCornersReverseInfiniteProjection( frustumCorners, eyeAxis, eyeOffset, Vector3( -1 ), subfrustumSizeRcp, testFrustumNearPlane, decalVolumeFarPlane_ );

		GetBoxCorners( Vector4( 0 ), Vector4::xAxis(), Vector4::yAxis(), Vector4::zAxis(), clipPoints );

		for ( int i = 0; i < maxDecalVolumes_; ++i )
		{
			DecalVolumeScaled &dv = decalVolumesCPU_[i];

			float angleX = distribution( generator ) * 2 * PI;
			float angleY = distribution( generator ) * 2 * PI;

			float nX = distribution( generator );// *0.25f + 0.25f;
			float nY = distribution( generator );// *0.25f + 0.25f;
			float nZ = distribution( generator );// *0.25f + 0.25f;
			nZ = powf( nZ, 0.25f );
			float hsX = distribution( generator );
			float hsY = distribution( generator );
			float hsZ = distribution( generator );
			hsX *= 0.25f;
			hsY *= 0.25f;
			hsZ *= 0.25f;
			//hsX *= decalVolumesRandomScale_;
			//hsY *= decalVolumesRandomScale_;
			//hsZ *= decalVolumesRandomScale_;

			//Vector3 pos = unprojectNormalizedDx( Vector3( nX, nY, nZ ), viewProjInv );
			float linearZ = testFrustumNearPlane + nZ * ( decalVolumeFarPlane_ - testFrustumNearPlane );
#if TEST_SAT
			nX = 0.5f;
			nY = 0.5f;
			linearZ = 20;
#endif // #if TEST_SAT
			Vector3 pos = WorldPositionFromScreenCoords3( eyeAxis, eyeOffset, nX * 2 - 1, nY * 2 - 1, linearZ );

			dv.position = ToFloat3( pos );

			//dv.halfSize = Vector4( hsX, hsY, hsZ, 0 );
			//dv.halfSize = Vector4( hsX );
			//dv.halfSize = Vector4( 4, 1, 1, 0 );
			//dv.halfSize *= decalVolumesRandomScale_;

#if TEST_SAT
			hsX = 4;
			hsY = 1;
			hsZ = 1;

			//Matrix4 rot = Matrix4::identity();
			Matrix4 rot = Matrix4::rotationZYX( Vector3( 0, 0, deg2rad(-45.0f) ) );
#else // #if TEST_SAT
			Matrix4 rot = Matrix4::rotationZYX( Vector3( 0, angleY, angleX ) );
#endif // #else // #if TEST_SAT

			dv.x = ToFloat3( rot.getCol0() * hsX * decalVolumesRandomScale_ );
			dv.y = ToFloat3( rot.getCol1() * hsY * decalVolumesRandomScale_ );
			dv.z = ToFloat3( rot.getCol2() * hsZ * decalVolumesRandomScale_ );

			//Vector4 boxVertices[8];
			//Vector4 xs = Vector4( dv.x.x * dv.halfSize.x, dv.x.y * dv.halfSize.x, dv.x.z * dv.halfSize.x, 1.0f );
			//Vector4 ys = Vector4( dv.y.x * dv.halfSize.y, dv.y.y * dv.halfSize.y, dv.y.z * dv.halfSize.y, 1.0f );
			//Vector4 zs = Vector4( dv.z.x * dv.halfSize.z, dv.z.y * dv.halfSize.z, dv.z.z * dv.halfSize.z, 1.0f );
			//GetBoxCorners( Vector4( pos, 1.0f ), xs, ys, zs, boxVertices );

			//for ( uint ib = 0; ib < 8; ++ib )
			//{
			//	clipPoints[ib] = viewProj * Vector4( boxVertices[ib].getXYZ(), 1.0f );
			//}

			//Vector4 v0 = viewProj * Vector4( boxVertices[0].getXYZ(), 1.0f );
			//Vector4 v4 = viewProj * Vector4( boxVertices[4].getXYZ(), 1.0f );
			//Vector4 v5 = viewProj * Vector4( boxVertices[5].getXYZ(), 1.0f );
			//Vector4 v7 = viewProj * Vector4( boxVertices[7].getXYZ(), 1.0f );

			//GetBoxCorners2( v4, v5, v7, v0, clipPoints + 8 );




			////GetBoxCorners( dv.position, dv.x, dv.y, dv.z, dv.halfSize, boxVertices );

			//Vector4 positionClip = viewProj * Vector4( pos, 1.0f );
			//Vector4 xsClip = viewProj * xs;
			//Vector4 ysClip = viewProj * ys;
			//Vector4 zsClip = viewProj * zs;

			//GetBoxCorners( positionClip, xsClip, ysClip, zsClip, clipPoints + 16 );

			//for ( uint iCellsZ = 0; iCellsZ < 2; ++iCellsZ )
			//{
			//	float clipSpacePlanes[6];
			//	buildFrustumClip( clipSpacePlanes, 1, 1, 2, 0, 0, iCellsZ, testFrustumNearPlane, decalVolumeFarPlane_ / testFrustumNearPlane );

			//	uint visible = TestDecalVolumeFrustumClipSpace( clipPoints + 8, clipSpacePlanes );

			//	uint rtWidth, rtHeight;
			//	GetRenderTargetSize( rtWidth, rtHeight );

			//	//float n = testFrustumNearPlane * pow( abs( decalVolumeFarPlane_ / testFrustumNearPlane ), (float)( iCellsZ ) / 2 );
			//	//float f = testFrustumNearPlane * pow( abs( decalVolumeFarPlane_ / testFrustumNearPlane ), (float)( iCellsZ + 1 ) / 2 );

			//	//Matrix4 proj = perspectiveProjectionDxStyle( deg2rad( 60.0f ), (float)rtWidth / (float)rtHeight, n, f );

			//	Vector4 planes[6];
			//	//extractFrustumPlanes( planes, proj );

			//	float tanHalfFovRcpX = projMatrixForDecalVolumes_.getElem( 0, 0 ).getAsFloat();
			//	float tanHalfFovRcpY = projMatrixForDecalVolumes_.getElem( 1, 1 ).getAsFloat();

			//	buildSubFrustum( planes, 1, 1, 2, 0, 0, iCellsZ, tanHalfFovRcpX, tanHalfFovRcpY, testFrustumNearPlane, decalVolumeFarPlane_ / testFrustumNearPlane );

			//	uint visible2 = frustumOBBIntersectSimpleOptimized( planes, Vector4( pos, 1.0f ), Vector4( hsX, hsY, hsZ, 0 ), rot.getCol0(), rot.getCol1(), rot.getCol2() );
			//	std::cout << "iCellsZ " << iCellsZ << "   visible " << visible << "   visible2 " << visible2 << std::endl;
			//}
		}

		decalVolumesGPU_.Initialize( dx11_->getDevice(), numDecalVolumes_, decalVolumesCPU_, true, false, false );
		decalVolumesCulledGPU_.Initialize( dx11_->getDevice(), numDecalVolumes_, nullptr, false, true, false );
		decalVolumesTestCulledGPU_.Initialize( dx11_->getDevice(), numDecalVolumes_, nullptr, false, true, false );

		//float nCellsX = 16.0f;
		//FrustumFace faces[2];
		//DecalVolume_GetFrustumClusterFaces( faces, Vector3( nCellsX ), Vector3( 1.0f / nCellsX ), Vector3( 0.0f ), tanHalfFov, testFrustumNearPlane, decalVolumeFarPlane_, decalVolumeFarPlane_ / testFrustumNearPlane, false );

		//for ( uint iCellX = 0; iCellX < 16; ++iCellX )
		//{
		//	DecalVolume_GetFrustumClusterFaces( faces, Vector3( nCellsX, 1.0f, 1.0f ), Vector3( 1.0f / nCellsX, 1.0f, 1.0f ), Vector3( (float)iCellX, 0, 0 ), tanHalfFov, testFrustumNearPlane, decalVolumeFarPlane_, decalVolumeFarPlane_ / testFrustumNearPlane, false );
		//}
	}

	void SettingsTestApp::GenDecalVolumesModel()
	{
		//if ( decalVolumesCPU_
		//	&& fabsf( decalVolumesAreaThresholdCur_ - decalVolumesAreaThresholdReq_ ) < 0.001f )
		//{
		//	return;
		//}

		//decalVolumesAreaThresholdCur_ = decalVolumesAreaThresholdReq_;

		ClearDecalVolumes();

		uint initValue = 0;
		decalVolumesCulledCountGPU_.Initialize( dx11_->getDevice(), 1, &initValue, false, true, true );

		if ( maxDecalVolumes_ == 0 )
		{
			return;
		}

		uint numVertices = 0;
		uint numIndices = 0;

		const Model &model = sceneModel_;

		for ( u32 meshIdx = 0; meshIdx < model.Meshes().size(); ++meshIdx )
		{
			const Mesh& mesh = model.Meshes()[meshIdx];

			numVertices += mesh.NumVertices();
			numIndices += mesh.NumIndices();
		}

		std::vector<MeshVertex> vertices( numVertices );
		std::vector<u32> indices( numIndices );

		MeshVertex *tmpVertices = vertices.data();
		u32 *tmpIndices = indices.data();
		uint baseVertex = 0;

		for ( u32 meshIdx = 0; meshIdx < model.Meshes().size(); ++meshIdx )
		{
			const Mesh& mesh = model.Meshes()[meshIdx];

			memcpy( tmpVertices, mesh.Vertices(), sizeof( MeshVertex ) * mesh.NumVertices() );
			//memcpy( tmpIndices, mesh.Indices(), sizeof( u16 ) * mesh.NumIndices() );
			const u16 *srcIndices = reinterpret_cast<const u16*>( mesh.Indices() );
			for ( uint iIndex = 0; iIndex < mesh.NumIndices(); ++iIndex )
			{
				tmpIndices[iIndex] = baseVertex + srcIndices[iIndex];
			}
			
			tmpVertices += mesh.NumVertices();
			tmpIndices += mesh.NumIndices();
			baseVertex += mesh.NumVertices();
		}

		struct Triangle
		{
			u32 idx0;
			u32 idx1;
			u32 idx2;
		};

		std::vector<Triangle> filteredTriangles;
		filteredTriangles.reserve( numIndices );

		for ( uint iTriangleIndex = 0; iTriangleIndex < numIndices; iTriangleIndex += 3 )
		{
			u32 idx0 = indices[iTriangleIndex + 0];
			u32 idx1 = indices[iTriangleIndex + 1];
			u32 idx2 = indices[iTriangleIndex + 2];

			const MeshVertex &v0 = vertices[idx0];
			const MeshVertex &v1 = vertices[idx1];
			const MeshVertex &v2 = vertices[idx2];

			float side0 = ( v1.Position - v0.Position ).Length();
			float side1 = ( v2.Position - v1.Position ).Length();
			float side2 = ( v0.Position - v2.Position ).Length();

			float area = TriangleAreaFromSides( side0, side1, side2 );
			if ( area > decalVolumesAreaThreshold_ )
			{
				filteredTriangles.push_back( { idx0, idx1, idx2 } );
			}
		}

		decalVolumesCPU_ = reinterpret_cast<DecalVolumeScaled*>( spadMallocAligned( sizeof( DecalVolumeScaled ) * maxDecalVolumes_, alignof( DecalVolumeScaled ) ) );

		std::default_random_engine generator( 1973U );
		std::uniform_real_distribution<float> distribution( 0, 1 );

		numDecalVolumes_ = 0;

		{
			DecalVolumeScaled &dv = decalVolumesCPU_[numDecalVolumes_];
			numDecalVolumes_ += 1;
			dv.position = float3( 0, 2, 0 );
			//dv.halfSize = Float3( 0.5, 0.5, 0.5 );
			//dv.x = Float3( 1, 0, 0 );
			//dv.y = Float3( 0, 1, 0 );
			//dv.z = Float3( 0, 0, 1 );
			Matrix3 basis = createBasisZAxis( Vector3::yAxis() );
			dv.x = ToFloat3( basis.getCol0() * 0.5f );
			dv.y = ToFloat3( basis.getCol1() * 0.5f );
			dv.z = ToFloat3( basis.getCol2() * 0.5f );
		}

		while ( numDecalVolumes_ < maxDecalVolumes_ && !filteredTriangles.empty() )
		{
			float index01 = distribution( generator );
			size_t index = std::min( static_cast<size_t>(filteredTriangles.size() * index01), filteredTriangles.size() - 1 );

			const Triangle &tri = filteredTriangles[index];

			const MeshVertex &v0 = vertices[tri.idx0];
			const MeshVertex &v1 = vertices[tri.idx1];
			const MeshVertex &v2 = vertices[tri.idx2];

			Float3 center = ( v0.Position + v1.Position + v2.Position ) * 0.33333f;
			Float3 normal = Float3::Normalize( v0.Normal + v1.Normal + v2.Normal );

			DecalVolumeScaled &dv = decalVolumesCPU_[numDecalVolumes_];
			numDecalVolumes_ += 1;

			dv.position = ToFloat3( Vector4( center.x, center.y, center.z, 1.0f ) );

			float s0 = ( v0.Position - center ).Length();
			float s1 = ( v1.Position - center ).Length();
			float s2 = ( v2.Position - center ).Length();

			float s = std::max( s0, std::max( s1, s2 ) );
			s *= 0.05f;
			s *= decalVolumesModelScale_;

			float randomScale = distribution( generator );
			s *= randomScale + 0.75f;

			//dv.halfSize = Vector4( s, s, s, 0 );

			Matrix3 decalVolumeBasis = createBasisZAxis( Vector3( normal.x, normal.y, normal.z ) );
			dv.x = ToFloat3( Vector4( decalVolumeBasis.getCol0(), floatInVec( 0.0f ) ) * s );
			dv.y = ToFloat3( Vector4( decalVolumeBasis.getCol1(), floatInVec( 0.0f ) ) * s );
			dv.z = ToFloat3( Vector4( decalVolumeBasis.getCol2(), floatInVec( 0.0f ) ) * s );


			if ( index != filteredTriangles.size() - 1 )
			{
				filteredTriangles[index] = filteredTriangles.back();
			}

			filteredTriangles.pop_back();
		}

		//for ( uint i = 0; i < maxDecalVolumes; ++i )
		//{
		//	DecalVolume &dv = g_decalVolumes[i];

		//	float angleX = distribution( generator ) * 2 * PI;
		//	float angleY = distribution( generator ) * 2 * PI;

		//	float nX = distribution( generator );// *0.25f + 0.25f;
		//	float nY = distribution( generator );// *0.25f + 0.25f;
		//	float nZ = distribution( generator );// *0.25f + 0.25f;
		//	nZ = powf( nZ, 0.25f );
		//	float hsX = distribution( generator );
		//	float hsY = distribution( generator );
		//	float hsZ = distribution( generator );
		//	hsX *= 0.25f;
		//	hsY *= 0.25f;
		//	hsZ *= 0.25f;

		//	Vector3 pos = unprojectNormalizedDx( Vector3( nX, nY, nZ ), viewProjInv );
		//	dv.position = Vector4( pos, 0 );

		//	dv.halfSize = Vector4( hsX, hsY, hsZ, 0 );

		//	Matrix4 rot = Matrix4::rotationZYX( Vector3( 0, angleY, angleX ) );
		//	dv.x = rot.getCol0();
		//	dv.y = rot.getCol1();
		//	dv.z = rot.getCol2();
		//}

		decalVolumesGPU_.Initialize( dx11_->getDevice(), numDecalVolumes_, decalVolumesCPU_, true, false, false );
		decalVolumesCulledGPU_.Initialize( dx11_->getDevice(), numDecalVolumes_, nullptr, false, true, false );
		decalVolumesTestCulledGPU_.Initialize( dx11_->getDevice(), numDecalVolumes_, nullptr, false, true, false );
	}

	void SettingsTestApp::ClearDecalVolumes()
	{
		spadFreeAligned( decalVolumesCPU_ );
		decalVolumesCPU_ = nullptr;
		numDecalVolumes_ = 0;
		decalVolumesGPU_.DeInitialize();
		decalVolumesCulledGPU_.DeInitialize();
		decalVolumesTestCulledGPU_.DeInitialize();
		decalVolumesCulledCountGPU_.DeInitialize();
	}

	Matrix4 SettingsTestApp::ProjMatrixForDecalVolumes() const
	{
		uint rtWidth, rtHeight;
		GetRenderTargetSize( rtWidth, rtHeight );

		//return perspectiveProjectionDxStyle( deg2rad( 60.0f ), (float)rtWidth / (float)rtHeight, testFrustumNearPlane, decalVolumeFarPlane_ );

		//Matrix4 proj = InfinitePerspectiveMatrix(
		//	1.0f / projMatrixForDecalVolumes_.getElem( 0, 0 ).getAsFloat(),
		//	1.0f / projMatrixForDecalVolumes_.getElem( 1, 1 ).getAsFloat(),
		//	testFrustumNearPlane
		//);


		return InfinitePerspectiveMatrix2( deg2rad( 60.0f ), (float)rtWidth / (float)rtHeight, testFrustumNearPlane );
	}

	void SettingsTestApp::PopulateStats( Dx11DeviceContext& deviceContext, DecalVolumeClusteringData &data )
	{
		for ( size_t iPass = 0; iPass < data.passes_.size(); ++iPass )
		{
			const bool firstPass = iPass == 0;
			const bool lastPass = iPass == ( data.passes_.size() - 1 );

			DecalVolumeClusteringPass &p = data.passes_[iPass];

			if ( lastPass )
			{
				const u32 *decalsPerCell = p.decalIndices.CPUReadbackStart( deviceContext.context );

				for ( float & i : p.stats.countPerCellHistogram )
				{
					i = 0;
				}

				uint sum = 0;
				uint maxCount = 0;
				uint minCount = 0xffffffff;
				const uint cellCount = p.nCellsX * p.nCellsY * p.nCellsZ;

				for ( uint i = 0; i < cellCount; ++i )
				{
					uint c = decalsPerCell[i] & 0x3ff;
					sum += c;
					maxCount = std::max( maxCount, c );
					minCount = std::min( minCount, c );

					p.stats.countPerCellHistogram[c] += 1;
				}

				p.stats.numDecalsInAllCells = sum;
				p.stats.avgDecalsPerCell = (float)sum / (float)cellCount;
				p.stats.maxDecalsPerCell = maxCount;
				p.stats.minDecalsPerCell = minCount;
				memset( &p.stats.numCellIndirections, 0, sizeof(p.stats.numCellIndirections) );
				p.stats.numWaves = 0;

				p.decalIndices.CPUReadbackEnd( deviceContext.context );
			}
			else
			{
				const CellIndirection *cellIndirection = p.cellIndirection.CPUReadbackStart( deviceContext.context );
				const u32 *cellIndirectionCount = p.cellIndirectionCount.CPUReadbackStart( deviceContext.context );
				const u32 *args = p.indirectArgs.CPUReadbackStart( deviceContext.context );
				//const GroupToBucket *groupToBucket = nullptr;
				//if ( !firstPass )
				//{
				//	groupToBucket = p.groupToBucket.CPUReadbackStart( deviceContext.context );
				//}

				for ( float & i : p.stats.countPerCellHistogram )
				{
					i = 0;
				}

				uint sum = 0;
				uint maxCount = 0;
				uint minCount = 0xffffffff;
				if ( data.enableBuckets_ )
				{
					p.stats.numWaves = 0;

					for ( uint iBucket = 0; iBucket < maxBuckets; ++iBucket )
					{
						const uint cellOffset = iBucket * p.maxCellIndirectionsPerBucket;
						const CellIndirection *cellIndirectionBucket = cellIndirection + cellOffset;

						uint cellCount = cellIndirectionCount[iBucket];
						if ( data.clustering_ )
						{
							SPAD_ASSERT( cellCount % 8 == 0 );
							cellCount /= 8;
						}
						else
						{
							SPAD_ASSERT( cellCount % 4 == 0 );
							cellCount /= 4;
						}
						for ( uint i = 0; i < cellCount; ++i )
						{
							uint c = cellIndirectionBucket[i].decalCount;

							sum += c;
							maxCount = std::max( maxCount, c );
							minCount = std::min( minCount, c );

							uint ci = std::min( c, (uint)p.stats.countPerCellHistogram.size() - 1 );
							p.stats.countPerCellHistogram[ci] += 1;
						}

						p.stats.numWaves += args[iBucket*3];
						p.stats.numCellIndirections[iBucket] = cellCount;
					}
				}
				else
				{
					uint cellCount = cellIndirectionCount[0];
					SPAD_ASSERT( cellCount % 8 == 0 );
					cellCount /= 8;
					for ( uint i = 0; i < cellCount; ++i )
					{
						uint c = cellIndirection[i].decalCount;

						sum += c;
						maxCount = std::max( maxCount, c );
						minCount = std::min( minCount, c );

						uint ci = std::min( c, (uint)p.stats.countPerCellHistogram.size() - 1 );
						p.stats.countPerCellHistogram[ci] += 1;
					}

					p.stats.numWaves = args[0];
					p.stats.numCellIndirections[0] = cellCount;
					p.stats.avgDecalsPerCell = (float)sum / (float)cellCount;
				}

				p.stats.numDecalsInAllCells = sum; // / 8;
				p.stats.maxDecalsPerCell = maxCount;
				p.stats.minDecalsPerCell = minCount;

				//if ( !firstPass )
				//{
				//	p.groupToBucket.CPUReadbackEnd( deviceContext.context );
				//}
				p.indirectArgs.CPUReadbackEnd( deviceContext.context );
				p.cellIndirectionCount.CPUReadbackEnd( deviceContext.context );
				p.cellIndirection.CPUReadbackEnd( deviceContext.context );
			}

			const u32 *memAlloc = p.decalIndicesCount.CPUReadbackStart( deviceContext.context );
			p.stats.memAllocated = memAlloc[0] * sizeof( uint );
			p.decalIndicesCount.CPUReadbackEnd( deviceContext.context );

			//for ( int i = 0; i < (int)p.stats.countPerCellHistogram.size(); ++i )
			//{
			//	float f = p.stats.countPerCellHistogram[i];
			//	//float flog2 = log2f( f );
			//	//p.stats.countPerCellHistogram[i] = flog2;
			//	p.stats.countPerCellHistogram[i] = f;
			//}
		}
	}

	void SettingsTestApp::ImGuiPrintClusteringInfo( DecalVolumeClusteringData &data )
	{
		//ImGui::Columns( 4, "mycolumns" ); // 4-ways, with border
		//ImGui::Separator();
		//ImGui::Text( "ID" ); ImGui::NextColumn();
		//ImGui::Text( "Name" ); ImGui::NextColumn();
		//ImGui::Text( "Path" ); ImGui::NextColumn();
		//ImGui::Text( "Hovered" ); ImGui::NextColumn();

		ImGui::Text( "Time [us]	 last    avg    min    max" );
		ImGui::Text( "Total  time %6u %6u %6u %6u", data.timer_.getDurationUS(), data.timer_.getAvgDurationUS(), data.timer_.getMinDurationUS(), data.timer_.getMaxDurationUS() );

		for ( size_t iPass = 0; iPass < data.passes_.size(); ++iPass )
		{
			const DecalVolumeClusteringPass &p = data.passes_[iPass];
			ImGui::Text( "Pass %u time %6u %6u %6u %6u", (uint)iPass, p.timer.getDurationUS(), p.timer.getAvgDurationUS(), p.timer.getMinDurationUS(), p.timer.getMaxDurationUS() );
		}

		ImGui::Spacing();

		ImGui::Text( "Total mem %u [B], %u [kB], %u [MB]", data.totalMemUsed_, data.totalMemUsed_ / 1024, data.totalMemUsed_ / ( 1024 * 1024 ) );

		{
			const char* items[] = { "World space optimized", "Clip space", "Clip space (decal in)", "SAT" };
			ImGui::Combo( "Intersection method", reinterpret_cast<int*>( &data.intersectionMethod_ ), items, IM_ARRAYSIZE( items ) );
		}

		ImGui::Checkbox( "SAT Last Pass Only", &data.satOnlyInLastPass_ );
		ImGui::Checkbox( "Buckets", &data.enableBuckets_ );
		ImGui::Checkbox( "Dynamic buckets", &data.dynamicBuckets_ );
		ImGui::Checkbox( "Dynamic buckets merge", &data.dynamicBucketsMerge_ );
		ImGui::Checkbox( "Pass timing", &data.enablePassTiming_ );

		showExtendedStats_ = false;

		if ( ImGui::CollapsingHeader( "Extended stats", nullptr, ImGuiTreeNodeFlags_DefaultOpen ) )
		{
			showExtendedStats_ = true;

			for ( size_t iPass = 0; iPass < data.passes_.size(); ++iPass )
			{
				const bool firstPass = iPass == 0;
				const bool lastPass = iPass == ( data.passes_.size() - 1 );

				const DecalVolumeClusteringPass &p = data.passes_[iPass];
				const uint totalCells = p.nCellsX * p.nCellsY * p.nCellsZ;

				char passName[256];
				snprintf( passName, sizeof( passName ), "Pass %u - %u x %u x %u - %u", (uint)iPass, p.nCellsX, p.nCellsY, p.nCellsZ, totalCells );

				if ( ImGui::CollapsingHeader( passName, nullptr, ImGuiTreeNodeFlags_DefaultOpen ) )
				{
					ImGui::Text( "Pass mem %u [kB], %u [MB]", p.stats.totalMem / 1024, p.stats.totalMem / ( 1024 * 1024 ) );
					ImGui::Text( "Decal indices mem %u [kB] (header %u [kB]), %u [MB]", p.maxDecalIndices * sizeof(uint) / 1024, ( totalCells * sizeof( uint ) ) / 1024, p.maxDecalIndices * sizeof( uint ) / ( 1024 * 1024 ) );
					ImGui::Text( "Cells indirection mem %u [kB], %u [MB]", (p.maxCellIndirectionsPerBucket * maxBuckets * sizeof( CellIndirection ) ) / 1024, ( p.maxCellIndirectionsPerBucket * maxBuckets * sizeof( CellIndirection ) ) / ( 1024 * 1024 ) );
					if ( lastPass )
					{
						ImGui::Text( "Decal indices used [kB] %u / %u, +header %u / %u", p.stats.memAllocated / 1024, (p.maxDecalIndices - totalCells) * sizeof( uint ) / 1024, ( p.stats.memAllocated + totalCells * sizeof(uint) ) / 1024, ( p.maxDecalIndices * sizeof( uint ) ) / 1024 );
					}
					else
					{
						ImGui::Text( "Decal indices used [kB] %u / %u", p.stats.memAllocated / 1024, ( p.maxDecalIndices * sizeof( uint ) ) / 1024 );
					}

					if ( !lastPass )
					{
						// Cells indirection is not written out in last pass
						if ( data.enableBuckets_ )
						{
							for ( uint iBucket = 0; iBucket < maxBuckets; ++iBucket )
							{
								ImGui::Text( "Cells [%u] %u / %u (%3.3f%%)", iBucket, p.stats.numCellIndirections[iBucket], p.maxCellIndirectionsPerBucket, ( (float)p.stats.numCellIndirections[iBucket] / (float)p.maxCellIndirectionsPerBucket ) * 100.0f );
							}
						}
						else
						{
							ImGui::Text( "Cells %u / %u (%3.3f%%)", p.stats.numCellIndirections[0], p.maxCellIndirectionsPerBucket, ( (float)p.stats.numCellIndirections[0] / (float)p.maxCellIndirectionsPerBucket ) * 100.0f );
						}
					}

					if ( iPass == 0 )
					{
						ImGui::Text( "Spawned waves %u", totalCells );
					}
					else
					{
						const DecalVolumeClusteringPass &pp = data.passes_[iPass - 1];
						ImGui::Text( "Spawned waves %u", pp.stats.numWaves );
					}

					float maxValue = 0;
					int maxIndex = (int)0;
					for ( int i = 0; i < (int)p.stats.countPerCellHistogram.size(); ++i )
					{
						float f = p.stats.countPerCellHistogram[i];
						if ( f > 0 )
							maxIndex = i;

						maxValue = std::max( maxValue, f );
					}

					ImGui::PlotHistogram( "count per cell", p.stats.countPerCellHistogram.data(), maxIndex + 1, 0, NULL, FLT_MAX, FLT_MAX, ImVec2( 0, 80 ) );

					//SPAD_ASSERT( sum <= p.maxDecalIndices );
					if ( p.stats.numDecalsInAllCells > p.maxDecalIndices )
					{
						ImGui::TextColored( ImVec4(1, 0, 0, 1), "Num decals in all cells %u / %u", p.stats.numDecalsInAllCells, p.maxDecalIndices );
					}
					else
					{
						ImGui::Text( "Num decals in all cells %u / %u", p.stats.numDecalsInAllCells, p.maxDecalIndices );
					}
					ImGui::Text( "Avg decals per cell %3.3f", p.stats.avgDecalsPerCell );
					ImGui::Text( "Min decals per cell %u", p.stats.minDecalsPerCell );
					ImGui::Text( "Max decals per cell %u", p.stats.maxDecalsPerCell );
				}
			}
		}
	}

	//SettingsTestApp::DecalVolumeTilingDataPtr SettingsTestApp::DecalVolumeTilingStartUp()
	//{
	//	//ID3D11Device* dxDevice = dx11_->getDevice();

	//	DecalVolumeTilingDataPtr tilingPtr = std::make_unique<DecalVolumeTilingData>();

	//	//tilingPtr->tilingConstants_.Initialize( dxDevice );
	//	//tilingPtr->decalVolumesTilingTimer_.Initialize( dxDevice );
	//	//tilingPtr->decalVolumesTilingShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\cs_decal_volume_tiling.hlslc_packed" );

	//	//tilingPtr->tilingPasses_.resize( DECAL_VOLUME_TILING_NUM_PASSES );

	//	//uint rtWidth, rtHeight;
	//	//GetRenderTargetSize( rtWidth, rtHeight );

	//	//uint nTilesXBase = ( rtWidth + DECAL_VOLUME_TILE_SIZE_X - 1 ) / DECAL_VOLUME_TILE_SIZE_X;
	//	//uint nTilesYBase = ( rtHeight + DECAL_VOLUME_TILE_SIZE_Y - 1 ) / DECAL_VOLUME_TILE_SIZE_Y;

	//	//const uint maxDivider = 1 << (DECAL_VOLUME_TILING_NUM_PASSES - 1);
	//	//const uint a = nTilesYBase / maxDivider;
	//	//if ( a * maxDivider != nTilesYBase )
	//	//{
	//	//	nTilesYBase = spadAlignU32_2( nTilesYBase - maxDivider - 1, maxDivider );
	//	//}

	//	//const uint b = nTilesXBase / maxDivider;
	//	//if ( b * maxDivider != nTilesXBase )
	//	//{
	//	//	nTilesXBase = spadAlignU32_2( nTilesXBase - maxDivider - 1, maxDivider );
	//	//}

	//	//uint nTilesX = nTilesXBase;
	//	//uint nTilesY = nTilesYBase;
	//	//uint nDecalsPerTile = 32;

	//	//uint totalMemoryUsed = 0;

	//	//for ( int iPass = (int)tilingPtr->tilingPasses_.size()-1; iPass >= 0; --iPass )
	//	//{
	//	//	DecalVolumeClusteringPass &p = tilingPtr->tilingPasses_[iPass];
	//	//	p.nCellsX = nTilesX;
	//	//	p.nCellsY = nTilesY;
	//	//	p.nCellsZ = 1;
	//	//	p.maxDecalsPerCell = nDecalsPerTile;
	//	//	//p.maxDecalsPerCell = (iPass == tilingPasses_.size()-1) ? 32 : nDecalsPerTile;

	//	//	uint passTotalMemory = 0;

	//	//	//totalMemoryUsed += p.countPerCell.Initialize( dxDevice, p.nCellsX * p.nCellsY, nullptr, false, true, true );
	//	//	p.stats.decalsPerCellMem = p.decalPerCell.Initialize( dxDevice, p.nCellsX * p.nCellsY * p.maxDecalsPerCell, nullptr, false, true, true );
	//	//	passTotalMemory += p.stats.decalsPerCellMem;
	//	//	passTotalMemory += p.cellIndirection.Initialize( dxDevice, p.nCellsX * p.nCellsY * 4, nullptr, false, true, true );
	//	//	passTotalMemory += p.cellIndirectionCount.Initialize( dxDevice, 1, nullptr, false, true, true );
	//	//	passTotalMemory += p.indirectArgs.Initialize( dxDevice, 3, nullptr, false, true, true, true );
	//	//	passTotalMemory += p.memAlloc.Initialize( dxDevice, 1, nullptr, false, true, true );

	//	//	p.timer.Initialize( dxDevice );

	//	//	p.stats.totalMem = passTotalMemory;

	//	//	totalMemoryUsed += passTotalMemory;

	//	//	p.stats.totalMem = passTotalMemory;
	//	//	//p.stats.headerMem = p.nCellsX * p.nCellsY * p.nCellsZ * sizeof( uint );

	//	//	p.stats.countPerCellHistogram.resize( p.maxDecalsPerCell );

	//	//	nTilesX = (nTilesX + 1) / 2;
	//	//	nTilesY = (nTilesY + 1) / 2;
	//	//	//nTilesX /= 2;
	//	//	//nTilesY /= 2;
	//	//	//nTilesX = spadAlignU32_2( nTilesX / 2, 2 );
	//	//	//nTilesY = spadAlignU32_2( nTilesY / 2, 2 );
	//	//	nDecalsPerTile *= 2;
	//	//}

	//	////std::cout << "Total mem used tiling: " << totalMemoryUsed << " B, " << totalMemoryUsed / ( 1024 * 1024 ) << " MB" << std::endl;
	//	//tilingPtr->tiling_.totalMemUsed_ = totalMemoryUsed;

	//	return tilingPtr;
	//}

	//void SettingsTestApp::DecalVolumeTilingRun( Dx11DeviceContext& deviceContext )
	//{
	//	//const uint rtWidth = 128;
	//	//const uint rtHeight = 128;

	//	tiling_->decalVolumesTilingTimer_.begin( deviceContext.context );

	//	for ( size_t iPass = 0; iPass < tiling_->tilingPasses_.size() - 1; ++iPass )
	//	{
	//		DecalVolumeClusteringPass &p = tiling_->tilingPasses_[iPass];
	//		p.cellIndirectionCount.clearUAVUint( deviceContext.context, 0 );
	//		//p.cellIndirectionCount.clearUAVUint( deviceContext.context, p.nTilesX * p.nTilesY * 4 );
	//		//p.countPerCell.clearUAVUint( deviceContext.context, 0 );
	//		//p.decalPerCell.clearUAVUint( deviceContext.context, 0 );
	//		p.decalIndicesCount.clearUAVUint( deviceContext.context, 0 );
	//	}

	//	//tilingPasses_.back().decalPerCell.clearUAVUint( deviceContext.context, 0 );
	//	tiling_->tilingPasses_.back().decalIndicesCount.clearUAVUint( deviceContext.context, 0 );

	//	for ( size_t iPass = 0; iPass < tiling_->tilingPasses_.size(); ++iPass )
	//	{
	//		DecalVolumeClusteringPass &p = tiling_->tilingPasses_[iPass];

	//		const bool firstPass = iPass == 0;
	//		const bool lastPass = iPass == ( tiling_->tilingPasses_.size() - 1 );

	//		p.timer.begin( deviceContext.context );

	//		if ( lastPass )
	//		{
	//			const HlslShaderPass& fxPass = *tiling_->decalVolumesTilingShader_->getPass( "cs_decal_volume_clear_header" );
	//			fxPass.setCS( deviceContext.context );

	//			p.decalIndices.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES );

	//			uint nGroupsX = ( p.nCellsX * p.nCellsY + 256 - 1 ) / 256;
	//			deviceContext.context->Dispatch( nGroupsX, 1, 1 );

	//			deviceContext.UnbindCSUAVs();
	//		}

	//		//const HlslShaderPass& fxPassClear = *decalVolumeTilingShader_->getPass( "DecalTilingClearIndirectArgs" );
	//		//fxPassClear.setCS( deviceContext.context );

	//		//p.indirectArgs.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS );
	//		//deviceContext.context->Dispatch( 1, 1, 1 );

	//		//char passName[128];
	//		//snprintf( passName, sizeof( passName ), "DecalTilingPass%u", (uint)iPass );
	//		//const HlslShaderPass& fxPass = *decalVolumesTilingShader_->getPass( passName );
	//		//fxPass.setCS( deviceContext.context );
	//		if ( firstPass )
	//		{
	//			const HlslShaderPass& fxPass = *tiling_->decalVolumesTilingShader_->getPass( "DecalVolumeTilingFirstPass", { (uint)tiling_->tiling_.intersectionMethod_ } );
	//			fxPass.setCS( deviceContext.context );
	//		}
	//		else if ( lastPass )
	//		{
	//			const HlslShaderPass& fxPass = *tiling_->decalVolumesTilingShader_->getPass( "DecalVolumeTilingLastPass", { (uint)tiling_->tiling_.intersectionMethod_ } );
	//			fxPass.setCS( deviceContext.context );
	//		}
	//		else
	//		{
	//			const HlslShaderPass& fxPass = *tiling_->decalVolumesTilingShader_->getPass( "DecalVolumeTilingMidPass", { (uint)tiling_->tiling_.intersectionMethod_ } );
	//			fxPass.setCS( deviceContext.context );
	//		}

	//		//tilingConstants_.data.BaseProjMatrix = testFrustumProj;
	//		tiling_->tilingConstants_.data.dvViewMatrix = viewMatrixForDecalVolumes_;
	//		tiling_->tilingConstants_.data.dvNearFar = Vector4( testFrustumNearPlane, decalVolumeFarPlane_, decalVolumeFarPlane_ / testFrustumNearPlane, 0 );
	//		tiling_->tilingConstants_.data.dvTanHalfFov.setX( floatInVec( 1.0f ) / projMatrixForDecalVolumes_.getElem( 0, 0 ) );
	//		tiling_->tilingConstants_.data.dvTanHalfFov.setY( floatInVec( 1.0f ) / projMatrixForDecalVolumes_.getElem( 1, 1 ) );
	//		tiling_->tilingConstants_.data.dvTanHalfFov.setZ( projMatrixForDecalVolumes_.getElem( 0, 0 ) );
	//		tiling_->tilingConstants_.data.dvTanHalfFov.setW( projMatrixForDecalVolumes_.getElem( 1, 1 ) );
	//		//tiling_->tilingConstants_.data.renderTargetSize = Vector4( 0 );
	//		data.constants_.data.dvCellCount[0] = p.nCellsX;
	//		data.constants_.data.dvCellCount[1] = p.nCellsY;
	//		data.constants_.data.dvCellCount[2] = 1;
	//		data.constants_.data.dvCellCount[3] = p.nCellsX * p.nCellsY;
	//		data.constants_.data.dvCellCountRcp[0] = 1.0f / p.nCellsX;
	//		data.constants_.data.dvCellCountRcp[1] = 1.0f / p.nCellsY;
	//		data.constants_.data.dvCellCountRcp[2] = 1;
	//		data.constants_.data.dvCellCountRcp[3] = 0;
	//		tiling_->tilingConstants_.data.dvPassLimits[0] = p.maxDecalIndices;
	//		tiling_->tilingConstants_.data.dvPassLimits[1] = p.maxCellIndirectionsPerBucket;
	//		tiling_->tilingConstants_.data.dvPassLimits[2] = 0;
	//		tiling_->tilingConstants_.data.dvPassLimits[3] = 0;

	//		if ( !firstPass )
	//		{
	//			DecalVolumeClusteringPass &pp = tiling_->tilingPasses_[iPass-1];

	//			tiling_->tilingConstants_.data.dvPassLimits[2] = pp.maxCellIndirectionsPerBucket;

	//			//pp.countPerCell.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_COUNT_PER_CELL );
	//			pp.decalIndices.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECAL_INDICES );
	//			pp.cellIndirection.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION );
	//			pp.cellIndirectionCount.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT );
	//		}

	//		tiling_->tilingConstants_.updateGpu( deviceContext.context );
	//		tiling_->tilingConstants_.setCS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS );

	//		//decalVolumesGPU_.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS );
	//		if ( tiling_->tiling_.intersectionMethod_ )
	//		{
	//			decalVolumesTestCulledGPU_.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_TEST );
	//		}
	//		else
	//		{
	//			decalVolumesCulledGPU_.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS );
	//		}
	//		decalVolumesCulledCountGPU_.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_COUNT );

	//		if ( !lastPass )
	//		{
	//			//p.countPerCell.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_COUNT_PER_CELL );
	//			p.cellIndirection.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION );
	//			p.cellIndirectionCount.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION_COUNT );
	//		}

	//		if ( lastPass )
	//		{
	//			DecalVolumeClusteringPass &pp = tiling_->tilingPasses_[iPass - 1];
	//			pp.cellIndirectionCount.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT );
	//		}

	//		p.decalIndices.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES );
	//		p.decalIndicesCount.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES_COUNT );

	//		if ( firstPass )
	//		{
	//			deviceContext.context->Dispatch( p.nCellsX, p.nCellsY, 1 );
	//		}
	//		else
	//		{
	//			DecalVolumeClusteringPass &pp = tiling_->tilingPasses_[iPass - 1];
	//			deviceContext.context->DispatchIndirect( pp.indirectArgs.getDxBuffer(), 0 );
	//		}

	//		deviceContext.UnbindCSUAVs();

	//		if ( ! lastPass )
	//		{
	//			// Fill indirect args

	//			if ( iPass == tiling_->tilingPasses_.size() - 2 )
	//			{
	//				const HlslShaderPass& fxPassCopy = *tiling_->decalVolumesTilingShader_->getPass( "cs_decal_volume_indirect_args_last_pass" );
	//				fxPassCopy.setCS( deviceContext.context );
	//			}
	//			else
	//			{
	//				const HlslShaderPass& fxPassCopy = *tiling_->decalVolumesTilingShader_->getPass( "cs_decal_volume_indirect_args" );
	//				fxPassCopy.setCS( deviceContext.context );
	//			}

	//			p.cellIndirectionCount.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT );
	//			p.indirectArgs.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS );

	//			deviceContext.context->Dispatch( 1, 1, 1 );

	//			deviceContext.UnbindCSUAVs();
	//		}

	//		p.timer.end( deviceContext.context );
	//		p.timer.calculateDuration( deviceContext );

	//		//const u32 *decalsPerCell = p.decalPerCell.CPUReadbackStart( deviceContext.context );
	//		//const u32 *decalCountPerCell = p.countPerCell.CPUReadbackStart( deviceContext.context );
	//		//const CellIndirection *cellIndirection = p.cellIndirection.CPUReadbackStart( deviceContext.context );
	//		//const u32 *cellIndirectionCount = p.cellIndirectionCount.CPUReadbackStart( deviceContext.context );
	//		//const u32 *args = p.indirectArgs.CPUReadbackStart( deviceContext.context );

	//		//p.indirectArgs.CPUReadbackEnd( deviceContext.context );
	//		//p.cellIndirectionCount.CPUReadbackEnd( deviceContext.context );
	//		//p.cellIndirection.CPUReadbackEnd( deviceContext.context );
	//		//p.countPerCell.CPUReadbackEnd( deviceContext.context );
	//		//p.decalPerCell.CPUReadbackEnd( deviceContext.context );
	//	}

	//	tiling_->decalVolumesTilingTimer_.end( deviceContext.context );
	//	tiling_->decalVolumesTilingTimer_.calculateDuration( deviceContext );

	//	if ( showExtendedStats_ )
	//	{
	//		PopulateStats( deviceContext, tiling_->tiling_, tiling_->tilingPasses_ );
	//	}
	//}


	void SettingsTestApp::GetTileSize( TileSize tileSize, uint &outTileSize )
	{
		switch ( tileSize )
		{
		case spad::SettingsTestApp::TileSize_512x512:
			outTileSize = 512;
			break;
		case spad::SettingsTestApp::TileSize_256x256:
			outTileSize = 256;
			break;
		case spad::SettingsTestApp::TileSize_128x128:
			outTileSize = 128;
			break;
		case spad::SettingsTestApp::TileSize_64x64:
			outTileSize = 64;
			break;
		case spad::SettingsTestApp::TileSize_48x48:
			outTileSize = 48;
			break;
		case spad::SettingsTestApp::TileSize_32x32:
			outTileSize = 32;
			break;
		case spad::SettingsTestApp::TileSize_16x16:
			outTileSize = 16;
			break;
		case spad::SettingsTestApp::TileSize_8x8:
			outTileSize = 8;
			break;
		default:
			SPAD_NOT_IMPLEMENTED;
			outTileSize = 32;
		}
	}

	void SettingsTestApp::CalculateCellCount( uint rtWidth, uint rtHeight, uint tileSize, uint numPasses, uint &outCellsX, uint &outCellsY, uint &outCellsZ )
	{
		SPAD_ASSERT( numPasses > 0 );

		uint tileSizeX = tileSize;
		uint tileSizeY = tileSize;// 1024;

		uint nCellsXBase = ( rtWidth + tileSizeX - 1 ) / tileSizeX;
		uint nCellsYBase = ( rtHeight + tileSizeY - 1 ) / tileSizeY;

		//const uint maxDivider = 1 << ( numPasses - 1 );
		//const uint a = nCellsYBase / maxDivider;
		//if ( a * maxDivider != nCellsYBase )
		//{
		//	//nCellsYBase = spadAlignU32_2( nCellsYBase - maxDivider - 1, maxDivider );
		//	nCellsYBase = spadAlignU32_2( nCellsYBase, maxDivider );
		//}

		//const uint b = nCellsXBase / maxDivider;
		//if ( b * maxDivider != nCellsXBase )
		//{
		//	//nCellsXBase = spadAlignU32_2( nCellsXBase - maxDivider - 1, maxDivider );
		//	nCellsXBase = spadAlignU32_2( nCellsXBase, maxDivider );

		//}

		outCellsX = nCellsXBase;
		outCellsY = nCellsYBase;
		//outCellsZ = DECAL_VOLUME_CLUSTER_CELLS_Z;
		outCellsZ = 32;
		//outCellsZ = 1;
	}

	SettingsTestApp::DecalVolumeClusteringDataPtr SettingsTestApp::DecalVolumeClusteringStartUp( bool clustering )
	{
		std::cout << std::endl;

		uint tileSizeBase;
		GetTileSize( clustering ? tileSizeForClustering_ : tileSizeForTiling_, tileSizeBase );

		for ( uint rtSize = RTW_64_64; rtSize < RenderTargetSizeCount; ++rtSize )
		{
			uint rtWidth, rtHeight;
			GetRenderTargetSize( static_cast<RenderTargetSize>( rtSize ), rtWidth, rtHeight );

			uint nCellsX;
			uint nCellsY;
			uint nCellsZ;
			CalculateCellCount( rtWidth, rtHeight, tileSizeBase, static_cast<uint>(clustering ? numPassesForClustering_ : numPassesForTiling_), nCellsX, nCellsY, nCellsZ );
			if ( !clustering )
				nCellsZ = 1;

			uint cellCount = nCellsX * nCellsY * nCellsZ;
			uint cellCountSqr = static_cast<uint>( sqrtf( static_cast<float>( cellCount ) ) );
			std::cout << rtWidth << " x " << rtHeight << "  " << cellCount << "   " << cellCountSqr << std::endl;
		}

		ID3D11Device* dxDevice = dx11_->getDevice();

		DecalVolumeClusteringDataPtr clusteringPtr = std::make_unique<DecalVolumeClusteringData>();
		clusteringPtr->clustering_ = clustering;

		clusteringPtr->constants_.Initialize( dxDevice );
		clusteringPtr->timer_.Initialize( dxDevice );
		if ( clustering )
		{
			clusteringPtr->shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\cs_decal_volume_clustering.hlslc_packed" );
		}
		else
		{
			clusteringPtr->shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\cs_decal_volume_tiling.hlslc_packed" );
		}

		clusteringPtr->passes_.resize( clustering ? numPassesForClustering_ : numPassesForTiling_ );

		uint rtWidth, rtHeight;
		GetRenderTargetSize( rtWidth, rtHeight );

		//clusteringPtr->tileWidthClip_ = 2.0f * tileSize / (float)rtWidth;
		//clusteringPtr->tileHeightClip_ = 2.0f * tileSize / (float)rtHeight;

		uint nCellsX;
		uint nCellsY;
		uint nCellsZ;
		CalculateCellCount( rtWidth, rtHeight, tileSizeBase, static_cast<uint>( clustering ? numPassesForClustering_ : numPassesForTiling_ ), nCellsX, nCellsY, nCellsZ );
		if ( !clustering )
			nCellsZ = 1;

		float nCellsXF = static_cast<float>( nCellsX );
		float nCellsYF = static_cast<float>( nCellsY );
		float nCellsZF = static_cast<float>( nCellsZ );

		//uint cellCountSqr = static_cast<uint>( sqrtf( static_cast<float>( nCellsX * nCellsY * nCellsZ ) ) );
		uint tileSize = tileSizeBase;

		for ( int iPass = (int)clusteringPtr->passes_.size() - 1; iPass >= 0; --iPass )
		{
			const bool firstPass = iPass == 0;
			const bool lastPass = iPass == ( clusteringPtr->passes_.size() - 1 );

			DecalVolumeClusteringPass &p = clusteringPtr->passes_[iPass];
			p.nCellsX = nCellsX;
			p.nCellsY = nCellsY;
			p.nCellsZ = nCellsZ;
			p.nCellsXF = nCellsXF;
			p.nCellsYF = nCellsYF;
			p.nCellsZF = nCellsZF;

			if ( lastPass )
			{
				//p.nCellsXF = static_cast<float>( nCellsX );
				//p.nCellsYF = static_cast<float>( nCellsY );
				//p.nCellsZF = static_cast<float>( nCellsZ );
				p.nCellsXRcp = 1.0f / nCellsX;
				p.nCellsYRcp = 1.0f / nCellsY;
			}
			else
			{
				DecalVolumeClusteringPass &np = clusteringPtr->passes_[iPass + 1];
				//p.nCellsXF = ( np.nCellsXF + 1) * 0.5f;
				//p.nCellsYF = ( np.nCellsYF + 1) * 0.5f;
				//p.nCellsXF = ( np.nCellsXF ) * 0.5f;
				//p.nCellsYF = ( np.nCellsYF ) * 0.5f;
				p.nCellsXRcp = 2.0f * np.nCellsXRcp;
				p.nCellsYRcp = 2.0f * np.nCellsYRcp;
			}

			//p.nCellsZF = static_cast<float>( nCellsZ );
			p.nCellsZRcp = 1.0f / nCellsZ;

			p.tileWidthClip_ = tileSize / (float)rtWidth;
			p.tileHeightClip_ = tileSize / (float)rtHeight;

			//nCellsX /= 2;
			//nCellsY /= 2;
			nCellsX = (nCellsX + 1) / 2;
			nCellsY = (nCellsY + 1) / 2;
			nCellsZ = maxOfPair( nCellsZ / 2, 1U );

			nCellsXF *= 0.5f;
			nCellsYF *= 0.5f;
			nCellsZF = maxOfPair( nCellsZF * 0.5f, 1.0f );

			tileSize *= 2;
		}

		uint totalMemoryUsed = 0;

		//for ( uint iPass = 0; iPass < (uint)clusteringPtr->clusteringPasses_.size(); ++iPass )
		for ( int iPass = (int)clusteringPtr->passes_.size() - 1; iPass >= 0; --iPass )
		{
			const bool firstPass = iPass == 0;
			const bool lastPass = iPass == ( clusteringPtr->passes_.size() - 1 );

			DecalVolumeClusteringPass &p = clusteringPtr->passes_[iPass];

			uint cellCount = p.nCellsX * p.nCellsY * p.nCellsZ;

			if ( firstPass )
			{
				if ( clustering )
				{
					p.maxDecalIndicesPerCellFirstPass = maxOfPair( maxDecalVolumes_ / 4, 1 );
				}
				else
				{
					p.maxDecalIndicesPerCellFirstPass = maxOfPair( maxDecalVolumes_ / 1, 1 );
				}

				p.maxDecalIndices = cellCount * p.maxDecalIndicesPerCellFirstPass;
			}
			else if ( lastPass )
			{
				p.maxDecalIndicesPerCellFirstPass = 0;

				if ( clustering )
				{
					p.maxDecalIndices = cellCount + cellCount * 8;// *( maxOfPair( (int)RoundUpToPowerOfTwo( maxDecalVolumes_ ) / ( 2048 ), 1 ) );
					//p.maxDecalIndices = cellCount * maxDecalVolumes_;
				}
				else
				{
					p.maxDecalIndices = cellCount + cellCount * 64;
					//p.maxDecalIndices = cellCount * 2 * ( maxOfPair( (int)RoundUpToPowerOfTwo( maxDecalVolumes_ ) / ( 2048 ), 1 ) );
					//p.maxDecalIndices = cellCount * 16;
				}
			}
			else
			{
				p.maxDecalIndicesPerCellFirstPass = 0;

				if ( clustering )
				{
					//p.maxDecalIndices = ( cellCountSqr / 8 ) * (256 + 64) * ( maxOfPair( (int)RoundUpToPowerOfTwo( maxDecalVolumes_ ) / ( 1024 ), 1 ) );
					//p.maxDecalIndices = cellCount * maxOfPair( maxDecalVolumes_ >> ( iPass + 2 ), 1 );
					//p.maxDecalIndices = cellCount * 16 * maxOfPair( (int)RoundUpToPowerOfTwo( maxDecalVolumes_ ) / ( 1024 ), 1 );
					p.maxDecalIndices = 1024 * 64 * maxOfPair( (int)RoundUpToPowerOfTwo( maxDecalVolumes_ ) / ( 1024 ), 1 );
					//p.maxDecalIndices = cellCount * maxDecalVolumes_;
				}
				else
				{
					p.maxDecalIndices = cellCount * maxDecalVolumes_;
					//p.maxDecalIndices = cellCount * 64;
					//p.maxDecalIndices = ( cellCountSqr / 4 ) * 1024 * ( maxOfPair( (int)RoundUpToPowerOfTwo( maxDecalVolumes_ ) / ( 1024 ), 1 ) );
				}
			}

			if ( lastPass )
			{
				p.maxCellIndirectionsPerBucket = 0;
			}
			else if ( firstPass )
			{
				p.maxCellIndirectionsPerBucket = cellCount;
			}
			//else if ( iPass == 1 )
			//{
			//	p.maxCellIndirectionsPerBucket = cellCount / 2;
			//}
			else
			{
				p.maxCellIndirectionsPerBucket = cellCount;// / 4;
			}

			uint passTotalMemory = 0;

			passTotalMemory += p.decalIndices.Initialize( dxDevice, p.maxDecalIndices, nullptr, false, true, true );
			if ( !lastPass )
			{
				passTotalMemory += p.cellIndirection.Initialize( dxDevice, p.maxCellIndirectionsPerBucket * maxBuckets, nullptr, false, true, true );
				passTotalMemory += p.cellIndirectionCount.Initialize( dxDevice, maxBuckets, nullptr, false, true, true );
				passTotalMemory += p.indirectArgs.Initialize( dxDevice, 3 * maxBuckets, nullptr, false, true, true, true );
			}
			passTotalMemory += p.decalIndicesCount.Initialize( dxDevice, 1, nullptr, false, true, true );
			//if ( !firstPass )
			//{
			//	passTotalMemory += p.groupToBucket.Initialize( dxDevice, p.nCellsX * p.nCellsY * p.nCellsZ, nullptr, false, true, true );
			//}

			p.timer.Initialize( dxDevice );

			totalMemoryUsed += passTotalMemory;

			p.stats.totalMem = passTotalMemory;
			p.stats.countPerCellHistogram.resize( 1024 );

			//for ( uint y = 0; y < p.nCellsY + 1; ++y )
			//{
			//	float v = 0;
			//	if ( p.nCellsY & 1 )
			//	{
			//		v = -1 + 2.0f * ( 1.0f / (p.nCellsY + 1) ) * y;
			//	}
			//	else
			//	{
			//		v = -1 + 2.0f * ( 1.0f / p.nCellsY ) * y;
			//	}
			//	std::cout << "iPass: " << iPass << " y: " << v << std::endl;
			//}
		}

		for ( uint iPass = 0; iPass < (uint)clusteringPtr->passes_.size(); ++iPass )
		{
			DecalVolumeClusteringPass &p = clusteringPtr->passes_[iPass];

			const bool firstPass = iPass == 0;
			const bool lastPass = iPass == ( clusteringPtr->passes_.size() - 1 );

			//float sub = 0;
			//if ( !lastPass )
			//{

			//}

			for ( uint y = 0; y < p.nCellsY + 1; ++y )
			{
				//float v = 0;
				//if ( p.nCellsY & 1 )
				//{
				//	if ( !lastPass )
				//	{
				//		DecalVolumeClusteringPass &np = clusteringPtr->passes_[iPass + 1];
				//		v = -1 + 2.0f * ( 1.0f / ( np.nCellsY * 0.5f ) ) * y;
				//	}
				//	else
				//	{
				//		v = -1 + 2.0f * ( 1.0f / ( p.nCellsY ) ) * y;
				//	}
				//}
				//else
				//{
				//	v = -1 + 2.0f * ( 1.0f / p.nCellsY ) * y;
				//}
				//std::cout << "iPass: " << iPass << " y: " << v * 0.5f + 0.5f << std::endl;
				float v = -1 + 2.0f * p.nCellsYRcp * y;
				std::cout << "iPass: " << iPass << " y: " << v << std::endl;
			}
		}


		clusteringPtr->totalMemUsed_ = totalMemoryUsed;

		return clusteringPtr;
	}

	void SettingsTestApp::DecalVolumeClusteringRun( Dx11DeviceContext& deviceContext, DecalVolumeClusteringData &data )
	{
		deviceContext.BeginMarker( "DecalVolumeClusteringRun" );

		data.timer_.begin( deviceContext.context );

		for ( size_t iPass = 0; iPass < data.passes_.size() - 1; ++iPass )
		{
			DecalVolumeClusteringPass &p = data.passes_[iPass];
			p.cellIndirectionCount.clearUAVUint( deviceContext.context, 0 );
			//p.cellIndirection.clearUAVUint( deviceContext.context, 0 );
			//p.countPerCell.clearUAVUint( deviceContext.context, 0 );
			p.decalIndicesCount.clearUAVUint( deviceContext.context, 0 );
		}

		//clusteringPasses_.back().decalPerCell.clearUAVUint( deviceContext.context, 0 );
		data.passes_.back().decalIndicesCount.clearUAVUint( deviceContext.context, 0 );
		
		uint rtWidth, rtHeight;
		GetRenderTargetSize( rtWidth, rtHeight );

		const size_t numPasses = data.passes_.size();
		for ( size_t iPass = 0; iPass < numPasses; ++iPass )
		{
			deviceContext.BeginMarker( "Pass", (uint)iPass );

			DecalVolumeClusteringPass &p = data.passes_[iPass];

			const bool firstPass = iPass == 0;
			const bool lastPass = iPass == ( data.passes_.size() - 1 );

			if ( data.enablePassTiming_ )
			{
				p.timer.begin( deviceContext.context );
			}

			if ( lastPass )
			{
				const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_clear_header" );
				fxPass.setCS( deviceContext.context );

				p.decalIndices.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES );

				uint nGroupsX = (p.nCellsX * p.nCellsY * p.nCellsZ + DECAL_VOLUME_CLUSTER_CLEAR_HEADER_NUM_GROUPS - 1) / DECAL_VOLUME_CLUSTER_CLEAR_HEADER_NUM_GROUPS;
				deviceContext.context->Dispatch( nGroupsX, 1, 1 );

				deviceContext.UnbindCSUAVs();
			}

			const uint bucketsEnabled = data.enableBuckets_ ? 1 : 0;
			const uint bucketsMergeEnabled = bucketsEnabled & ( data.dynamicBucketsMerge_ ? 1 : 0 );

			if ( firstPass )
			{
				if ( numPasses == 1 )
				{
					const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_single_pass", { (uint)data.intersectionMethod_ } );
					fxPass.setCS( deviceContext.context );
				}
				else
				{
					//const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_first_pass", { (uint)data.intersectionMethod_, bucketsEnabled } );
					const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_first_pass", { (uint)data.intersectionMethod_ } );
					fxPass.setCS( deviceContext.context );
				}
			}
			else if ( lastPass )
			{
				if ( bucketsMergeEnabled )
				{
					//const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_last_pass", { (uint)data.intersectionMethod_, bucketsEnabled, DECAL_VOLUME_CLUSTER_SUBGROUP_BUCKET_MERGED } );
					const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_last_pass", { (uint)data.intersectionMethod_ } );
					fxPass.setCS( deviceContext.context );
				}
				else if ( bucketsEnabled )
				{
				}
				else
				{
					const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_last_pass", { (uint)data.intersectionMethod_, bucketsEnabled, 0 } );
					fxPass.setCS( deviceContext.context );
				}
			}
			else
			{
				if ( bucketsMergeEnabled )
				{
					//const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_mid_pass", { (uint)data.intersectionMethod_, bucketsEnabled, DECAL_VOLUME_CLUSTER_SUBGROUP_BUCKET_MERGED } );
					const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_mid_pass", { (uint)data.intersectionMethod_ } );
					fxPass.setCS( deviceContext.context );
				}
				else if ( bucketsEnabled )
				{
				}
				else
				{
					const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_mid_pass", { (uint)data.intersectionMethod_, bucketsEnabled, maxBuckets - 1 } );
					fxPass.setCS( deviceContext.context );
				}
			}

			data.constants_.data.dvViewMatrix = viewMatrixForDecalVolumes_;
			data.constants_.data.dvViewProjMatrix = projMatrixForDecalVolumes_ * viewMatrixForDecalVolumes_;
			data.constants_.data.dvNearFar = Vector4( testFrustumNearPlane, decalVolumeFarPlane_, decalVolumeFarPlane_ / testFrustumNearPlane, 0 );

			Vector4 tanHalfFov;
			tanHalfFov.setX( floatInVec( 1.0f ) / projMatrixForDecalVolumes_.getElem( 0, 0 ) );
			tanHalfFov.setY( floatInVec( 1.0f ) / projMatrixForDecalVolumes_.getElem( 1, 1 ) );
			tanHalfFov.setZ( projMatrixForDecalVolumes_.getElem( 0, 0 ) );
			tanHalfFov.setW( projMatrixForDecalVolumes_.getElem( 1, 1 ) );
			data.constants_.data.dvTanHalfFov = tanHalfFov;

			data.constants_.data.dvCellCount[0] = p.nCellsX;
			data.constants_.data.dvCellCount[1] = p.nCellsY;
			data.constants_.data.dvCellCount[2] = p.nCellsZ;
			data.constants_.data.dvCellCount[3] = p.nCellsX * p.nCellsY * p.nCellsZ;
			data.constants_.data.dvCellCountF[0] = p.nCellsXF;
			data.constants_.data.dvCellCountF[1] = p.nCellsYF;
			data.constants_.data.dvCellCountF[2] = p.nCellsZF;
			data.constants_.data.dvCellCountF[3] = 0;
			//data.constants_.data.dvCellCountRcp[0] = 1.0f / p.nCellsX;
			//data.constants_.data.dvCellCountRcp[1] = 1.0f / p.nCellsY;
			//data.constants_.data.dvCellCountRcp[2] = 1.0f / p.nCellsZ;
			//if ( /*(p.nCellsY & 1) &&*/ !lastPass )
			//{
			//	DecalVolumeClusteringPass &np = data.passes_[iPass + 1];
			//	data.constants_.data.dvCellCountRcp[0] = 1.0f / ( np.nCellsX * 0.5f );
			//	data.constants_.data.dvCellCountRcp[1] = 1.0f / ( np.nCellsY * 0.5f );
			//}
			data.constants_.data.dvCellCountRcp[0] = p.nCellsXRcp;
			data.constants_.data.dvCellCountRcp[1] = p.nCellsYRcp;
			data.constants_.data.dvCellCountRcp[2] = p.nCellsZRcp;
			data.constants_.data.dvCellCountRcp[3] = 0;
			data.constants_.data.dvCellSize[0] = p.tileWidthClip_;
			data.constants_.data.dvCellSize[1] = p.tileHeightClip_;
			data.constants_.data.dvCellSize[2] = 0;
			data.constants_.data.dvCellSize[3] = 0;

			data.constants_.data.dvEyeAxisX = viewMatrixForDecalVolumes_.getCol0() * tanHalfFov.getX();
			data.constants_.data.dvEyeAxisY = viewMatrixForDecalVolumes_.getCol1() * tanHalfFov.getY();
			data.constants_.data.dvEyeAxisZ = -viewMatrixForDecalVolumes_.getCol2();
			data.constants_.data.dvEyeOffset = Vector4( viewMatrixForDecalVolumes_.getTranslation(), 0.0f );

			data.constants_.data.dvPassLimits[0] = p.maxDecalIndices;
			data.constants_.data.dvPassLimits[1] = p.maxDecalIndicesPerCellFirstPass;
			data.constants_.data.dvPassLimits[2] = p.maxCellIndirectionsPerBucket;
			data.constants_.data.dvPassLimits[3] = 0;

			if ( !firstPass )
			{
				DecalVolumeClusteringPass &pp = data.passes_[iPass - 1];

				data.constants_.data.dvPassLimits[3] = pp.maxCellIndirectionsPerBucket;

				pp.decalIndices.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECAL_INDICES );
				pp.cellIndirection.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION );
				//if ( bucketsMergeEnabled )
				//{
				//	p.groupToBucket.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_GROUP_TO_BUCKET );
				//}
			}

			//if ( !lastPass )
			//{
			//	DecalVolumeClusteringPass &pp = data.clusteringPasses_[iPass - 1];
			//	pp.cellIndirectionCount.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT );
			//}

			data.constants_.updateGpu( deviceContext.context );
			data.constants_.setCS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS );

			if ( data.intersectionMethod_ == DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE )
			{
				decalVolumesTestCulledGPU_.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_TEST );
			}
			else
			{
				decalVolumesCulledGPU_.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS );
			}

			decalVolumesCulledCountGPU_.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_COUNT );

			if ( lastPass && !data.clustering_ && appMode_ == Scene )
			{
				deviceContext.setCS_SRV( REGISTER_TEXTURE_DECAL_VOLUME_IN_DEPTH, clusterDS_.GetSRV( 0, 4 ) );
			}

			if ( !lastPass )
			{
				p.cellIndirection.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION );
				p.cellIndirectionCount.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION_COUNT );
			}

			p.decalIndices.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES );
			p.decalIndicesCount.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES_COUNT );

			if ( firstPass )
			{
				deviceContext.context->Dispatch( p.nCellsX, p.nCellsY, p.nCellsZ );
			}
			else
			{
				DecalVolumeClusteringPass &pp = data.passes_[iPass - 1];

				if ( bucketsMergeEnabled )
				{
					deviceContext.context->DispatchIndirect( pp.indirectArgs.getDxBuffer(), 0 );
				}
				else if ( bucketsEnabled )
				{
					for ( uint i = 0; i < maxBuckets; ++i )
					{
						if ( data.dynamicBuckets_ )
						{
							if ( i == 0 )
							{
								if ( lastPass )
								{
									const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_last_pass", { (uint)data.intersectionMethod_, 1, 6 } );
									fxPass.setCS( deviceContext.context );
								}
								else
								{
									const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_mid_pass", { (uint)data.intersectionMethod_, 1, 6 } );
									fxPass.setCS( deviceContext.context );
								}
							}

							data.constants_.data.dvBuckets[0] = i;
							data.constants_.updateGpu( deviceContext.context );
						}
						else
						{
							if ( lastPass )
							{
								const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_last_pass", { (uint)data.intersectionMethod_, 1, i } );
								fxPass.setCS( deviceContext.context );
							}
							else
							{
								const HlslShaderPass& fxPass = *data.shader_->getPass( "cs_decal_volume_cluster_mid_pass", { (uint)data.intersectionMethod_, 1, i } );
								fxPass.setCS( deviceContext.context );
							}
						}

						deviceContext.context->DispatchIndirect( pp.indirectArgs.getDxBuffer(), 12 * i );
					}
				}
				else
				{
					deviceContext.context->DispatchIndirect( pp.indirectArgs.getDxBuffer(), 0 );
				}
			}

			deviceContext.UnbindCSUAVs();

			if ( !lastPass )
			{
				// Fill indirect args

				if ( bucketsMergeEnabled )
				{
					const HlslShaderPass& fxPassCopy = *data.shader_->getPass( "cs_decal_volume_indirect_args_buckets_merged" );
					fxPassCopy.setCS( deviceContext.context );
				}
				else if ( bucketsEnabled )
				{
					const HlslShaderPass& fxPassCopy = *data.shader_->getPass( "cs_decal_volume_indirect_args_buckets" );
					fxPassCopy.setCS( deviceContext.context );
				}
				else
				{
					if ( iPass == data.passes_.size() - 2 )
					{
						const HlslShaderPass& fxPassCopy = *data.shader_->getPass( "cs_decal_volume_indirect_args_last_pass" );
						fxPassCopy.setCS( deviceContext.context );
					}
					else
					{
						const HlslShaderPass& fxPassCopy = *data.shader_->getPass( "cs_decal_volume_indirect_args" );
						fxPassCopy.setCS( deviceContext.context );
					}
				}

				p.cellIndirectionCount.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT );
				p.indirectArgs.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS );

				deviceContext.context->Dispatch( 1, 1, 1 );

				deviceContext.UnbindCSUAVs();

				//if ( bucketsMergeEnabled )
				//{
				//	deviceContext.BeginMarker( "cs_decal_volume_assign_bucket" );
				//
				//	DecalVolumeClusteringPass &np = data.clusteringPasses_[iPass + 1];

				//	const HlslShaderPass& fxPassCopy = *data.decalVolumesClusteringShader_->getPass( "cs_decal_volume_assign_bucket" );
				//	fxPassCopy.setCS( deviceContext.context );

				//	p.cellIndirectionCount.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT );
				//	np.groupToBucket.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_GROUP_TO_BUCKET );

				//	deviceContext.context->DispatchIndirect( p.indirectArgs.getDxBuffer(), 12 );

				//	deviceContext.UnbindCSUAVs();

				//	deviceContext.EndMarker();
				//}
			}

			if ( data.enablePassTiming_ )
			{
				p.timer.end( deviceContext.context );
				p.timer.calculateDuration( deviceContext );
			}

			//const u32 *decalsPerCell = p.decalPerCell.CPUReadbackStart( deviceContext.context );
			//const u32 *decalCountPerCell = p.countPerCell.CPUReadbackStart( deviceContext.context );
			//const CellIndirection *cellIndirection = p.cellIndirection.CPUReadbackStart( deviceContext.context );
			//const u32 *cellIndirectionCount = p.cellIndirectionCount.CPUReadbackStart( deviceContext.context );
			//const u32 *args = p.indirectArgs.CPUReadbackStart( deviceContext.context );

			//p.indirectArgs.CPUReadbackEnd( deviceContext.context );
			//p.cellIndirectionCount.CPUReadbackEnd( deviceContext.context );
			//p.cellIndirection.CPUReadbackEnd( deviceContext.context );
			//p.countPerCell.CPUReadbackEnd( deviceContext.context );
			//p.decalPerCell.CPUReadbackEnd( deviceContext.context );

			deviceContext.EndMarker();
		}

		data.timer_.end( deviceContext.context );
		data.timer_.calculateDuration( deviceContext );

		deviceContext.EndMarker();

		if ( showExtendedStats_ )
		{
			PopulateStats( deviceContext, data );
		}
	}


	void SettingsTestApp::DrawClusteringHeatmap( Dx11DeviceContext& deviceContext )
	{
		if ( currentView_ != GpuHeatmap && currentView_ != CpuHeatmap )
		{
			return;
		}

		ID3D11DeviceContext* context = deviceContext.context;

		const HlslShaderPass& fxPass = *decalVolumeRenderingShader_->getPass( "DecalVolumeHeatmapTile" );
		fxPass.setVS( context );
		fxPass.setPS( context );

		context->RSSetState( RasterizerStates::NoCull() );
		context->OMSetBlendState( BlendStates::alphaBlend, nullptr, 0xffffffff );
		context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
		context->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );
		context->IASetInputLayout( nullptr );

		ID3D11ShaderResourceView* srvs[1] = { nullptr };

		uint rtWidth = dx11_->getBackBufferWidth();
		uint rtHeight = dx11_->getBackBufferHeight();

		if ( currentView_ == GpuHeatmap )
		{
			decalVolumeRenderingConstants_.data.dvdRenderTargetSize = Vector4( (float)rtWidth, (float)rtHeight, 1.0f / rtWidth, 1.0f / rtHeight );

			if ( appMode_ == Tiling || appMode_ == Scene )
			{
				decalVolumeRenderingConstants_.data.dvdMode[0] = DECAL_VOLUME_CLUSTER_DISPLAY_MODE_2D;
				decalVolumeRenderingConstants_.data.dvdMode[1] = 0;
				decalVolumeRenderingConstants_.data.dvdMode[2] = 0;
				decalVolumeRenderingConstants_.data.dvdMode[3] = 0;
				decalVolumeRenderingConstants_.data.dvdCellCount[0] = tiling_->passes_.back().nCellsX;
				decalVolumeRenderingConstants_.data.dvdCellCount[1] = tiling_->passes_.back().nCellsY;
				decalVolumeRenderingConstants_.data.dvdCellCount[2] = 1;
				decalVolumeRenderingConstants_.data.dvdCellCount[3] = 0;

				srvs[0] = tiling_->passes_.back().decalIndices.getSRV();
			}
			else
			{
				decalVolumeRenderingConstants_.data.dvdMode[0] = DECAL_VOLUME_CLUSTER_DISPLAY_MODE_3D;
				decalVolumeRenderingConstants_.data.dvdMode[1] = 0;
				decalVolumeRenderingConstants_.data.dvdMode[2] = 0;
				decalVolumeRenderingConstants_.data.dvdMode[3] = 0;
				decalVolumeRenderingConstants_.data.dvdCellCount[0] = clustering_->passes_.back().nCellsX;
				decalVolumeRenderingConstants_.data.dvdCellCount[1] = clustering_->passes_.back().nCellsY;
				decalVolumeRenderingConstants_.data.dvdCellCount[2] = clustering_->passes_.back().nCellsZ;
				decalVolumeRenderingConstants_.data.dvdCellCount[3] = 0;

				srvs[0] = clustering_->passes_.back().decalIndices.getSRV();
			}
			decalVolumeRenderingConstants_.updateGpu( deviceContext.context );
			decalVolumeRenderingConstants_.setVS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CONSTANTS );
			decalVolumeRenderingConstants_.setPS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CONSTANTS );
		}
		else
		{
			//assert( currentView_ == CpuHeatmap );
			//srvs[0] = decalVolumesLinkedListCPU_.getSRV();
		}

		context->PSSetShaderResources( REGISTER_BUFFER_DECAL_VOLUME_IN_DECAL_INDICES, 1, srvs );

		context->Draw( 3, 0 );

	}

	void SettingsTestApp::DrawDepth( Dx11DeviceContext& deviceContext )
	{
		if ( !(currentView_ == DepthBuffer && appMode_ == Scene) )
		{
			return;
		}

		ID3D11DeviceContext* context = deviceContext.context;

		const HlslShaderPass& fxPass = *decalVolumeRenderingShader_->getPass( "DecalVolumeHeatmapTile" );
		fxPass.setVS( context );
		fxPass.setPS( context );

		context->RSSetState( RasterizerStates::NoCull() );
		context->OMSetBlendState( BlendStates::alphaBlend, nullptr, 0xffffffff );
		context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
		context->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );
		context->IASetInputLayout( nullptr );

		uint rtWidth = dx11_->getBackBufferWidth();
		uint rtHeight = dx11_->getBackBufferHeight();

		decalVolumeRenderingConstants_.data.dvdRenderTargetSize = Vector4( (float)rtWidth, (float)rtHeight, 1.0f / rtWidth, 1.0f / rtHeight );
		decalVolumeRenderingConstants_.data.dvdMode[0] = DECAL_VOLUME_CLUSTER_DISPLAY_MODE_DEPTH;
		decalVolumeRenderingConstants_.data.dvdMode[1] = depthBufferMip_;
		decalVolumeRenderingConstants_.data.dvdMode[2] = depthBufferShowMin_;
		decalVolumeRenderingConstants_.data.dvdMode[3] = 0;
		decalVolumeRenderingConstants_.data.dvdNearFarPlane[0] = testFrustumNearPlane;
		decalVolumeRenderingConstants_.updateGpu( deviceContext.context );
		decalVolumeRenderingConstants_.setVS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CONSTANTS );
		decalVolumeRenderingConstants_.setPS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CONSTANTS );

		context->PSSetSamplers( REGISTER_SAMPLER_DIFFUSE_SAMPLER, 1, &SamplerStates::point );
		//ID3D11ShaderResourceView *srvs[1] = { clusterDS_.GetSRV( 0, 4 ) };
		ID3D11ShaderResourceView *srvs[1] = { clusterDS_.srv_ };
		context->PSSetShaderResources( REGISTER_TEXTURE_DIFFUSE_TEXTURE, 1, srvs );

		context->Draw( 3, 0 );
	}

	void SettingsTestApp::DrawBoxesAndAxesFillIndirectArgs( Dx11DeviceContext& deviceContext )
	{
		deviceContext.BeginMarker( "DrawBoxesAndAxesFillIndirectArgs" );

		decalVolumesCulledCountGPU_.setCS_SRV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_COUNT );

		{
			const HlslShaderPass& fxPass = *decalVolumeRenderingShader_->getPass( "DecalVolumeCopyIndirectArgsIndexed" );
			fxPass.setCS( deviceContext.context );

			boxIndirectArgs_.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS );
			deviceContext.context->Dispatch( 1, 1, 1 );
		}

		{
			const HlslShaderPass& fxPass = *decalVolumeRenderingShader_->getPass( "cs_decal_volume_indirect_args" );
			fxPass.setCS( deviceContext.context );

			axesIndirectArgs_.setCS_UAV( deviceContext.context, REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS );
			deviceContext.context->Dispatch( 1, 1, 1 );
		}

		deviceContext.UnbindCSUAVs();

		deviceContext.EndMarker();
	}

	void SettingsTestApp::DrawDecalBoxes( Dx11DeviceContext& deviceContext )
	{
		//if ( currentView_ == ExternalCamera )
		//{
		//	return;
		//}

		//const float clearColor[] = { 0, 0, 0, 1 };
		//deviceContext.context->ClearRenderTargetView( dx11_->getBackBufferRTV(), clearColor );
		//deviceContext.context->ClearDepthStencilView( mainDS_.dsv_, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 1, 0 );

		deviceContext.BeginMarker( "DrawDecalBoxes" );

		passConstants_.data.Projection = ToFloat4x4( projMatrixForDecalVolumes_ );
		passConstants_.data.View = ToFloat4x4( viewMatrixForDecalVolumes_ );
		passConstants_.data.ViewProjection = ToFloat4x4( projMatrixForDecalVolumes_ * viewMatrixForDecalVolumes_ );
		passConstants_.updateGpu( deviceContext.context );
		passConstants_.setVS( deviceContext.context, REGISTER_CBUFFER_PASS_CONSTANTS );
		passConstants_.setPS( deviceContext.context, REGISTER_CBUFFER_PASS_CONSTANTS );

		decalVolumeRenderingConstants_.data.dvdColorMultiplier = Vector4( 0.25f );
		decalVolumeRenderingConstants_.updateGpu( deviceContext.context );
		decalVolumeRenderingConstants_.setPS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CONSTANTS );

		//objectConstants_.setVS( deviceContext.context, CB_OBJECT_CONSTANTS_REGISTER );

		const HlslShaderPass& fxPass = *decalVolumeRenderingShader_->getPass( "DecalVolumesAccum" );
		fxPass.setVS( deviceContext.context );
		fxPass.setPS( deviceContext.context );

		deviceContext.context->RSSetState( RasterizerStates::BackFaceCull() );
		//deviceContext.context->RSSetState( RasterizerStates::WireframeBackFaceCull() );
		//deviceContext.context->OMSetBlendState( BlendStates::additiveBlend, nullptr, 0xffffffff );
		deviceContext.context->OMSetBlendState( BlendStates::blendDisabled, nullptr, 0xffffffff );
		deviceContext.context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
		//deviceContext.context->OMSetDepthStencilState( DepthStencilStates::DepthEnabled(), 0 );
		deviceContext.context->OMSetDepthStencilState( DepthStencilStates::ReverseDepthWriteEnabled(), 0 );

		D3D11_INPUT_ELEMENT_DESC layout[] =
		{
			{ "POSITION", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
		};

		u32 layoutHash = Dx11HashInputElementDescriptions( layout, 1 );
		deviceContext.inputLayoutCache.setInputLayout( deviceContext.context, layoutHash, fxPass.vsInputSignatureHash_
			, layout, 1, reinterpret_cast<const u8*>( fxPass.vsInputSignature_->GetBufferPointer() ), (u32)fxPass.vsInputSignature_->GetBufferSize() );

		uint stride = sizeof( Vector4 );
		uint offset = 0;
		ID3D11Buffer *vb = boxVertexBuffer_;
		deviceContext.context->IASetVertexBuffers( 0, 1, &vb, &stride, &offset );
		deviceContext.context->IASetIndexBuffer( boxIndexBuffer_, DXGI_FORMAT_R16_UINT, 0 );

		deviceContext.context->VSSetShaderResources( REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS, 1, decalVolumesCulledGPU_.getSRVs() );
		deviceContext.context->PSSetShaderResources( REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS, 1, decalVolumesCulledGPU_.getSRVs() );

		//deviceContext.context->DrawIndexedInstanced( 36, numDecalVolumes_, 0, 0, 0 );
		deviceContext.context->DrawIndexedInstancedIndirect( boxIndirectArgs_.getDxBuffer(), 0 );

		// Draw wireframe
		decalVolumeRenderingConstants_.data.dvdColorMultiplier = Vector4( 0.0f );
		decalVolumeRenderingConstants_.updateGpu( deviceContext.context );

		deviceContext.context->RSSetState( RasterizerStates::WireframeBackFaceCull() );

		//deviceContext.context->DrawIndexedInstanced( 36, numDecalVolumes_, 0, 0, 0 );
		deviceContext.context->DrawIndexedInstancedIndirect( boxIndirectArgs_.getDxBuffer(), 0 );

		//for ( uint iDecal = 0; iDecal < numDecalVolumes_; ++iDecal )
		//{
		//	const DecalVolume &dv = decalVolumesCPU_[iDecal];

		//	Matrix4 rot( Matrix3( dv.x.ToVector3(), dv.y.ToVector3(), dv.z.ToVector3() ), Vector3( 0, 0, 0 ) );
		//	Matrix4 tr = Matrix4::translation( dv.position.ToVector3() );
		//	Matrix4 sc = Matrix4::scale( (dv.halfSize * 2).ToVector3() );

		//	Matrix4 world = tr * rot * sc;
		//	//Matrix4 world = Matrix4::translation( Vector3( 0, 0, -5 ) );
		//	objectConstants_.data.World = world;
		//	objectConstants_.data.WorldIT = transpose( inverse( world ) );
		//	objectConstants_.updateGpu( deviceContext.context );

		//	deviceContext.context->DrawIndexed( 36, 0, 0 );
		//}

		deviceContext.EndMarker();
	}

	void SettingsTestApp::DrawDecalAxes( Dx11DeviceContext& deviceContext )
	{
		deviceContext.BeginMarker( "DrawDecalAxes" );

		passConstants_.data.Projection = ToFloat4x4( projMatrixForDecalVolumes_ );
		passConstants_.data.View = ToFloat4x4( viewMatrixForDecalVolumes_ );
		passConstants_.data.ViewProjection = ToFloat4x4( projMatrixForDecalVolumes_ * viewMatrixForDecalVolumes_ );
		passConstants_.updateGpu( deviceContext.context );
		passConstants_.setVS( deviceContext.context, REGISTER_CBUFFER_PASS_CONSTANTS );
		passConstants_.setPS( deviceContext.context, REGISTER_CBUFFER_PASS_CONSTANTS );

		const HlslShaderPass& fxPass = *decalVolumeRenderingShader_->getPass( "DecalVolumeAxes" );
		fxPass.setVS( deviceContext.context );
		fxPass.setPS( deviceContext.context );

		deviceContext.context->RSSetState( RasterizerStates::BackFaceCull() );
		deviceContext.context->OMSetBlendState( BlendStates::blendDisabled, nullptr, 0xffffffff );
		deviceContext.context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_LINELIST );
		//deviceContext.context->OMSetDepthStencilState( DepthStencilStates::DepthEnabled(), 0 );
		deviceContext.context->OMSetDepthStencilState( DepthStencilStates::ReverseDepthWriteEnabled(), 0 );

		D3D11_INPUT_ELEMENT_DESC layout[] =
		{
			{ "POSITION", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
		};

		u32 layoutHash = Dx11HashInputElementDescriptions( layout, 1 );
		deviceContext.inputLayoutCache.setInputLayout( deviceContext.context, layoutHash, fxPass.vsInputSignatureHash_
			, layout, 1, reinterpret_cast<const u8*>( fxPass.vsInputSignature_->GetBufferPointer() ), (u32)fxPass.vsInputSignature_->GetBufferSize() );

		uint stride = sizeof( Vector4 );
		uint offset = 0;
		ID3D11Buffer *vb = axesVertexBuffer_;
		deviceContext.context->IASetVertexBuffers( 0, 1, &vb, &stride, &offset );

		deviceContext.context->VSSetShaderResources( REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS, 1, decalVolumesCulledGPU_.getSRVs() );
		deviceContext.context->PSSetShaderResources( REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS, 1, decalVolumesCulledGPU_.getSRVs() );

		//deviceContext.context->DrawInstanced( 6, numDecalVolumes_, 0, 0 );
		deviceContext.context->DrawInstancedIndirect( axesIndirectArgs_.getDxBuffer(), 0 );

		deviceContext.EndMarker();
	}

	void SettingsTestApp::DrawDecalFarPlane( Dx11DeviceContext& deviceContext )
	{
		deviceContext.BeginMarker( "DrawDecalFarPlane" );

		Vector4 ndc = projMatrixForCamera_ * Vector4( 0, 0, -decalVolumeFarPlane_, 1 );
		float farPlaneNDC = ndc.getZ().getAsFloat() / ndc.getW().getAsFloat();

		decalVolumeRenderingConstants_.data.dvdNearFarPlane[1] = farPlaneNDC;
		decalVolumeRenderingConstants_.updateGpu( deviceContext.context );
		decalVolumeRenderingConstants_.setVS( deviceContext.context, REGISTER_CBUFFER_DECAL_VOLUME_CONSTANTS );

		const HlslShaderPass& fxPass = *decalVolumeRenderingShader_->getPass( "DecalVolumeFarPlane" );
		fxPass.setVS( deviceContext.context );
		fxPass.setPS( deviceContext.context );

		//deviceContext.context->RSSetState( RasterizerStates::BackFaceCull() );
		//deviceContext.context->OMSetBlendState( BlendStates::blendDisabled, nullptr, 0xffffffff );
		//deviceContext.context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
		//deviceContext.context->OMSetDepthStencilState( DepthStencilStates::DepthEnabled(), 0 );
		deviceContext.context->RSSetState( RasterizerStates::BackFaceCull() );
		deviceContext.context->OMSetBlendState( BlendStates::alphaBlend, nullptr, 0xffffffff );
		deviceContext.context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
		deviceContext.context->OMSetDepthStencilState( DepthStencilStates::DepthEnabled(), 0 );

		deviceContext.context->Draw( 3, 0 );

		deviceContext.EndMarker();
	}

	void SettingsTestApp::DrawScreenSpaceGrid( Dx11DeviceContext& /*deviceContext*/ )
	{
		uint windowWidth = dx11_->getBackBufferWidth();
		uint windowHeight = dx11_->getBackBufferHeight();
		uint nCellsX = tiling_->passes_.back().nCellsX;
		uint nCellsY = tiling_->passes_.back().nCellsY;
		uint xStep = windowWidth / nCellsX;
		uint yStep = windowHeight / nCellsY;

		for ( uint x = xStep; x < windowWidth; x += xStep )
		{
			debugDraw::AddLineSS( x, 0, x, windowHeight, 0xffffffff );
		}

		for ( uint y = 0; y < windowHeight; y += yStep )
		{
			debugDraw::AddLineSS( 0, y, windowWidth, y, 0xff808080 );
		}
	}

	void SettingsTestApp::GetRenderTargetSize( RenderTargetSize rtSize, uint &rtWidth, uint &rtHeight )
	{
		switch ( rtSize )
		{
		case spad::SettingsTestApp::RTW_1920_1080:
			rtWidth = 1920;// / 8;
			rtHeight = 1080;// / 8;
			break;
		case spad::SettingsTestApp::RTW_1280_720:
			rtWidth = 1280;
			rtHeight = 720;
			break;
		case spad::SettingsTestApp::RTW_3840_2160:
			rtWidth = 3840;
			rtHeight = 2160;
			break;
		case spad::SettingsTestApp::RTW_4096_4096:
			rtWidth = 4 * 1024;
			rtHeight = 4 * 1024;
			break;
		case spad::SettingsTestApp::RTW_2048_2048:
			rtWidth = 2 * 1024;
			rtHeight = 2 * 1024;
			break;
		case spad::SettingsTestApp::RTW_1024_1024:
			rtWidth = 1024;
			rtHeight = 1024;
			break;
		case spad::SettingsTestApp::RTW_512_512:
			rtWidth = 512;
			rtHeight = 512;
			break;
		case spad::SettingsTestApp::RTW_128_128:
			rtWidth = 128;
			rtHeight = 128;
			break;
		case spad::SettingsTestApp::RTW_64_64:
			rtWidth = 64;
			rtHeight = 64;
			break;
		default:
			SPAD_NOT_IMPLEMENTED;
			break;
		}
	}

	void SettingsTestApp::GetRenderTargetSize( uint &rtWidth, uint &rtHeight ) const
	{
		GetRenderTargetSize( rtSize_, rtWidth, rtHeight );
	}

}
