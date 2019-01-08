#ifndef DECAL_VOLUME_CSHARED_HLSL
#define DECAL_VOLUME_CSHARED_HLSL

#include "HlslFrameworkInterop.h"

#define DECAL_VOLUME_IN_DECALS_BINDING				0
#define DECAL_VOLUME_IN_DECALS_COUNT_BINDING		1
#define DECAL_VOLUME_IN_DECALS_PER_CELL_BINDING		2
#define DECAL_VOLUME_OUT_INDIRECT_ARGS_BINDING		0

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
	float4 v0;
	float4 v4;
	float4 v5;
	float4 v7;

	//float4  v1;
	//float4  v2;
	//float4  v3;
	//float4  v6;
};


#ifndef __cplusplus
uint DecalVolume_PackHeader( uint decalCount, uint offsetToFirstDecalIndex )
{
	return ( decalCount & 0xff ) | ( ( offsetToFirstDecalIndex & 0xffffff ) << 8 );
}


void DecalVolume_UnpackHeader( uint packedHeader, out uint decalCount, out uint offsetToFirstDecalIndex )
{
	decalCount = packedHeader & 0xff;
	offsetToFirstDecalIndex = packedHeader >> 8;
}


uint DecalVolume_GetCellFlatIndex( uint3 cellID, uint3 numCells )
{
	return ( cellID.z * numCells.x * numCells.y + cellID.y * numCells.x + cellID.x );
}
#endif // #ifndef __cplusplus

#endif // DECAL_VOLUME_CSHARED_HLSL