#pragma once

#include <Util\vectormath.h>
#include "HLSLEmulation.h"

// planes point inward, into center of frustum
struct ViewFrustum
{
	// 8 planes in SOA format
	//
	Vector4 xPlaneLRBT, yPlaneLRBT, zPlaneLRBT, wPlaneLRBT;
	Vector4 xPlaneNFNF, yPlaneNFNF, zPlaneNFNF, wPlaneNFNF;

	enum e_Plane
	{
		ePlane_left,
		ePlane_right,
		ePlane_bottom,
		ePlane_top,
		ePlane_near,
		ePlane_far,
		ePlane_ext0,
		ePlane_ext1,
		ePlane_count
	};

	enum e_Corner
	{
		eCorner_leftTopNear,
		eCorner_leftTopFar,
		eCorner_leftBottomNear,
		eCorner_leftBottomFar,
		eCorner_rightBottomNear,
		eCorner_rightBottomFar,
		eCorner_rightTopNear,
		eCorner_rightTopFar,
	};

	Vector4 planes[ePlane_count]; // planes in AOS format
	Vector3 corners[8];

}; // struct ViewFrustum


inline const Vector3 unprojectNormalized( const Vector3& screenPos01, const Matrix4& inverseMatrix )
{
	// z maps to  <-1,1>
	const floatInVec one( 1.0f );
	Vector4 hpos = Vector4( screenPos01, one );
	hpos = mulPerElem( hpos, Vector4( 2.0f ) ) - Vector4( one ); // msubf4(hpos, Vector4(2.0f), Vector4(one)); //mulPerElem( hpos, Vector4(2.0f) ) - Vector4(1.0f);
	Vector4 worldPos = inverseMatrix * hpos;
	worldPos /= worldPos.getW();
	return worldPos.getXYZ();
}


inline const Vector3 unprojectNormalizedDx( const Vector3& screenPos01, const Matrix4& inverseMatrix )
{
	// z maps to <0,1>
	const floatInVec one( 1.0f );
	const floatInVec zer( 0.0f );
	Vector4 hpos = Vector4( screenPos01, one );
	hpos = mulPerElem( hpos, Vector4( 2.0f, 2.0f, 1.0f, 1.0f ) ) - Vector4( one, one, zer, zer ); // msubf4(hpos, Vector4(2.0f), Vector4(one)); //mulPerElem( hpos, Vector4(2.0f) ) - Vector4(1.0f);
	Vector4 worldPos = inverseMatrix * hpos;
	worldPos /= worldPos.getW();
	return worldPos.getXYZ();
}


ViewFrustum extractFrustum( const Matrix4& viewProjection, bool dxStyleProjection );


inline float3 WorldPositionFromScreenCoords( float3 eyeAxis[3], float3 eyeOffset, float2 screenCoords, float depth )
{
	float3 eyeRay = eyeAxis[0] * screenCoords.xxx +
		eyeAxis[1] * screenCoords.yyy +
		eyeAxis[2];

	return eyeOffset + eyeRay * depth;
}

struct FrustumFace
{
	float3 center;
	float3 axes[2];
};

struct OrientedBoundingBox
{
	float3 center;
	float3 axes[3];
	float3 halfSize;
};

inline float3 GetFrustumVertex( const HLSL_in FrustumFace frustumFaces[2], int vertIndex )
{
	int sx = vertIndex & 1;
	int sy = ( vertIndex >> 1 ) & 1;
	int iz = vertIndex >> 2;

	//return frustumFaces[iz].center + frustumFaces[iz].axes[0] * (float)sx + frustumFaces[iz].axes[1] * (float)sy; // incorrect
	float sxn = sx * 2.0f - 1.0f;
	float syn = sy * 2.0f - 1.0f;
	return frustumFaces[iz].center + frustumFaces[iz].axes[0] * (float)sxn + frustumFaces[iz].axes[1] * (float)syn;
}

bool TestFrustumObbIntersectionSAT( const OrientedBoundingBox obb, const FrustumFace frustumFaces[2] );
//void GetFrustumClusterFaces( HLSL_out FrustumFace faces[2], float3 eyeAxis[3], float3 eyeOffset, float2 cellSize, float3 cellCount, float3 cellCountF, float3 cellCountRcp, float3 cellIndex, float2 tanHalfFov, float nearPlane, float farPlane, float farPlaneOverNearPlane, bool farClip = false );
void GetFrustumClusterFaces( HLSL_out FrustumFace faces[2], float3 eyeAxis[3], float3 eyeOffset, float2 cellSize, float3 cellCount, float3 cellCountF, float3 cellCountRcp, float3 cellIndex, float2 tanHalfFov, float nearPlane, float farPlane, float farPlaneOverNearPlane, bool farClip = false );
