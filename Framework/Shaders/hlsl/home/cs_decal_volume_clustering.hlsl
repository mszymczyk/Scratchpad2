#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	DecalTilingClearHeader = {
		ComputeProgram = {
		EntryName = "DecalTilingClearHeader";
			cdefines = {
				DECAL_TILING_PASS_NO = ( "666" );
			}
		}
	}

	DecalTilingCopyIndirectArgs = {
		ComputeProgram = {
			EntryName = "DecalTilingCopyIndirectArgs";
			cdefines = {
				DECAL_TILING_PASS_NO = ( "666" );
			}
		}
	}

	DecalTilingPass0 = {
		ComputeProgram = {
			EntryName = "DecalTilingPass0";
			cdefines = {
				DECAL_TILING_PASS_NO = ( "0" );
			}
		}
	}

	DecalTilingPass1 = {
		ComputeProgram = {
			EntryName = "DecalTilingPass1";
			cdefines = {
				DECAL_TILING_PASS_NO = ( "1" );
			}
		}
	}

	DecalTilingPass2 = {
		ComputeProgram = {
			EntryName = "DecalTilingPass2";
			cdefines = {
				DECAL_TILING_PASS_NO = ( "2" );
			}
		}
	}

	DecalTilingPass3 = {
		ComputeProgram = {
			EntryName = "DecalTilingPass3";
			cdefines = {
				DECAL_TILING_PASS_NO = ( "3" );
			}
		}
	}

	DecalTilingPass4 = {
		ComputeProgram = {
			EntryName = "DecalTilingPass4";
			cdefines = {
				DECAL_TILING_PASS_NO = ( "4" );
			}
		}
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "cs_decal_volume_cshared.hlsl"

StructuredBuffer<DecalVolume> inDecalVolumes REGISTER_T( DECAL_VOLUME_IN_DECALS_BINDING );
#if DECAL_TILING_PASS_NO != 0
StructuredBuffer<uint> inDecalCountPerCell REGISTER_T( DECAL_VOLUME_IN_COUNT_PER_CELL_BINDING );
StructuredBuffer<uint> inDecalsPerCell REGISTER_T( DECAL_VOLUME_IN_DECALS_PER_CELL_BINDING );
StructuredBuffer<CellIndirection> inCellIndirection REGISTER_T( DECAL_VOLUME_IN_CELL_INDIRECTION_BINDING );
#endif // #if DECAL_TILING_PASS_NO != 0

#if DECAL_TILING_PASS_NO != DECAL_VOLUME_TILING_LAST_PASS
RWStructuredBuffer<uint> outDecalCountPerCell REGISTER_U( DECAL_VOLUME_OUT_COUNT_PER_CELL_BINDING );
RWStructuredBuffer<CellIndirection> outDecalCellIndirection REGISTER_U( DECAL_VOLUME_OUT_CELL_INDIRECTION_BINDING );
RWStructuredBuffer<uint> outCellIndirectionCount REGISTER_U( DECAL_VOLUME_OUT_CELL_INDIRECTION_COUNT_BINDING );
#endif // #if DECAL_TILING_PASS_NO != 2

StructuredBuffer<uint> inCellIndirectionCount REGISTER_T( DECAL_VOLUME_IN_CELL_INDIRECTION_COUNT_BINDING );
RWByteAddressBuffer outIndirectArgs REGISTER_U( DECAL_VOLUME_OUT_INDIRECT_ARGS_BINDING );

RWStructuredBuffer<uint> outDecalsPerCell REGISTER_U( DECAL_VOLUME_OUT_DECALS_PER_CELL_BINDING );


struct Frustum
{
	// left, right, bottom, top, near, far
	float4 planes[6];
};


void extractFrustumPlanes( out float4 planes[6], float4x4 vp )
{
	planes[0] = vp[0] + vp[3]; // left
	planes[1] = -vp[0] + vp[3]; // right
	planes[2] = vp[1] + vp[3]; // bottom
	planes[3] = -vp[1] + vp[3]; // top
	planes[4] = vp[2] + vp[3]; // near
	planes[5] = -vp[2] + vp[3]; // far

	for ( int i = 0; i < 6; ++i )
	{
		float lenRcp = 1.0f / length( planes[i].xyz );
		planes[i] *= lenRcp;
	}
}


//void buildFrustum( out Frustum frustum, const uint3 subdiv, uint3 cellIndex, float4x4 baseProj, float4x4 viewMatrix, float nearPlane, float farPlane )
//{
//	float n = nearPlane * pow( farPlane / nearPlane, (float)cellIndex.z / subdiv.z );
//	float f = nearPlane * pow( farPlane / nearPlane, (float)(cellIndex.z + 1) / subdiv.z );
//	float a = f / ( n - f );
//	float b = n * f / ( n - f );
//
//	float tileScaleX = subdiv.x;
//	float tileScaleY = subdiv.y;
//
//	uint subFrustumX = cellIndex.x;
//	uint subFrustumY = cellIndex.y;
//
//	float tileBiasX = subFrustumX * 2 - tileScaleX + 1;
//	float tileBiasY = subFrustumY * 2 - tileScaleY + 1;
//
//	float4x4 subProj = {
//		baseProj[0][0] * tileScaleX,		0,									tileBiasX,			0,
//		0,									baseProj[1][1] * -tileScaleY,		tileBiasY,			0,
//		0,									0,									a,					b,
//		0,									0,									-1,					0
//	};
//	float4x4 viewProj = mul( subProj, viewMatrix );
//
//	extractFrustumPlanes( frustum.planes, viewProj );
//}


void buildFrustum( out Frustum frustum, const uint3 cellCount, uint3 cellIndex, float2 tanHalfFovRcp, float4x4 viewMatrix, float nearPlane, float farPlaneOverNearPlane )
{
	//float n = nearPlane * pow( farPlaneOverNearPlane, (float)cellIndex.z / cellCount.z );
	//float f = nearPlane * pow( farPlaneOverNearPlane, (float)( cellIndex.z + 1 ) / cellCount.z );
	float n = 1;
	float f = 20;
	float nmf = 1.0f / ( n - f );
	float a = f * nmf;
	float b = n * f * nmf;

	float tileScaleX = cellCount.x;
	float tileScaleY = cellCount.y;

	uint subFrustumX = cellIndex.x;
	uint subFrustumY = cellIndex.y;

	float tileBiasX = subFrustumX * 2 - tileScaleX + 1;
	float tileBiasY = subFrustumY * 2 - tileScaleY + 1;

	float4x4 subProj = {
		tanHalfFovRcp.x * tileScaleX,		0,									tileBiasX,			0,
		0,									tanHalfFovRcp.y * -tileScaleY,		tileBiasY,			0,
		0,									0,									a,					b,
		0,									0,									-1,					0
	};
	float4x4 viewProj = mul( subProj, viewMatrix );

	extractFrustumPlanes( frustum.planes, viewProj );
}


// Real-Time Rendering, 3rd Edition - 16.10.1, 16.14.3 (p. 755, 777)
// pico warning!!!! picoViewFrustum has planes pointing inwards
// this test assumes opposite
// to use it with picoViewFrustum one has to change test from if ( s > e ) to if ( s + e < 0 )
uint frustumOBBIntersectSimpleOptimized( float4 frustumPlanes[6], float3 boxPosition, float3 boxHalfSize, float3 boxX, float3 boxY, float3 boxZ )
{
	[unroll]
	for ( int i = 0; i < 6; ++i )
	{
		float3 n = frustumPlanes[i].xyz;
		float e = boxHalfSize.x*abs( dot( n, boxX ) )
			+ boxHalfSize.y*abs( dot( n, boxY ) )
			+ boxHalfSize.z*abs( dot( n, boxZ ) );
		float s = dot( boxPosition, n ) + frustumPlanes[i].w;
		if ( s + e < 0 )
			return 0;
	}
	return 1;
}


uint TestDecalVolumeFrustum( in DecalVolume dv, in Frustum frustum )
{
	return frustumOBBIntersectSimpleOptimized( frustum.planes, dv.position.xyz, dv.halfSize.xyz, dv.x.xyz, dv.y.xyz, dv.z.xyz );
}


[numthreads( 256, 1, 1 )]
void DecalTilingClearHeader( uint3 dtid : SV_DispatchThreadID )
{
	outDecalsPerCell[dtid.x] = 0;
}


[numthreads( 1, 1, 1 )]
void DecalTilingCopyIndirectArgs()
{
	uint n = inCellIndirectionCount[0];
	outIndirectArgs.Store3( 0, uint3( n, 1, 1 ) );
}


#if DECAL_TILING_PASS_NO == 0

#define DECAL_VOLUME_CLUSTER_FIRST_PASS				(DECAL_TILING_PASS_NO == 0)
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		32

#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalTilingPass0( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	uint flatCellIndex = DecalVolume_GetCellFlatIndex( uint3( cellID.xy, 0 ), uint3( cellCountA.xy, 1 ) );
	DecalVisibilityGeneric( cellThreadID, flatCellIndex, 0, maxCountPerCell.x, maxCountPerCell.y );
}
#endif // #if DECAL_TILING_PASS_NO == 0

