#include "LaneSwizzle_pch.h"
#include "LaneSwizzle.h"
#include <Gfx\Dx11/Dx11DeviceStates.h>
#include <Gfx\DebugDraw.h>

namespace spad
{
	void bin( unsigned int n, char buf[33] )
	{
		buf[32] = 0;
		//unsigned i;
		//for ( unsigned i = 1 << 31; i > 0; i = i / 2 )
		//	( n & i ) ? printf( "1" ) : printf( "0" );
		for ( int i = 0; i < 32; ++i )
		{
			buf[i] = ( n & ( 1 << (31 - i) ) ) ? '1' : '0';
		}
	}

	void bin64( uint64_t n, char buf[65] )
	{
		buf[64] = 0;
		//unsigned i;
		//for ( unsigned i = 1 << 31; i > 0; i = i / 2 )
		//	( n & i ) ? printf( "1" ) : printf( "0" );
		for ( uint64_t i = 0; i < 64; ++i )
		{
			buf[i] = ( n & ( 1ULL << ( 63ULL - i ) ) ) ? '1' : '0';
		}
	}

	void printBin( unsigned n )
	{
		char binBuf[33];
		bin( n, binBuf );
		printf( "%3u - %s\n", n, binBuf );
	}

	void printBin64( uint64_t n )
	{
		char binBuf[65];
		bin64( n, binBuf );
		printf( "%12zu - %s\n", n, binBuf );
	}

	bool LaneSwizzle::StartUp()
	{
		//ID3D11Device* dxDevice = dx11_->getDevice();

		shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\LaneSwizzle.hlslc_packed" );

		for ( uint i = 0; i < 64; ++i )
		{
			printBin( i );
		}

		printBin( 0x303 );

		printf( "quadMask\n" );

		for ( uint groupIndex = 0; groupIndex < 64; ++groupIndex )
		{
			//uint64_t quadmask = ( 0x0000000000000303ULL << ( groupIndex & ~( 8 | 1 ) ) );
			//uint64_t quadmask = ( 0x000000000F0F0F0FULL << ( groupIndex & ~( 16 | 8 | 2 | 1 ) ) );
			uint64_t quadmask = groupIndex & ~( 8 | 1 );
			//uint64_t quadmask = groupIndex & ~( 16 | 8 | 2 | 1 );
			printBin64( quadmask );
		}

		printf( "blah\n" );
		printBin64( ~( 8ULL | 1ULL ) );
		printBin64( ~( 16ULL | 8ULL | 2ULL | 1ULL ) );

		return true;
	}

	void LaneSwizzle::ShutDown()
	{
	}

	void LaneSwizzle::UpdateAndRender( const Timer& /*timer*/ )
	{
		Dx11DeviceContext& immediateContextWrapper = dx11_->getImmediateContextWrapper();
		ID3D11DeviceContext* immediateContext = immediateContextWrapper.context;
		immediateContext->ClearState();

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

		const float clearColor[] = { 0.0f, 0.0f, 0.0f, 1 };
		immediateContext->ClearRenderTargetView( dx11_->getBackBufferRTV(), clearColor );

		immediateContext->RSSetState( RasterizerStates::NoCull() );
		immediateContext->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );
		immediateContext->OMSetBlendState( BlendStates::alphaBlend, nullptr, 0xffffffff );

		const HlslShaderPass& fxPass = *shader_->getPass( "Fullscreen" );
		fxPass.setVS( immediateContext );
		fxPass.setPS( immediateContext );

		immediateContext->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
		immediateContext->IASetInputLayout( nullptr );

		immediateContext->Draw( 3, 0 );
	}


	void LaneSwizzle::KeyPressed( uint key, bool shift, bool alt, bool ctrl )
	{
		(void)shift;
		(void)alt;
		(void)ctrl;

		if ( key == 'R' || key == 'r' )
		{
			shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\LaneSwizzle.hlslc_packed" );
		}
	}
}
