#ifndef CS_DECAL_VOLUME_CSHARED_HLSL
#define CS_DECAL_VOLUME_CSHARED_HLSL

#include "HlslFrameworkInterop.h"

#define DECAL_VOLUME_CS_CONSTANTS_BINDING			0

#define DECAL_VOLUME_IN_DECALS_BINDING				0
#define DECAL_VOLUME_IN_COUNT_PER_CELL_BINDING		1
#define DECAL_VOLUME_IN_DECALS_PER_CELL_BINDING		2
#define DECAL_VOLUME_IN_CELL_INDIRECTION_BINDING	3

#define DECAL_VOLUME_OUT_COUNT_PER_CELL_BINDING				0
#define DECAL_VOLUME_OUT_DECALS_PER_CELL_BINDING			1
#define DECAL_VOLUME_OUT_CELL_INDIRECTION_BINDING			2
#define DECAL_VOLUME_OUT_CELL_INDIRECTION_COUNT_BINDING		3

#define DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT_BINDING		0
#define DECAL_VOLUME_OUT_INDIRECT_ARGS_BINDING				0

#define DECAL_VOLUME_TILE_SIZE_X					8
#define DECAL_VOLUME_TILE_SIZE_Y					8

#define DECAL_VOLUME_TILING_NUM_PASSES				3
#define DECAL_VOLUME_TILING_LAST_PASS				(DECAL_VOLUME_TILING_NUM_PASSES-1)

MAKE_FLAT_CBUFFER( DecalVolumeCsConstants, DECAL_VOLUME_CS_CONSTANTS_BINDING )
{
	CBUFFER_FLOAT4X4( ViewMatrix );
	CBUFFER_FLOAT4( renderTargetSize ); // rcp in zw
	CBUFFER_FLOAT4( tanHalfFov ); // rcp in zw
	CBUFFER_FLOAT4( nearFar ); // far over near in z
	CBUFFER_UINT4( cellCountA );
	CBUFFER_UINT4( decalCountInFrustum );
	CBUFFER_UINT4( maxCountPerCell );
};


//MAKE_FLAT_CBUFFER( DecalVolumeDrawConstants, DECAL_VOLUME_CS_CONSTANTS_BINDING )
//{
//	CBUFFER_FLOAT4( renderTargetSize ); // rcp in zw
//	CBUFFER_UINT4( cellCount );
//};

//CBUFFER CbGpuClusteringConstants REGISTER_B( CB_GPU_CLUSTERING_CONSTANTS_BINDING )
//{
//	float4x4 BaseProjMatrix;
//	float4x4 ViewMatrix;
//	float4 tanHalfFov; // rcp in zw
//	float4 nearFar; // far over near in z
//	uint frustumDecalCount;
//	//uint nDecals64;
//	uint pad0;
//	//uint nDecalGroups;
//	uint pad1;
//	//uint nDecalWords;
//	uint pad2;
//	float4 renderTargetSize;
//};


struct DecalVolume
{
	float4 position;
	float4 halfSize;
	float4 x;
	float4 y;
	float4 z;
};


struct CellIndirection
{
	uint parentCellIndex;
	uint cellIndex;
};


struct IndirectDispatchArgs
{
	uint numGroupsX;
	uint numGroupsY;
	uint numGroupsZ;
};


#ifndef __cplusplus
uint DecalVolume_PackHeader( uint decalCount, uint offsetToFirstDecalIndex )
{
	return ( decalCount & 0xfff ) | ( ( offsetToFirstDecalIndex ) << 8 );
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

#endif // CS_DECAL_VOLUME_CSHARED_HLSL