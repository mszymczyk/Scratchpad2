#include "Octahedron_pch.h"
#include "OctahedronApp.h"
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
	constexpr float decalVolumeFarPlane_ = 1000;
	//const uint texSize = 64;

	uint dualParaboloidWidthScale = 1;

	u32 GetMipMapCountFromDimesions( u32 mipW, u32 mipH, u32 mipD )
	{
		u32 max = maxOfTriple( (i32)mipW, (i32)mipH, (i32)mipD );
		u16 i = 0;

		while ( max > 0 )
		{
			max >>= 1;
			i++;
		}

		return i;
	}

	#define ENVMAP_MIPLEVEL_0_PB	(5.0f)
	#define ENVMAP_MIPLEVEL_1_PB	(0.0f)

	static inline float GlossFromMiplevel( int mipLevel )
	{
		return ( ENVMAP_MIPLEVEL_0_PB - mipLevel ) / ( ENVMAP_MIPLEVEL_0_PB - ENVMAP_MIPLEVEL_1_PB );
	}

	//void TestUvBorderMapping()
	//{
	//	float s = 64;
	//	float uv = 0.0f;
	//	float b = 16;
	//	//float scale = ( s - 2 * b ) / s;
	//	//float offset = 1.0f 
	//	float scale = s / ( s - 2 * b );
	//	uv = uv * scale;
	//}

	bool SettingsTestApp::StartUp()
	{
		const float aspect = (float)dx11_->getBackBufferWidth() / (float)dx11_->getBackBufferHeight();
		projMatrixForCamera_ = perspectiveProjectionDxStyle( deg2rad( 60.0f ), aspect, 1.0f, decalVolumeFarPlane_ );
		viewMatrixForCamera_ = ( Matrix4::lookAt( Point3( 5, 5, 5 ), Point3( 0, 0, 0 ), Vector3::yAxis() ) );
		cameraDistance_ = Vector3( 0.0f, 0.0f, 5.0f );

		float viewMatrix[16] = {
			  -0.857470632f, -0.0419470631f,      0.512821972f,     -0.000000000f,
			0.000109484659f,      0.996659815f,     0.0817059800f,      0.000000000f,
			  -0.514533162f,     0.0701168105f,     -0.854601145f,     -0.000000000f,
			1.19326899e-07f,   3.82033960e-09f,      -2.41014862f,      0.999945104f,
		};

		memcpy( &viewMatrixForCamera_, viewMatrix, sizeof( viewMatrixForCamera_ ) );

		ID3D11Device* dxDevice = dx11_->getDevice();

		mainDS_.Initialize( dxDevice, dx11_->getBackBufferWidth(), dx11_->getBackBufferHeight(), 1, DXGI_FORMAT_D24_UNORM_S8_UINT, 1, 0, true );

		shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\octahedron.hlslc_packed" );
		compressionShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\block_compression.hlslc_packed" );

		srcCubeMapSrv_ = LoadTexture( dxDevice, "Assets\\refl_probe.dds" );
		srcCubeMapUnfilteredSrv_ = LoadTexture( dxDevice, "Assets\\refl_probe_unfiltered.dds" );

		//ID3D11Resource *cubeMap_;
		//cubeMapSrv_->GetResource( &cubeMap_ );
		//ID3D11Texture2D *cubeMapTex_;
		//HRESULT hr = cubeMap_->QueryInterface( IID_ID3D11Texture2D, (void **)&cubeMapTex_ );
		//assert( hr == S_OK );
		//D3D11_TEXTURE2D_DESC cubeMapDesc;
		//cubeMapTex_->GetDesc( &cubeMapDesc );
		//cubeMapTex_->Release();
		//cubeMap_->Release();

		//passConstants_.Initialize( dx11_->getDevice() );
		//objectConstants_.Initialize( dx11_->getDevice() );
		octahedronConstants_.Initialize( dxDevice );
		//octahedronGenConstants_.Initialize( dxDevice );
		compressionConstants_.Initialize( dxDevice );

		//{
		//	D3D11_TEXTURE2D_DESC desc;
		//	ZeroMemory( &desc, sizeof( desc ) );
		//	desc.Width = texSize;
		//	desc.Height = texSize;
		//	desc.ArraySize = 1;
		//	desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS | D3D11_BIND_SHADER_RESOURCE;
		//	desc.SampleDesc.Count = 1;
		//	desc.SampleDesc.Quality = 0;
		//	desc.CPUAccessFlags = 0;
		//	desc.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
		//	desc.MipLevels = 1;
		//	desc.Usage = D3D11_USAGE_DEFAULT;

		//	DXCall( dxDevice->CreateTexture2D( &desc, nullptr, &tex_ ) );
		//	debug::Dx11SetDebugName( tex_, "tex" );

		//	D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc;
		//	ZeroMemory( &srvDesc, sizeof( srvDesc ) );
		//	srvDesc.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
		//	srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
		//	srvDesc.Texture2D.MipLevels = (UINT)-1;
		//	srvDesc.Texture2D.MostDetailedMip = 0;

		//	DXCall( dxDevice->CreateShaderResourceView( tex_, &srvDesc, &texSrv_ ) );
		//	debug::Dx11SetDebugName3( texSrv_, "tex SRV" );
		//	
		//	D3D11_UNORDERED_ACCESS_VIEW_DESC uavDesc;
		//	ZeroMemory( &uavDesc, sizeof( uavDesc ) );
		//	uavDesc.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
		//	uavDesc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2D;
		//	uavDesc.Texture2D.MipSlice = 0;

		//	DXCall( dxDevice->CreateUnorderedAccessView( tex_, &uavDesc, &texUav_ ) );
		//	debug::Dx11SetDebugName( texUav_, "tex UAV" );
		//}

		//octahedronTex_.Initialize( dxDevice, texSize, texSize, 1, DXGI_FORMAT_R32G32B32A32_FLOAT, GetMipMapCountFromDimesions( texSize, texSize, texSize ), 1, false, nullptr, true );
		RecreateTexture();

		pickBuffer_.Initialize( dxDevice, 1, nullptr, false, true, true, false );

		for ( uint i = 0; i < NumColorPick; ++i )
		{
			ColorPick &cp = colorPickQueue[i];
			cp.r = cp.g = cp.b = cp.a = 0;
			cp.pixelX = cp.pixelY = 0;
		}

		return true;
	}

	void SettingsTestApp::RecreateTexture()
	{
		ID3D11Device* dxDevice = dx11_->getDevice();

		const uint baseTextureSize = 16;

		octahedronTex_.DeInitialize();
		cubeMapTex_.DeInitialize();
		octahedronCompressedTex_.DeInitialize();
		octahedronCompressTempTex_.DeInitialize();
		dualParaboloidTex_.DeInitialize();
		dualParaboloidCompressedTex_.DeInitialize();
		dualParaboloidCompressTempTex_.DeInitialize();

		spad::clear_cont( srvMipsCubeMapAsArray_, [&]( ID3D11ShaderResourceView* h ) { h->Release(); } );
		spad::clear_cont( srvMipsSrcCubeMapUnfilteredAsArray_, [&]( ID3D11ShaderResourceView* h ) { h->Release(); } );
		spad::clear_cont( uavMipsCubeMapAsArray_, [&]( ID3D11UnorderedAccessView* h ) { h->Release(); } );

		uint texSize = baseTextureSize << textureSize_;
		//if ( textureSize_ == TextureSize_128 )
		//	texSize = 192;

		uint mipCount = std::min( GetMipMapCountFromDimesions( texSize, texSize, texSize ), 8U );
		octahedronTex_.Initialize( dxDevice, texSize, texSize, 1, DXGI_FORMAT_R32G32B32A32_FLOAT, mipCount, 1, false, nullptr, true );
		cubeMapTex_.Initialize( dxDevice, 128, 128, 1, DXGI_FORMAT_R32G32B32A32_FLOAT, 6, 6, true, nullptr, true );
		octahedronCompressedTex_.Initialize( dxDevice, texSize, texSize, 1, DXGI_FORMAT_BC6H_UF16, mipCount, 1, false, nullptr, false );
		octahedronCompressTempTex_.Initialize( dxDevice, texSize / 4, texSize / 4, 1, DXGI_FORMAT_R32G32B32A32_UINT, mipCount - 2, 1, false, nullptr, true );

		dualParaboloidTex_.Initialize( dxDevice, texSize * dualParaboloidWidthScale, texSize, 1, DXGI_FORMAT_R32G32B32A32_FLOAT, mipCount, 1, false, nullptr, true );
		dualParaboloidCompressedTex_.Initialize( dxDevice, texSize * dualParaboloidWidthScale, texSize, 1, DXGI_FORMAT_BC6H_UF16, mipCount, 1, false, nullptr, false );
		dualParaboloidCompressTempTex_.Initialize( dxDevice, (texSize * dualParaboloidWidthScale ) / 4, texSize / 4, 1, DXGI_FORMAT_R32G32B32A32_UINT, mipCount - 2, 1, false, nullptr, true );

		{
			ID3D11Resource *cubeMap;
			srcCubeMapUnfilteredSrv_->GetResource( &cubeMap );
			ID3D11Texture2D *cubeMapTex;
			HRESULT hr = cubeMap->QueryInterface( IID_ID3D11Texture2D, (void **)&cubeMapTex );
			assert( hr == S_OK );
			D3D11_TEXTURE2D_DESC cubeMapDesc;
			cubeMapTex->GetDesc( &cubeMapDesc );
			cubeMapTex->Release();

			srvMipsSrcCubeMapUnfilteredAsArray_.resize( cubeMapDesc.MipLevels );
			//uavMipsSrcCubeMapUnfilteredAsArray_.resize( cubeMapDesc.MipLevels );

			uint w = cubeMapDesc.Width;

			for ( uint iMip = 0; iMip < cubeMapDesc.MipLevels; ++iMip )
			{
				{
					D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc;
					ZeroMemory( &srvDesc, sizeof( srvDesc ) );
					srvDesc.Format = cubeMapDesc.Format;

					srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2DARRAY;
					srvDesc.Texture2DArray.ArraySize = cubeMapDesc.ArraySize;
					srvDesc.Texture2DArray.FirstArraySlice = 0;
					srvDesc.Texture2DArray.MipLevels = 1;
					srvDesc.Texture2DArray.MostDetailedMip = iMip;

					ID3D11ShaderResourceView* srView;
					DXCall( dxDevice->CreateShaderResourceView( cubeMap, &srvDesc, &srView ) );
					debug::Dx11SetDebugName3( srView, "CodeTexture %s, SRV(mip %u)", "src cube map unfiltered", iMip );
					srvMipsSrcCubeMapUnfilteredAsArray_[iMip] = srView;
				}

				//{
				//	D3D11_UNORDERED_ACCESS_VIEW_DESC uavDesc;
				//	ZeroMemory( &uavDesc, sizeof( uavDesc ) );
				//	uavDesc.Format = cubeMapDesc.Format;
				//	uavDesc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2DARRAY;
				//	uavDesc.Texture2DArray.ArraySize = cubeMapDesc.ArraySize;
				//	uavDesc.Texture2DArray.FirstArraySlice = 0;
				//	uavDesc.Texture2DArray.MipSlice = iMip;

				//	ID3D11UnorderedAccessView *uaView;
				//	DXCall( dxDevice->CreateUnorderedAccessView( cubeMap, &uavDesc, &uaView ) );
				//	debug::Dx11SetDebugName3( uaView, "CodeTexture %s, UAV(mip %u)", "src cube map unfiltered", iMip );
				//	uavMipsSrcCubeMapUnfilteredAsArray_[iMip] = uaView;
				//}

				w /= 2;
			}

			cubeMap->Release();
		}

		{
			srvMipsCubeMapAsArray_.resize( cubeMapTex_.numMipLevels_ );
			uavMipsCubeMapAsArray_.resize( cubeMapTex_.numMipLevels_ );

			uint w = cubeMapTex_.width_;

			for ( uint iMip = 0; iMip < cubeMapTex_.numMipLevels_; ++iMip )
			{
				{
					D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc;
					ZeroMemory( &srvDesc, sizeof( srvDesc ) );
					srvDesc.Format = cubeMapTex_.format_;

					srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2DARRAY;
					srvDesc.Texture2DArray.ArraySize = cubeMapTex_.arraySize_;
					srvDesc.Texture2DArray.FirstArraySlice = 0;
					srvDesc.Texture2DArray.MipLevels = 1;
					srvDesc.Texture2DArray.MostDetailedMip = iMip;

					ID3D11ShaderResourceView* srView;
					DXCall( dxDevice->CreateShaderResourceView( cubeMapTex_.texture_, &srvDesc, &srView ) );
					debug::Dx11SetDebugName3( srView, "CodeTexture %s, SRV(mip %u)", "cubeMapTex_ temp", iMip );
					srvMipsCubeMapAsArray_[iMip] = srView;
				}

				{
					D3D11_UNORDERED_ACCESS_VIEW_DESC uavDesc;
					ZeroMemory( &uavDesc, sizeof( uavDesc ) );
					uavDesc.Format = cubeMapTex_.format_;
					uavDesc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2DARRAY;
					uavDesc.Texture2DArray.ArraySize = cubeMapTex_.arraySize_;
					uavDesc.Texture2DArray.FirstArraySlice = 0;
					uavDesc.Texture2DArray.MipSlice = iMip;

					ID3D11UnorderedAccessView *uaView;
					DXCall( dxDevice->CreateUnorderedAccessView( cubeMapTex_.texture_, &uavDesc, &uaView ) );
					debug::Dx11SetDebugName3( uaView, "CodeTexture %s, UAV(mip %u)", "cubeMapTex_ temp", iMip );
					uavMipsCubeMapAsArray_[iMip] = uaView;
				}

				w /= 2;
			}
		}

		uint cubeMapSize = 0;
		uint cubeMapSize128 = 0;
		uint octahedronSize = 0;
		uint w = texSize;
		uint w128 = 128;
		for ( uint mip = 0; mip < 6; ++mip )
		{
			cubeMapSize += w * w * 6; // BC6, 1 byte per pixel
			cubeMapSize128 += w128 * w128 * 6;
			octahedronSize += w * w;

			w /= 2;
			w128 /= 2;
		}

		std::cout << "CubeMap size:       " << cubeMapSize / 1024 << " [kB]" << std::endl;
		std::cout << "CubeMap size (128): " << cubeMapSize128 / 1024 << " [kB]" << std::endl;
		std::cout << "Octahedron size:    " << octahedronSize / 1024 << " [kB]" << std::endl;
	}

	void SettingsTestApp::ShutDown()
	{
		//DX_SAFE_RELEASE( texUav_ );
		//DX_SAFE_RELEASE( texSrv_ );
		//DX_SAFE_RELEASE( tex_ );
		octahedronTex_.DeInitialize();
		pickBuffer_.DeInitialize();
		cubeMapTex_.DeInitialize();
		octahedronCompressedTex_.DeInitialize();
		octahedronCompressTempTex_.DeInitialize();
		dualParaboloidTex_.DeInitialize();
		dualParaboloidCompressedTex_.DeInitialize();
		dualParaboloidCompressTempTex_.DeInitialize();

		spad::clear_cont( srvMipsCubeMapAsArray_, [&]( ID3D11ShaderResourceView* h ) { h->Release(); } );
		spad::clear_cont( srvMipsSrcCubeMapUnfilteredAsArray_, [&]( ID3D11ShaderResourceView* h ) { h->Release(); } );
		spad::clear_cont( uavMipsCubeMapAsArray_, [&]( ID3D11UnorderedAccessView* h ) { h->Release(); } );
	}

	void SettingsTestApp::UpdateCamera( const Timer& timer )
	{
		const float dt = timer.getDeltaSeconds();

		Matrix4 world = inverse( viewMatrixForCamera_ );
		AppBase::UpdateCameraOrbit( world, cameraDistance_, dt * 1.0f );
		viewMatrixForCamera_ = inverse( world );
	}

	void SettingsTestApp::KeyPressed( uint key, bool shift, bool alt, bool ctrl )
	{
		(void)shift;
		(void)alt;
		(void)ctrl;

		if ( key == 'R' || key == 'r' )
		{
			shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\octahedron.hlslc_packed" );
			compressionShader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\block_compression.hlslc_packed" );
		}
	}

	void SettingsTestApp::MousePressed( uint /*mouseX*/, uint /*mouseY*/ )
	{
		pickColor_ = true;
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
		immediateContext->ClearDepthStencilView( mainDS_.dsv_, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 1, 0 );
		//immediateContext->ClearDepthStencilView( mainDS_.dsv_, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 0, 0 );

		immediateContext->RSSetState( RasterizerStates::BackFaceCull() );
		//immediateContext->OMSetDepthStencilState( DepthStencilStates::DepthWriteEnabled(), 0 );
		immediateContext->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );
		//immediateContext->OMSetDepthStencilState( DepthStencilStates::ReverseDepthWriteEnabled(), 0 );

		immediateContextWrapper.BindGlobalSamplers();

		UpdateCamera( timer );

		float mousePosX01 = mouseXContinous_ / (float)dx11_->getBackBufferWidth();
		float mousePosY01 = mouseYContinous_ / (float)dx11_->getBackBufferHeight();

		uint texSize = octahedronTex_.width_;

		{
			uint w = texSize;
			for ( uint i = 0; i < (uint)floorf( sampleMipLevel_ ) && w > 1; ++i )
			{
				w /= 2;
			}

			mousePixelPosX_ = static_cast<int>( w * mousePosX01 );
			mousePixelPosY_ = static_cast<int>( w * mousePosY01 );
		}

		uint borderWidth;
		if ( octahedronSeamMode_ == OctahedronSeam_PullFixup || octahedronSeamMode_ == OctahedronSeam_None )
		{
			borderWidth = 0;
		}
		else if ( octahedronSeamMode_ == OctahedronSeam_Thinborder )
		{
			borderWidth = 4;
		}
		else
		{
			borderWidth = borderWidth_;
		}

		const float aspect = (float)dx11_->getBackBufferWidth() / (float)dx11_->getBackBufferHeight();
		projMatrixForCamera_ = perspectiveProjectionDxStyle( deg2rad( 60.0f ), aspect, 1.0f, decalVolumeFarPlane_ );
		//projMatrixForCamera_ = InfinitePerspectiveMatrix2( deg2rad( 60.0f ), aspect, 4.0f );

		Matrix4 cameraWorld = inverse( viewMatrixForCamera_ );

		Vector4 tanHalfFov;
		tanHalfFov.setX( floatInVec( 1.0f ) / projMatrixForCamera_.getElem( 0, 0 ) );
		tanHalfFov.setY( floatInVec( 1.0f ) / projMatrixForCamera_.getElem( 1, 1 ) );
		tanHalfFov.setZ( projMatrixForCamera_.getElem( 0, 0 ) );
		tanHalfFov.setW( projMatrixForCamera_.getElem( 1, 1 ) );

		octahedronConstants_.data.borderWidth[1] = static_cast<float>( octahedronSeamMode_ );
		octahedronConstants_.data.eyeOrigin = Vector4( cameraWorld.getTranslation(), floatInVec( 0 ) );
		octahedronConstants_.data.eyeAxisX = cameraWorld.getCol0() * tanHalfFov.getX();
		octahedronConstants_.data.eyeAxisY = cameraWorld.getCol1() * tanHalfFov.getY();
		octahedronConstants_.data.eyeAxisZ = cameraWorld.getCol2();
		octahedronConstants_.data.normalRotation = Matrix4::rotationX( 0.5f * PI );
		octahedronConstants_.data.sampleMipLevel[0] = sampleMipLevel_;
		octahedronConstants_.data.picPosition[0] = mousePosX01;
		octahedronConstants_.data.picPosition[1] = mousePosY01;
		octahedronConstants_.data.manualMipLerp[0] = octahedronSeamMode_ == OctahedronSeam_Thinborder ? 1.0f : 0.0f;
		octahedronConstants_.data.manualMipLerp[1] = static_cast<float>( samplerType_ );
		octahedronConstants_.data.solidAngleMode[0] = solidAngle_ - 1;
		octahedronConstants_.data.solidAngleMode[1] = solidAngleScale_;
		
		octahedronConstants_.updateGpu( immediateContext );
		octahedronConstants_.setVS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );
		octahedronConstants_.setPS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );
		octahedronConstants_.setCS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );

		if ( importanceSampleBoxFilter_ )
		{
			immediateContextWrapper.BeginMarker( "box filter", 0 );

			const HlslShaderPass& pass = *shader_->getPass( "cs_cubemap_box_filter" );
			pass.setCS( immediateContext );

			uint w = cubeMapTex_.width_;
			for ( uint iMip = 0; iMip < cubeMapTex_.numMipLevels_; ++iMip )
			{
				assert( w > 0 );

				if ( iMip == 0 )
				{
					ID3D11ShaderResourceView* srvs[1] = { srvMipsSrcCubeMapUnfilteredAsArray_[iMip] };
					immediateContext->CSSetShaderResources( 2, 1, srvs );
				}
				else
				{
					ID3D11ShaderResourceView* srvs[1] = { srvMipsCubeMapAsArray_[iMip-1] };
					immediateContext->CSSetShaderResources( 2, 1, srvs );
				}

				ID3D11UnorderedAccessView *uavs[1] = { uavMipsCubeMapAsArray_[iMip] };
				UINT initialCounts[1] = { 0 };
				immediateContext->CSSetUnorderedAccessViews( 0, 1, uavs, initialCounts );

				octahedronConstants_.data.texSize[0] = static_cast<float>( w );
				octahedronConstants_.data.texSize[1] = 1.0f / static_cast<float>( w );
				octahedronConstants_.data.texSize[2] = static_cast<float>( iMip );
				octahedronConstants_.data.texSize[3] = iMip == 0 ? 1024.0f : ( w * 2.0f );
				//octahedronConstants_.data.sampleMipLevel[0] = static_cast<float>( iMip );
				octahedronConstants_.updateGpu( immediateContext );
				octahedronConstants_.setCS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );

				uint nGroupsXY = ( w + 8 - 1 ) / 8;

				immediateContext->Dispatch( nGroupsXY, nGroupsXY, 6 );

				immediateContextWrapper.UnbindCSUAV( 0 );

				w /= 2;
			}

			immediateContextWrapper.EndMarker();
		}

		if ( solidAngle_ )
		{
			const HlslShaderPass& pass = *shader_->getPass( "cs_octahedron_solid_angle" );
			pass.setCS( immediateContext );
		}
		else
		{
			//if ( displayMode_ == SphereFacesOctahedron /*|| displayMode_ == OctahedronFacesTexture*/ )
			if ( displayMode_ == DisplayMode_Faces )
			{
				if ( octahedronSeamMode_ == OctahedronSeam_PullFixup )
				{
					const HlslShaderPass& pass = *shader_->getPass( "cs_color_code_faces_pull_fixup" );
					pass.setCS( immediateContext );
				}
				else
				{
					const HlslShaderPass& pass = *shader_->getPass( "cs_color_code_faces" );
					pass.setCS( immediateContext );
				}
			}
			//else if ( displayMode_ == SphereNormalOctahedron /*|| displayMode_ == OctahedronNormalTexture*/ )
			else if ( displayMode_ == DisplayMode_Normal )
			{
				const HlslShaderPass& pass = *shader_->getPass( "cs_octahedron_encode_normal" );
				pass.setCS( immediateContext );
			}
			//else if ( displayMode_ == SceneOctahedron )
			else if ( displayMode_ == DisplayMode_Scene )
			{
				if ( importanceSample_ )
				{
					const HlslShaderPass& pass = *shader_->getPass( "cs_octahedron_importance_sample" );
					pass.setCS( immediateContext );

					if ( importanceSampleBoxFilter_ )
					{
						ID3D11ShaderResourceView* srvs[1] = { cubeMapTex_.srv_ };
						immediateContext->CSSetShaderResources( 1, 1, srvs );
					}
					else
					{
						ID3D11ShaderResourceView* srvs[1] = { srcCubeMapUnfilteredSrv_ };
						immediateContext->CSSetShaderResources( 1, 1, srvs );
						//immediateContext->CSSetSamplers( REGISTER_SAMPLER_CUBE_MAP_SAMPLER, 1, &SamplerStates::linear );
					}
				}
				else
				{
					if ( octahedronSeamMode_ == OctahedronSeam_PullFixup )
					{
						const HlslShaderPass& pass = *shader_->getPass( "cs_octahedron_encode_scene_pull_fixup" );
						pass.setCS( immediateContext );
					}
					else
					{
						const HlslShaderPass& pass = *shader_->getPass( "cs_octahedron_encode_scene" );
						pass.setCS( immediateContext );
					}

					if ( importanceSampleBoxFilter_ )
					{
						ID3D11ShaderResourceView* srvs[1] = { cubeMapTex_.srv_ };
						immediateContext->CSSetShaderResources( 1, 1, srvs );
					}
					else
					{
						ID3D11ShaderResourceView* srvs[1] = { srcCubeMapSrv_ };
						immediateContext->CSSetShaderResources( 1, 1, srvs );
						//immediateContext->CSSetSamplers( REGISTER_SAMPLER_CUBE_MAP_SAMPLER, 1, &SamplerStates::linear );
					}
				}
			}
		}

		if ( parametrization_ == Parametrization_DualParaboloid )
		{
			immediateContextWrapper.BeginMarker( "create dual paraboloidal", 0 );

			if ( importanceSample_ )
			{
				const HlslShaderPass& pass = *shader_->getPass( "cs_dual_paraboloid_importance_sample" );
				pass.setCS( immediateContext );

				if ( importanceSampleBoxFilter_ )
				{
					ID3D11ShaderResourceView* srvs[1] = { cubeMapTex_.srv_ };
						immediateContext->CSSetShaderResources( 1, 1, srvs );
				}
				else
				{
					ID3D11ShaderResourceView* srvs[1] = { srcCubeMapUnfilteredSrv_ };
					immediateContext->CSSetShaderResources( 1, 1, srvs );
				}
			}
			else
			{
				const HlslShaderPass& pass = *shader_->getPass( "cs_dual_paraboloid_sample" );
				pass.setCS( immediateContext );

				if ( importanceSampleBoxFilter_ )
				{
					ID3D11ShaderResourceView* srvs[1] = { cubeMapTex_.srv_ };
					immediateContext->CSSetShaderResources( 1, 1, srvs );
				}
				else
				{
					ID3D11ShaderResourceView* srvs[1] = { srcCubeMapSrv_ };
					immediateContext->CSSetShaderResources( 1, 1, srvs );
				}
			}

			uint w = texSize;
			uint borderW = borderWidth;
			for ( uint iMip = 0; iMip < octahedronTex_.numMipLevels_; ++iMip )
			{
				assert( w > 0 );

				octahedronConstants_.data.texSize[0] = static_cast<float>( w );
				octahedronConstants_.data.texSize[1] = 1.0f / static_cast<float>( w );
				octahedronConstants_.data.texSize[2] = static_cast<float>( iMip );
				octahedronConstants_.data.borderWidth[0] = static_cast<float>( borderW );
				octahedronConstants_.data.cbSpecularGloss[0] = GlossFromMiplevel( iMip );
				octahedronConstants_.updateGpu( immediateContext );
				octahedronConstants_.setCS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );

				ID3D11UnorderedAccessView *uavs[1] = { dualParaboloidTex_.GetUAV( 0, iMip ) };
				UINT initialCounts[1] = { 0 };
				immediateContext->CSSetUnorderedAccessViews( 0, 1, uavs, initialCounts );

				uint nGroupsX = ( w * dualParaboloidWidthScale + 8 - 1 ) / 8;
				uint nGroupsY = ( w + 8 - 1 ) / 8;

				immediateContext->Dispatch( nGroupsX, nGroupsY, 1 );

				immediateContextWrapper.UnbindCSUAV( 0 );

				w /= 2;
				if ( octahedronSeamMode_ == OctahedronSeam_Wideborder )
				{
					borderW /= 2;
				}
				else if ( octahedronSeamMode_ == OctahedronSeam_Thinborder )
				{
					if ( iMip >= 3 )
					{
						borderW /= 2;
					}
				}
			}

			immediateContextWrapper.EndMarker();

		}
		else if ( displayOctahedron_ )
		{
			immediateContextWrapper.BeginMarker( "create octahedron", 0 );

			uint w = texSize;
			uint borderW = borderWidth;
			for ( uint iMip = 0; iMip < octahedronTex_.numMipLevels_; ++iMip )
			{
				assert( w > 0 );

				octahedronConstants_.data.texSize[0] = static_cast<float>( w );
				octahedronConstants_.data.texSize[1] = 1.0f / static_cast<float>( w );
				octahedronConstants_.data.texSize[2] = static_cast<float>( iMip );
				octahedronConstants_.data.borderWidth[0] = static_cast<float>( borderW );
				octahedronConstants_.data.cbSpecularGloss[0] = GlossFromMiplevel( iMip );
				octahedronConstants_.updateGpu( immediateContext );
				octahedronConstants_.setCS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );

				ID3D11UnorderedAccessView *uavs[1] = { octahedronTex_.GetUAV( 0, iMip ) };
				UINT initialCounts[1] = { 0 };
				immediateContext->CSSetUnorderedAccessViews( 0, 1, uavs, initialCounts );

				uint nGroupsXY = ( w + 8 - 1 ) / 8;

				immediateContext->Dispatch( nGroupsXY, nGroupsXY, 1 );

				immediateContextWrapper.UnbindCSUAV( 0 );

				w /= 2;
				if ( octahedronSeamMode_ == OctahedronSeam_Wideborder )
				{
					borderW /= 2;
				}
				else if ( octahedronSeamMode_ == OctahedronSeam_Thinborder )
				{
					if ( iMip >= 3 )
					{
						borderW /= 2;
					}
				}
			}

			immediateContextWrapper.EndMarker();
		}

		if ( enableCompression_ )
		{
			immediateContextWrapper.BeginMarker( "compression", 0 );

			const HlslShaderPass& pass = *compressionShader_->getPass( "cs_bc6_compress_array_hq" );
			pass.setCS( immediateContext );

			if ( parametrization_ == Parametrization_DualParaboloid )
			{
				uint w = texSize;
				for ( uint iMip = 0; iMip < dualParaboloidCompressTempTex_.numMipLevels_; ++iMip )
				{
					ID3D11ShaderResourceView* srvs[1] = { dualParaboloidTex_.GetSRV( 0, iMip ) };
					immediateContext->CSSetShaderResources( RC_REGISTER_UNCOMPRESSED_TEXTURE, 1, srvs );

					ID3D11UnorderedAccessView *uavs[1] = { dualParaboloidCompressTempTex_.GetUAV( 0, iMip ) };
					UINT initialCounts[1] = { 0 };
					immediateContext->CSSetUnorderedAccessViews( RC_REGISTER_MIP_OUTPUT, 1, uavs, initialCounts );

					uint nGroupsX = ( w * dualParaboloidWidthScale + COMPRESS_ONE_MIP_THREADGROUP_WIDTH - 1 ) / COMPRESS_ONE_MIP_THREADGROUP_WIDTH;
					uint nGroupsY = ( w + COMPRESS_ONE_MIP_THREADGROUP_WIDTH - 1 ) / COMPRESS_ONE_MIP_THREADGROUP_WIDTH;

					immediateContext->Dispatch( nGroupsX, nGroupsY, 1 );

					immediateContextWrapper.UnbindCSUAV( 0 );

					w /= 2;
				}

				for ( uint iMip = 0; iMip < dualParaboloidCompressTempTex_.numMipLevels_; ++iMip )
				{
					uint dstSubResourceIndex = D3D11CalcSubresource( iMip, 0, dualParaboloidCompressedTex_.numMipLevels_ );
					uint srcSubResourceIndex = D3D11CalcSubresource( iMip, 0, dualParaboloidCompressTempTex_.numMipLevels_ );

					immediateContext->CopySubresourceRegion( dualParaboloidCompressedTex_.texture_, dstSubResourceIndex, 0, 0, 0, dualParaboloidCompressTempTex_.texture_, srcSubResourceIndex, nullptr );
				}
			}
			else
			{
				uint w = texSize;
				for ( uint iMip = 0; iMip < octahedronCompressTempTex_.numMipLevels_; ++iMip )
				{
					//assert( w > 0 );

					//compressionConstants_.data.g_oneOverTextureWidth = 1.0f / w;
					//compressionConstants_.data.arraySlice = 0;
					//compressionConstants_.updateGpu( immediateContext );
					//compressionConstants_.setCS( immediateContext, RC_REGISTER_CONSTANTS );

					ID3D11ShaderResourceView* srvs[1] = { octahedronTex_.GetSRV( 0, iMip ) };
					immediateContext->CSSetShaderResources( RC_REGISTER_UNCOMPRESSED_TEXTURE, 1, srvs );

					ID3D11UnorderedAccessView *uavs[1] = { octahedronCompressTempTex_.GetUAV( 0, iMip ) };
					UINT initialCounts[1] = { 0 };
					immediateContext->CSSetUnorderedAccessViews( RC_REGISTER_MIP_OUTPUT, 1, uavs, initialCounts );

					uint nGroupsXY = ( w + COMPRESS_ONE_MIP_THREADGROUP_WIDTH - 1 ) / COMPRESS_ONE_MIP_THREADGROUP_WIDTH;

					immediateContext->Dispatch( nGroupsXY, nGroupsXY, 1 );

					immediateContextWrapper.UnbindCSUAV( 0 );

					w /= 2;
				}

				for ( uint iMip = 0; iMip < octahedronCompressTempTex_.numMipLevels_; ++iMip )
				{
					uint dstSubResourceIndex = D3D11CalcSubresource( iMip, 0, octahedronCompressedTex_.numMipLevels_ );
					uint srcSubResourceIndex = D3D11CalcSubresource( iMip, 0, octahedronCompressTempTex_.numMipLevels_ );

					immediateContext->CopySubresourceRegion( octahedronCompressedTex_.texture_, dstSubResourceIndex, 0, 0, 0, octahedronCompressTempTex_.texture_, srcSubResourceIndex, nullptr );
				}
			}

			immediateContextWrapper.EndMarker();
		}

		octahedronConstants_.data.texSize[0] = static_cast<float>( texSize );
		octahedronConstants_.data.texSize[1] = 1.0f / static_cast<float>( texSize );
		octahedronConstants_.data.texSize[2] = static_cast<float>( 0 );
		octahedronConstants_.data.borderWidth[0] = static_cast<float>( borderWidth );
		octahedronConstants_.data.sampleMipLevel[0] = sampleMipLevel_;
		octahedronConstants_.updateGpu( immediateContext );
		octahedronConstants_.setVS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );
		octahedronConstants_.setPS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );
		octahedronConstants_.setCS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );

		//if ( displayMode_ == OctahedronFacesTexture || displayMode_ == OctahedronNormalTexture )
		if ( octahedronOverlay_ )
		{
			if ( parametrization_ == Parametrization_DualParaboloid )
			{
				const HlslShaderPass& fxPass = *shader_->getPass( "draw_dual_paraboloidal_map" );
				fxPass.setVS( immediateContext );
				fxPass.setPS( immediateContext );

				immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP );
				immediateContext->IASetInputLayout( nullptr );

				ID3D11ShaderResourceView* srvs[1] = { GetDualParaboloidSRV() };
				immediateContext->PSSetShaderResources( 0, 1, srvs );

				immediateContext->Draw( 4, 0 );
			}
			else
			{
				const HlslShaderPass& fxPass = *shader_->getPass( "draw_texture" );
				fxPass.setVS( immediateContext );
				fxPass.setPS( immediateContext );

				immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
				immediateContext->IASetInputLayout( nullptr );

				ID3D11ShaderResourceView* srvs[1] = { GetOctahedronSRV() };
				immediateContext->PSSetShaderResources( 0, 1, srvs );

				immediateContext->Draw( 3, 0 );
			}
		}
		//else if ( displayMode_ == SphereNormalOctahedron || displayMode_ == SphereFacesOctahedron || displayMode_ == SceneOctahedron )
		else if ( displayMode_ == DisplayMode_Faces || displayOctahedron_ )
		{
			if ( parametrization_ == Parametrization_DualParaboloid )
			{
				{
					const HlslShaderPass& fxPass = *shader_->getPass( "draw_sphere_dual_paraboloid" );
					fxPass.setVS( immediateContext );
					fxPass.setPS( immediateContext );

					immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
					immediateContext->IASetInputLayout( nullptr );

					ID3D11ShaderResourceView* srvs[2] = { GetDualParaboloidSRV(), srcCubeMapSrv_ };
					immediateContext->PSSetShaderResources( 0, 2, srvs );

					immediateContext->Draw( 3, 0 );
				}

				{
					const HlslShaderPass& fxPass = *shader_->getPass( "draw_texture_preview_dual_paraboloid" );
					fxPass.setVS( immediateContext );
					fxPass.setPS( immediateContext );

					immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP );
					immediateContext->Draw( 4, 0 );
				}
			}
			else
			{
				{
					const HlslShaderPass& fxPass = *shader_->getPass( "draw_sphere_octahedron" );
					fxPass.setVS( immediateContext );
					fxPass.setPS( immediateContext );

					immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
					immediateContext->IASetInputLayout( nullptr );

					ID3D11ShaderResourceView* srvs[2] = { GetOctahedronSRV(), srcCubeMapSrv_ };
					immediateContext->PSSetShaderResources( 0, 2, srvs );

					//immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::linearClamp );
					//immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::point );
					//immediateContext->PSSetSamplers( REGISTER_SAMPLER_CUBE_MAP_SAMPLER, 1, &SamplerStates::linearClamp );

					immediateContext->Draw( 3, 0 );
				}

				{
					const HlslShaderPass& fxPass = *shader_->getPass( "draw_texture_preview" );
					fxPass.setVS( immediateContext );
					fxPass.setPS( immediateContext );

					//immediateContext->PSSetSamplers( REGISTER_SAMPLER_CUBE_MAP_SAMPLER, 1, &SamplerStates::linear );

					immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP );
					immediateContext->Draw( 4, 0 );
				}
			}
		}
		//else if ( displayMode_ == SphereNormal || displayMode_ == SceneCubemap )
		else if ( displayMode_ == DisplayMode_Normal || displayMode_ == DisplayMode_Scene )
		{
			if ( displayMode_ == DisplayMode_Normal )
			{
				const HlslShaderPass& fxPass = *shader_->getPass( "draw_sphere_normal" );
				fxPass.setVS( immediateContext );
				fxPass.setPS( immediateContext );
			}
			else if ( displayMode_ == DisplayMode_Scene )
			{
				const HlslShaderPass& fxPass = *shader_->getPass( "draw_sphere_color_cube" );
				fxPass.setVS( immediateContext );
				fxPass.setPS( immediateContext );
			}

			immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
			immediateContext->IASetInputLayout( nullptr );

			ID3D11ShaderResourceView* srvs[2] = { GetOctahedronSRV(), srcCubeMapSrv_ };
			immediateContext->PSSetShaderResources( 0, 2, srvs );

			//immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::linear );
			//immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::point );
			//immediateContext->PSSetSamplers( REGISTER_SAMPLER_CUBE_MAP_SAMPLER, 1, &SamplerStates::linear );

			immediateContext->Draw( 3, 0 );
		}

		//if ( displayMode_ == SphereNormal || displayMode_ == SphereNormalOctahedron || displayMode_ == SphereFacesOctahedron || displayMode_ == SceneCubemap || displayMode_ == SceneOctahedron )
		if ( !octahedronOverlay_ )
		{
			// sphere is raytrayced so won't occlude debug draw
			Vector4 plane( 0, 1, 0, 0 );
			//debugDraw::AddPlaneWS( plane, 6, 6, 6, 6, 0xff0000ff, 1, true );
			debugDraw::AddAxes( Vector3( 0.0f ), Vector3( 10.0f ), Matrix3::identity(), 1.0f, 1.0f, false );

			debugDraw::DontTouchThis::Draw( immediateContextWrapper, viewMatrixForCamera_, projMatrixForCamera_, dx11_->getBackBufferWidth(), dx11_->getBackBufferHeight() );
			debugDraw::DontTouchThis::Clear();
		}

		if ( pickColor_ )
		{
			pickColor_ = false;

			//if ( displayMode_ == OctahedronFacesTexture || displayMode_ == OctahedronNormalTexture )
			if ( octahedronOverlay_ )
			{
				const HlslShaderPass& pass = *shader_->getPass( "cs_pick_texel" );
				pass.setCS( immediateContext );

				octahedronConstants_.setCS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );

				ID3D11ShaderResourceView* srvs[1] = { GetOctahedronSRV() };
				immediateContext->CSSetShaderResources( 0, 1, srvs );

				//immediateContext->CSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::point );

				ID3D11UnorderedAccessView *uavs[1] = { pickBuffer_.getUAV() };
				UINT initialCounts[1] = { 0 };
				immediateContext->CSSetUnorderedAccessViews( 0, 1, uavs, initialCounts );

				immediateContext->Dispatch( 1, 1, 1 );

				immediateContextWrapper.UnbindCSUAV( 0 );

				const float4 *colors = pickBuffer_.CPUReadbackStart( immediateContext );
				ColorPick &cp = colorPickQueue[pickColorIndex_];
				cp.r = colors[0][0];
				cp.g = colors[0][1];
				cp.b = colors[0][2];
				cp.a = colors[0][3];
				cp.pixelX = mousePixelPosX_;
				cp.pixelY = mousePixelPosY_;

				pickBuffer_.CPUReadbackEnd( immediateContext );

				pickColorIndex_ = ( pickColorIndex_ + 1 ) % NumColorPick;
			}
		}
	}

	void SettingsTestApp::UpdateImGui( const Timer& /*timer*/ )
	{
		Vector3 cameraPos = inverse( viewMatrixForCamera_ ).getTranslation();
		//ImGui::Text( "Camera pos [%3.3f %3.3f %3.3f]", cameraPos.getX().getAsFloat(), cameraPos.getY().getAsFloat(), cameraPos.getZ().getAsFloat() );

		ImGui::Text( "Pixel pos [%4u %4u]", mousePixelPosX_, mousePixelPosY_ );

		{
			const char* items[TextureSize_Count] = { "16", "32", "64", "128", "256", "512" };
			if ( ImGui::Combo( "Texture Size", reinterpret_cast<int*>( &textureSize_ ), items, IM_ARRAYSIZE( items ) ) )
			{
				RecreateTexture();
			}
		}

		{
			ImGui::RadioButton( "Octahedron", reinterpret_cast<int*>( &parametrization_ ), DisplayMode_Faces ); ImGui::SameLine();
			ImGui::RadioButton( "Dual Paraboloidal", reinterpret_cast<int*>( &parametrization_ ), DisplayMode_Normal );
		}

		{
			//const char* items[DisplayModeCount] = { "Sphere Normal", "Sphere Normal Octahedron", "Sphere Faces Octahedron", "Scene Cubemap", "Scene Octahedron" };
			//ImGui::Combo( "Display Mode", reinterpret_cast<int*>( &displayMode_ ), items, IM_ARRAYSIZE( items ) );

			ImGui::RadioButton( "Faces", reinterpret_cast<int*>( &displayMode_ ), DisplayMode_Faces ); ImGui::SameLine();
			ImGui::RadioButton( "Normal", reinterpret_cast<int*>( &displayMode_ ), DisplayMode_Normal ); ImGui::SameLine();
			ImGui::RadioButton( "Scene", reinterpret_cast<int*>( &displayMode_ ), DisplayMode_Scene );
		}
		
		{
			//const char* items[DisplayModeCount] = { "Sphere Normal", "Sphere Normal Octahedron", "Sphere Faces Octahedron", "Scene Cubemap", "Scene Octahedron" };
			//ImGui::Combo( "Display Mode", reinterpret_cast<int*>( &displayMode_ ), items, IM_ARRAYSIZE( items ) );

			ImGui::RadioButton( "None", reinterpret_cast<int*>( &octahedronSeamMode_ ), OctahedronSeam_None ); ImGui::SameLine();
			ImGui::RadioButton( "Wide border", reinterpret_cast<int*>( &octahedronSeamMode_ ), OctahedronSeam_Wideborder ); ImGui::SameLine();
			ImGui::RadioButton( "Thin border", reinterpret_cast<int*>( &octahedronSeamMode_ ), OctahedronSeam_Thinborder ); ImGui::SameLine();
			ImGui::RadioButton( "Pull fixup", reinterpret_cast<int*>( &octahedronSeamMode_ ),  OctahedronSeam_PullFixup );
		}

		{
			ImGui::Checkbox( "Display Octahedron", &displayOctahedron_ );
		}

		{
			ImGui::Checkbox( "Importance Sample Scene", &importanceSample_ );
		}

		{
			ImGui::Checkbox( "Importance Sample Box Filter", &importanceSampleBoxFilter_ );
		}

		{
			ImGui::Checkbox( "Octahedron Overlay", &octahedronOverlay_ );
		}

		{
			//ImGui::Checkbox( "Point Sampler", &pointSampler_ );
			ImGui::RadioButton( "Linear", reinterpret_cast<int*>( &samplerType_ ), Sampler_Linear ); ImGui::SameLine();
			ImGui::RadioButton( "Point", reinterpret_cast<int*>( &samplerType_ ), Sampler_Point ); ImGui::SameLine();
			ImGui::RadioButton( "Bicubic", reinterpret_cast<int*>( &samplerType_ ), Sampler_Bicubic );
		}

		{
			ImGui::Checkbox( "Enable BC6 Compression", &enableCompression_ );
		}

		{
			if ( ImGui::SliderFloat( "Sample mip level", &sampleMipLevel_, 0.0f, 5.0f ) )
			{
				sampleMipLevelInt_ = static_cast<int>( floorf( sampleMipLevel_ ) );
			}

			if ( ImGui::SliderInt( "Sample mip level int", &sampleMipLevelInt_, 0, 5 ) )
			{
				sampleMipLevel_ = static_cast<float>( sampleMipLevelInt_ );
			}
		}

		{
			ImGui::SliderInt( "Border width", &borderWidth_, 0, 64 );
		}
		{
			ImGui::RadioButton( "SA None", reinterpret_cast<int*>( &solidAngle_ ), SolidAngle_None ); ImGui::SameLine();
			ImGui::RadioButton( "SA CubeMap", reinterpret_cast<int*>( &solidAngle_ ), SolidAngle_CubeMap ); ImGui::SameLine();
			ImGui::RadioButton( "SA Octahedron", reinterpret_cast<int*>( &solidAngle_ ), SolidAngle_Octahedron ); ImGui::SameLine();
			ImGui::RadioButton( "SA Diff", reinterpret_cast<int*>( &solidAngle_ ), SolidAngle_Diff );
		}
		{
			ImGui::SliderInt( "SA Scale", &solidAngleScale_, 1, 100 );
		}
		{
			if ( ImGui::Button( "Clear color queue" ) )
			{
				for ( uint i = 0; i < NumColorPick; ++i )
				{
					ColorPick &cp = colorPickQueue[i];
					cp.r = cp.g = cp.b = cp.a = 0;
					cp.pixelX = cp.pixelY = 0;
				}

				pickColorIndex_ = 0;
			}

			for ( uint i = 0; i < NumColorPick; ++i )
			{
				const ColorPick &cp = colorPickQueue[i];

				ImGui::Text( "Color %u at [%4u, %4u]: %5.3f, %5.3f, %5.3f, %5.3f", i, cp.pixelX, cp.pixelY, cp.r, cp.g, cp.b, cp.a );
			}
		}
	}
}
