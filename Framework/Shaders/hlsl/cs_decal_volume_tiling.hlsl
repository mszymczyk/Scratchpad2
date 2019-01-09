#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	cs_decal_volume_clear_header = {
		ComputeProgram = "cs_decal_volume_clear_header";
	}

	cs_decal_volume_indirect_args = {
		ComputeProgram = "cs_decal_volume_indirect_args";
	}

	cs_decal_volume_indirect_args_last_pass = {
		ComputeProgram = "cs_decal_volume_indirect_args_last_pass";
	}

	DecalVolumeTilingFirstPass = {
		ComputeProgram = {
			EntryName = "DecalVolumeTilingFirstPass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_FIRST_PASS = ( "1" );
				DECAL_VOLUME_INTERSECTION_METHOD = ( "0", "1" );
			}
		}
	}

	DecalVolumeTilingMidPass = {
		ComputeProgram = {
			EntryName = "DecalVolumeTilingMidPass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_MID_PASS = ( "1" );
				DECAL_VOLUME_INTERSECTION_METHOD = ( "0", "1" );
				//DECAL_VOLUME_CLUSTER_SUB_WORD = ( "0", "2", "4", "8", "16" );
			}
		}
	}

	DecalVolumeTilingLastPass = {
		ComputeProgram = {
			EntryName = "DecalVolumeTilingLastPass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_LAST_PASS = ( "1" );
				DECAL_VOLUME_INTERSECTION_METHOD = ( "0", "1" );
			}
		}
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "cs_decal_volume_common.hlsl"

#define DECAL_VOLUME_CLUSTER_3D								0
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_FIRST_PASS		128
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_LAST_PASS			32
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS		32


[numthreads( 256, 1, 1 )]
void cs_decal_volume_clear_header( uint3 dtid : SV_DispatchThreadID )
{
	outDecalVolumeIndices[dtid.x] = 0;
}


[numthreads( 1, 1, 1 )]
void cs_decal_volume_indirect_args()
{
	uint n = inCellIndirectionCount[0];
	outIndirectArgs.Store3( 0, uint3( n, 1, 1 ) );
}


[numthreads( 1, 1, 1 )]
void cs_decal_volume_indirect_args_last_pass()
{
	uint n = inCellIndirectionCount[0];
	outIndirectArgs.Store3( 0, uint3( ( n + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS ) / DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS, 1, 1 ) );
}



#if DECAL_VOLUME_CLUSTER_FIRST_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_FIRST_PASS

#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalVolumeTilingFirstPass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	uint flatCellIndex = DecalVolume_GetCellFlatIndex( uint3( cellID.xy, 0 ), uint3( dvCellCount.xy, 1 ) );
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( cellThreadID, flatCellIndex, decalCountInFrustum, decalCountInFrustum, maxCountPerCell.x, 0, DECAL_VOLUME_INTERSECTION_METHOD );
}
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS



#if DECAL_VOLUME_CLUSTER_MID_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_LAST_PASS

#if DECAL_VOLUME_CLUSTER_SUB_WORD == 0
#include "cs_decal_volume_impl.hlsl"
#else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 0
#define DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL	DECAL_VOLUME_CLUSTER_SUB_WORD
#define DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP	(32 / DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL)
#include "cs_decal_volume_impl_subword.hlsl"
#endif // #else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 0

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalVolumeTilingMidPass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	uint decalCountInFrustum = inDecalVolumesCount[0];

#if DECAL_VOLUME_CLUSTER_SUB_WORD == 0
	CellIndirection ci = inCellIndirection[cellID.x];
	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, DECAL_VOLUME_INTERSECTION_METHOD );
#else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 0
	uint cellIndex = cellID.x * DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP + cellThreadID.x / DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL;
	CellIndirection ci = inCellIndirection[cellIndex];
	DecalVisibilitySubGroup( cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, DECAL_VOLUME_INTERSECTION_METHOD );
#endif // #else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 0
}

#endif // #if DECAL_VOLUME_CLUSTER_MID_PASS



#if DECAL_VOLUME_CLUSTER_LAST_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS

#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalVolumeTilingLastPass( uint3 dtid : SV_DispatchThreadID )
{
	uint cellIndex = dtid.x;
	uint nCells = inCellIndirectionCount[0];
	if ( cellIndex < nCells )
	{
		uint decalCountInFrustum = inDecalVolumesCount[0];
		CellIndirection ci = inCellIndirection[cellIndex];
		DecalVisibilityOnThreadPerCell( ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, DECAL_VOLUME_INTERSECTION_METHOD );
	}
}

#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS
