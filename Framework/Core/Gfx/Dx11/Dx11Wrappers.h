#pragma once

#include "Dx11DeviceContext.h"

namespace spad
{

struct RenderTarget2D
{
	ID3D11Texture2D* texture_ = nullptr;
	ID3D11RenderTargetView* rtv_ = nullptr;
	ID3D11ShaderResourceView* srv_ = nullptr;
	ID3D11UnorderedAccessView* uav_ = nullptr;
	u32 width_ = 0;
	u32 height_ = 0;
	u32 numMipLevels_ = 0;
	u32 arraySize_ = 0;
	DXGI_FORMAT format_ = DXGI_FORMAT_UNKNOWN;
	u32 multiSamples_ = 0;
	u32 msQuality_ = 0;
	bool autoGenMipMaps_ = false;
	bool cubeMap_ = false;
	std::vector<ID3D11RenderTargetView*> rtvArraySlices_;
	std::vector<ID3D11ShaderResourceView*> srvArraySlices_;

	std::string debugName_;

	RenderTarget2D( const char* _debugName )
		: debugName_( _debugName )
	{	}

	~RenderTarget2D();

	void Initialize( ID3D11Device* device,
		u32 width,
		u32 height,
		DXGI_FORMAT format,
		u32 numMipLevels = 1,
		u32 multiSamples = 1,
		u32 msQuality = 0,
		u32 arraySize = 1,
		bool autoGenMipMaps = false,
		bool createUAV = false,
		bool cubeMap = false
		);

	void DeInitialize();

	//void setDebugName( const char* debugName );
};

struct DepthStencil
{
	ID3D11Texture2D* texture_ = nullptr;
	ID3D11DepthStencilView* dsv_ = nullptr;
	ID3D11DepthStencilView* dsvReadOnly_ = nullptr;
	ID3D11ShaderResourceView* srv_ = nullptr;
	u32 width_ = 0;
	u32 height_ = 0;
	u32 arraySize_;
	DXGI_FORMAT format_ = DXGI_FORMAT_UNKNOWN;
	u32 multiSamples_ = 0;
	u32 msQuality_ = 0;
	std::vector<ID3D11DepthStencilView*> dsvArraySlices_;

	std::string debugName_;

	DepthStencil( const char* _debugName )
		: debugName_( _debugName )
	{	}

	~DepthStencil();

	void Initialize( ID3D11Device* device,
		u32 width,
		u32 height,
		u32 arraySize = 1,
		DXGI_FORMAT format = DXGI_FORMAT_D24_UNORM_S8_UINT,
		u32 multiSamples = 1,
		u32 msQuality = 0,
		bool useAsShaderResource = false
		);

	void DeInitialize();

};


struct CodeTexture
{
	ID3D11Texture2D* texture_ = nullptr;
	ID3D11ShaderResourceView* srv_ = nullptr;
	u32 width_ = 0;
	u32 height_ = 0;
	u32 depth_ = 0;
	u32 numMipLevels_ = 0;
	u32 arraySize_ = 0;
	DXGI_FORMAT format_ = DXGI_FORMAT_UNKNOWN;
	bool cubeMap_ = false;
	std::vector<ID3D11ShaderResourceView*> srvArraySlices_;
	std::vector<ID3D11ShaderResourceView*> srvMips_;
	std::vector<ID3D11UnorderedAccessView*> uavMips_;

	std::string debugName_;

	CodeTexture( const char* _debugName )
		: debugName_( _debugName )
	{	}

	~CodeTexture();

	void Initialize( ID3D11Device* device,
		u32 width,
		u32 height,
		u32 depth,
		DXGI_FORMAT format,
		u32 numMipLevels = 1,
		u32 arraySize = 1,
		bool cubeMap = false,
		const D3D11_SUBRESOURCE_DATA *const initData = nullptr,
		bool uav = false
	);

	void DeInitialize();

	ID3D11ShaderResourceView *GetSRV( uint slice, uint mip ) const
	{
		SPAD_ASSERT( slice * numMipLevels_ + mip < srvMips_.size() );
		return srvMips_[slice * numMipLevels_ + mip];
	}

	ID3D11UnorderedAccessView *GetUAV( uint slice, uint mip )
	{
		SPAD_ASSERT( slice * numMipLevels_ + mip < uavMips_.size() );
		return uavMips_[slice * numMipLevels_ + mip];
	}
};


template<typename T>
class ConstantBuffer
{
public:

