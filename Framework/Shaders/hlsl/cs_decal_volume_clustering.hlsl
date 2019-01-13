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
				//DECAL_VOLUME_CLUSTER_SUBGROUP = ( "1", "2", "4", "8", "16", "32", "64", "-1", "-2" );
				DECAL_VOLUME_CLUSTER_SUBGROUP = ( "1", "-2" );
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
				//DECAL_VOLUME_CLUSTER_SUBGROUP = ( "1", "2", "4", "8", "16", "32", "64", "-1", "-2" );
				DECAL_VOLUME_CLUSTER_SUBGROUP = ( "1", "-2" );
			}
		}
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#define DECAL_VOLUME_CLUSTER_3D									1

#include "cs_decal_volume_cluster_impl.hlsl"