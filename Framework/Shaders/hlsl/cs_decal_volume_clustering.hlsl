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

	cs_decal_volume_indirect_args_buckets = {
		ComputeProgram = "cs_decal_volume_indirect_args_buckets";
	}

	cs_decal_volume_indirect_args_buckets_merged = {
		ComputeProgram = "cs_decal_volume_indirect_args_buckets_merged";
	}

	cs_decal_volume_assign_slot = {
		ComputeProgram = "cs_decal_volume_assign_slot";
	}

	cs_decal_volume_cluster_first_pass = {
		ComputeProgram = {
			EntryName = "cs_decal_volume_cluster_first_pass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_FIRST_PASS = ( "1" );
				DECAL_VOLUME_INTERSECTION_METHOD = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_BUCKETS = ( "0", "1" );
			}
		}
	}

	cs_decal_volume_cluster_mid_pass = {
		ComputeProgram = {
			EntryName = "cs_decal_volume_cluster_mid_pass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_MID_PASS = ( "1" );
				DECAL_VOLUME_INTERSECTION_METHOD = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_BUCKETS = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_SUB_WORD = ( "1", "2", "4", "8", "16", "32", "64", "-1", "-2" );
			}
		}
	}

	cs_decal_volume_cluster_last_pass = {
		ComputeProgram = {
			EntryName = "cs_decal_volume_cluster_mid_pass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_LAST_PASS = ( "1" );
				DECAL_VOLUME_INTERSECTION_METHOD = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_BUCKETS = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_SUB_WORD = ( "1", "2", "4", "8", "16", "32", "64", "-1", "-2" );
			}
		}
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#define DECAL_VOLUME_CLUSTERING_3D								1
#define DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION			1
//#define DECAL_VOLUME_INTERSECTION_METHOD						0

#include "cs_decal_volume_common.hlsl"

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_FIRST_PASS		128
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_PASS			64
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS		64

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
	outIndirectArgs.Store3( 0, uint3( (n + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS ) / DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS, 1, 1 ) );
}