	ConstantBuffer()
	{
		ZeroMemory( &data, sizeof( T ) );
	}

	~ConstantBuffer()
	{
		DX_SAFE_RELEASE( dxBuffer_ );
	}

	void Initialize( ID3D11Device* device )
	{
		SPAD_ASSERT( !dxBuffer_ );

		D3D11_BUFFER_DESC desc;
		desc.ByteWidth = sizeof( T );
		desc.Usage = D3D11_USAGE_DEFAULT;
		desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
		desc.CPUAccessFlags = 0;
		desc.MiscFlags = 0;
		desc.StructureByteStride = 0;

		D3D11_SUBRESOURCE_DATA initData;
		ZeroMemory( &initData, sizeof( initData ) );
		initData.pSysMem = &data;
		DXCall( device->CreateBuffer( &desc, &initData, &dxBuffer_ ) );
	}

	void updateGpu( ID3D11DeviceContext* deviceContext )
	{
		SPAD_ASSERT( dxBuffer_ != nullptr );

		deviceContext->UpdateSubresource( dxBuffer_, 0, nullptr, &data, 0, 0 );
	}

	void setVS( ID3D11DeviceContext* deviceContext, u32 slot ) const
	{
		SPAD_ASSERT( dxBuffer_ != nullptr );

		ID3D11Buffer* bufferArray[1];
		bufferArray[0] = dxBuffer_;
		deviceContext->VSSetConstantBuffers( slot, 1, bufferArray );
	}

	void setPS( ID3D11DeviceContext* deviceContext, u32 slot ) const
	{
		SPAD_ASSERT( dxBuffer_ != nullptr );

		ID3D11Buffer* bufferArray[1];
		bufferArray[0] = dxBuffer_;
		deviceContext->PSSetConstantBuffers( slot, 1, bufferArray );
	}

	void setGS( ID3D11DeviceContext* deviceContext, u32 slot ) const
	{
		SPAD_ASSERT( dxBuffer_ != nullptr );

		ID3D11Buffer* bufferArray[1];
		bufferArray[0] = dxBuffer_;
		deviceContext->GSSetConstantBuffers( slot, 1, bufferArray );
	}

	void setCS( ID3D11DeviceContext* deviceContext, u32 slot ) const
	{
		SPAD_ASSERT( dxBuffer_ != nullptr );

		ID3D11Buffer* bufferArray[1];
		bufferArray[0] = dxBuffer_;
		deviceContext->CSSetConstantBuffers( slot, 1, bufferArray );
	}

	ID3D11Buffer* getDxBuffer() const
	{
		return dxBuffer_;
	}

public:
	T data;

private:
	ID3D11Buffer* dxBuffer_ = nullptr;
};

// constant buffer with dynamically allocated data buffer, rather than templated one above
class ConstantBuffer2
{
public:

	ConstantBuffer2()
	{	}

	~ConstantBuffer2()
	{
		DX_SAFE_RELEASE( dxBuffer_ );
		spadFreeAligned( data );
	}

	ConstantBuffer2( ConstantBuffer2&& other )
		: data( other.data )
		, size( other.size )
		, dxBuffer_( other.dxBuffer_ )
	{
		other.data = nullptr;
		other.size = 0;
		other.dxBuffer_ = nullptr;
	}

	ConstantBuffer2& operator=( ConstantBuffer2 && other )
	{
		spadFreeAligned( data );
		data = other.data;
		other.data = nullptr;

		size = other.size;
		other.size = 0;

		DX_SAFE_RELEASE( dxBuffer_ );
		dxBuffer_ = other.dxBuffer_;
		other.dxBuffer_ = nullptr;

		return *this;
	}

	void Initialize( ID3D11Device* device, u32 dataSize, u8* initialData = nullptr )
	{
		DX_SAFE_RELEASE( dxBuffer_ );
		spadFreeAligned2( data );

		ReInitilize( device, dataSize, initialData );
	}

