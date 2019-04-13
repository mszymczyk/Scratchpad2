#include "BCEncodeApp_pch.h"
#include "BCEncode.h"
#include <Gfx\Dx11/Dx11DeviceStates.h>
#include <Gfx\DebugDraw.h>

namespace spad
{
	static uint bc7Block[4];

	bool BCEncode::StartUp()
	{
		ID3D11Device* dxDevice = dx11_->getDevice();

		shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\BCEncode.hlslc_packed" );

		uint w = 4;
		uint h = 4;

		{
			D3D11_TEXTURE2D_DESC desc;
			ZeroMemory( &desc, sizeof( desc ) );
			desc.Width = w;
			desc.Height = h;
			desc.ArraySize = 1;
			desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
			desc.SampleDesc.Count = 1;
			desc.SampleDesc.Quality = 0;
			desc.CPUAccessFlags = 0;
			desc.Format = DXGI_FORMAT_BC7_UNORM;
			desc.MipLevels = 1;
			desc.Usage = D3D11_USAGE_DEFAULT;

			DXCall( dxDevice->CreateTexture2D( &desc, nullptr, &texture_ ) );
			debug::Dx11SetDebugName( texture_, "bc7 texture" );

			D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc;
			ZeroMemory( &srvDesc, sizeof( srvDesc ) );
			srvDesc.Format = DXGI_FORMAT_BC7_UNORM;
			srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
			srvDesc.Texture2D.MipLevels = (UINT)-1;
			srvDesc.Texture2D.MostDetailedMip = 0;

			DXCall( dxDevice->CreateShaderResourceView( texture_, &srvDesc, &srv_ ) );
			debug::Dx11SetDebugName3( srv_, "bc7 texture SRV" );
		}


		{
			D3D11_TEXTURE2D_DESC desc;
			ZeroMemory( &desc, sizeof( desc ) );
			desc.Width = w / 4;
			desc.Height = h / 4;
			desc.ArraySize = 1;
			desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS;
			desc.SampleDesc.Count = 1;
			desc.SampleDesc.Quality = 0;
			desc.CPUAccessFlags = 0;
			desc.Format = DXGI_FORMAT_R32G32B32A32_UINT;
			desc.MipLevels = 1;
			desc.Usage = D3D11_USAGE_DEFAULT;

			DXCall( dxDevice->CreateTexture2D( &desc, nullptr, &tmpBC7_ ) );
			debug::Dx11SetDebugName( tmpBC7_, "tmp bc7" );

			D3D11_UNORDERED_ACCESS_VIEW_DESC uavDesc;
			ZeroMemory( &uavDesc, sizeof( uavDesc ) );
			uavDesc.Format = DXGI_FORMAT_R32G32B32A32_UINT;
			uavDesc.ViewDimension = D3D11_UAV_DIMENSION_TEXTURE2D;
			uavDesc.Texture2D.MipSlice = 0;

			DXCall( dxDevice->CreateUnorderedAccessView( tmpBC7_, &uavDesc, &tmpBC7UAV_ ) );
			debug::Dx11SetDebugName( tmpBC7UAV_, "bc7 texture SRV" );
		}

		uint mode = 0x20;
		bc7Block[0] = mode;

		return true;
	}

	void BCEncode::ShutDown()
	{
		DX_SAFE_RELEASE( tmpBC7UAV_ );
		DX_SAFE_RELEASE( tmpBC7_ );

		DX_SAFE_RELEASE( srv_ );
		DX_SAFE_RELEASE( texture_ );
	}

	void BCEncode::UpdateAndRender( const Timer& /*timer*/ )
	{
		Dx11DeviceContext& immediateContextWrapper = dx11_->getImmediateContextWrapper();
		ID3D11DeviceContext* immediateContext = immediateContextWrapper.context;
		immediateContext->ClearState();


		// compute
		ID3D11UnorderedAccessView *uavs[1] = { tmpBC7UAV_ };
		UINT initialCounts[1] = { 0 };
		immediateContext->CSSetUnorderedAccessViews( 0, 1, uavs, initialCounts );

		const HlslShaderPass& encodePass = *shader_->getPass( "cs_bc7_encode_constant" );
		encodePass.setCS( immediateContext );

		immediateContext->Dispatch( 1, 1, 1 );

		immediateContextWrapper.UnbindCSUAV( 0 );

		immediateContext->CopyResource( texture_, tmpBC7_ );

		// Set default render targets
		ID3D11RenderTargetView* rtviews[1] = { dx11_->getBackBufferRTV() };
		immediateContext->OMSetRenderTargets( 1, rtviews, nullptr );

		// Setup the viewport
		D3D11_VIEWPORT vp;
		vp.Width = static_cast<float>( dx11_->getBackBufferWidth() );
		vp.Height = static_cast<float>( dx11_->getBackBufferHeight() );
		vp.MinDepth = 0.0f;
		vp.MaxDepth = 1.0f;
		vp.TopLeftX = 0;
		vp.TopLeftY = 0;
		immediateContext->RSSetViewports( 1, &vp );

		const float clearColor[] = { 1.0f, 0.0f, 0.0f, 1 };
		immediateContext->ClearRenderTargetView( dx11_->getBackBufferRTV(), clearColor );

		immediateContext->RSSetState( RasterizerStates::NoCull() );
		immediateContext->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );
		immediateContext->OMSetBlendState( BlendStates::alphaBlend, nullptr, 0xffffffff );

		const HlslShaderPass& fxPass = *shader_->getPass( "draw_bc_texture" );
		fxPass.setVS( immediateContext );
		fxPass.setPS( immediateContext );

		immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
		immediateContext->IASetInputLayout( nullptr );

		ID3D11ShaderResourceView* srvs[1] = { srv_ };
		immediateContext->PSSetShaderResources( 0, 1, srvs );

		immediateContext->Draw( 3, 0 );
	}

}
