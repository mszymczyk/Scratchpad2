#include "Gfx_pch.h"
#include "DebugDraw.h"
#include "Text\TextRenderer.h"
#include "shaders\hlsl\DebugRendererConstants.h"
#include "dx11\Dx11DeviceStates.h"

#if defined(_MSC_VER) && defined(_DEBUG)
#define new _DEBUG_NEW
#endif

namespace spad
{

namespace debugDraw
{
	struct _DebugObjectDrawContext
	{
		_DebugObjectDrawContext( RingBuffer& _vertices, ConstantBuffer<CbDebugRendererConstants>& _constants )
			: vertices( _vertices )
			, shaderConstants( _constants )
		{	}

		void operator=( _DebugObjectDrawContext& rhs ) = delete;

		Matrix4 view = Matrix4::identity();
		Matrix4 proj = Matrix4::identity();
		Matrix4 viewProj = Matrix4::identity();

		float rtWidthF = 0;
		float rtHeightF = 0;

		ConstantBuffer<CbDebugRendererConstants>& shaderConstants;
		RingBuffer& vertices;
	};

	struct _DebugObject
	{
		virtual ~_DebugObject()
		{ }

		virtual void draw( Dx11DeviceContext& deviceContext, const _DebugObjectDrawContext& drawContext ) = 0;
	};





	class _DebugLine : public _DebugObject
	{
	public:
		_DebugLine( const Vector3& from, const Vector3& to, bool screenSpace, bool normalizedCoords, const u32 colorABGR, float lineWidth, bool depthEnabled )
			: from_( from )
			, to_( to )
			, colorABGR_( colorABGR )
			, lineWidth_( lineWidth )
			, depthEnabled_( depthEnabled )
			, screenSpace_( screenSpace )
			, normalizedScreenCoords_( normalizedCoords )
		{	}

		~_DebugLine() {}

		void draw( Dx11DeviceContext& deviceContext, const _DebugObjectDrawContext& drawContext ) override;

	public:
		Vector3 from_;
		Vector3 to_;
		u32 colorABGR_;
		float lineWidth_;
		bool depthEnabled_;
		bool screenSpace_;
		bool normalizedScreenCoords_;
	};

	void _DebugLine::draw( Dx11DeviceContext& deviceContext, const _DebugObjectDrawContext& drawContext )
	{
		ID3D11DeviceContext* context = deviceContext.context;

		if ( screenSpace_ )
		{
			drawContext.shaderConstants.data.WorldViewProjection = normalizedScreenCoords_ ? Matrix4::orthographic( -1, 1, -1, 1, -1, 1 ) : Matrix4::orthographic( 0, drawContext.rtWidthF, drawContext.rtHeightF, 0, -1, 1 );
		}
		else
		{
			drawContext.shaderConstants.data.WorldViewProjection = drawContext.viewProj;
		}

		drawContext.shaderConstants.data.Color = abgrToRgba( colorABGR_ );
		drawContext.shaderConstants.updateGpu( context );

		context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_LINELIST );

		if ( depthEnabled_ )
			context->OMSetDepthStencilState( DepthStencilStates::DepthWriteEnabled(), 0 );
		else
			context->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );

		Vector3* ptr = reinterpret_cast<Vector3*>( drawContext.vertices.map( context, 2 * sizeof( Vector3 ) ) );
		ptr[0] = from_;
		ptr[1] = to_;
		drawContext.vertices.unmap( context );