	void ReInitilize( ID3D11Device* device, u32 dataSize, u8* initialData = nullptr )
	{
		D3D11_BUFFER_DESC desc;
		desc.ByteWidth = dataSize;
		desc.Usage = D3D11_USAGE_DEFAULT;
		desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
		desc.CPUAccessFlags = 0;
		desc.MiscFlags = 0;
		desc.StructureByteStride = 0;

		D3D11_SUBRESOURCE_DATA initData;
		ZeroMemory( &initData, sizeof( initData ) );
		data = reinterpret_cast<u8*>( spadMallocAligned( dataSize, SPAD_CACHELINE_SIZE ) );
		if ( initialData )
			memcpy( data, initialData, dataSize );
		else
			memset( data, 0, dataSize );
		initData.pSysMem = data;
		DXCall( device->CreateBuffer( &desc, &initData, &dxBuffer_ ) );
		size = dataSize;
	}

	void ReInitilize( ID3D11Device* device, const ConstantBuffer2& otherBuf )
	{
		ReInitilize( device, otherBuf.size, otherBuf.data );
	}

	void updateGpu( ID3D11DeviceContext* deviceContext )
	{
		SPAD_ASSERT( dxBuffer_ != nullptr );

		deviceContext->UpdateSubresource( dxBuffer_, 0, nullptr, data, 0, 0 );
	}

	ID3D11Buffer* getDxBuffer() const
	{
		return dxBuffer_;
	}

public:
	u8* data = nullptr;
	u32 size = 0;

private:
	ID3D11Buffer* dxBuffer_ = nullptr;
};


template<typename T>
class StructuredBuffer
{
public:

	StructuredBuffer()
	{
	}

	~StructuredBuffer()
	{
		DeInitialize();
	}

	uint Initialize( ID3D11Device* device, uint numItems, const T *initialData, bool immutable, bool unorderedAccess, bool createStagingRead, bool indirectArgs = false )
	{
		SPAD_ASSERT( !dxBuffer_ );
		SPAD_ASSERT( ( immutable && !unorderedAccess ) || ( !immutable ) );

		D3D11_BUFFER_DESC desc;
		ZeroMemory( &desc, sizeof( desc ) );
		desc.ByteWidth = sizeof( T ) * numItems;
		desc.Usage = immutable ? D3D11_USAGE_IMMUTABLE : D3D11_USAGE_DEFAULT;
		desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
		if ( unorderedAccess )
			desc.BindFlags |= D3D11_BIND_UNORDERED_ACCESS;
		desc.CPUAccessFlags = 0;
		if ( indirectArgs )
		{
			SPAD_ASSERT( unorderedAccess );
			desc.MiscFlags = D3D11_RESOURCE_MISC_DRAWINDIRECT_ARGS;
			desc.MiscFlags |= D3D11_RESOURCE_MISC_BUFFER_ALLOW_RAW_VIEWS;
		}
		else
		{
			desc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_STRUCTURED;
		}
		desc.StructureByteStride = sizeof( T );

		if ( initialData )
		{
			D3D11_SUBRESOURCE_DATA initData;
			ZeroMemory( &initData, sizeof( initData ) );
			initData.pSysMem = initialData;
			DXCall( device->CreateBuffer( &desc, &initData, &dxBuffer_ ) );
		}
		else
		{
			SPAD_ASSERT( !immutable );
			DXCall( device->CreateBuffer( &desc, nullptr, &dxBuffer_ ) );
		}

		HRESULT hr;

		if ( !indirectArgs )
		{
			D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc;
			ZeroMemory( &srvDesc, sizeof( srvDesc ) );
			srvDesc.Format = indirectArgs ? DXGI_FORMAT_R32_TYPELESS : DXGI_FORMAT_UNKNOWN;
			srvDesc.ViewDimension = D3D11_SRV_DIMENSION_BUFFEREX;
			srvDesc.BufferEx.FirstElement = 0;
			srvDesc.BufferEx.NumElements = numItems;

			hr = device->CreateShaderResourceView( dxBuffer_, &srvDesc, &dxSRV_ );
			SPAD_ASSERT( SUCCEEDED( hr ) );
		}

		if ( unorderedAccess )
		{
			D3D11_UNORDERED_ACCESS_VIEW_DESC uavDesc;
			ZeroMemory( &uavDesc, sizeof( uavDesc ) );
			uavDesc.Format = indirectArgs ? DXGI_FORMAT_R32_TYPELESS : DXGI_FORMAT_UNKNOWN;
			uavDesc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
			uavDesc.Buffer.FirstElement = 0;
			uavDesc.Buffer.NumElements = numItems;
			if ( indirectArgs )
				uavDesc.Buffer.Flags |= D3D11_BUFFER_UAV_FLAG_RAW;

			hr = device->CreateUnorderedAccessView( dxBuffer_, &uavDesc, &dxUAV_ );
			(void)hr;
			SPAD_ASSERT( SUCCEEDED( hr ) );
		}

		if ( createStagingRead )
		{
			ZeroMemory( &desc, sizeof( desc ) );
			desc.ByteWidth = sizeof( T ) * numItems;
			desc.Usage = D3D11_USAGE_STAGING;
			desc.CPUAccessFlags |= D3D11_CPU_ACCESS_READ;

			DXCall( device->CreateBuffer( &desc, nullptr, &dxStagingBuffer_ ) );
		}

		return numItems * sizeof( T );
	}