#if DECAL_TILING_PASS_NO == 1

#define DECAL_VOLUME_CLUSTER_LAST_PASS				(DECAL_TILING_PASS_NO == DECAL_VOLUME_TILING_LAST_PASS)
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		32

#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalTilingPass1( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	CellIndirection ci = inCellIndirection[cellID.x];
	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.parentCellIndex, maxCountPerCell.x, maxCountPerCell.y );
}

#endif // #if DECAL_TILING_PASS_NO == 1



#if DECAL_TILING_PASS_NO == 2

#define DECAL_VOLUME_CLUSTER_LAST_PASS				(DECAL_TILING_PASS_NO == DECAL_VOLUME_TILING_LAST_PASS)
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		32

#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalTilingPass2( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	CellIndirection ci = inCellIndirection[cellID.x];
	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.parentCellIndex, maxCountPerCell.x, maxCountPerCell.y );
}

#endif // #if DECAL_TILING_PASS_NO == 2


#if DECAL_TILING_PASS_NO == 3

#define DECAL_VOLUME_CLUSTER_LAST_PASS				(DECAL_TILING_PASS_NO == DECAL_VOLUME_TILING_LAST_PASS)
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		32

#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalTilingPass3( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	CellIndirection ci = inCellIndirection[cellID.x];
	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.parentCellIndex, maxCountPerCell.x, maxCountPerCell.y );
}

