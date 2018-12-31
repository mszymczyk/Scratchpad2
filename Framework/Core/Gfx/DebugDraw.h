#pragma once

#include "dx11/Dx11DeviceContext.h"
#include "Math/ViewFrustum.h"
#include "Math/DirectXMathWrap.h"

namespace spad
{

	namespace debugDraw
	{
		void AddLine( const Vector3& from, const Vector3& to, bool screenSpace, bool normalizedCoords, const u32 colorABGR, float lineWidth = 1.0f, bool depthEnabled = true );
		void AddLineWS( const Vector3& from, const Vector3& to, const u32 colorABGR, float lineWidth = 1.0f, bool depthEnabled = true );
		inline void AddLineSS( float x0, float y0, float x1, float y1, bool normalizedCoords, const u32 colorABGR, float lineWidth = 1.0f )
		{
			AddLine( Vector3( x0, y0, 0 ), Vector3( x1, y1, 0 ), true, normalizedCoords, colorABGR, lineWidth, false );
		}
		inline void AddLineSS( int x0, int y0, int x1, int y1, const u32 colorABGR, float lineWidth = 1.0f )
		{
			AddLineSS( static_cast<float>( x0 ), static_cast<float>( y0 ), static_cast<float>( x1 ), static_cast<float>( y1 ), false, colorABGR, lineWidth );
		}
		// creates plane on ZX axis, with normal pointing along Y axis (right handed system)
		void AddPlaneWS( const Vector4& plane, float xSize, float ySize, u32 xSubdivs, u32 ySubdivs, const u32 colorABGR, float lineWidth = 1.0f, bool depthEnabled = true );
		void AddFrustum( const ViewFrustum& frustum, const u32 colorABGR, float lineWidth = 1.0f, bool depthEnabled = true );
		//void AddOBB( const Vector3 &center, const Vector3 &halfSize, const Matrix3 &orientation, const u32 colorABGR, float lineWidth = 1.0f, bool depthEnabled = true );
		void AddAxes( const Vector3 &center, const Vector3 &halfSize, const Matrix3 &orientation, const float colorMod, float lineWidth = 1.0f, bool depthEnabled = true );
		inline void AddAxes( const dxmath::Float3 &center, const dxmath::Float3 &halfSize, const dxmath::Float3 &xAxis, const dxmath::Float3 &yAxis, const dxmath::Float3 &zAxis, const float colorMod, float lineWidth = 1.0f, bool depthEnabled = true )
		{
			AddAxes( center.ToVector3(), halfSize.ToVector3(), Matrix3( xAxis.ToVector3(), yAxis.ToVector3(), zAxis.ToVector3() ), colorMod, lineWidth, depthEnabled );
		}
		void AddLineListWS( std::vector<Vector3>&& verts, const u32 colorABGR, float lineWidth = 1.0f, bool depthEnabled = true );
		void AddLineListSS( std::vector<Vector3>&& verts, const u32 colorABGR, float lineWidth = 1.0f );
		void AddLineStripWS( std::vector<Vector3>&& verts, const u32 colorABGR, float lineWidth = 1.0f, bool depthEnabled = true );
		void AddLineStripSS( std::vector<Vector3>&& verts, const u32 colorABGR, float lineWidth = 1.0f );
		void AddQuadSS( float leftTopX, float leftTopY, float width, float height, const u32 colorABGR, bool normalizedCoords );
		inline void AddQuadSS( int leftTopX, int leftTopY, int width, int height, const u32 colorABGR )
		{
			AddQuadSS( static_cast<float>( leftTopX ), static_cast<float>( leftTopY ), static_cast<float>( width ), static_cast<float>( height ), colorABGR, false );
		}

		namespace DontTouchThis
		{
			void Initialize( ID3D11Device* dxDevice );
			void DeInitialize();

			void Draw( Dx11DeviceContext& deviceContext, const Matrix4& view, const Matrix4& proj, u32 rtWidth, u32 rtHeight );
			void Clear();
		};
	} // namespace debug

} // namespace spad