[numthreads( 1, 1, 1 )]
void cs_decal_volume_indirect_args_buckets()
{
#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
	uint mult = 1;
#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
	uint mult = 1;
#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
	uint b1  = inCellIndirectionCount[0] * mult;
	uint b2  = inCellIndirectionCount[1] * mult;
	uint b4  = inCellIndirectionCount[2] * mult;
	uint b8  = inCellIndirectionCount[3] * mult;
	uint b16 = inCellIndirectionCount[4] * mult;
	uint b32 = inCellIndirectionCount[5] * mult;
	uint b64 = inCellIndirectionCount[6] * mult;

	uint n1  = b1  ? ( b1  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  ) : 0;
	uint n2  = b2  ? ( b2  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  ) : 0;
	uint n4  = b4  ? ( b4  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  ) : 0;
	uint n8  = b8  ? ( b8  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  ) : 0;
	uint n16 = b16 ? ( b16 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 ) : 0;
	uint n32 = b32 ? ( b32 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 ) : 0;
	uint n64 = b64 ? ( b64 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 64 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 64 ) : 0;

	outIndirectArgs.Store3( 12 * 0, uint3( n1,  1, 1 ) );
	outIndirectArgs.Store3( 12 * 1, uint3( n2,  1, 1 ) );
	outIndirectArgs.Store3( 12 * 2, uint3( n4,  1, 1 ) );
	outIndirectArgs.Store3( 12 * 3, uint3( n8,  1, 1 ) );
	outIndirectArgs.Store3( 12 * 4, uint3( n16, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 5, uint3( n32, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 6, uint3( n64, 1, 1 ) );
}


[numthreads( 1, 1, 1 )]
void cs_decal_volume_indirect_args_buckets_merged()
{
#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
	uint mult = 1;
#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
	uint mult = 1;
#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
	uint b1  = inCellIndirectionCount[0] * mult;
	uint b2  = inCellIndirectionCount[1] * mult;
	uint b4  = inCellIndirectionCount[2] * mult;
	uint b8  = inCellIndirectionCount[3] * mult;
	uint b16 = inCellIndirectionCount[4] * mult;
	uint b32 = inCellIndirectionCount[5] * mult;
	uint b64 = inCellIndirectionCount[6] * mult;

	uint n1  = b1  ? ( b1  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  ) : 0;
	uint n2  = b2  ? ( b2  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  ) : 0;
	uint n4  = b4  ? ( b4  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  ) : 0;
	uint n8  = b8  ? ( b8  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  ) : 0;
	uint n16 = b16 ? ( b16 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 ) : 0;
	uint n32 = b32 ? ( b32 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 ) : 0;
	uint n64 = b64 ? ( b64 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 64 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 64 ) : 0;

	uint n = n1 + n2 + n4 + n8 + n16 + n32 + n64;
	outIndirectArgs.Store3( 12 * 0, uint3( n, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 1, uint3( 0, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 2, uint3( 0, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 3, uint3( 0, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 4, uint3( 0, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 5, uint3( 0, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 6, uint3( 0, 1, 1 ) );
}


void DecalVolume_GetBucket( uint groupIndex, out uint bucket, out uint firstGroup )
{
#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
	uint mult = 1;
#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
	uint mult = 1;
#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1
	uint b1  = inCellIndirectionCount[0] * mult;
	uint b2  = inCellIndirectionCount[1] * mult;
	uint b4  = inCellIndirectionCount[2] * mult;
	uint b8  = inCellIndirectionCount[3] * mult;
	uint b16 = inCellIndirectionCount[4] * mult;
	uint b32 = inCellIndirectionCount[5] * mult;
	uint b64 = inCellIndirectionCount[6] * mult;

	uint n1  = b1  ? ( b1  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  ) : 0;
	uint n2  = b2  ? ( b2  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  ) : 0;
	uint n4  = b4  ? ( b4  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  ) : 0;
	uint n8  = b8  ? ( b8  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  ) : 0;
	uint n16 = b16 ? ( b16 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 ) : 0;
	uint n32 = b32 ? ( b32 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 ) : 0;
	uint n64 = b64 ? ( b64 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 64 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 64 ) : 0;

	uint s0 = n1;
	uint s1 = n1 + n2;
	uint s2 = n1 + n2 + n4;
	uint s3 = n1 + n2 + n4 + n8;
	uint s4 = n1 + n2 + n4 + n8 + n16;
	uint s5 = n1 + n2 + n4 + n8 + n16 + n32;
	uint s6 = n1 + n2 + n4 + n8 + n16 + n32 + n64;

	if ( groupIndex >= s6 )
	{
		bucket = 0xff;
		firstGroup = 0xffffffff;
	}
	else if ( groupIndex >= s5 )
	{
		bucket = 6;
		firstGroup = n1 + n2 + n4 + n8 + n16 + n32;
	}
	else if ( groupIndex >= s4 )
	{
		bucket = 5;
		firstGroup = n1 + n2 + n4 + n8 + n16;
	}
	else if ( groupIndex >= s3 )
	{
		bucket = 4;
		firstGroup = n1 + n2 + n4 + n8;
	}
	else if ( groupIndex >= s2 )
	{
		bucket = 3;
		firstGroup = n1 + n2 + n4;
	}
	else if ( groupIndex >= s1 )
	{
		bucket = 2;
		firstGroup = n1 + n2;
	}
	else if ( groupIndex >= s0 )
	{
		bucket = 1;
		firstGroup = n1;
	}
	else // if ( groupIndex >= s0 )
	{
		bucket = 0;
		firstGroup = 0;
	}
}


void DecalVolume_ReadBucket( uint groupIndex, out uint bucket, out uint firstGroup )
{
	GroupToBucket gtb = inGroupToBucket[groupIndex];
	DecalVolume_UnpackGroupToBucket( gtb, bucket, firstGroup );
}


[numthreads( 64, 1, 1 )]
void cs_decal_volume_assign_slot( uint3 dtid : SV_DispatchThreadID )
{
	uint bucket;
	uint firstGroup;
	DecalVolume_GetBucket( dtid.x, bucket, firstGroup );

	GroupToBucket gtb;
	DecalVolume_PackGroupToBucket( bucket, firstGroup, gtb );
	outGroupToBucket[dtid.x] = gtb;
}


#if DECAL_VOLUME_CLUSTER_FIRST_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_FIRST_PASS

#include "cs_decal_volume_impl.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void cs_decal_volume_cluster_first_pass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	uint flatCellIndex = DecalVolume_EncodeCell3D( cellID.xyz );
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( cellThreadID, flatCellIndex, decalCountInFrustum, decalCountInFrustum, 0 );
}
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS


#if DECAL_VOLUME_CLUSTER_MID_PASS || DECAL_VOLUME_CLUSTER_LAST_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_PASS

#if DECAL_VOLUME_CLUSTER_SUB_WORD == 1
#include "cs_decal_volume_impl_one_thread_per_cell.hlsl"
#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -1 || DECAL_VOLUME_CLUSTER_SUB_WORD == -2
#include "cs_decal_volume_impl.hlsl"
#define DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP
#include "cs_decal_volume_impl_subword.hlsl"
#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32 || DECAL_VOLUME_CLUSTER_SUB_WORD == 64
#include "cs_decal_volume_impl.hlsl"
#else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 32
#define DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP
#include "cs_decal_volume_impl_subword.hlsl"
#endif // #else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 0


CellIndirection DecalVolumeGetCellIndirection( uint cellIndex, uint cellBucket )
{
#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

	// Expands single cell indirection into 8 cell indirections

	uint dataIndex = cellIndex / 8;
	uint childIndex = cellIndex % 8;

	CellIndirection ci = inCellIndirection[dataIndex + cellBucket * DecalVolume_GetMaxPrevOutCellIndirections()];

	uint3 parentCellXYZ = DecalVolume_DecodeCell3D( ci.cellIndex );

	uint slice = childIndex / 4;
	uint sliceSize = dvCellCount.x * dvCellCount.y;
	uint tile = childIndex % 4;
	uint row = tile / 2;
	uint col = tile % 2;
	//ci.cellIndex = DecalVolume_EncodeCell3D( uint3( parentCellXYZ.x * 2 + col, parentCellXYZ.y * 2 + row, parentCellXYZ.z * 2 + slice ) );
	ci.cellIndex = DecalVolume_EncodeCell3D( uint3( mad24( parentCellXYZ.x, 2, col ), mad24( parentCellXYZ.y, 2, row ), mad24( parentCellXYZ.z, 2, slice ) ) );

#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

	CellIndirection ci = inCellIndirection[cellIndex + cellBucket * DecalVolume_CellCountCurrentPass()];

#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

	return ci;
}


[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void cs_decal_volume_cluster_mid_pass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID, uint3 dtid : SV_DispatchThreadID )
{
#if DECAL_VOLUME_CLUSTER_SUB_WORD == 1

	// Every thread processes one cell
	uint cellIndex = dtid.x;
	uint nCells = inCellIndirectionCount[0];
	if ( cellIndex < nCells )
	{
		uint decalCountInFrustum = inDecalVolumesCount[0];
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
		DecalVisibilityOnThreadPerCell( ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	}

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -1

	//uint bucket = DecalVolume_GetBucketIndex();
	//uint numThreadsPerCell = 1 << bucket;

	//uint nCells = inCellIndirectionCount[bucket];
	//uint decalCountInFrustum = inDecalVolumesCount[0];

	//if ( bucket == 5 )
	//{
	//	uint cellIndex = cellID.x;
	//	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
	//	DecalVisibilitySubWordLoop( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	//}
	//else
	//{
	//	uint cellIndex = dtid.x / numThreadsPerCell;
	//	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
	//	DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	//}

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -2

	uint bucket;
	uint firstGroup;
	DecalVolume_GetBucket( cellID.x, bucket, firstGroup );
	//DecalVolume_ReadBucket( cellID.x, bucket, firstGroup );
	uint numThreadsPerCell = 1 << bucket;

	uint nCells = inCellIndirectionCount[bucket];
	uint decalCountInFrustum = inDecalVolumesCount[0];

	if ( bucket == 6 )
	{
		uint cellIndex = cellID.x - firstGroup;
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
		DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
		// causes GPU hang... DecalVisibilitySubWordLoop( 64, true, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	}
	else
	{
		uint cellIndex = ( dtid.x - firstGroup * 64 ) / numThreadsPerCell;
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
		DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	}

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32

//	// 32 threads process one cell
//	uint cellIndex = cellID.x;
//#if DECAL_VOLUME_CLUSTER_BUCKETS
//	uint bucket = 5;
//	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
//#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
//	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
//#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
//	uint decalCountInFrustum = inDecalVolumesCount[0];
//	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 64

	// 32 threads process one cell
	uint cellIndex = cellID.x;
#if DECAL_VOLUME_CLUSTER_BUCKETS
	uint bucket = 6;
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );

#else // #elif DECAL_VOLUME_CLUSTER_SUB_WORD == 64

//	// DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL threads process one cell
//	// DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP processed in parallel
//	const uint numThreadsPerCell = DECAL_VOLUME_CLUSTER_SUB_WORD;
//
//	uint bucket = firstbitlow( numThreadsPerCell );
//	uint nCells = inCellIndirectionCount[bucket];
//	uint cellIndex = dtid.x / numThreadsPerCell;
//
//	uint decalCountInFrustum = inDecalVolumesCount[0];
//#if DECAL_VOLUME_CLUSTER_BUCKETS
//	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
//#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
//	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
//#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
//	DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );

#endif // #else // #elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32
}
#endif // #if DECAL_VOLUME_CLUSTER_MID_PASS || DECAL_VOLUME_CLUSTER_LAST_PASS
