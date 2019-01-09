#ifndef CS_DECAL_VOLUME_CSHARED_HLSL
#define CS_DECAL_VOLUME_CSHARED_HLSL

#include "decal_volume_cshared.h"

#define REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS					MAKE_REGISTER_CBUFFER( 0 )

#define REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION			MAKE_REGISTER_SRV( 3 )
#define REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_TEST					MAKE_REGISTER_SRV( 0 )

#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES				MAKE_REGISTER_UAV( 0 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION			MAKE_REGISTER_UAV( 1 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION_COUNT		MAKE_REGISTER_UAV( 2 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES_COUNT		MAKE_REGISTER_UAV( 3 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS						MAKE_REGISTER_UAV( 0 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS_COUNT				MAKE_REGISTER_UAV( 1 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS_TEST				MAKE_REGISTER_UAV( 2 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_GROUP_TO_BUCKET			MAKE_REGISTER_UAV( 0 )

#define REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT		MAKE_REGISTER_SRV( 4 )
#define REGISTER_BUFFER_DECAL_VOLUME_IN_GROUP_TO_BUCKET				MAKE_REGISTER_SRV( 5 )

//#define DECAL_VOLUME_TILE_SIZE_X					8
//#define DECAL_VOLUME_TILE_SIZE_Y					8
//
//#define DECAL_VOLUME_TILING_NUM_PASSES				2
//#define DECAL_VOLUME_TILING_LAST_PASS				(DECAL_VOLUME_TILING_NUM_PASSES-1)

//#define DECAL_VOLUME_CLUSTER_SIZE_X					32
//#define DECAL_VOLUME_CLUSTER_SIZE_Y					32
//#define DECAL_VOLUME_CLUSTER_CELLS_Z				32

//#define DECAL_VOLUME_CLUSTERING_NUM_PASSES			5
//#define DECAL_VOLUME_CLUSTERING_LAST_PASS			(DECAL_VOLUME_CLUSTERING_NUM_PASSES-1)

#define DECAL_VOLUME_CULL_NUM_THREADS_PER_GROUP		256

MAKE_FLAT_CBUFFER( DecalVolumeCsConstants, REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS )
{
	CBUFFER_FLOAT4X4( dvViewMatrix );
	//CBUFFER_FLOAT4( renderTargetSize ); // rcp in zw
	CBUFFER_FLOAT4( dvTanHalfFov ); // rcp in zw
	CBUFFER_FLOAT4( dvNearFar ); // x - near, y - far, z - far over near
	CBUFFER_UINT4( dvCellCount ); // w = dvCellCount.x * dvCellCount.y * dvCellCount.z
	CBUFFER_FLOAT4( dvCellCountRcp ); // w - unused
	CBUFFER_UINT4( dvPassLimits ); // x - max output decal indices, y - max cell indirections per bucket, z - max cell indirections per bucket for previous pass, w - bucket index
};

MAKE_FLAT_CBUFFER( DecalVolumeCsCullConstants, REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS )
{
	CBUFFER_FLOAT4X4( ViewProjMatrix );
	CBUFFER_FLOAT4( frustumPlane0 );
	CBUFFER_FLOAT4( frustumPlane1 );
	CBUFFER_FLOAT4( frustumPlane2 );
	CBUFFER_FLOAT4( frustumPlane3 );
	CBUFFER_FLOAT4( frustumPlane4 );
	CBUFFER_FLOAT4( frustumPlane5 );
	CBUFFER_UINT4( numDecalsToCull );
};


struct CellIndirection
{
	uint cellIndex;
	uint offsetToFirstDecalIndex;
	uint decalCount;
};


struct GroupToBucket
{
	uint packedBucketAndFirstGroup;
};


struct IndirectDispatchArgs
{
	uint numGroupsX;
	uint numGroupsY;
	uint numGroupsZ;
};

#ifndef __cplusplus

void DecalVolume_UnpackGroupToBucket( GroupToBucket gtb, out uint bucket, out uint firstGroup )
{
	bucket = gtb.packedBucketAndFirstGroup & 0xf;
	firstGroup = gtb.packedBucketAndFirstGroup >> 4;
}

void DecalVolume_PackGroupToBucket( uint bucket, uint firstGroup, out GroupToBucket gtb )
{
	gtb.packedBucketAndFirstGroup = bucket | ( firstGroup << 4 );
}

#endif // #ifndef __cplusplus

#endif // CS_DECAL_VOLUME_CSHARED_HLSL