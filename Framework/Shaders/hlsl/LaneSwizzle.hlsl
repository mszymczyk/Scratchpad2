#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	Fullscreen = {
		VertexProgram = "fullscreen_vp";
		FragmentProgram = "fullscreen_fp";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "HlslFrameworkInterop.h"


struct vs_output
{
	float4 hpos			: SV_POSITION;
	float2 uv			: TEXCOORD0;
};

vs_output fullscreen_vp( uint vertexId : SV_VertexID )
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



//uint LaneSwizzle( uint x, uint andMask, uint orMask, uint xorMask )
//Reorders( swizzles ) lanes within vector register x according to a set of mask parameters.Each lane n of the result( for n = 0...63 ) is set to the contents of lane p of the original vector register, where p = ( n & ( 0x20 | andMask ) | orMask ) ^ xorMask.
//If lane p of the vector register is not active, lane n of the result is set to 0.

uint LaneSwizzleHelper( uint n, uint andMask, uint orMask, uint xorMask )
{
	uint p = ( n & ( 0x20 | andMask ) | orMask ) ^ xorMask;
	return p;
}

float4 fullscreen_fp( in vs_output IN ) : SV_Target
{
	float3 color = float3( 0, 0, 0 );

	uint2 pixel = (uint2) IN.hpos.xy;
	uint groupIndex = ( pixel.x / 64 ) + ( pixel.y / 64 ) * 8;
	uint groupBit = 1 << groupIndex;

	color = ( float3( 1, 1, 1 ) / 63.0 ) * groupIndex;

	//sum += LaneSwizzle( sum, 0x1fu, 0u, 0x1u );
	//ulong quadmask = ( 0x0000000000000303UL << ( groupIndex & ~( 8 | 1 ) ) );
	//uint quadmask = ( 0x00000303 << ( (groupIndex % 32) & ~( 8 | 1 ) ) );
	//uint quadmask = ( 0x0F0F0F0FUL << ( ( groupIndex % 32 ) & ~( 16 | 8 | 2 | 1 ) ) );
	//uint quadmask = 0x0F0F0F0F;
	uint quadmask = 0x00000303;
	//if ( groupIndex & ~( 16 | 8 | 2 | 1 ) )
	//if ( groupIndex & ~( 8 | 1 ) )
	if ( ( groupIndex & ( 16 | 8 | 2 | 1 ) ) == 0 )
	//if ( ( groupIndex & ( 16 | 8 | 2 | 1 ) ) == 0 )
	//if ( ( groupIndex & ( ( 4 ) ) ) == 0 )
	//if ( groupIndex < 32 && ( groupBit & quadmask ) != 0 )
	//if ( ( groupIndex & ~( 16 | 8 ) ) )
	{
		color = float3( 1, 0, 0 );
	}

	if ( ( pixel.x % 64 ) == 0 || ( pixel.y % 64 ) == 0 )
	{
		color = float3( 1, 1, 1 );
	}

	return float4( color, 1 );
}
