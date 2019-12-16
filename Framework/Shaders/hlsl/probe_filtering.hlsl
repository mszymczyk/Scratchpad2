#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	cs_pick_texel = {
		ComputeProgram = "cs_pick_texel";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "probe_filtering_cshared.h"
#include "global_samplers.hlsl"

Texture2D   inTex							MAKE_REGISTER_SRV( 0 );
TextureCube inCubeMap						MAKE_REGISTER_SRV( 1 );
RWTexture2D<float4> outTex					MAKE_REGISTER_UAV( 0 );


[numthreads( 8, 8, 1 )]
void cs_octahedron_filter( uint3 dtid : SV_DispatchThreadID )
{
	outTex[dtid.xy] = float4( 1, 1, 0, 1 );
}