	void DeInitialize()
	{
		DX_SAFE_RELEASE( dxUAV_ );
		DX_SAFE_RELEASE( dxSRV_ );
		DX_SAFE_RELEASE( dxBuffer_ );
		DX_SAFE_RELEASE( dxStagingBuffer_ );
	}

	void clearUAVUint( ID3D11DeviceContext* deviceContext, uint clearValue ) const
	{
		const uint clearValue4[4] = { clearValue, clearValue, clearValue, clearValue };
		deviceContext->ClearUnorderedAccessViewUint( getUAV(), clearValue4 );
	}

	void updateGpu( ID3D11DeviceContext* deviceContext, const T *data )
	{
		SPAD_ASSERT( dxBuffer_ != nullptr );

		deviceContext->UpdateSubresource( dxBuffer_, 0, nullptr, data, 0, 0 );
	}

	void setVS_SRV( ID3D11DeviceContext* deviceContext, u32 slot ) const
	{
		ID3D11ShaderResourceView* bufferArray[1] = { getSRV() };
		deviceContext->VSSetShaderResources( slot, 1, bufferArray );
	}

	void setCS_SRV( ID3D11DeviceContext* deviceContext, u32 slot ) const
	{
		ID3D11ShaderResourceView* bufferArray[1] = { getSRV() };
		deviceContext->CSSetShaderResources( slot, 1, bufferArray );
	}

	void setCS_UAV( ID3D11DeviceContext* deviceContext, u32 slot ) const
	{
		ID3D11UnorderedAccessView* bufferArray[1] = { getUAV() };
		UINT initialCounts[1] = { 0 };
		deviceContext->CSSetUnorderedAccessViews( slot, 1, bufferArray, initialCounts );
	}

	ID3D11Buffer* getDxBuffer() const
	{
		return dxBuffer_;
	}

	ID3D11ShaderResourceView *getSRV() const
	{
		SPAD_ASSERT( dxSRV_ );
		return dxSRV_;
	}

	ID3D11ShaderResourceView *const *getSRVs() const
	{
		SPAD_ASSERT( dxSRV_ );
		return &dxSRV_;
	}

	ID3D11UnorderedAccessView *getUAV() const
	{
		SPAD_ASSERT( dxUAV_ );
		return dxUAV_;
	}

	const T *CPUReadbackStart( ID3D11DeviceContext* deviceContext )
	{
		assert( dxStagingBuffer_ != nullptr );
		deviceContext->CopyResource( dxStagingBuffer_, dxBuffer_ );
		D3D11_MAPPED_SUBRESOURCE mappedResource;
		DXCall( deviceContext->Map( dxStagingBuffer_, 0, D3D11_MAP_READ, 0, &mappedResource ) );
		return reinterpret_cast<const T*>( mappedResource.pData );
	}

	void CPUReadbackEnd( ID3D11DeviceContext* deviceContext )
	{
		deviceContext->Unmap( dxStagingBuffer_, 0 );
	}

private:
	ID3D11Buffer *dxBuffer_ = nullptr;
	ID3D11ShaderResourceView *dxSRV_ = nullptr;
	ID3D11UnorderedAccessView *dxUAV_ = nullptr;
	ID3D11Buffer *dxStagingBuffer_ = nullptr;
};


class RingBuffer
{
public:
	RingBuffer()
	{
		mappedRes_.pData = nullptr;
		mappedRes_.RowPitch = 0;
		mappedRes_.DepthPitch = 0;
	}

	~RingBuffer()
	{
		DeInitialize();
	}

	void Initialize( ID3D11Device* dxDevice, u32 size );
	void DeInitialize();

