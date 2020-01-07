#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	cs_linear_blend_skinning = {
		ComputeProgram = "cs_linear_blend_skinning";
	}

	draw_model = {
		VertexProgram = "draw_model_vp";
		FragmentProgram = "draw_model_fp";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "PassConstants.h"
#include "skinning_cshared.h"

StructuredBuffer<SkinnedVertex> inSkinnedVertices		REGISTER_BUFFER_SKINNING_IN_SKINNED_VERTICES;
StructuredBuffer<BaseVertex> inBaseVertices				REGISTER_BUFFER_SKINNING_IN_BASE_VERTICES;
StructuredBuffer<float4x4> inSkinningMatrices			REGISTER_BUFFER_SKINNING_IN_SKINNING_MATRICES;

RWStructuredBuffer<SkinnedVertex> outSkinnedVertices	REGISTER_BUFFER_SKINNING_OUT_SKINNED_VERTICES;


//StructuredBuffer<uint> inDecalVolumesCount			REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_COUNT;
//StructuredBuffer<uint> inDecalVolumeIndices			REGISTER_BUFFER_DECAL_VOLUME_IN_DECAL_INDICES;
//RWByteAddressBuffer outIndirectArgs					REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS;

//Texture2D diffuseTex								REGISTER_TEXTURE_DIFFUSE_TEXTURE;
//SamplerState diffuseTexSamp							REGISTER_SAMPLER_DIFFUSE_SAMPLER;


[numthreads( SKINNING_NUM_THREADS_X, 1, 1 )]
void cs_linear_blend_skinning( uint3 dtid : SV_DispatchThreadID )
{
	if ( dtid.x >= numVertices )
		return;

	BaseVertex bv = inBaseVertices[dtid.x];
	SkinnedVertex sv;

	float3 pos = 0;
	float3 nrm = 0;

	for ( uint iWeight = 0; iWeight < 4; ++iWeight )
	{
		float4x4 mat = inSkinningMatrices[bv.b[iWeight]];
		float weight = bv.w[iWeight];
		pos += weight * mul( mat, float4( bv.x, bv.y, bv.z, 1 ) ).xyz;
		nrm += weight * mul( (float3x3)mat, float3( bv.nx, bv.ny, bv.nz ) ).xyz;
	}

	//pos = float3( bv.x, bv.y, bv.z );
	//nrm = float3( bv.nx, bv.ny, bv.nz );

	nrm = normalize( nrm );
	sv.x = pos.x;
	sv.y = pos.y;
	sv.z = pos.z;
	sv.nx = nrm.x;
	sv.ny = nrm.y;
	sv.nz = nrm.z;
	sv.tx = bv.tx;
	sv.ty = bv.ty;

	outSkinnedVertices[dtid.x] = sv;
}

struct vs_model_output
{
	float4 hpos			: SV_POSITION; // vertex position in clip space
	float3 normalWS		: NORMAL;      // vertex normal in world space
	float2 texCoord0	: TEXCOORD0;   // vertex texture coords 
};

vs_model_output draw_model_vp( uint vertexId : SV_VertexID )
{
	vs_model_output OUT;

	SkinnedVertex vertex = inSkinnedVertices[vertexId];

	float4 positionWorld = mul( World, float4( vertex.x, vertex.y, vertex.z, 1 ) );

	OUT.hpos = mul( ViewProjection, positionWorld );
	OUT.normalWS = mul( ( float3x3 )WorldIT, float3( vertex.nx, vertex.ny, vertex.nz ) );
	OUT.texCoord0 = float2( vertex.tx, vertex.ty );

	return OUT;
}

float4 draw_model_fp( in vs_model_output IN ) : SV_Target
{
	return float4( 1, 0, 1, 1 );
	//return float4( diffuseTex.Sample( diffuseTexSamp, IN.texCoord0 ).xyz, 1 );
}
