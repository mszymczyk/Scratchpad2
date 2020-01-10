#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	cs_bc7_encode_constant = {
		ComputeProgram = "cs_bc7_encode_constant";
	}

	draw_bc_texture = {
		VertexProgram = "draw_bc_texture_vp";
		FragmentProgram = "draw_bc_texture_fp";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "HlslFrameworkInterop.h"

Texture2D inBC7Tex									MAKE_REGISTER_SRV( 0 );
RWTexture2D<uint4> outBC7Tex								MAKE_REGISTER_UAV( 0 );


[numthreads( 1, 1, 1 )]
void cs_bc7_encode_constant()
{
	float4 color = float4( 1, 0, 1, 1 );

	uint4 res = 0;

	// mode 5
	uint mode = 0x20;
	uint rotation = 0;

	//uint r = 127;
	//uint g = 127;
	//uint b = 127;
	//uint a = 127;

	uint r = ( uint )( color.r * 127 );
	uint g = ( uint )( color.g * 127 );
	uint b = ( uint )( color.b * 127 );
	uint a = ( uint )( color.a * 255 );

	uint idxColor = 0;
	uint idxAlpha = 0;

	uint w0 = mode;
	// 6
	w0 |= rotation << 6;
	// 8
	w0 |= r << ( 6 + 2 );
	// 15
	w0 |= r << ( 6 + 2 + 7 );
	// 22
	w0 |= g << ( 6 + 2 + 7 + 7 );
	// 29
	w0 |= ( g & 0x7 ) << ( 6 + 2 + 7 + 7 + 7 );
	// 32

	uint w1 = g >> 3;
	// 4
	w1 |= b << 4;
	// 11
	w1 |= b << ( 4 + 7 );
	// 18
	w1 |= a << ( 4 + 7 + 7 );
	// 26
	w1 |= ( a & 0x3f ) << ( 4 + 7 + 7 + 8 );
	// 32

	uint w2 = a >> 6;
	// 2
	w2 |= ( idxColor & 0x3fffffff ) << 2;

	uint w3 = idxColor >> 30;
	// 1
	w3 |= ( idxAlpha & 0x3fffffff ) << 1;

	res.x = w0;
	res.y = w1;
	res.z = w2;
	res.w = w3;

	//res.x = mode | ( r << ( 6 + 2 ) );
	//res.x = mode << 26;
	//res.x |= ( r << 17 );

	outBC7Tex[uint2( 0, 0 )] = res;
}


struct vs_output
{
	float4 hpos			: SV_POSITION;
	float2 uv			: TEXCOORD0;
};

vs_output draw_bc_texture_vp( uint vertexId : SV_VertexID )
{
	vs_output OUT = (vs_output)0;

	if ( vertexId == 0 )
	{
		OUT.hpos = float4( -1, -1, 0, 1 );
		OUT.uv = float2( 0, 1 );
	}
	else if ( vertexId == 1 )
	{
		OUT.hpos = float4( 3, -1, 0, 1 );
		OUT.uv = float2( 2, 2 );
	}
	else // if ( vertexId == 2 )
	{
		OUT.hpos = float4( -1, 3, 0, 1 );
		OUT.uv = float2( 0, -1 );
	}

	return OUT;
}


float4 draw_bc_texture_fp( in vs_output IN ) : SV_Target
{
	//return float4( IN.uv, 0, 1 );
	float4 t = inBC7Tex.Load( uint3( 0, 0, 0 ) );
	return float4( t.xyzw );
}