	ID3D11Buffer* getBuffer() const { return buffer_; }
	u32 getLastMapOffset() const { return lastAllocOffset_; }

	ID3D11Buffer* const * getBuffers() { return &buffer_; }
	const u32* getLastMapOffsets() const { return &lastAllocOffset_; }

	void* map( ID3D11DeviceContext* context, u32 nBytes );
	void unmap( ID3D11DeviceContext* context );

	void setVertexBuffer( ID3D11DeviceContext* context, u32 slot, u32 stride );

private:

	ID3D11Buffer* buffer_ = nullptr;
	D3D11_MAPPED_SUBRESOURCE mappedRes_;
	u32 size_ = 0;
	u32 nextFreeOffset_ = 0;
	u32 allocatedSize_ = 0;
	u32 lastAllocOffset_ = 0;
};

struct IndexBuffer
{
	ID3D11Buffer* buffer_ = nullptr;
	u32 size_ = 0;
	u32 nIndices_ = 0;
	DXGI_FORMAT format_ = DXGI_FORMAT_UNKNOWN;

	IndexBuffer( const char* _debugName )
		: debugName_( _debugName )
	{	}

	~IndexBuffer()
	{
		DeInitialize();
	}

	void Initialize( ID3D11Device* dxDevice, DXGI_FORMAT format, u32 nIndices, void* initialData );
	void DeInitialize();

private:
	std::string debugName_;
};


class GpuTimerQuery
{
public:
	GpuTimerQuery()
		: startTimeQuery_( nullptr )
		, endTimeQuery_( nullptr )
		, startTime_( 0 )
		, endTime_( 0 )
		, lastValue_( 0 )
		, avgValue_( 0 )
		, minValueTmp_( 0xffffffff )
		, maxValueTmp_( 0 )
		, minValue_( 0 )
		, maxValue_( 0 )
		, avgSum_( 0 )
		, avgCounter_( 0 )
		, timeQueryStarted_( false )
		, timeQueryHasResult_( false )
		, canQuery_( true )
	{	}

	~GpuTimerQuery()
	{
		DeInitialize();
	}

	void Initialize( ID3D11Device* dxDevice );
	void DeInitialize()
	{
		DX_SAFE_RELEASE( startTimeQuery_ );
		DX_SAFE_RELEASE( endTimeQuery_ )
	}

	void begin( ID3D11DeviceContext* deviceContext )
	{
		if ( canQuery_ )
		{
			timeQueryStarted_ = true;
			timeQueryHasResult_ = false;

			deviceContext->End( startTimeQuery_ );
		}
	}

	void end( ID3D11DeviceContext* deviceContext )
	{
		if ( timeQueryStarted_ )
		{
			timeQueryStarted_ = false;
			timeQueryHasResult_ = true;
			canQuery_ = false;

			deviceContext->End( endTimeQuery_ );
		}
	}

	u32 calculateDuration( Dx11DeviceContext &context );

	u32 getDurationUS() const { return lastValue_; }
	u32 getAvgDurationUS() const { return avgValue_; }
	u32 getMinDurationUS() const { return minValueTmp_; }
	u32 getMaxDurationUS() const { return maxValueTmp_; }

private:
	ID3D11Query *startTimeQuery_;
	ID3D11Query *endTimeQuery_;
	u64 startTime_;
	u64 endTime_;
	u32 lastValue_;
	u32 avgValue_;
	u32 minValueTmp_;
	u32 maxValueTmp_;
	u32 minValue_;
	u32 maxValue_;
	u32 avgSum_;
	u32 avgCounter_;
	bool timeQueryStarted_;
	bool timeQueryHasResult_;
	bool canQuery_;
};


//struct GpuTimerQueryScoped
//{
//	GpuTimerQueryScoped( GpuTimerQuery &timerQuery, ID3D11DeviceContext *deviceContext )
//		: timerQuery_( timerQuery )
//		, deviceContext_( deviceContext )
//	{
//		timerQuery_.begin( deviceContext_ );
//	}
//
//	~GpuTimerQueryScoped()
//	{
//		timerQuery_.end( deviceContext_ );
//	}
//
//
//	GpuTimerQuery &timerQuery_;
//	ID3D11DeviceContext *deviceContext_;
//};
//
//
//#define GPU_PROFILE_SCOPE( timerQuery, deviceContext ) 


} // namespace spad