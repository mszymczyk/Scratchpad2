#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	DecalTilingClearHeader = {
		ComputeProgram = "DecalTilingClearHeader";
	}

	DecalTilingCopyIndirectArgs = {
		ComputeProgram = "DecalTilingCopyIndirectArgs";
	}

	DecalTilingCopyIndirectArgsLastPass = {
		ComputeProgram = "DecalTilingCopyIndirectArgsLastPass";
	}

	DecalVolumeClusteringFirstPass = {
		ComputeProgram = {
			EntryName = "DecalVolumeClusteringFirstPass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_FIRST_PASS = ( "1" );
				INTERSECTION_METHOD = ( "0", "1" );
			}
		}
	}

	DecalVolumeClusteringMidPass = {
		ComputeProgram = {
			EntryName = "DecalVolumeClusteringMidPass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_MID_PASS = ( "1" );
				INTERSECTION_METHOD = ( "0", "1" );
			}
		}
	}

	DecalVolumeClusteringLastPass = {
		ComputeProgram = {
			EntryName = "DecalVolumeClusteringLastPass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_LAST_PASS = ( "1" );
				INTERSECTION_METHOD = ( "0", "1" );
			}
		}
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "cs_decal_volume_common.hlsl"

#define DECAL_VOLUME_CLUSTERING_3D								1
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_FIRST_PASS		128
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_PASS			32
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS		32


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


[numthreads( 1, 1, 1 )]
void DecalTilingCopyIndirectArgsLastPass()
{
	uint n = inCellIndirectionCount[0];
	outIndirectArgs.Store3( 0, uint3( (n + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS ) / DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS, 1, 1 ) );
}


#if DECAL_VOLUME_CLUSTER_FIRST_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_FIRST_PASS


#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalVolumeClusteringFirstPass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	uint flatCellIndex = DecalVolume_GetCellFlatIndex( uint3( cellID.xyz ), uint3( cellCountA.xyz ) );
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( cellThreadID, flatCellIndex, decalCountInFrustum, decalCountInFrustum, maxCountPerCell.x, 0, INTERSECTION_METHOD );// , maxCountPerCell.y );
}
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS


#if DECAL_VOLUME_CLUSTER_MID_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_PASS


#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalVolumeClusteringMidPass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	CellIndirection ci = inCellIndirection[cellID.x];
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );// , maxCountPerCell.y );
}
#endif // #if DECAL_VOLUME_CLUSTER_MID_PASS


#if DECAL_VOLUME_CLUSTER_LAST_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS

#include "cs_decal_volume_impl.hlsl"

//[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
//void DecalVolumeClusteringLastPass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
//{
//	CellIndirection ci = inCellIndirection[cellID.x];
//	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.parentCellIndex, maxCountPerCell.x, maxCountPerCell.y );
//}

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalVolumeClusteringLastPass( uint3 dtid : SV_DispatchThreadID )
{
	uint cellIndex = dtid.x;
	uint nCells = inCellIndirectionCount[0];
	if ( cellIndex < nCells )
	{
		uint decalCountInFrustum = inDecalVolumesCount[0];
		CellIndirection ci = inCellIndirection[cellIndex];
		DecalVisibilityOnThreadPerCell( ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );// , maxCountPerCell.y );
	}
}
#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS



//#if DECAL_VOLUME_CLUSTERING_PASS_NO == 3
//
//#define DECAL_VOLUME_CLUSTER_FIRST_PASS				(DECAL_VOLUME_CLUSTERING_PASS_NO == 0)
//#define DECAL_VOLUME_CLUSTER_LAST_PASS				(DECAL_VOLUME_CLUSTERING_PASS_NO == DECAL_VOLUME_CLUSTERING_LAST_PASS)
//#define DECAL_VOLUME_CLUSTERING_3D					1
//#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		64
//
//
//#include "cs_decal_volume_impl.hlsl"
//
////[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
////void DecalVolumeClusteringPass3( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
////{
////	CellIndirection ci = inCellIndirection[cellID.x];
////	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.parentCellIndex, maxCountPerCell.x, maxCountPerCell.y );
////}
//
//[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
//void DecalVolumeClusteringPass3( uint3 dtid : SV_DispatchThreadID )
//{
//	uint cellIndex = dtid.x;
//	uint nCells = inCellIndirectionCount[0];
//	if ( cellIndex < nCells )
//	{
//		CellIndirection ci = inCellIndirection[cellIndex];
//		DecalVisibilityOnThreadPerCell( ci.cellIndex, ci.parentCellIndex, maxCountPerCell.x, maxCountPerCell.y );
//	}
//}
//#endif // #if DECAL_VOLUME_CLUSTERING_PASS_NO == 3
//
//
//
//#if DECAL_VOLUME_CLUSTERING_PASS_NO == 4
//
//#define DECAL_VOLUME_CLUSTER_FIRST_PASS				(DECAL_VOLUME_CLUSTERING_PASS_NO == 0)
//#define DECAL_VOLUME_CLUSTER_LAST_PASS				(DECAL_VOLUME_CLUSTERING_PASS_NO == DECAL_VOLUME_CLUSTERING_LAST_PASS)
//#define DECAL_VOLUME_CLUSTERING_3D					1
//#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		32
//
//
//#include "cs_decal_volume_impl.hlsl"
//
////[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
////void DecalVolumeClusteringPass4( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
////{
////	CellIndirection ci = inCellIndirection[cellID.x];
////	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.parentCellIndex, maxCountPerCell.x, maxCountPerCell.y );
////}
//
//[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
//void DecalVolumeClusteringPass4( uint3 dtid : SV_DispatchThreadID )
//{
//	uint cellIndex = dtid.x;
//	uint nCells = inCellIndirectionCount[0];
//	if ( cellIndex < nCells )
//	{
//		CellIndirection ci = inCellIndirection[cellIndex];
//		DecalVisibilityOnThreadPerCell( ci.cellIndex, ci.parentCellIndex, maxCountPerCell.x, maxCountPerCell.y );
//	}
//}
//#endif // #if DECAL_VOLUME_CLUSTERING_PASS_NO == 4
