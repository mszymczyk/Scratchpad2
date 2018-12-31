#pragma once

#include <Dx11Util\Dx11Util.h>
#include "Dx11InputLayoutCache.h"

namespace spad
{

class Dx11DeviceContext
{
public:
	Dx11DeviceContext( const char* debugName )
		: debugName_( debugName )
		, disjointQuery_( nullptr )
	{
		disjointQueryResult_.Frequency = 1;
		disjointQueryResult_.Disjoint = false;
	}

	~Dx11DeviceContext()
	{
		DeInitialize();
	}

	void Initialize( ID3D11Device* device, ID3D11DeviceContext* context );
	void DeInitialize();

	void UnbindCSUAV( uint slot )
	{
		ID3D11UnorderedAccessView* uavsClear[1] = { nullptr };
		UINT initialCounts[1] = { 0 };
		context->CSSetUnorderedAccessViews( slot, 1, uavsClear, initialCounts );
	}

	void UnbindCSUAVs()
	{
		ID3D11UnorderedAccessView* uavsClear[8] = { nullptr };
		UINT initialCounts[8] = { 0 };
		context->CSSetUnorderedAccessViews( 0, 8, uavsClear, initialCounts );
	}

	void BeginMarker( const char *name );
	void EndMarker();
	void SetMarker( const char *name );

	ID3D11DeviceContext* context = nullptr;
	Dx11InputLayoutCache inputLayoutCache;
	D3D11_QUERY_DATA_TIMESTAMP_DISJOINT disjointQueryResult_;

private:
	ID3DUserDefinedAnnotationPtr userDefinedAnnotation_;

	std::string debugName_;
	ID3D11Query* disjointQuery_;
	uint markerDepth_ = 0;
	bool markersEnabled_ = true;
};


} // namespace spad
