#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	cs_linear_blend_skinning = {
		ComputeProgram = "cs_linear_blend_skinning";
	}

	cs_ddm_skinning_v0 = {
		ComputeProgram = "cs_ddm_skinning_v0";
	}

	cs_ddm_skinning_v1 = {
		ComputeProgram = "cs_ddm_skinning_v1";
	}

	cs_svd_debug = {
		ComputeProgram = "cs_svd_debug";
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
#include "svd2.hlsl"

StructuredBuffer<SkinnedVertex> inSkinnedVertices		REGISTER_BUFFER_SKINNING_IN_SKINNED_VERTICES;
StructuredBuffer<BaseVertex> inBaseVertices				REGISTER_BUFFER_SKINNING_IN_BASE_VERTICES;
StructuredBuffer<float4x4> inSkinningMatrices			REGISTER_BUFFER_SKINNING_IN_SKINNING_MATRICES;

StructuredBuffer<OmegaRef> inOmegaRefs					REGISTER_BUFFER_SKINNING_IN_OMEGA_REFS;
StructuredBuffer<float4x4> inOmegas						REGISTER_BUFFER_SKINNING_IN_OMEGAS;
StructuredBuffer<uint> inTransformIndices				REGISTER_BUFFER_SKINNING_IN_TRANSFORM_INDICES;

StructuredBuffer<float3x3> inSVD						REGISTER_BUFFER_SKINNING_IN_SVD;

RWStructuredBuffer<SkinnedVertex> outSkinnedVertices	REGISTER_BUFFER_SKINNING_OUT_SKINNED_VERTICES;
RWStructuredBuffer<DebugOutput> outDebugOutput			REGISTER_BUFFER_SKINNING_OUT_DEBUG;

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

float3x3 MulMat( float3 a, float3 b )
{
	float3x3 r;
	r[0][0] = a[0] * b[0];
	r[0][1] = a[0] * b[1];
	r[0][2] = a[0] * b[2];

	r[1][0] = a[1] * b[0];
	r[1][1] = a[1] * b[1];
	r[1][2] = a[1] * b[2];

	r[2][0] = a[2] * b[0];
	r[2][1] = a[2] * b[1];
	r[2][2] = a[2] * b[2];

	return r;
};

[numthreads( SKINNING_NUM_THREADS_X, 1, 1 )]
void cs_ddm_skinning_v0( uint3 dtid : SV_DispatchThreadID )
{
	uint vertIndex = dtid.x;
	if ( vertIndex >= numVertices )
		return;

	BaseVertex bv = inBaseVertices[vertIndex];
	OmegaRef oref = inOmegaRefs[vertIndex];
	
	float4x4 sm = ( float4x4 )0;

	for ( uint iRef = 0; iRef < oref.indexCount; ++iRef )
	{
		uint j = iRef + oref.firstIndex;
		uint boneIndex = inTransformIndices[j];
		float4x4 skinMat = inSkinningMatrices[boneIndex];
		//skinMat = transpose( skinMat );
		float4x4 omega_ij = inOmegas[j];

		sm += mul( skinMat, omega_ij );
		//sm += mul( omega_ij, skinMat );
	}

	//sm = transpose( sm );

	float3x3 Q_i = ( float3x3 )sm;
	//Q_i = transpose( Q_i );
	float3 p_i_T = sm[3].xyz;
	float3 q_i = float3( sm[0][3], sm[1][3], sm[2][3] );
	//float3 q_i = sm[3].xyz;
	//float3 p_i_T = float3( sm[0][3], sm[1][3], sm[2][3] );

	float3x3 m = Q_i - MulMat( q_i, p_i_T );

	SVD_mats B = svd( m );
	float3x3 R_i = mul( B.U, B.V );
	float3 t_i = q_i - mul( R_i, p_i_T );

	float3 pos = mul( R_i, float3( bv.x, bv.y, bv.z ) ) + t_i;
	float3 nrm = mul( R_i, float3( bv.nx, bv.ny, bv.nz ) );

	nrm = normalize( nrm );

	SkinnedVertex sv;
	sv.x = pos.x;
	sv.y = pos.y;
	sv.z = pos.z;
	sv.nx = nrm.x;
	sv.ny = nrm.y;
	sv.nz = nrm.z;
	sv.tx = bv.tx;
	sv.ty = bv.ty;

	outSkinnedVertices[vertIndex] = sv;


	DebugOutput dout = (DebugOutput)0;
	dout.qmat = sm;
	dout.Q_i = Q_i;
	dout.p_i_T = p_i_T;
	dout.q_i = q_i;
	dout.m = m;
	dout.svdU = B.U;
	dout.svdV = B.V;
	dout.svdS = B.Sigma;

	outDebugOutput[vertIndex] = dout;
}


float3x3 inverse( float3x3 m )
{
	float OneOverDeterminant = 1.0f / (
		+ m[0][0] * ( m[1][1] * m[2][2] - m[2][1] * m[1][2] )
		- m[1][0] * ( m[0][1] * m[2][2] - m[2][1] * m[0][2] )
		+ m[2][0] * ( m[0][1] * m[1][2] - m[1][1] * m[0][2] ) );

	float3x3 Inverse;
	Inverse[0][0] = +( m[1][1] * m[2][2] - m[2][1] * m[1][2] ) * OneOverDeterminant;
	Inverse[1][0] = -( m[1][0] * m[2][2] - m[2][0] * m[1][2] ) * OneOverDeterminant;
	Inverse[2][0] = +( m[1][0] * m[2][1] - m[2][0] * m[1][1] ) * OneOverDeterminant;
	Inverse[0][1] = -( m[0][1] * m[2][2] - m[2][1] * m[0][2] ) * OneOverDeterminant;
	Inverse[1][1] = +( m[0][0] * m[2][2] - m[2][0] * m[0][2] ) * OneOverDeterminant;
	Inverse[2][1] = -( m[0][0] * m[2][1] - m[2][0] * m[0][1] ) * OneOverDeterminant;
	Inverse[0][2] = +( m[0][1] * m[1][2] - m[1][1] * m[0][2] ) * OneOverDeterminant;
	Inverse[1][2] = -( m[0][0] * m[1][2] - m[1][0] * m[0][2] ) * OneOverDeterminant;
	Inverse[2][2] = +( m[0][0] * m[1][1] - m[1][0] * m[0][1] ) * OneOverDeterminant;

	return Inverse;
}


[numthreads( SKINNING_NUM_THREADS_X, 1, 1 )]
void cs_ddm_skinning_v1( uint3 dtid : SV_DispatchThreadID )
{
	uint vertIndex = dtid.x;
	if ( vertIndex >= numVertices )
		return;

	BaseVertex bv = inBaseVertices[vertIndex];
	OmegaRef oref = inOmegaRefs[vertIndex];

	float4x4 qmat = ( float4x4 )0;
	float4x4 pmat = ( float4x4 )0;

	for ( uint iRef = 0; iRef < oref.indexCount; ++iRef )
	{
		uint j = iRef + oref.firstIndex;
		uint boneIndex = inTransformIndices[j];
		float4x4 skinMat = inSkinningMatrices[boneIndex];
		float4x4 omega_ij = inOmegas[j];

		qmat += mul( skinMat, omega_ij );
		pmat += omega_ij;
	}

	float3x3 Q_i = ( float3x3 )qmat;
	float3 p_i_T = qmat[3].xyz;
	float3 q_i = float3( qmat[0][3], qmat[1][3], qmat[2][3] );

	float3x3 qm = Q_i - MulMat( q_i, p_i_T );

	float3x3 P_i = ( float3x3 )pmat;
	//float3 p_i = pmat[3].xyz;
	float3 p_i = float3( qmat[0][3], qmat[1][3], qmat[2][3] );

	float3x3 pm = P_i - MulMat( p_i, p_i_T );

	float detqm = determinant( qm );
	float detpm = determinant( pm );

	float3x3 R_i = ( detqm / detpm ) * transpose( inverse( qm ) ) * pm;

	//SVD_mats B = svd( qm );
	//float3x3 R_i = mul( B.U, B.V );
	float3 t_i = q_i - mul( R_i, p_i_T );

	float3 pos = mul( R_i, float3( bv.x, bv.y, bv.z ) ) + t_i;
	float3 nrm = mul( R_i, float3( bv.nx, bv.ny, bv.nz ) );

	nrm = normalize( nrm );

	SkinnedVertex sv;
	sv.x = pos.x;
	sv.y = pos.y;
	sv.z = pos.z;
	sv.nx = nrm.x;
	sv.ny = nrm.y;
	sv.nz = nrm.z;
	sv.tx = bv.tx;
	sv.ty = bv.ty;

	outSkinnedVertices[vertIndex] = sv;


	DebugOutput dout = (DebugOutput)0;
	dout.qmat = qmat;
	dout.Q_i = Q_i;
	dout.p_i_T = p_i_T;
	dout.q_i = q_i;
	dout.m = qm;
	//dout.svdU = B.U;
	//dout.svdV = B.V;
	//dout.svdS = B.Sigma;

	outDebugOutput[vertIndex] = dout;
}


[numthreads( SKINNING_NUM_THREADS_X, 1, 1 )]
void cs_svd_debug( uint3 dtid : SV_DispatchThreadID )
{
	uint vertIndex = dtid.x;
	if ( vertIndex >= numVertices )
		return;

	float3x3 m = inSVD[vertIndex];

	SVD_mats B = svd( m );

	DebugOutput dout = (DebugOutput)0;
	dout.m = m;
	dout.svdU = B.U;
	dout.svdV = B.V;
	dout.svdS = B.Sigma;

	outDebugOutput[vertIndex] = dout;
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
