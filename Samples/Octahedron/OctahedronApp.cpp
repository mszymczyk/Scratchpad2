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

		ID3D11Device* dxDevice = dx11_->getDevice();

		mainDS_.Initialize( dxDevice, dx11_->getBackBufferWidth(), dx11_->getBackBufferHeight(), 1, DXGI_FORMAT_D24_UNORM_S8_UINT, 1, 0, true );

		shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\Octahedron.hlslc_packed" );

		cubeMapSrv_ = LoadTexture( dxDevice, "Assets\\refl_probe.dds" );
		ID3D11Resource *cubeMap_;
		cubeMapSrv_->GetResource( &cubeMap_ );

		ID3D11Texture2D *cubeMapTex_;
		HRESULT hr = cubeMap_->QueryInterface( IID_ID3D11Texture2D, (void **)&cubeMapTex_ );
		assert( hr == S_OK );
		D3D11_TEXTURE2D_DESC cubeMapDesc;
		cubeMapTex_->GetDesc( &cubeMapDesc );
		cubeMapTex_->Release();
		cubeMap_->Release();

		//passConstants_.Initialize( dx11_->getDevice() );
		//objectConstants_.Initialize( dx11_->getDevice() );
		octahedronConstants_.Initialize( dxDevice );
		//octahedronGenConstants_.Initialize( dxDevice );

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

		uint texSize = baseTextureSize << textureSize_;
		octahedronTex_.Initialize( dxDevice, texSize, texSize, 1, DXGI_FORMAT_R32G32B32A32_FLOAT, GetMipMapCountFromDimesions( texSize, texSize, texSize ), 1, false, nullptr, true );
	}

	void SettingsTestApp::ShutDown()
	{
		//DX_SAFE_RELEASE( texUav_ );
		//DX_SAFE_RELEASE( texSrv_ );
		//DX_SAFE_RELEASE( tex_ );
		octahedronTex_.DeInitialize();
		pickBuffer_.DeInitialize();
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
			shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\Octahedron.hlslc_packed" );
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
		immediateContext->OMSetDepthStencilState( DepthStencilStates::DepthWriteEnabled(), 0 );
		//immediateContext->OMSetDepthStencilState( DepthStencilStates::ReverseDepthWriteEnabled(), 0 );

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

		const float aspect = (float)dx11_->getBackBufferWidth() / (float)dx11_->getBackBufferHeight();
		projMatrixForCamera_ = perspectiveProjectionDxStyle( deg2rad( 60.0f ), aspect, 1.0f, decalVolumeFarPlane_ );
		//projMatrixForCamera_ = InfinitePerspectiveMatrix2( deg2rad( 60.0f ), aspect, 4.0f );

		Matrix4 cameraWorld = inverse( viewMatrixForCamera_ );

		Vector4 tanHalfFov;
		tanHalfFov.setX( floatInVec( 1.0f ) / projMatrixForCamera_.getElem( 0, 0 ) );
		tanHalfFov.setY( floatInVec( 1.0f ) / projMatrixForCamera_.getElem( 1, 1 ) );
		tanHalfFov.setZ( projMatrixForCamera_.getElem( 0, 0 ) );
		tanHalfFov.setW( projMatrixForCamera_.getElem( 1, 1 ) );

		octahedronConstants_.data.eyeOrigin = Vector4( cameraWorld.getTranslation(), floatInVec( 0 ) );
		octahedronConstants_.data.eyeAxisX = cameraWorld.getCol0() * tanHalfFov.getX();
		octahedronConstants_.data.eyeAxisY = cameraWorld.getCol1() * tanHalfFov.getY();
		octahedronConstants_.data.eyeAxisZ = cameraWorld.getCol2();
		octahedronConstants_.data.normalRotation = Matrix4::rotationX( 0.5f * PI );
		octahedronConstants_.data.sampleMipLevel[0] = sampleMipLevel_;
		octahedronConstants_.data.picPosition[0] = mousePosX01;
		octahedronConstants_.data.picPosition[1] = mousePosY01;

		octahedronConstants_.updateGpu( immediateContext );
		octahedronConstants_.setVS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );
		octahedronConstants_.setPS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );
		octahedronConstants_.setCS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );


		if ( displayMode_ == SphereFacesOctahedron /*|| displayMode_ == OctahedronFacesTexture*/ )
		{
			const HlslShaderPass& pass = *shader_->getPass( "cs_color_code_faces" );
			pass.setCS( immediateContext );
		}
		else if ( displayMode_ == SphereNormalOctahedron /*|| displayMode_ == OctahedronNormalTexture*/ )
		{
			const HlslShaderPass& pass = *shader_->getPass( "cs_octahedron_encode_normal" );
			pass.setCS( immediateContext );
		}
		else if ( displayMode_ == SceneOctahedron )
		{
			const HlslShaderPass& pass = *shader_->getPass( "cs_octahedron_encode_scene" );
			pass.setCS( immediateContext );

			ID3D11ShaderResourceView* srvs[1] = { cubeMapSrv_ };
			immediateContext->CSSetShaderResources( 1, 1, srvs );
			immediateContext->CSSetSamplers( REGISTER_SAMPLER_CUBE_MAP_SAMPLER, 1, &SamplerStates::linear );
		}

		if ( displayMode_ == SphereFacesOctahedron /*|| displayMode_ == OctahedronFacesTexture*/ || displayMode_ == SphereNormalOctahedron /*|| displayMode_ == OctahedronNormalTexture*/ || displayMode_ == SceneOctahedron )
		{
			uint w = texSize;
			uint borderW = borderWidth_;
			for ( uint iMip = 0; iMip < octahedronTex_.numMipLevels_; ++iMip )
			{
				assert( w > 0 );

				octahedronConstants_.data.texSize[0] = static_cast<float>( w );
				octahedronConstants_.data.borderWidth[0] = static_cast<float>( borderW );
				octahedronConstants_.updateGpu( immediateContext );
				octahedronConstants_.setCS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );

				ID3D11UnorderedAccessView *uavs[1] = { octahedronTex_.GetUAV( 0, iMip ) };
				UINT initialCounts[1] = { 0 };
				immediateContext->CSSetUnorderedAccessViews( 0, 1, uavs, initialCounts );

				uint nGroupsXY = ( w + 8 - 1 ) / 8;

				immediateContext->Dispatch( nGroupsXY, nGroupsXY, 1 );

				immediateContextWrapper.UnbindCSUAV( 0 );

				w /= 2;
				borderW /= 2;
			}
		}

		octahedronConstants_.data.texSize[0] = static_cast<float>( texSize );
		octahedronConstants_.data.borderWidth[0] = static_cast<float>( borderWidth_ );
		octahedronConstants_.updateGpu( immediateContext );
		octahedronConstants_.setVS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );
		octahedronConstants_.setPS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );
		octahedronConstants_.setCS( immediateContext, REGISTER_CBUFFER_OCTAHEDRON_CONSTANTS );

		//if ( displayMode_ == OctahedronFacesTexture || displayMode_ == OctahedronNormalTexture )
		if ( octahedronOverlay_ )
		{
			const HlslShaderPass& fxPass = *shader_->getPass( "draw_texture" );
			fxPass.setVS( immediateContext );
			fxPass.setPS( immediateContext );

			immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
			immediateContext->IASetInputLayout( nullptr );

			ID3D11ShaderResourceView* srvs[1] = { octahedronTex_.srv_ };
			immediateContext->PSSetShaderResources( 0, 1, srvs );

			immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::linear );
			//immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::point );

			immediateContext->Draw( 3, 0 );
		}
		else if ( displayMode_ == SphereNormal || displayMode_ == SceneCubemap )
		{
			if ( displayMode_ == SphereNormal )
			{
				const HlslShaderPass& fxPass = *shader_->getPass( "draw_sphere_normal" );
				fxPass.setVS( immediateContext );
				fxPass.setPS( immediateContext );
			}
			else if ( displayMode_ == SceneCubemap )
			{
				const HlslShaderPass& fxPass = *shader_->getPass( "draw_sphere_color_cube" );
				fxPass.setVS( immediateContext );
				fxPass.setPS( immediateContext );
			}

			immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
			immediateContext->IASetInputLayout( nullptr );

			ID3D11ShaderResourceView* srvs[2] = { octahedronTex_.srv_, cubeMapSrv_ };
			immediateContext->PSSetShaderResources( 0, 2, srvs );

			//immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::linear );
			immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::point );
			immediateContext->PSSetSamplers( REGISTER_SAMPLER_CUBE_MAP_SAMPLER, 1, &SamplerStates::linear );

			immediateContext->Draw( 3, 0 );
		}
		else if ( displayMode_ == SphereNormalOctahedron || displayMode_ == SphereFacesOctahedron || displayMode_ == SceneOctahedron )
		{
			{
				const HlslShaderPass& fxPass = *shader_->getPass( "draw_sphere_octahedron" );
				fxPass.setVS( immediateContext );
				fxPass.setPS( immediateContext );

				immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
				immediateContext->IASetInputLayout( nullptr );

				ID3D11ShaderResourceView* srvs[2] = { octahedronTex_.srv_, cubeMapSrv_ };
				immediateContext->PSSetShaderResources( 0, 2, srvs );

				//immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::linearClamp );
				immediateContext->PSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::point );
				immediateContext->PSSetSamplers( REGISTER_SAMPLER_CUBE_MAP_SAMPLER, 1, &SamplerStates::linearClamp );

				immediateContext->Draw( 3, 0 );
			}

			{
				const HlslShaderPass& fxPass = *shader_->getPass( "draw_texture_preview" );
				fxPass.setVS( immediateContext );
				fxPass.setPS( immediateContext );

				immediateContext->PSSetSamplers( REGISTER_SAMPLER_CUBE_MAP_SAMPLER, 1, &SamplerStates::linear );

				immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP );
				immediateContext->Draw( 4, 0 );
			}
		}

		if ( displayMode_ == SphereNormal || displayMode_ == SphereNormalOctahedron || displayMode_ == SphereFacesOctahedron || displayMode_ == SceneCubemap || displayMode_ == SceneOctahedron )
		{
			Vector4 plane( 0, 1, 0, 0 );
			debugDraw::AddPlaneWS( plane, 6, 6, 6, 6, 0xff0000ff, 1, false );
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

				ID3D11ShaderResourceView* srvs[1] = { octahedronTex_.srv_ };
				immediateContext->CSSetShaderResources( 0, 1, srvs );

				immediateContext->CSSetSamplers( REGISTER_SAMPLER_TEX_SAMPLER, 1, &SamplerStates::point );

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
		ImGui::Text( "Camera pos [%3.3f %3.3f %3.3f]", cameraPos.getX().getAsFloat(), cameraPos.getY().getAsFloat(), cameraPos.getZ().getAsFloat() );

		ImGui::Text( "Pixel pos [%4u %4u]", mousePixelPosX_, mousePixelPosY_ );

		{
			const char* items[TextureSize_Count] = { "16", "32", "64", "128", "256", "512" };
			if ( ImGui::Combo( "Texture Size", reinterpret_cast<int*>( &textureSize_ ), items, IM_ARRAYSIZE( items ) ) )
			{
				RecreateTexture();
			}
		}

		{
			const char* items[DisplayModeCount] = { "Sphere Normal", "Sphere Normal Octahedron", "Sphere Faces Octahedron", "Scene Cubemap", "Scene Octahedron" };
			ImGui::Combo( "Display Mode", reinterpret_cast<int*>( &displayMode_ ), items, IM_ARRAYSIZE( items ) );
		}

		{
			ImGui::Checkbox( "Octahedron Overlay", &octahedronOverlay_ );
		}

		{
			ImGui::SliderFloat( "Sample mip level", &sampleMipLevel_, 0.0f, 5.0f );
		}

		{
			ImGui::SliderInt( "Border width", &borderWidth_, 0, 64 );
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
