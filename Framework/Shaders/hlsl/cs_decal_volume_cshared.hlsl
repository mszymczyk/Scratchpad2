#ifndef CS_DECAL_VOLUME_CSHARED_HLSL
#define CS_DECAL_VOLUME_CSHARED_HLSL

#include "decal_volume_cshared.h"

#define DECAL_VOLUME_CS_CONSTANTS_BINDING			0

#define DECAL_VOLUME_IN_CELL_INDIRECTION_BINDING	3
#define DECAL_VOLUME_IN_DECALS_TEST_BINDING			0

#define DECAL_VOLUME_OUT_DECALS_PER_CELL_BINDING			0
#define DECAL_VOLUME_OUT_CELL_INDIRECTION_BINDING			1
#define DECAL_VOLUME_OUT_CELL_INDIRECTION_COUNT_BINDING		2
#define DECAL_VOLUME_OUT_MEM_ALLOC_BINDING					3
#define DECAL_VOLUME_OUT_DECALS_BINDING						0
#define DECAL_VOLUME_OUT_DECALS_COUNT_BINDING				1
#define DECAL_VOLUME_OUT_DECALS_TEST_BINDING				2
#define DECAL_VOLUME_OUT_GROUP_TO_BUCKET_BINDING			0

#define DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT_BINDING		4
#define DECAL_VOLUME_IN_GROUP_TO_BUCKET_BINDING				5

#define DECAL_VOLUME_TILE_SIZE_X					8
#define DECAL_VOLUME_TILE_SIZE_Y					8

#define DECAL_VOLUME_TILING_NUM_PASSES				2
#define DECAL_VOLUME_TILING_LAST_PASS				(DECAL_VOLUME_TILING_NUM_PASSES-1)

#define DECAL_VOLUME_CLUSTER_SIZE_X					32
#define DECAL_VOLUME_CLUSTER_SIZE_Y					32
#define DECAL_VOLUME_CLUSTER_CELLS_Z				32

#define DECAL_VOLUME_CLUSTERING_NUM_PASSES			5
#define DECAL_VOLUME_CLUSTERING_LAST_PASS			(DECAL_VOLUME_CLUSTERING_NUM_PASSES-1)

#define DECAL_VOLUME_CULL_NUM_THREADS_PER_GROUP		256

MAKE_FLAT_CBUFFER( DecalVolumeCsConstants, DECAL_VOLUME_CS_CONSTANTS_BINDING )
{
	CBUFFER_FLOAT4X4( ViewMatrix );
	CBUFFER_FLOAT4( renderTargetSize ); // rcp in zw
	CBUFFER_FLOAT4( tanHalfFov ); // rcp in zw
	CBUFFER_FLOAT4( nearFar ); // far over near in z
	CBUFFER_UINT4( cellCountA );
	//CBUFFER_UINT4( decalCountInFrustum );
	CBUFFER_UINT4( maxCountPerCell ); // x - maxCountPerCell, y - cell bucket
};

MAKE_FLAT_CBUFFER( DecalVolumeCsCullConstants, DECAL_VOLUME_CS_CONSTANTS_BINDING )
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

#define mul24( x, y ) (x * y )

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