#endif // #if DECAL_TILING_PASS_NO == 3


#if DECAL_TILING_PASS_NO == 4

#define DECAL_VOLUME_CLUSTER_LAST_PASS				(DECAL_TILING_PASS_NO == DECAL_VOLUME_TILING_LAST_PASS)
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		32

#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalTilingPass4( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	CellIndirection ci = inCellIndirection[cellID.x];
	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.parentCellIndex, maxCountPerCell.x, maxCountPerCell.y );
}

#endif // #if DECAL_TILING_PASS_NO == 4



//#if DECAL_TILING_PASS_NO == 3
//
//#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_PASS3_NUM_THREADS
//
//#include "gpuClustering_visibility.hlsl"
//
//[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
//void DecalTilingPass3( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
//{
//	uint3 numGridCells = uint3( DECAL_VOLUME_CLUSTER_PASS3_CELLS_X, DECAL_VOLUME_CLUSTER_PASS3_CELLS_Y, DECAL_VOLUME_CLUSTER_PASS3_CELLS_Z );
//	DecalVisibilityGeneric( cellThreadID, cellID, numGridCells, DECAL_VOLUME_CLUSTER_PASS3_MAX_DECALS_PER_CELL, DECAL_VOLUME_CLUSTER_PASS2_MAX_DECALS_PER_CELL );
//}
//
//#endif // #if DECAL_TILING_PASS_NO == 3
//
//
//
//#if DECAL_TILING_PASS_NO == 4
//
//#define DECAL_VOLUME_CLUSTER_LAST_PASS				1
//#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_PASS4_NUM_THREADS
//
//#include "gpuClustering_visibility.hlsl"
//
//[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
//void DecalTilingPass4( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
//{
//	uint3 numGridCells = uint3( DECAL_VOLUME_CLUSTER_PASS4_CELLS_X, DECAL_VOLUME_CLUSTER_PASS4_CELLS_Y, DECAL_VOLUME_CLUSTER_PASS4_CELLS_Z );
//	DecalVisibilityGeneric( cellThreadID, cellID, numGridCells, DECAL_VOLUME_CLUSTER_PASS4_MAX_DECALS_PER_CELL, DECAL_VOLUME_CLUSTER_PASS3_MAX_DECALS_PER_CELL );
//}

//#endif // #if DECAL_TILING_PASS_NO == 4
