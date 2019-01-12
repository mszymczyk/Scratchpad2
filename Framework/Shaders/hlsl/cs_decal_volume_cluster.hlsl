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

	cs_decal_volume_assign_bucket = {
		ComputeProgram = "cs_decal_volume_assign_bucket";
	}

	cs_decal_volume_cluster_single_pass = {
		ComputeProgram = {
			EntryName = "cs_decal_volume_cluster_first_pass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_SINGLE_PASS = ( "1" );
				DECAL_VOLUME_CLUSTER_FIRST_PASS = ( "1" );
				DECAL_VOLUME_CLUSTER_LAST_PASS = ( "1" );
				DECAL_VOLUME_INTERSECTION_METHOD = ( "1" );
				DECAL_VOLUME_CLUSTER_BUCKETS = ( "0" );
			}
		}
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

#define DECAL_VOLUME_CLUSTER_GCN								0

#define DECAL_VOLUME_CLUSTER_3D									1
#define DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION			1
//#define DECAL_VOLUME_INTERSECTION_METHOD						0

#include "cs_decal_volume_util.hlsl"

#if DECAL_VOLUME_CLUSTER_GCN
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_FIRST_PASS		64
#else // #if DECAL_VOLUME_CLUSTER_GCN
#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_FIRST_PASS		128
#endif // #else // #if DECAL_VOLUME_CLUSTER_GCN

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_LAST_PASS	64

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
	outIndirectArgs.Store3( 0, uint3( (n + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_LAST_PASS - 1 ) / DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_LAST_PASS, 1, 1 ) );
}


void DecalVolume_GetBuckets( uint numThreadsPerGroup, out uint n1, out uint n2, out uint n4, out uint n8, out uint n16, out uint n32, out uint n64 )
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

	n1  = b1  ? ( b1  + numThreadsPerGroup / 1  - 1 ) / ( numThreadsPerGroup / 1 )  : 0;
	n2  = b2  ? ( b2  + numThreadsPerGroup / 2  - 1 ) / ( numThreadsPerGroup / 2 )  : 0;
	n4  = b4  ? ( b4  + numThreadsPerGroup / 4  - 1 ) / ( numThreadsPerGroup / 4 )  : 0;
	n8  = b8  ? ( b8  + numThreadsPerGroup / 8  - 1 ) / ( numThreadsPerGroup / 8 )  : 0;
	n16 = b16 ? ( b16 + numThreadsPerGroup / 16 - 1 ) / ( numThreadsPerGroup / 16 ) : 0;
	n32 = b32 ? ( b32 + numThreadsPerGroup / 32 - 1 ) / ( numThreadsPerGroup / 32 ) : 0;
	n64 = b64 ? ( b64 + numThreadsPerGroup / 64 - 1 ) / ( numThreadsPerGroup / 64 ) : 0;
}