		drawContext.vertices.setVertexBuffer( context, 0, 16 );
		context->Draw( 2, 0 );
	}





	class _DebugPlane : public _DebugObject
	{
	public:
		_DebugPlane( const Vector4& plane, float xSize, float zSize, u32 xSubdivs, u32 zSubdivs, const u32 colorABGR, float lineWidth = 1.0f, bool depthEnabled = true )
			: plane_( plane )
			, xSize_( xSize )
			, zSize_( zSize )
			, xSubdivs_( xSubdivs )
			, zSubdivs_( zSubdivs )
			, colorABGR_( colorABGR )
			, lineWidth_( lineWidth )
			, depthEnabled_( depthEnabled )
		{	}

		~_DebugPlane() {}

		void draw( Dx11DeviceContext& deviceContext, const _DebugObjectDrawContext& drawContext ) override;

	public:
		Vector4 plane_;
		float xSize_;
		float zSize_;
		u32 xSubdivs_;
		u32 zSubdivs_;
		u32 colorABGR_;
		float lineWidth_;
		bool depthEnabled_;
	};

	//// provided vector will be y axis of the frame
	////
	//inline Matrix3 createBasisYAxis( const Vector3& n )
	//{
	//	// http://orbit.dtu.dk/fedora/objects/orbit:113874/datastreams/file_75b66578-222e-4c7d-abdf-f7e255100209/content
	//	//
	//	if ( n.getY().getAsFloat() < -0.9999999f )
	//	{
	//		return Matrix3( Vector3( 1.f, 0.f, 0.f ), n, Vector3( 0.f, 0.f, -1.f ) );
	//	}

	//	const floatInVec oneInVec( 1.0f );
	//	const floatInVec a = oneInVec / ( oneInVec + n.getZ() );
	//	const floatInVec b = -n.getX()*n.getZ()*a;
	//	const Vector3 x = Vector3( oneInVec - n.getX()*n.getX()*a, -n.getX(), b );
	//	const Vector3 z = Vector3( b, -n.getZ(), oneInVec - n.getZ()*n.getZ()*a );
	//	return Matrix3( x, n, z );
	//}

	void _DebugPlane::draw( Dx11DeviceContext& deviceContext, const _DebugObjectDrawContext& drawContext )
	{
		ID3D11DeviceContext* context = deviceContext.context;

		Matrix3 rot = createBasisYAxis( plane_.getXYZ() );
		Vector3 tr = plane_.getXYZ() * plane_.getW();
		Matrix4 world = Matrix4( rot, tr );

		drawContext.shaderConstants.data.WorldViewProjection = drawContext.viewProj * world;
		drawContext.shaderConstants.data.Color = abgrToRgba( colorABGR_ );
		drawContext.shaderConstants.updateGpu( context );

		context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_LINELIST );

		if ( depthEnabled_ )
			context->OMSetDepthStencilState( DepthStencilStates::DepthWriteEnabled(), 0 );
		else
			context->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );

		u32 nLinesAlongX = ( xSubdivs_ + 1 );
		u32 nLinesAlongZ = ( zSubdivs_ + 1 );
		// one line representing normal
		u32 nVertices = ( nLinesAlongX + nLinesAlongZ + 1 ) * 2;

		Vector3* ptr = reinterpret_cast<Vector3*>( drawContext.vertices.map( context, nVertices * sizeof( Vector3 ) ) );
		Vector3* tmpPtr = ptr;
		drawContext.vertices.unmap( context );

		const floatInVec halfXSize( xSize_ * 0.5f );
		const floatInVec halfZSize( zSize_ * 0.5f );
		const floatInVec zero( 0.0f );

		const floatInVec dx( xSize_ / (float)xSubdivs_ );
		floatInVec x( -halfXSize );

		for ( u32 ix = 0; ix < nLinesAlongX; ++ix )
		{
			tmpPtr[0] = Vector3( x, zero, -halfZSize );
			tmpPtr[1] = Vector3( x, zero, halfZSize );
			tmpPtr += 2;
			x += dx;
		}

		floatInVec z( -halfZSize );
		const floatInVec dz( zSize_ / (float)zSubdivs_ );

		for ( u32 ix = 0; ix < nLinesAlongZ; ++ix )
		{
			tmpPtr[0] = Vector3( -halfXSize, zero, z );
			tmpPtr[1] = Vector3( halfXSize, zero, z );
			tmpPtr += 2;
			z += dz;
		}

		tmpPtr[0] = Vector3( 0.0f );
		tmpPtr[1] = Vector3::yAxis();

		drawContext.vertices.setVertexBuffer( context, 0, 16 );
		context->Draw( nVertices, 0 );
	}





	class _DebugLineList : public _DebugObject
	{
	public:
		_DebugLineList( std::vector<Vector3>&& vertices, const u32 colorABGR, float lineWidth, bool lineStrip, bool screenSpace, bool depthEnabled )
			: vertices_( std::move( vertices ) )
			, colorABGR_( colorABGR )
			, lineWidth_( lineWidth )
			, lineStrip_( lineStrip )
			, screenSpace_( screenSpace )
			, depthEnabled_( depthEnabled )
		{	}

		~_DebugLineList() {}

		void draw( Dx11DeviceContext& deviceContext, const _DebugObjectDrawContext& drawContext ) override;

	public:
		std::vector<Vector3> vertices_;
		u32 colorABGR_;
		float lineWidth_;
		bool lineStrip_;
		bool screenSpace_;
		bool depthEnabled_;
	};

	void _DebugLineList::draw( Dx11DeviceContext& deviceContext, const _DebugObjectDrawContext& drawContext )
	{
		ID3D11DeviceContext* context = deviceContext.context;

		drawContext.shaderConstants.data.WorldViewProjection = screenSpace_ ? Matrix4::orthographic( -1, 1, -1, 1, -1, 1 ) : drawContext.viewProj;
		drawContext.shaderConstants.data.Color = abgrToRgba( colorABGR_ );
		drawContext.shaderConstants.updateGpu( context );

		if ( lineStrip_ )
			context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_LINESTRIP );
		else
			context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_LINELIST );

		if (depthEnabled_)
			context->OMSetDepthStencilState( DepthStencilStates::DepthWriteEnabled(), 0 );
		else
			context->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );

		size_t siz = vertices_.size() * sizeof( Vector3 );
		Vector3* ptr = reinterpret_cast<Vector3*>( drawContext.vertices.map( context, (u32)siz ) );
		memcpy( ptr, &vertices_[0], siz );
		drawContext.vertices.unmap( context );

		drawContext.vertices.setVertexBuffer( context, 0, 16 );
		context->Draw( (UINT)vertices_.size(), 0 );
	}




	class _DebugQuadSS : public _DebugObject
	{
	public:
		_DebugQuadSS( float leftTopX, float leftTopY, float width, float height, u32 colorABGR, bool normalizedScreenCoords )
			: leftTopX_( leftTopX )
			, leftTopY_( leftTopY )
			, width_( width )
			, height_( height )
			, colorABGR_( colorABGR )
			, normalizedScreenCoords_( normalizedScreenCoords )
		{	}

		~_DebugQuadSS() {}

		void draw( Dx11DeviceContext& deviceContext, const _DebugObjectDrawContext& drawContext ) override;

	public:
		float leftTopX_;
		float leftTopY_;
		float width_;
		float height_;
		u32 colorABGR_;
		bool normalizedScreenCoords_;
	};

	void _DebugQuadSS::draw( Dx11DeviceContext& deviceContext, const _DebugObjectDrawContext& drawContext )
	{
		ID3D11DeviceContext* context = deviceContext.context;

		drawContext.shaderConstants.data.WorldViewProjection = normalizedScreenCoords_ ? Matrix4::orthographic( -1, 1, -1, 1, -1, 1 ) : Matrix4::orthographic( 0, drawContext.rtWidthF, drawContext.rtHeightF, 0, -1, 1 );
		drawContext.shaderConstants.data.Color = abgrToRgba( colorABGR_ );
		drawContext.shaderConstants.updateGpu( context );

		context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );

		context->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );

		Vector3* ptr = reinterpret_cast<Vector3*>( drawContext.vertices.map( context, 6 * sizeof( Vector3 ) ) );
		
		ptr[0] = Vector3( leftTopX_, leftTopY_ + height_, 0 );
		ptr[1] = Vector3( leftTopX_ + width_, leftTopY_ + height_, 0 );
		ptr[2] = Vector3( leftTopX_, leftTopY_, 0 );

		ptr[3] = Vector3( leftTopX_, leftTopY_, 0 );
		ptr[4] = Vector3( leftTopX_ + width_, leftTopY_ + height_, 0 );
		ptr[5] = Vector3( leftTopX_ + width_, leftTopY_, 0 );

		drawContext.vertices.unmap( context );

		drawContext.vertices.setVertexBuffer( context, 0, 16 );
		context->Draw( 6, 0 );
	}




	struct _Impl
	{
		~_Impl()
		{
			DeInitialize();
		}

		void Initialize( ID3D11Device* dxDevice );
		void DeInitialize();

		HlslShaderPtr debugShader_;
		BMFont font_consolas_;
		TextRenderer textRenderer_;
		RingBuffer vertices_;
		ConstantBuffer<CbDebugRendererConstants> constantBuffer_;

		std::mutex mutex_;

		std::vector<std::unique_ptr<_DebugObject>> objects_;

	} * _gImpl;

	void _Impl::Initialize( ID3D11Device* dxDevice )
	{
		std::lock_guard<std::mutex> lck( mutex_ );

		debugShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\DebugRenderer.hlslc_packed" );
		font_consolas_.Initialize( dxDevice, "Data\\Fonts\\consolas.fnt" );
		textRenderer_.Initialize( dxDevice );
		vertices_.Initialize( dxDevice, 64 * 1024 );
		constantBuffer_.Initialize( dxDevice );
	}

	void _Impl::DeInitialize()
	{

	}


	void DontTouchThis::Initialize( ID3D11Device* dxDevice )
	{
		SPAD_ASSERT( !_gImpl );
		_gImpl = new _Impl();
		_gImpl->Initialize( dxDevice );
	}

	void DontTouchThis::DeInitialize()
	{
		if ( _gImpl )
		{
			delete _gImpl;
			_gImpl = nullptr;
		}
	}

	void DontTouchThis::Draw( Dx11DeviceContext& deviceContext, const Matrix4& view, const Matrix4& proj, u32 rtWidth, u32 rtHeight )
	{
		if ( !_gImpl )
			return;

		std::lock_guard<std::mutex> lck( _gImpl->mutex_ );

		ID3D11DeviceContext* context = deviceContext.context;

		const HlslShaderPass& fxPass = *_gImpl->debugShader_->getPass( "DebugDraw" );
		fxPass.setVS( context );
		fxPass.setPS( context );

		context->RSSetState( RasterizerStates::NoCull() );
		context->OMSetBlendState( BlendStates::blendDisabled , nullptr, 0xffffffff );
		_gImpl->constantBuffer_.setVS( context, REGISTER_CBUFFER_DEBUG_RENDERER_CONSTANTS );
		_gImpl->constantBuffer_.setPS( context, REGISTER_CBUFFER_DEBUG_RENDERER_CONSTANTS );

		D3D11_INPUT_ELEMENT_DESC layout[] =
		{
			{ "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
		};

		u32 layoutHash = Dx11HashInputElementDescriptions( layout, 1 );
		// Set the input layout
		deviceContext.inputLayoutCache.setInputLayout( context, layoutHash, fxPass.vsInputSignatureHash_
			, layout, 1, reinterpret_cast<const u8*>( fxPass.vsInputSignature_->GetBufferPointer() ), (u32)fxPass.vsInputSignature_->GetBufferSize() );

		_DebugObjectDrawContext ctx( _gImpl->vertices_, _gImpl->constantBuffer_ );
		ctx.view = view;
		ctx.proj = proj;
		ctx.viewProj = ctx.proj * ctx.view;
		ctx.rtWidthF = static_cast<float>( rtWidth );
		ctx.rtHeightF = static_cast<float>( rtHeight );
		ctx.shaderConstants.data.WorldViewProjection = ctx.viewProj;
		ctx.shaderConstants.data.Color = Vector4( 1.0f );

		for ( const auto& dob : _gImpl->objects_ )
		{
			dob->draw( deviceContext, ctx );
		}
	}

	void DontTouchThis::Clear()
	{
		if ( !_gImpl )
			return;

		std::lock_guard<std::mutex> lck( _gImpl->mutex_ );

		_gImpl->objects_.clear();
	}

	void AddLine( const Vector3& from, const Vector3& to, bool screenSpace, bool normalizedCoords, const u32 colorABGR, float lineWidth /*= 1.0f*/, bool depthEnabled /*= true */ )
	{
		if ( !_gImpl )
			return;

		std::unique_ptr<_DebugObject> ob = std::make_unique<_DebugLine>( from, to, screenSpace, normalizedCoords, colorABGR,  lineWidth, depthEnabled );

		{
			std::lock_guard<std::mutex> lck( _gImpl->mutex_ );
			_gImpl->objects_.emplace_back( std::move( ob ) );
		}

	}

	void AddLineWS( const Vector3& from, const Vector3& to, const u32 colorABGR, float lineWidth /*= 1.0f*/, bool depthEnabled /*= true */ )
	{
		if ( !_gImpl )
			return;

		std::unique_ptr<_DebugObject> ob = std::make_unique<_DebugLine>( from, to, false, false, colorABGR, lineWidth, depthEnabled );

		{
			std::lock_guard<std::mutex> lck( _gImpl->mutex_ );
			_gImpl->objects_.emplace_back( std::move(ob) );
		}
	}

	void AddPlaneWS( const Vector4& plane, float xSize, float zSize, u32 xSubdivs, u32 zSubdivs, const u32 colorABGR, float lineWidth /*= 1.0f*/, bool depthEnabled /*= true */ )
	{
		if ( !_gImpl )
			return;

		std::unique_ptr<_DebugObject> ob = std::make_unique<_DebugPlane>( plane, xSize, zSize, xSubdivs, zSubdivs, colorABGR, lineWidth, depthEnabled );

		{
			std::lock_guard<std::mutex> lck( _gImpl->mutex_ );
			_gImpl->objects_.emplace_back( std::move( ob ) );
		}
	}

	void AddFrustum( const ViewFrustum& frustum, const u32 colorABGR, float lineWidth /*= 1.0f*/, bool depthEnabled /*= true */ )
	{
		if (!_gImpl)
			return;

		std::vector<Vector3> verts;
		verts.resize( 12 * 2 ); // 12 lines, 2 vertices each

		verts[0]  = frustum.corners[ViewFrustum::eCorner_leftBottomNear];
		verts[1]  = frustum.corners[ViewFrustum::eCorner_leftBottomFar];
		verts[2]  = frustum.corners[ViewFrustum::eCorner_rightBottomNear];
		verts[3]  = frustum.corners[ViewFrustum::eCorner_rightBottomFar];

		verts[4]  = frustum.corners[ViewFrustum::eCorner_rightTopNear];
		verts[5]  = frustum.corners[ViewFrustum::eCorner_rightTopFar];
		verts[6]  = frustum.corners[ViewFrustum::eCorner_leftTopNear];
		verts[7]  = frustum.corners[ViewFrustum::eCorner_leftTopFar];

		verts[8]  = frustum.corners[ViewFrustum::eCorner_leftBottomNear];
		verts[9]  = frustum.corners[ViewFrustum::eCorner_rightBottomNear];
		verts[10] = frustum.corners[ViewFrustum::eCorner_rightBottomNear];
		verts[11] = frustum.corners[ViewFrustum::eCorner_rightTopNear];

		verts[12] = frustum.corners[ViewFrustum::eCorner_rightTopNear];
		verts[13] = frustum.corners[ViewFrustum::eCorner_leftTopNear];
		verts[14] = frustum.corners[ViewFrustum::eCorner_leftTopNear];
		verts[15] = frustum.corners[ViewFrustum::eCorner_leftBottomNear];

		verts[16] = frustum.corners[ViewFrustum::eCorner_rightBottomFar];
		verts[17] = frustum.corners[ViewFrustum::eCorner_leftBottomFar];
		verts[18] = frustum.corners[ViewFrustum::eCorner_leftBottomFar];
		verts[19] = frustum.corners[ViewFrustum::eCorner_leftTopFar];

		verts[20] = frustum.corners[ViewFrustum::eCorner_leftTopFar];
		verts[21] = frustum.corners[ViewFrustum::eCorner_rightTopFar];
		verts[22] = frustum.corners[ViewFrustum::eCorner_rightTopFar];
		verts[23] = frustum.corners[ViewFrustum::eCorner_rightBottomFar];

		std::unique_ptr<_DebugLineList> ob = std::make_unique<_DebugLineList>( std::move(verts), colorABGR, lineWidth, false, false, depthEnabled );

		{
			std::lock_guard<std::mutex> lck( _gImpl->mutex_ );
			_gImpl->objects_.emplace_back( std::move( ob ) );
		}
	}

	//void AddOBB( const Vector3 &center, const Vector3 &halfSize, const Matrix3 &orientation, const u32 colorABGR, float lineWidth /*= 1.0f*/, bool depthEnabled /*= true */ )
	//{
	//	Vector3 corners[8];
	//	corners[ViewFrustum::eCorner_leftBottomNear] = center - orientation.
	//}

	void AddAxes( const Vector3 &worldPosition, const Vector3 &halfSize, const Matrix3 &orientation, const float colorMod, float lineWidth /*= 1.0f*/, bool depthEnabled /*= true */ )
	{
		Vector3 xAxis( orientation.getCol0() );
		Vector3 yAxis( orientation.getCol1() );
		Vector3 zAxis( orientation.getCol2() );

		u32 colorX = 0xff000000 + ( (u32)( 0xff * colorMod ) );
		u32 colorY = 0xff000000 + ( (u32)( 0xff * colorMod ) << 8 );
		u32 colorZ = 0xff000000 + ( (u32)( 0xff * colorMod ) << 16 );

		AddLineWS( worldPosition, worldPosition + xAxis * halfSize.getX(), colorX, lineWidth, depthEnabled );
		AddLineWS( worldPosition, worldPosition + yAxis * halfSize.getY(), colorY, lineWidth, depthEnabled );
		AddLineWS( worldPosition, worldPosition + zAxis * halfSize.getZ(), colorZ, lineWidth, depthEnabled );
	}

	void AddLineListWS( std::vector<Vector3>&& verts, const u32 colorABGR, float lineWidth /*= 1.0f*/, bool depthEnabled /*= true */ )
	{
		std::unique_ptr<_DebugLineList> ob = std::make_unique<_DebugLineList>( std::move( verts ), colorABGR, lineWidth, false, false, depthEnabled );

		{
			std::lock_guard<std::mutex> lck( _gImpl->mutex_ );
			_gImpl->objects_.emplace_back( std::move( ob ) );
		}
	}

	void AddLineListSS( std::vector<Vector3>&& verts, const u32 colorABGR, float lineWidth /*= 1.0f*/ )
	{
		std::unique_ptr<_DebugLineList> ob = std::make_unique<_DebugLineList>( std::move( verts ), colorABGR, lineWidth, false, true, false );

		{
			std::lock_guard<std::mutex> lck( _gImpl->mutex_ );
			_gImpl->objects_.emplace_back( std::move( ob ) );
		}
	}

	void AddLineStripWS( std::vector<Vector3>&& verts, const u32 colorABGR, float lineWidth /*= 1.0f*/, bool depthEnabled /*= true */ )
	{
		std::unique_ptr<_DebugLineList> ob = std::make_unique<_DebugLineList>( std::move( verts ), colorABGR, lineWidth, true, false, depthEnabled );

		{
			std::lock_guard<std::mutex> lck( _gImpl->mutex_ );
			_gImpl->objects_.emplace_back( std::move( ob ) );
		}

	}

	void AddLineStripSS( std::vector<Vector3>&& verts, const u32 colorABGR, float lineWidth /*= 1.0f*/ )
	{
		std::unique_ptr<_DebugLineList> ob = std::make_unique<_DebugLineList>( std::move( verts ), colorABGR, lineWidth, true, true, false );

		{
			std::lock_guard<std::mutex> lck( _gImpl->mutex_ );
			_gImpl->objects_.emplace_back( std::move( ob ) );
		}
	}


	void AddQuadSS( float leftTopX, float leftTopY, float width, float height, const u32 colorABGR, bool normalizedScreenCoords )
	{
		std::unique_ptr<_DebugQuadSS> ob = std::make_unique<_DebugQuadSS>( leftTopX, leftTopY, width, height, colorABGR, normalizedScreenCoords );

		{
			std::lock_guard<std::mutex> lck( _gImpl->mutex_ );
			_gImpl->objects_.emplace_back( std::move( ob ) );
		}
	}

} // namespace debug
} // namespace spad
