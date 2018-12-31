#include "Gfx_pch.h"
#include "Dx11DeviceContext.h"

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
