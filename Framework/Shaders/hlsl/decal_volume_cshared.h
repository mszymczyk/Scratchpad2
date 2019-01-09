#ifndef DECAL_VOLUME_CSHARED_HLSL
#define DECAL_VOLUME_CSHARED_HLSL

#include "HlslFrameworkInterop.h"

#define REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS				MAKE_REGISTER_SRV( 0 )
#define REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_COUNT		MAKE_REGISTER_SRV( 1 )
#define REGISTER_BUFFER_DECAL_VOLUME_IN_DECAL_INDICES		MAKE_REGISTER_SRV( 2 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS		MAKE_REGISTER_UAV( 0 )

#define DECAL_VOLUME_USE_XYW_CORNERS 1

struct DecalVolume
{
	float3 position;
	float3 halfSize;
	float3 x;
	float3 y;
	float3 z;
};


// Positions in clip space
struct DecalVolumeTest
{
#if DECAL_VOLUME_USE_XYW_CORNERS
	// every vector has clip space x, y and w
	// see cs_decal_volume_culling for the box's corner layout
	float3 v0;
	float3 v4;
	float3 v5;
	float3 v7;
#else // DECAL_VOLUME_USE_XYW_CORNERS
	// every vector has clip space x, y, z and w
	float4 v0;
	float4 v4;
	float4 v5;
	float4 v7;

	//float4  v1;
	//float4  v2;
	//float4  v3;
	//float4  v6;
#endif // #else // DECAL_VOLUME_USE_XYW_CORNERS
};


#ifndef __cplusplus
uint DecalVolume_PackHeader( uint decalCount, uint offsetToFirstDecalIndex )
{
	return ( decalCount & 0x3ff ) | ( ( offsetToFirstDecalIndex & 0xffffff ) << 10 );
}


void DecalVolume_UnpackHeader( uint packedHeader, out uint decalCount, out uint offsetToFirstDecalIndex )
{
	decalCount = packedHeader & 0x3ff;
	offsetToFirstDecalIndex = packedHeader >> 10;
}


uint DecalVolume_GetCellFlatIndex( uint3 cellID, uint3 numCells )
{
	return mad24( cellID.z, mul24( numCells.x, numCells.y ), mad24( cellID.y, numCells.x, cellID.x ) );
}
#endif // #ifndef __cplusplus

#endif // DECAL_VOLUME_CSHARED_HLSL