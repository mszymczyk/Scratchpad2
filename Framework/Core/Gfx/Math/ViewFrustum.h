#pragma once

#include <Util\vectormath.h>

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
