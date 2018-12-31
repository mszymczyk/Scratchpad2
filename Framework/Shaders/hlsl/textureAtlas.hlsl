#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	SampleAtlas = {
		VertexProgram = "Vp";
		FragmentProgram = "Fp";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "PassConstants.h"
#include "textureAtlasConstants.h"

Texture2D diffuseTex : register( t0 );
SamplerState sampAniso : register( s0 );
SamplerState sampAniso4x : register( s1 );
SamplerState sampLinear : register( s2 );
SamplerState sampLinearNoMips : register( s3 );
SamplerState sampPoint : register( s4 );


///////////////////////////////////////////////////////////////////////////////
// vertex program
///////////////////////////////////////////////////////////////////////////////
struct vs_output
{
	float4 hpos			: SV_POSITION; // vertex position in clip space
	float3 normalWS		: NORMAL;      // vertex normal in world space
	float2 texCoord0	: TEXCOORD0;   // vertex texture coords 
	float3 posWS		: TEXCOORD1;
};

vs_output Vp(
					  float3 position : POSITION
					, float3 normal : NORMAL
					, float2 texCoord0 : TEXCOORD0
				)
{
	vs_output OUT;

	float4 positionWorld = mul( World, float4( position, 1 ) );

	OUT.hpos = mul( ViewProjection, positionWorld );
	OUT.normalWS = mul( ( float3x3 )WorldIT, normal );
	OUT.texCoord0 = texCoord0;
	OUT.posWS = positionWorld.xyz;

	return OUT;
}

///////////////////////////////////////////////////////////////////////////////
// fragment program
///////////////////////////////////////////////////////////////////////////////
float4 Fp( in vs_output IN ) : SV_Target
{
	float2 uv = IN.texCoord0.xy;
	float3 texSample = diffuseTex.Sample( sampAniso, uv ).xyz;

	return float4( texSample, 1 );
}