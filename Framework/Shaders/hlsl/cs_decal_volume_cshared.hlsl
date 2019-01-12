#ifndef CS_DECAL_VOLUME_CSHARED_HLSL
#define CS_DECAL_VOLUME_CSHARED_HLSL

#include "HlslFrameworkInterop.h"

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

#define DECAL_VOLUME_CULL_NUM_THREADS_PER_GROUP						256
#define DECAL_VOLUME_USE_XYW_CORNERS								1

#define DECAL_VOLUME_CLUSTER_SUBGROUP_BUCKET_MERGED					1


MAKE_FLAT_CBUFFER( DecalVolumeCsConstants, REGISTER_CBUFFER_DECAL_VOLUME_CS_CONSTANTS )
{
	CBUFFER_FLOAT4X4( dvViewMatrix );
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


#if COMPILING_SHADER_CODE

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
	return safe_mad24( cellID.z, safe_mul24( numCells.x, numCells.y ), safe_mad24( cellID.y, numCells.x, cellID.x ) );
}


float LogBase( float base, float x )
{
	return log2( x ) * rcp( log2( base ) );
}


// pixelPosition is in range <0, renderTargetSize>
uint2 DecalVolume_GetCellXYFromScreenPosition( float2 pixelPosition, float2 renderTargetSizeRcp, float2 nCellsXY )
{
	float2 pixelUV = pixelPosition * renderTargetSizeRcp;
	uint2 tileXY = uint2( pixelUV * nCellsXY );
	return min( tileXY, uint2( nCellsXY - 1 ) );
}


uint DecalVolume_GetCellZFromCameraZ( float cameraZ, float nearPlaneRcp, float farPlaneOverNearPlane, float nCellsZ )
{
	float base = farPlaneOverNearPlane;
	return ( uint ) min( floor( LogBase( base, cameraZ * nearPlaneRcp ) * nCellsZ ), nCellsZ - 1 );
}


uint3 DecalVolume_GetCellFromViewPos( float2 pixelPosition, float cameraZ, float2 renderTargetSizeRcp, float3 nCellsXYZ, float nearPlaneRcp, float farPlaneOverNearPlane )
{
	return uint3(
		DecalVolume_GetCellXYFromScreenPosition( pixelPosition, renderTargetSizeRcp, nCellsXYZ.xy ),
		DecalVolume_GetCellZFromCameraZ( cameraZ, nearPlaneRcp, farPlaneOverNearPlane, nCellsXYZ.z )
		);
}

#endif // #if COMPILING_SHADER_CODE


#endif // CS_DECAL_VOLUME_CSHARED_HLSL