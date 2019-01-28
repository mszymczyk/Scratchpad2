#ifndef CS_DECAL_VOLUME_CSHARED_HLSL
#define CS_DECAL_VOLUME_CSHARED_HLSL

#include "decal_volume_cshared.hlsl"

#define REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS					MAKE_REGISTER_CBUFFER( 0 )

#define REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS						MAKE_REGISTER_SRV( 0 )
#define REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_TEST					MAKE_REGISTER_SRV( 0 )
#define REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_COUNT				MAKE_REGISTER_SRV( 1 )
#define REGISTER_BUFFER_DECAL_VOLUME_IN_DECAL_INDICES				MAKE_REGISTER_SRV( 2 )
#define REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION			MAKE_REGISTER_SRV( 3 )
#define REGISTER_BUFFER_DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT		MAKE_REGISTER_SRV( 4 )

#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES				MAKE_REGISTER_UAV( 0 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECAL_INDICES_COUNT		MAKE_REGISTER_UAV( 1 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION			MAKE_REGISTER_UAV( 2 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_CELL_INDIRECTION_COUNT		MAKE_REGISTER_UAV( 3 )

#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS						MAKE_REGISTER_UAV( 0 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS_COUNT				MAKE_REGISTER_UAV( 1 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS_TEST				MAKE_REGISTER_UAV( 2 )

#define REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS				MAKE_REGISTER_UAV( 0 )

#define REGISTER_BUFFER_DECAL_VOLUME_IN_GROUP_TO_BUCKET				MAKE_REGISTER_SRV( 5 )
#define REGISTER_BUFFER_DECAL_VOLUME_OUT_GROUP_TO_BUCKET			MAKE_REGISTER_UAV( 0 )

#define REGISTER_TEXTURE_DECAL_VOLUME_IN_DEPTH						MAKE_REGISTER_SRV( 5 )
#define REGISTER_SAMPLER_DECAL_VOLUME_IN_DEPTH						MAKE_REGISTER_SAMPLER( 5 )
#define REGISTER_TEXTURE_DECAL_VOLUME_OUT_DEPTH						MAKE_REGISTER_UAV( 0 )


#define DECAL_VOLUME_CULL_NUM_THREADS_PER_GROUP						256
#define DECAL_VOLUME_USE_XYW_CORNERS								1

#define DECAL_VOLUME_CLUSTER_3D_UNIFORMZ							1

#define DECAL_VOLUME_CLUSTER_MAX_BUCKETS							7
#define DECAL_VOLUME_CLUSTER_SUBGROUP_BUCKET_MERGED					1
#define DECAL_VOLUME_CLUSTER_CLEAR_HEADER_NUM_GROUPS				64

#define DECAL_VOLUME_INTERSECTION_METHOD_SIMPLE						0
#define DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE					1
#define DECAL_VOLUME_INTERSECTION_METHOD_CLIP_SPACE2				2
#define DECAL_VOLUME_INTERSECTION_METHOD_SAT						3


MAKE_FLAT_CBUFFER( DecalVolumeCsConstants, REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS )
{
	CBUFFER_FLOAT4X4( dvViewMatrix );
	CBUFFER_FLOAT4X4( dvViewProjMatrix );
	CBUFFER_FLOAT4( dvTanHalfFov ); // rcp in zw
	CBUFFER_FLOAT4( dvNearFar ); // x - near, y - far, z - far over near
	CBUFFER_UINT4( dvCellCount ); // w = dvCellCount.x * dvCellCount.y * dvCellCount.z
	CBUFFER_FLOAT4( dvCellCountF );
	CBUFFER_FLOAT4( dvCellCountRcp ); // w - unused
	CBUFFER_FLOAT4( dvCellSize ); // xy = cell size / render target size, zw - unused
	CBUFFER_FLOAT4( dvEyeAxisX ); // tanHalfFov builtin
	CBUFFER_FLOAT4( dvEyeAxisY ); // tanHalfFov builtin
	CBUFFER_FLOAT4( dvEyeAxisZ );
	CBUFFER_FLOAT4( dvEyeOffset );
	CBUFFER_UINT4( dvPassLimits ); // x - max output decal indices, y -max output decal indices per cell, z - max cell indirections per bucket, w - max cell indirections per bucket for previous pass
	CBUFFER_UINT4( dvBuckets ); // x - bucket index
};


MAKE_FLAT_CBUFFER( DecalVolumeCsCullConstants, REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS )
{
	CBUFFER_FLOAT4( dvcRenderTargetSize ); // rcp in zw
	CBUFFER_FLOAT4( dvcProjMatrixParams );
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


//struct DecalVolume
//{
//	cfloat3 position;
//	cfloat3 x;
//	cfloat3 y;
//	cfloat3 z;
//	cfloat3 halfSize;
//};


// x, y, z have halfSize premultiplied
struct DecalVolumeScaled
{
	cfloat3 position;
	cfloat3 x;
	cfloat3 y;
	cfloat3 z;
};


// Positions in clip space
struct DecalVolumeClipSpace
{
#if DECAL_VOLUME_USE_XYW_CORNERS
	// every vector has clip space x, y and w
	// see cs_decal_volume_culling for the box's corner layout
	cfloat3 v0;
	cfloat3 v4;
	cfloat3 v5;
	cfloat3 v7;
#else // DECAL_VOLUME_USE_XYW_CORNERS
	// every vector has clip space x, y, z and w
	cfloat4 v0;
	cfloat4 v4;
	cfloat4 v5;
	cfloat4 v7;

	//cfloat4  v1;
	//cfloat4  v2;
	//cfloat4  v3;
	//cfloat4  v6;
#endif // #else // DECAL_VOLUME_USE_XYW_CORNERS
};


#endif // CS_DECAL_VOLUME_CSHARED_HLSL