#include "Gfx_pch.h"
#include "Dx11DeviceContext.h"
#include "Dx11DeviceStates.h"
#include <Shaders/hlsl/global_samplers.hlsl>

namespace spad
{
	void Dx11DeviceContext::Initialize( ID3D11Device* device, ID3D11DeviceContext* _context )
	{
		context = _context;
		inputLayoutCache.setDxDevice( device );
		
		DXCall( context->QueryInterface( __uuidof( userDefinedAnnotation_ ), reinterpret_cast<void**>( &userDefinedAnnotation_ ) ) );

		D3D11_QUERY_DESC qd;
		qd.Query = D3D11_QUERY_TIMESTAMP_DISJOINT;
		qd.MiscFlags = 0;
		HRESULT hr = device->CreateQuery( &qd, &disjointQuery_ );
		if ( FAILED( hr ) )
		{
			logError( "Couldn't create disjoint query" );
		}
		else
		{
			context->Begin( disjointQuery_ );
			context->End( disjointQuery_ );
			while ( context->GetData( disjointQuery_, &disjointQueryResult_, sizeof( disjointQueryResult_ ), 0 ) != S_OK );
		}
	}

	void Dx11DeviceContext::DeInitialize()
	{
		DX_SAFE_RELEASE( disjointQuery_ );
	}

	void Dx11DeviceContext::BindGlobalSamplers()
	{
		auto setSampler = [&]( uint index, ID3D11SamplerState *sstate ) {
			context->VSSetSamplers( index, 1, &sstate );
			context->HSSetSamplers( index, 1, &sstate );
			context->DSSetSamplers( index, 1, &sstate );
			context->GSSetSamplers( index, 1, &sstate );
			context->PSSetSamplers( index, 1, &sstate );
			context->CSSetSamplers( index, 1, &sstate );
		};

		setSampler( REGISTER_SAMPLER_ANISO_MIPMAP_CLAMP, SamplerStates::anisotropic4xClamp );
		setSampler( REGISTER_SAMPLER_ANISO_MIPMAP_WRAP_U, SamplerStates::anisotropic4xWrapU );
		setSampler( REGISTER_SAMPLER_ANISO_MIPMAP_WRAP_V, SamplerStates::anisotropic4xWrapV );
		setSampler( REGISTER_SAMPLER_ANISO_MIPMAP_WRAP, SamplerStates::anisotropic4xWrap );
		setSampler( REGISTER_SAMPLER_SHADOWMAP, SamplerStates::shadowMap );
		setSampler( REGISTER_SAMPLER_POINT_CLAMP, SamplerStates::pointClampNoMips );
		setSampler( REGISTER_SAMPLER_POINT_WRAP, SamplerStates::pointWrapNoMips );
		setSampler( REGISTER_SAMPLER_POINT_MIP_CLAMP, SamplerStates::pointClamp );
		setSampler( REGISTER_SAMPLER_LINEAR_CLAMP, SamplerStates::linearClampNoMips );
		setSampler( REGISTER_SAMPLER_LINEAR_WRAP, SamplerStates::linearWrapNoMips );
		setSampler( REGISTER_SAMPLER_LINEAR_MIP_CLAMP, SamplerStates::linearClampMipPoint );
		setSampler( REGISTER_SAMPLER_LINEAR_MIP_LINEAR_CLAMP, SamplerStates::linearClamp );
		setSampler( REGISTER_SAMPLER_LINEAR_MIPMAP_WRAP_U, SamplerStates::linearWrapU );
		setSampler( REGISTER_SAMPLER_LINEAR_MIPMAP_WRAP_V, SamplerStates::linearWrapV );
		setSampler( REGISTER_SAMPLER_LINEAR_MIP_LINEAR_WRAP, SamplerStates::linearWrap );

	}

	void Dx11DeviceContext::BeginMarker( const char *name )
	{
		if ( !markersEnabled_ )
			return;

		markerDepth_ += 1;

		constexpr size_t maxMarkerLen = 128;

		size_t markerNameLen = strlen( name );
		if ( markerNameLen >= maxMarkerLen )
			markerNameLen = maxMarkerLen - 1;

		const size_t newsize = maxMarkerLen;
		size_t convertedChars = 0;
		wchar_t wcstring[newsize];
		mbstowcs_s( &convertedChars, wcstring, newsize, name, markerNameLen );

		userDefinedAnnotation_->BeginEvent( wcstring );
	}

	void Dx11DeviceContext::BeginMarker( const char *name, uint index )
	{
		if ( !markersEnabled_ )
			return;

		constexpr size_t maxMarkerLen = 128;
		char buf[maxMarkerLen];

		snprintf( buf, sizeof( buf ) - 1, "%s %u", name, index );
		buf[maxMarkerLen - 1] = 0;

		BeginMarker( buf );
	}

	void Dx11DeviceContext::EndMarker()
	{
		if ( !markersEnabled_ )
			return;

		SPAD_ASSERT( markerDepth_ > 0 );
		markerDepth_ -= 1;

		userDefinedAnnotation_->EndEvent();
	}

	void Dx11DeviceContext::SetMarker( const char *name )
	{
		if ( !markersEnabled_ )
			return;

		constexpr size_t maxMarkerLen = 128;

		size_t markerNameLen = strlen( name );
		if ( markerNameLen >= maxMarkerLen )
			markerNameLen = maxMarkerLen - 1;

		const size_t newsize = maxMarkerLen;
		size_t convertedChars = 0;
		wchar_t wcstring[newsize];
		mbstowcs_s( &convertedChars, wcstring, newsize, name, markerNameLen );

		userDefinedAnnotation_->SetMarker( wcstring );
	}

} // namespace spad