[numthreads( 1, 1, 1 )]
void cs_decal_volume_indirect_args_buckets()
{
	uint n1, n2, n4, n8, n16, n32, n64;
	DecalVolume_GetBuckets( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_LAST_PASS, n1, n2, n4, n8, n16, n32, n64 );

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
	uint n1, n2, n4, n8, n16, n32, n64;
	DecalVolume_GetBuckets( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_LAST_PASS, n1, n2, n4, n8, n16, n32, n64 );

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
	uint n1, n2, n4, n8, n16, n32, n64;
	DecalVolume_GetBuckets( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_LAST_PASS, n1, n2, n4, n8, n16, n32, n64 );

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
void cs_decal_volume_assign_bucket( uint3 dtid : SV_DispatchThreadID )
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

#include "cs_decal_volume_cluster_impl_generic.hlsl"

[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void cs_decal_volume_cluster_first_pass( uint3 groupThreadID : SV_GroupThreadID, uint3 groupID : SV_GroupID )
{
	uint flatCellIndex = DecalVolume_EncodeCell3D( groupID.xyz );
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( groupThreadID, flatCellIndex, decalCountInFrustum, decalCountInFrustum, 0 );
}
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS


#if ( DECAL_VOLUME_CLUSTER_MID_PASS || DECAL_VOLUME_CLUSTER_LAST_PASS ) && !DECAL_VOLUME_CLUSTER_SINGLE_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_LAST_PASS

#if DECAL_VOLUME_CLUSTER_SUB_WORD == 1
#include "cs_decal_volume_cluster_impl_one_thread_per_cell.hlsl"
#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -1 || DECAL_VOLUME_CLUSTER_SUB_WORD == -2
#include "cs_decal_volume_cluster_impl_generic.hlsl"
#define DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP
#include "cs_decal_volume_cluster_impl_subgroup.hlsl"
#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32 || DECAL_VOLUME_CLUSTER_SUB_WORD == 64
#include "cs_decal_volume_cluster_impl_generic.hlsl"
#else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 32
#define DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP
#include "cs_decal_volume_cluster_impl_subgroup.hlsl"
#endif // #else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 0


CellIndirection DecalVolumeGetCellIndirection( uint cellIndex, uint cellBucket )
{
#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

	// Expands single cell indirection into 8 cell indirections

	uint dataIndex = cellIndex / 8;
	uint childIndex = cellIndex % 8;

	CellIndirection ci = inCellIndirection[ safe_mad24( cellBucket, DecalVolume_GetMaxPrevOutCellIndirections(), dataIndex ) ];

	uint3 parentCellXYZ = DecalVolume_DecodeCell3D( ci.cellIndex );

	uint slice = childIndex / 4;
	uint sliceSize = safe_mul24( dvCellCount.x, dvCellCount.y );
	uint tile = childIndex % 4;
	uint row = tile / 2;
	uint col = tile % 2;
	ci.cellIndex = DecalVolume_EncodeCell3D( uint3( safe_mad24( parentCellXYZ.x, 2, col ), safe_mad24( parentCellXYZ.y, 2, row ), safe_mad24( parentCellXYZ.z, 2, slice ) ) );

#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

	CellIndirection ci = inCellIndirection[safe_mad24( cellBucket, DecalVolume_CellCountCurrentPass(), cellIndex ) ];

#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

	return ci;
}


[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void cs_decal_volume_cluster_mid_pass( uint3 groupThreadID : SV_GroupThreadID, uint3 groupID : SV_GroupID, uint3 dtid : SV_DispatchThreadID )
{

#if DECAL_VOLUME_CLUSTER_SUB_WORD == -1

	uint bucket = DecalVolume_GetBucketIndex();
	uint numThreadsPerCell = 1 << bucket;

	uint nCells = inCellIndirectionCount[bucket];
	uint decalCountInFrustum = inDecalVolumesCount[0];

	if ( bucket == 6 )
	{
		uint cellIndex = groupID.x;
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
		DecalVisibilityGeneric( groupThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	}
	else
	{
		uint cellIndex = dtid.x / numThreadsPerCell;
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
		DecalVisibilitySubGroup( numThreadsPerCell, bucket, cellIndex < nCells, groupThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	}

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -2

	uint bucket;
	uint firstGroup;
	DecalVolume_GetBucket( groupID.x, bucket, firstGroup );
	// reading it from mem seems to be slower...
	//DecalVolume_ReadBucket( cellID.x, bucket, firstGroup );
	uint numThreadsPerCell = 1 << bucket;

	uint nCells = inCellIndirectionCount[bucket];
	uint decalCountInFrustum = inDecalVolumesCount[0];

	if ( bucket == 6 )
	{
		uint cellIndex = groupID.x - firstGroup;
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
		DecalVisibilityGeneric( groupThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
		// causes GPU hang... DecalVisibilitySubWordLoop( 64, true, groupThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	}
	else
	{
		uint cellIndex = ( dtid.x - firstGroup * 64 ) / numThreadsPerCell;
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
		DecalVisibilitySubGroup( numThreadsPerCell, bucket, cellIndex < nCells, groupThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	}

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 1

	// Every thread processes one cell
	uint cellIndex = dtid.x;
	uint nCells = inCellIndirectionCount[0];
	if ( cellIndex < nCells )
	{
		uint decalCountInFrustum = inDecalVolumesCount[0];
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
		DecalVisibilityOneThreadPerCell( ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );
	}

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32

	// 32 threads process one cell
	uint cellIndex = groupID.x;
#if DECAL_VOLUME_CLUSTER_BUCKETS
	uint bucket = 5;
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( groupThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 64

	// 32 threads process one cell
	uint cellIndex = groupID.x;
#if DECAL_VOLUME_CLUSTER_BUCKETS
	uint bucket = 6;
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( groupThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );

#else // #elif DECAL_VOLUME_CLUSTER_SUB_WORD == 64

	// DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL threads process one cell
	// DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP processed in parallel
	const uint numThreadsPerCell = DECAL_VOLUME_CLUSTER_SUB_WORD;

	uint bucket = firstbitlow( numThreadsPerCell );
	uint nCells = inCellIndirectionCount[bucket];
	uint cellIndex = dtid.x / numThreadsPerCell;

	uint decalCountInFrustum = inDecalVolumesCount[0];
#if DECAL_VOLUME_CLUSTER_BUCKETS
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, bucket );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	DecalVisibilitySubGroup( numThreadsPerCell, bucket, cellIndex < nCells, groupThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, ci.offsetToFirstDecalIndex );

#endif // #else // #elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32
}
#endif // #if ( DECAL_VOLUME_CLUSTER_MID_PASS || DECAL_VOLUME_CLUSTER_LAST_PASS ) && !DECAL_VOLUME_CLUSTER_SINGLE_PASS
