#ifndef SKINNING_CSHARED_H
#define SKINNING_CSHARED_H

#include "HlslFrameworkInterop.h"

#define REGISTER_CBUFFER_SKINNING_CONSTANTS					MAKE_REGISTER_CBUFFER( 2 )

#define REGISTER_BUFFER_SKINNING_IN_SKINNED_VERTICES		MAKE_REGISTER_SRV( 0 )
#define REGISTER_BUFFER_SKINNING_IN_BASE_VERTICES			MAKE_REGISTER_SRV( 1 )
#define REGISTER_BUFFER_SKINNING_IN_SKINNING_MATRICES		MAKE_REGISTER_SRV( 2 )

#define REGISTER_BUFFER_SKINNING_IN_OMEGA_REFS				MAKE_REGISTER_SRV( 3 )
#define REGISTER_BUFFER_SKINNING_IN_OMEGAS					MAKE_REGISTER_SRV( 4 )
#define REGISTER_BUFFER_SKINNING_IN_TRANSFORM_INDICES		MAKE_REGISTER_SRV( 5 )

#define REGISTER_BUFFER_SKINNING_IN_SVD						MAKE_REGISTER_SRV( 0 )

#define REGISTER_BUFFER_SKINNING_OUT_SKINNED_VERTICES		MAKE_REGISTER_UAV( 0 )
#define REGISTER_BUFFER_SKINNING_OUT_DEBUG					MAKE_REGISTER_UAV( 1 )

#define REGISTER_TEXTURE_DIFFUSE_TEXTURE					MAKE_REGISTER_SRV( 3 )
#define REGISTER_SAMPLER_DIFFUSE_SAMPLER					MAKE_REGISTER_SAMPLER( 3 )

#define SKINNING_NUM_THREADS_X								64

#define DECAL_VOLUME_CLUSTER_DISPLAY_MODE_3D				0
#define DECAL_VOLUME_CLUSTER_DISPLAY_MODE_2D				1
#define DECAL_VOLUME_CLUSTER_DISPLAY_MODE_DEPTH				2

MAKE_FLAT_CBUFFER( CbSkinningConstants, REGISTER_CBUFFER_SKINNING_CONSTANTS )
{
	CBUFFER_UINT( numVertices );
};

//MAKE_FLAT_CBUFFER( CbSkinningRenderingConstants, REGISTER_CBUFFER_SKINNING_CONSTANTS )
//{
//	uint numVertices;
//};


struct BaseVertex
{
	float x, y, z;
	float nx, ny, nz;
	float tx, ty;
	float w[4];
	uint b[4];
	uint numWeights;
};

struct BaseVertexPrecompute
{
	float x, y, z;
	float w[4];
	uint b[4];
	uint numWeights;
};

struct SkinnedVertex
{
	float x, y, z;
	float nx, ny, nz;
	float tx, ty;
};


struct OmegaRef
{
	uint firstIndex;
	uint indexCount;
};

struct DebugOutput
{
	float4x4 qmat;
	float3x3 Q_i;
	float3 p_i_T;
	float3 q_i;
	float3x3 m;
	float3x3 svdU;
	float3x3 svdV;
	float3x3 svdS;
};


#endif // SKINNING_CSHARED_H
