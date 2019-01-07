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

	DecalTilingCopyIndirectArgsBuckets = {
		ComputeProgram = "DecalTilingCopyIndirectArgsBuckets";
	}

	DecalTilingCopyIndirectArgsBucketsMerge = {
		ComputeProgram = "DecalTilingCopyIndirectArgsBucketsMerge";
	}

	cs_decal_volume_assign_slot = {
		ComputeProgram = "cs_decal_volume_assign_slot";
	}

	DecalVolumeClusteringFirstPass = {
		ComputeProgram = {
			EntryName = "DecalVolumeClusteringFirstPass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_FIRST_PASS = ( "1" );
				//DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION = ( "0", "1" );
				INTERSECTION_METHOD = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_BUCKETS = ( "0", "1" );
			}
		}
	}

	DecalVolumeClusteringMidPass = {
		ComputeProgram = {
			EntryName = "DecalVolumeClusteringMidPass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_MID_PASS = ( "1" );
				INTERSECTION_METHOD = ( "0", "1" );
				//DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_BUCKETS = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_SUB_WORD = ( "1", "2", "4", "8", "16", "32", "-1", "-2" );
				//DECAL_VOLUME_CLUSTER_SUB_WORD = ( "-2" );
			}
		}
	}

	DecalVolumeClusteringLastPass = {
		ComputeProgram = {
			EntryName = "DecalVolumeClusteringMidPass";
			cdefines = {
				DECAL_VOLUME_CLUSTER_LAST_PASS = ( "1" );
				INTERSECTION_METHOD = ( "0", "1" );
				//DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_BUCKETS = ( "0", "1" );
				DECAL_VOLUME_CLUSTER_SUB_WORD = ( "1", "2", "4", "8", "16", "32", "-1", "-2" );
				//DECAL_VOLUME_CLUSTER_SUB_WORD = ( "-2" );
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

#define DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION			1
//#define INTERSECTION_METHOD										0

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


[numthreads( 1, 1, 1 )]
void DecalTilingCopyIndirectArgsBuckets()
{
	uint b1 = inCellIndirectionCount[0];
	uint b2 = inCellIndirectionCount[1];
	uint b4 = inCellIndirectionCount[2];
	uint b8 = inCellIndirectionCount[3];
	uint b16 = inCellIndirectionCount[4];
	uint b32 = inCellIndirectionCount[5];

	uint n1  = b1  ? ( b1  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  ) : 0;
	uint n2  = b2  ? ( b2  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  ) : 0;
	uint n4  = b4  ? ( b4  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  ) : 0;
	uint n8  = b8  ? ( b8  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  ) : 0;
	uint n16 = b16 ? ( b16 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 ) : 0;
	uint n32 = b32 ? ( b32 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 ) : 0;

	outIndirectArgs.Store3( 12 * 0, uint3( n1,  1, 1 ) );
	outIndirectArgs.Store3( 12 * 1, uint3( n2,  1, 1 ) );
	outIndirectArgs.Store3( 12 * 2, uint3( n4,  1, 1 ) );
	outIndirectArgs.Store3( 12 * 3, uint3( n8,  1, 1 ) );
	outIndirectArgs.Store3( 12 * 4, uint3( n16, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 5, uint3( n32, 1, 1 ) );
}


[numthreads( 1, 1, 1 )]
void DecalTilingCopyIndirectArgsBucketsMerge()
{
	uint b1 = inCellIndirectionCount[0];
	uint b2 = inCellIndirectionCount[1];
	uint b4 = inCellIndirectionCount[2];
	uint b8 = inCellIndirectionCount[3];
	uint b16 = inCellIndirectionCount[4];
	uint b32 = inCellIndirectionCount[5];

	uint n1  = b1  ? ( b1  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  ) : 0;
	uint n2  = b2  ? ( b2  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  ) : 0;
	uint n4  = b4  ? ( b4  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  ) : 0;
	uint n8  = b8  ? ( b8  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  ) : 0;
	uint n16 = b16 ? ( b16 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 ) : 0;
	uint n32 = b32 ? ( b32 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 ) : 0;

	uint n = n1 + n2 + n4 + n8 + n16 + n32;
	outIndirectArgs.Store3( 12 * 0, uint3( n, 1, 1 ) );
	//outIndirectArgs.Store3( 12 * 0, uint3( n1 + n2, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 1, uint3( (n + 64 - 1) / 64, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 2, uint3( 0, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 3, uint3( 0, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 4, uint3( 0, 1, 1 ) );
	outIndirectArgs.Store3( 12 * 5, uint3( 0, 1, 1 ) );
}


void DecalVolume_GetBucket( uint groupIndex, out uint bucket, out uint firstGroup )
{
	uint b1 = inCellIndirectionCount[0];
	uint b2 = inCellIndirectionCount[1];
	uint b4 = inCellIndirectionCount[2];
	uint b8 = inCellIndirectionCount[3];
	uint b16 = inCellIndirectionCount[4];
	uint b32 = inCellIndirectionCount[5];

	uint n1  = b1  ? ( b1  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 1  ) : 0;
	uint n2  = b2  ? ( b2  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 2  ) : 0;
	uint n4  = b4  ? ( b4  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 4  ) : 0;
	uint n8  = b8  ? ( b8  + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 8  ) : 0;
	uint n16 = b16 ? ( b16 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 16 ) : 0;
	uint n32 = b32 ? ( b32 + DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 - 1 ) / ( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS / 32 ) : 0;

	//uint s0 = b1;
	//uint s1 = b1 + b2;
	//uint s2 = b1 + b2 + b4;
	//uint s3 = b1 + b2 + b4 + b8;
	//uint s4 = b1 + b2 + b4 + b8 + b16;
	//uint s5 = b1 + b2 + b4 + b8 + b16 + b32;

	uint s0 = n1;
	uint s1 = n1 + n2;
	uint s2 = n1 + n2 + n4;
	uint s3 = n1 + n2 + n4 + n8;
	uint s4 = n1 + n2 + n4 + n8 + n16;
	uint s5 = n1 + n2 + n4 + n8 + n16 + n32;

	//slot = 0;
	if ( groupIndex >= s5 )
	{
		bucket = 0xff;
		firstGroup = 0xffffffff;
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

	//slot = 5;
	//firstGroup = 0;// 169;// n1 + n2 + n4 + n8 + n16;

	//return slot;
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
void DecalVolumeClusteringFirstPass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID )
{
	//uint flatCellIndex = DecalVolume_GetCellFlatIndex( uint3( cellID.xyz ), uint3( cellCountA.xyz ) );
	uint flatCellIndex = DecalVolume_EncodeCell( cellID.xyz );
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( cellThreadID, flatCellIndex, decalCountInFrustum, decalCountInFrustum, maxCountPerCell.x, 0, INTERSECTION_METHOD );// , maxCountPerCell.y );
}
#endif // #if DECAL_VOLUME_CLUSTER_FIRST_PASS


#if DECAL_VOLUME_CLUSTER_MID_PASS || DECAL_VOLUME_CLUSTER_LAST_PASS

#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_MID_PASS

#if DECAL_VOLUME_CLUSTER_SUB_WORD == 1
#include "cs_decal_volume_impl_one_thread_per_cell.hlsl"
#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -1 || DECAL_VOLUME_CLUSTER_SUB_WORD == -2
//#define DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL	DECAL_VOLUME_CLUSTER_SUB_WORD
//#define DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP	(32 / DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL)
#include "cs_decal_volume_impl_one_thread_per_cell.hlsl"
#define DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP
#include "cs_decal_volume_impl_subword.hlsl"
#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32 // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 1
#include "cs_decal_volume_impl.hlsl"
#else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 32
//#define DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL	DECAL_VOLUME_CLUSTER_SUB_WORD
//#define DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP	(32 / DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL)
#define DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP //DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP
#include "cs_decal_volume_impl_subword.hlsl"
#endif // #else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 0

uint3 DecalVolume_GetCell3DIndex( uint flatCellIndex, uint3 numCellsXYZ )
{
	uint sliceSize = numCellsXYZ.x * numCellsXYZ.y;
	uint cellZ = flatCellIndex / sliceSize;
	uint tileIndex = flatCellIndex % sliceSize;
	uint cellX = tileIndex % numCellsXYZ.x;
	uint cellY = tileIndex / numCellsXYZ.x;

	return uint3( cellX, cellY, cellZ );
}


CellIndirection DecalVolumeGetCellIndirection( uint cellIndex, uint cellBucket )
{
#if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

	uint dataIndex = cellIndex / 8;
	uint childIndex = cellIndex % 8;

	CellIndirection ci = inCellIndirection[dataIndex + cellBucket * DecalVolume_CellCountCurrentPass()];

	//uint3 parentCellXYZ = DecalVolume_GetCell3DIndex( ci.cellIndex, cellCountA.xyz / 2 );
	//uint3 parentCellXYZ = DecalVolume_GetCell3DIndex( ci.cellIndex, uint3(7, 4, 4) );
	uint3 parentCellXYZ = DecalVolume_DecodeCell( ci.cellIndex );

	uint slice = childIndex / 4;
	uint sliceSize = cellCountA.x * cellCountA.y;
	uint tile = childIndex % 4;
	uint row = tile / 2;
	uint col = tile % 2;
	//ci.cellIndex = ( parentCellXYZ.z * 2 + slice ) * sliceSize /** 4*/ + ( parentCellXYZ.y * 2 + row ) * cellCountA.x /** 2*/ + parentCellXYZ.x * 2 + col;
	ci.cellIndex = DecalVolume_EncodeCell( uint3( parentCellXYZ.x * 2 + col, parentCellXYZ.y * 2 + row, parentCellXYZ.z * 2 + slice ) );

#else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

	CellIndirection ci = inCellIndirection[cellIndex + cellBucket * DecalVolume_CellCountCurrentPass()];

#endif // #else // #if DECAL_VOLUME_CLUSTER_OUTPUT_CELL_OPTIMIZATION == 1

	return ci;
}


[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
void DecalVolumeClusteringMidPass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID, uint3 dtid : SV_DispatchThreadID )
{
#if DECAL_VOLUME_CLUSTER_SUB_WORD == 1

	// Every thread processes one cell
	uint cellIndex = dtid.x;
	uint nCells = inCellIndirectionCount[0];
	if ( cellIndex < nCells )
	{
		uint decalCountInFrustum = inDecalVolumesCount[0];
		//CellIndirection ci = inCellIndirection[cellIndex];
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
		DecalVisibilityOnThreadPerCell( ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );// , maxCountPerCell.y );
	}

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -1

	uint cellSlot = maxCountPerCell.y;
	uint numThreadsPerCell = 1 << cellSlot;

	uint nCells = inCellIndirectionCount[cellSlot];
	uint decalCountInFrustum = inDecalVolumesCount[0];

	if ( cellSlot == 5 )
	{
		uint cellIndex = cellID.x;
		//CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, cellSlot );
		DecalVisibilitySubWordLoop( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
	}
	else
	{
		uint cellIndex = dtid.x / numThreadsPerCell;
		//CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, cellSlot );
		DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
	}

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -2

	uint cellSlot;
	uint firstGroup;
	DecalVolume_GetBucket( cellID.x, cellSlot, firstGroup );
	//DecalVolume_ReadBucket( cellID.x, cellSlot, firstGroup );
	uint numThreadsPerCell = 1 << cellSlot;

	uint nCells = inCellIndirectionCount[cellSlot];
	uint decalCountInFrustum = inDecalVolumesCount[0];

	//if ( cellSlot == 0 )
	//{
	//	uint cellIndex = dtid.x - firstGroup * 32;
	//	if ( cellIndex < nCells )
	//	{
	//		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
	//		DecalVisibilityOnThreadPerCell( ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );// , maxCountPerCell.y );
	//	}
	//}
	//else
		if ( cellSlot == 5 )
	{
		uint cellIndex = cellID.x - firstGroup;
		//CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, cellSlot );
		DecalVisibilitySubWordLoop( 32, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
	}
	else
	{
		uint cellIndex = (dtid.x - firstGroup * 32) / numThreadsPerCell;
		//CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
		CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, cellSlot );
		DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
	}

#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32

	// 32 threads process one cell
	uint cellIndex = cellID.x;
#if DECAL_VOLUME_CLUSTER_BUCKETS
	uint cellSlot = 5;
	//CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, cellSlot );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	//CellIndirection ci = inCellIndirection[cellIndex];
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	uint decalCountInFrustum = inDecalVolumesCount[0];
	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );// , maxCountPerCell.y );

#else // #elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32

	// DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL threads process one cell
	// DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP processed in parallel
	const uint numThreadsPerCell = DECAL_VOLUME_CLUSTER_SUB_WORD;

	uint cellSlot = firstbitlow( numThreadsPerCell );
	uint nCells = inCellIndirectionCount[cellSlot];
	uint cellIndex = dtid.x / numThreadsPerCell;

	uint decalCountInFrustum = inDecalVolumesCount[0];
#if DECAL_VOLUME_CLUSTER_BUCKETS
	//CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, cellSlot );
#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	//CellIndirection ci = inCellIndirection[cellIndex];
	CellIndirection ci = DecalVolumeGetCellIndirection( cellIndex, 0 );
#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
	DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );

#endif // #else // #elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32
}
#endif // #if DECAL_VOLUME_CLUSTER_MID_PASS || DECAL_VOLUME_CLUSTER_LAST_PASS


//#if DECAL_VOLUME_CLUSTER_LAST_PASS
//
//#define DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP_LAST_PASS
//
//#if DECAL_VOLUME_CLUSTER_SUB_WORD == 1
//
//#include "cs_decal_volume_impl_one_thread_per_cell.hlsl"
//
//#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -1 || DECAL_VOLUME_CLUSTER_SUB_WORD == -2
//
////#define DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL	DECAL_VOLUME_CLUSTER_SUB_WORD
////#define DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP	(32 / DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL)
//#define DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP
//#include "cs_decal_volume_impl_subword.hlsl"
//
//#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32 // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 1
//
//#include "cs_decal_volume_impl.hlsl"
//
//#else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 32
//
////#define DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL	DECAL_VOLUME_CLUSTER_SUB_WORD
////#define DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP	(32 / DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL)
//#define DECAL_VOLUME_CLUSTER_SHARED_MEM_WORDS		DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP // DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP
//#include "cs_decal_volume_impl_subword.hlsl"
//
//#endif // #else // #if DECAL_VOLUME_CLUSTER_SUB_WORD == 0
//
//[numthreads( DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP, 1, 1 )]
//void DecalVolumeClusteringLastPass( uint3 cellThreadID : SV_GroupThreadID, uint3 cellID : SV_GroupID, uint3 dtid : SV_DispatchThreadID )
//{
//#if DECAL_VOLUME_CLUSTER_SUB_WORD == 1
//	
//	// Every thread processes one cell
//	uint cellIndex = dtid.x;
//	uint nCells = inCellIndirectionCount[0];
//	if ( cellIndex < nCells )
//	{
//		uint decalCountInFrustum = inDecalVolumesCount[0];
//		CellIndirection ci = inCellIndirection[cellIndex];
//		DecalVisibilityOnThreadPerCell( ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );// , maxCountPerCell.y );
//	}
//
//#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -1
//
//	//uint cellSlot = maxCountPerCell.y;
//	//uint numThreadsPerCell = 1 << cellSlot;
//
//	//uint nCells = inCellIndirectionCount[cellSlot];
//	//uint cellIndex = dtid.x / numThreadsPerCell;
//
//	//uint decalCountInFrustum = inDecalVolumesCount[0];
//	//CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
//	//DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
//
//	uint cellSlot = maxCountPerCell.y;
//	uint numThreadsPerCell = 1 << cellSlot;
//
//	uint nCells = inCellIndirectionCount[cellSlot];
//	uint decalCountInFrustum = inDecalVolumesCount[0];
//
//	if ( cellSlot == 5 )
//	{
//		uint cellIndex = cellID.x;
//		CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
//		DecalVisibilitySubWordLoop( 32, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
//	}
//	else
//	{
//		uint cellIndex = dtid.x / numThreadsPerCell;
//		CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
//		DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
//	}
//
//#elif DECAL_VOLUME_CLUSTER_SUB_WORD == -2
//
//	//uint cellSlot = DecalVolume_GetBucket( dtid.x / DECAL_VOLUME_CLUSTER_THREADS_PER_GROUP );
//	uint cellSlot;
//	uint firstGroup;
//	DecalVolume_GetBucket( cellID.x, cellSlot, firstGroup );
//	uint numThreadsPerCell = 1 << cellSlot;
//
//	uint nCells = inCellIndirectionCount[cellSlot];
//	uint decalCountInFrustum = inDecalVolumesCount[0];
//
//	if ( cellSlot == 5 )
//	{
//		uint cellIndex = cellID.x - firstGroup;
//		CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
//		DecalVisibilitySubWordLoop( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
//	}
//	else
//	{
//		uint cellIndex = ( dtid.x - firstGroup * 32 ) / numThreadsPerCell;
//		CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
//		DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
//	}
//#elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32
//
//	// 32 threads process one cell
//	uint cellIndex = cellID.x;
//	uint cellSlot = 5;
//#if DECAL_VOLUME_CLUSTER_BUCKETS
//	CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
//#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
//	CellIndirection ci = inCellIndirection[cellIndex];
//#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
//	uint decalCountInFrustum = inDecalVolumesCount[0];
//	DecalVisibilityGeneric( cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );// , maxCountPerCell.y );
//
//#else // #elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32
//
//	// DECAL_VOLUME_CLUSTER_NUM_THREADS_PER_CELL threads process one cell
//	// DECAL_VOLUME_CLUSTER_NUM_CELLS_PER_GROUP processed in parallel
//	const uint numThreadsPerCell = DECAL_VOLUME_CLUSTER_SUB_WORD;
//
//	uint cellSlot = firstbitlow( numThreadsPerCell );
//	uint nCells = inCellIndirectionCount[cellSlot];
//	uint cellIndex = dtid.x / numThreadsPerCell;
//	uint decalCountInFrustum = inDecalVolumesCount[0];
//#if DECAL_VOLUME_CLUSTER_BUCKETS
//	CellIndirection ci = inCellIndirection[cellIndex + cellSlot * DecalVolume_CellCountCurrentPass()];
//#else // #if DECAL_VOLUME_CLUSTER_BUCKETS
//	CellIndirection ci = inCellIndirection[cellIndex];
//#endif // #else // #if DECAL_VOLUME_CLUSTER_BUCKETS
//	DecalVisibilitySubWord( numThreadsPerCell, cellIndex < nCells, cellThreadID, ci.cellIndex, ci.decalCount, decalCountInFrustum, maxCountPerCell.x, ci.offsetToFirstDecalIndex, INTERSECTION_METHOD );
//
//#endif // #else // #elif DECAL_VOLUME_CLUSTER_SUB_WORD == 32
//}
//#endif // #if DECAL_VOLUME_CLUSTER_LAST_PASS
