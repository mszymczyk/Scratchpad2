#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	cs_pick_texel = {
		ComputeProgram = "cs_pick_texel";
	}

	cs_color_code_faces = {
		ComputeProgram = "cs_color_code_faces";
	}

	cs_color_code_faces_pull_fixup = {
		ComputeProgram = "cs_color_code_faces_pull_fixup";
	}

	cs_octahedron_encode_normal = {
		ComputeProgram = "cs_octahedron_encode_normal";
	}

	cs_octahedron_encode_scene = {
		ComputeProgram = "cs_octahedron_encode_scene";
	}

	cs_octahedron_importance_sample = {
		ComputeProgram = "cs_octahedron_importance_sample";
	}

	cs_octahedron_solid_angle = {
		ComputeProgram = "cs_octahedron_solid_angle";
	}

	cs_cubemap_box_filter = {
		ComputeProgram = "cs_cubemap_box_filter";
	}

	cs_octahedron_encode_scene_pull_fixup = {
		ComputeProgram = "cs_octahedron_encode_scene_pull_fixup";
	}

	//cs_octahedron_encode_scene_pull_fixup_pass2 = {
	//	ComputeProgram = "cs_octahedron_encode_scene_pull_fixup_pass2";
	//}

	cs_dual_paraboloid_sample = {
		ComputeProgram = "cs_dual_paraboloid_sample";
	}

	cs_dual_paraboloid_importance_sample = {
		ComputeProgram = "cs_dual_paraboloid_importance_sample";
	}

	draw_texture = {
		VertexProgram = "draw_texture_fullscreen_vp";
		FragmentProgram = "draw_texture_fullscreen_fp";
	}

	draw_texture_preview = {
		VertexProgram = "draw_texture_preview_vp";
		FragmentProgram = "draw_texture_fullscreen_fp";
	}

	draw_texture_preview_dual_paraboloid = {
		VertexProgram = "draw_texture_preview_dual_paraboloid_vp";
		FragmentProgram = "draw_texture_fullscreen_fp";
	}

	draw_dual_paraboloidal_map = {
		VertexProgram = "draw_dual_paraboloidal_map_vs";
		FragmentProgram = "draw_texture_fullscreen_fp";
	}

	draw_sphere_color_cube = {
		VertexProgram = "draw_texture_fullscreen_vp";
		FragmentProgram = "draw_sphere_color_cube_fp";
	}

	draw_sphere_normal = {
		VertexProgram = "draw_texture_fullscreen_vp";
		FragmentProgram = "draw_sphere_normal_fp";
	}

	draw_sphere_octahedron = {
		VertexProgram = "draw_texture_fullscreen_vp";
		FragmentProgram = "draw_sphere_octahedron_fp";
	}

	draw_sphere_dual_paraboloid = {
		VertexProgram = "draw_texture_fullscreen_vp";
		FragmentProgram = "draw_sphere_dual_paraboloid_fp";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "octahedron_cshared.h"
#include "global_samplers.hlsl"

#define PB_GGX_MAX_SPEC_POWER 20.0f
#define PI 3.1415926535897932384626433f // force PI to float // also see fsl_PI

Texture2D   inTex							MAKE_REGISTER_SRV( 0 );
TextureCube inCubeMap						MAKE_REGISTER_SRV( 1 );
Texture2DArray inTexArray					MAKE_REGISTER_SRV( 2 );
RWTexture2D<float4> outTex					MAKE_REGISTER_UAV( 0 );
RWStructuredBuffer<float4> outBuffer		MAKE_REGISTER_UAV( 0 );
RWTexture2DArray<float4> outTexArray		MAKE_REGISTER_UAV( 0 );


//SamplerState inTexSamp						REGISTER_SAMPLER_TEX_SAMPLER;
//SamplerState inCubeMapSamp					REGISTER_SAMPLER_CUBE_MAP_SAMPLER;

void EncodeOctaNormal( float3 v, inout float2 encV )
{
	//v.z *= -1;
	float rcp_denom = 1.0f / ( abs( v[0] ) + abs( v[1] ) + abs( v[2] ) );

	float2 t = v.xy * rcp_denom;
	float2 t_flipped = 1.0f - abs( t.yx );
	float2 t_flipped_sgn = t >= 0.0 ? 1.0f : -1.0f;

	encV = ( v.z <= 0.0f ) ? t_flipped * t_flipped_sgn : t;
}

void DecodeOctaNormal( const float2 encV, inout float3 v )
{
	v.z = 1.0f - abs( encV.x ) - abs( encV.y );
	float2 encV_flipped = 1.0f - abs( encV.yx );
	float2 encV_flipped_sgn = encV >= 0.0f ? 1.0f : -1.0f;

	v.xy = ( v.z < 0.0f ) ? encV_flipped * encV_flipped_sgn : encV.xy;

	v = normalize( v );
	//v.z *= -1;
}


// https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch20.html
float2 DirectionDualParaboloidalUV( float3 dir, float b )
{
	b = 1.0f;
	if ( dir.z < 0 )
	{
		float s = 1.0f / ( 2.0f * b ) * ( dir.x / ( 1 - dir.z ) ) + 0.5f;
		float t = 1.0f / ( 2.0f * b ) * ( dir.y / ( 1 - dir.z ) ) + 0.5f;
		return float2( s * 0.5f, t );
	}
	else
	{
		float s = 1.0f / ( 2.0f * b ) * ( dir.x / ( 1 + dir.z ) ) + 0.5f;
		float t = 1.0f / ( 2.0f * b ) * ( dir.y / ( 1 + dir.z ) ) + 0.5f;
		return float2( s * 0.5f + 0.5f, t );
	}
}


float3 DualParaboloidalUVToDir( float2 uv, float b )
{
	if ( uv.x < 0.5f )
	{
		float s = uv.x * 2.0f;
		float t = uv.y;
		float2 stn = float2( s, t ) * 2 - 1;
		return normalize( float3( stn, -(0.5f - 0.5f * ( stn.x * stn.x + stn.y * stn.y ) ) ) );
	}
	else
	{
		float s = uv.x * 2.0f - 1.0f;
		float t = uv.y;
		float2 stn = float2( s, t ) * 2 - 1;
		return normalize( float3( stn, (0.5f - 0.5f * ( stn.x * stn.x + stn.y * stn.y ) ) ) );
	}
}


void DecodeOctaNormalFace( const float2 encV, inout uint face )
{
	float3 v;
	v.z = 1.0f - abs( encV.x ) - abs( encV.y );
	float2 encV_flipped = 1.0f - abs( encV.yx );
	float2 encV_flipped_sgn = encV >= 0.0f ? 1.0f : -1.0f;

	v.xy = ( v.z < 0.0f ) ? encV_flipped * encV_flipped_sgn : encV.xy;

	//v = normalize( v );

	if ( v.z <= 0.0f )
	{
		if ( v.x <= 0 && v.y <= 0 )
		{
			face = 6;
		}
		else if ( v.x >= 0 && v.y <= 0 )
		{
			face = 5;
		}
		else if ( v.x >= 0 && v.y >= 0 )
		{
			face = 8;
		}
		else
		{
			face = 7;
		}
	}
	else
	{
		if ( v.x <= 0 && v.y <= 0 )
		{
			face = 2;
		}
		else if ( v.x >= 0 && v.y <= 0 )
		{
			face = 1;
		}
		else if ( v.x >= 0 && v.y >= 0 )
		{
			face = 4;
		}
		else
		{
			face = 3;
		}
	}
}


float3 ColorCodeOctaFace( uint face )
{
	if ( face > 4 )
	{
		if ( face == 5 )
		{
			return float3( 0.3f, 0.3f, 1 ); // light blue
		}
		else if ( face == 6 )
		{
			return float3( 0.5f, 0.5f, 0.5f ); // gray
		}
		else if ( face == 7 )
		{
			return float3( 0, 0, 1 ); // dark blue
		}
		else // if ( face == 8 )
		{
			return float3( 1, 1, 0 ); // yellow
		}
	}
	else
	{
		if ( face == 1 )
		{
			return float3( 139, 69, 19 ) * rcp( 255.0f ); // brown
		}
		else if ( face == 2 )
		{
			return float3( 1, 0, 1 ); // pink
		}
		else if ( face == 3 )
		{
			return float3( 1, 0, 0 ); // red
		}
		else // if ( face == 4 )
		{
			return float3( 0, 1, 0 );
		}
	}
}


// From r_brdf_util.h R_SpecParamFromGloss() also see PhysicallyBased_Alpha2FromGloss()
float SpecParamFromGloss( const in float gloss )
{
	const float exponent = pow( 2.0f, gloss * (float)PB_GGX_MAX_SPEC_POWER );
	return 2.0f / ( 2.0f + exponent ); // matches alpha^2 for GGX physically-based shader
}


float GGX_D( const in float NdotH, const in float alpha2 )
{
	const float denom = ( NdotH * NdotH ) * ( alpha2 - 1.0f ) + 1.0f;
	return alpha2 / ( denom * denom );
}


float GGX_PDF( const float NdotH, const in float alpha2 )
{
	//const float LdotH = NdotH;
	//return GGX_D( NdotH, alpha2 ) * NdotH  / (4.0f * PI * LdotH);

	// simplified as NdotH == LdotH
	return GGX_D( NdotH, alpha2 ) / ( 4.0f * PI );
}


// Z is preserved, Y may be modified to make matrix orthogonal
float3x3 OrthoNormalMatrixFromZY( const in float3 zDirIn, const in float3 yHintDir )
{
	const float3 xDir = normalize( cross( zDirIn, yHintDir ) );
	const float3 yDir = normalize( cross( xDir, zDirIn ) );
	const float3 zDir = normalize( zDirIn );

	float3x3 result = { xDir, yDir, zDir };

	return result;
}


float3x3 OrthoNormalMatrixFromZ( const in float3 zDir )
{
	if ( abs( zDir.y ) < 0.999f )
	{
		const float3 yAxis = float3( 0.0f, 1.0f, 0.0f );
		return OrthoNormalMatrixFromZY( zDir, yAxis );
	}
	else
	{
		const float3 xAxis = float3( 1.0f, 0.0f, 0.0f );
		return OrthoNormalMatrixFromZY( zDir, xAxis );
	}
}


float RadicalInverseVdC( uint bits )
{
	// http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html

	bits = ( bits << 16u ) | ( bits >> 16u );
	bits = ( ( bits & 0x55555555u ) << 1u ) | ( ( bits & 0xAAAAAAAAu ) >> 1u );
	bits = ( ( bits & 0x33333333u ) << 2u ) | ( ( bits & 0xCCCCCCCCu ) >> 2u );
	bits = ( ( bits & 0x0F0F0F0Fu ) << 4u ) | ( ( bits & 0xF0F0F0F0u ) >> 4u );
	bits = ( ( bits & 0x00FF00FFu ) << 8u ) | ( ( bits & 0xFF00FF00u ) >> 8u );
	return float( bits ) * 2.3283064365386963e-10; // / 0x100000000
}


float2 Hammersley2D( const in uint i, const in float rcpSampleCount )
{
	return float2( float( i ) * rcpSampleCount, RadicalInverseVdC( i ) );
}


float2 GetUniformDistribution2DPos( const in uint index, float rcpSampleCount )
{
	return Hammersley2D( index, rcpSampleCount );
}


// Transform from a uniform 2D 0->1 sample space to a spherical co-ordiante with a probability distribution that represents important GGX half-angle vector locations
float2 ImportanceSampleGGXTransform( const float2 uniformSamplePos, const in float alpha2 )
{
	// [Karis2013]  Real Shading in Unreal Engine 4
	// http://blog.tobias-franke.eu/2014/03/30/notes_on_importance_sampling.html

	float theta = acos( sqrt( ( 1.0f - uniformSamplePos.y ) /
		( ( alpha2 - 1.0f ) * uniformSamplePos.y + 1.0f )
	) );

	float phi = 2.0f * PI * uniformSamplePos.x;

	return float2( theta, phi );
}


float3 SphericalToCartesianDirection( const in float2 spherical )
{
	const float theta = spherical.x;
	const float phi = spherical.y;
	const float sinTheta = sin( theta );

	return float3( cos( phi ) * sinTheta, sin( phi ) * sinTheta, cos( theta ) );
}


// Transform from a uniform 2D 0->1 sample space to a direction vector with a probability distribution that represents important GGX half-angle vector locations
float3 ImportanceSampleGGX( const in float2 uniformSamplePos, const in float3 N, const in float alpha2 )
{
	const float2 sphereSamplePos = ImportanceSampleGGXTransform( uniformSamplePos, alpha2 );

	const float3 specSpaceH = SphericalToCartesianDirection( sphereSamplePos );

	const float3x3 specToCubeMat = OrthoNormalMatrixFromZ( N );

	return mul( specSpaceH, specToCubeMat );
}


float CalcNormalizationFactor( float3 dir )
{
	float normalizationFactor = 1.0f;

#ifdef REFLECTION_PROBE_CALC_NORMALIZATION_FACTOR
	normalizationFactor *= REFLECTION_PROBE_CALC_NORMALIZATION_FACTOR( dir );
#endif // #ifdef REFLECTION_PROBE_CALC_NORMALIZATION_FACTOR	

	return normalizationFactor;
}


float3 EvaluateReflectionMipPixel_ImportanceSampling( const in float3 outputPixelDir, const in uint srcDimension, const in float alpha2, const uint sampleCount )
{
	const float rcpSrcDimension = rcp( (float)srcDimension );

	float3 result = float3( 0.0f, 0.0f, 0.0f );

	const float cubeMip0PixelCount = (float)srcDimension * (float)srcDimension;
	const float mipOffset = -0.5f; // User tweaked constant to adjust final mip values ( this is also correcting for any scale factor error I have made in GGX_PDF() etc. )

	const float maxMipLevel = 5.0f; // don't sample from the bottom few mips

	float totalWeight = 0.0f;

	const float rcpSampleCount = rcp( (float)sampleCount );
	for ( uint sampleIndex = 0; sampleIndex < sampleCount; sampleIndex++ )
	{
		const float2 uniformSamplePos = GetUniformDistribution2DPos( sampleIndex, rcpSampleCount );

		const float3 N = outputPixelDir;
		const float3 V = outputPixelDir;
		const float3 H = ImportanceSampleGGX( uniformSamplePos, N, alpha2 );
		const float3 L = reflect( -V, H );

#if USE_PRE_FILTERED_IMPORTANCE_SAMPLING
		// GPU Gems 3 - Chapter 20. GPU-Based Importance Sampling - http://http.developer.nvidia.com/GPUGems3/gpugems3_ch20.html

		const float NdotH = saturate( dot( N, H ) );
		const float pdf = GGX_PDF( NdotH, alpha2 );
		const float sampleSolidAngleRatio = rcp( (float)sampleCount * pdf );

		// Note: 0.5 * log2( x ) == log2( sqrt( x ) )
		// Note: Adding mipOffset is the equivalent of scaling sampleSolidAngleRatio by (2 ^ mipOffset)
		const float sampleMipLevel = clamp( mipOffset + 0.5f * log2( sampleSolidAngleRatio * cubeMip0PixelCount ), 0, maxMipLevel );
#else // #if USE_PRE_FILTERED_IMPORTANCE_SAMPLING
		const float sampleMipLevel = 0.0f;
#endif // #else // #if USE_PRE_FILTERED_IMPORTANCE_SAMPLING

		const float3 sampleValue = inCubeMap.SampleLevel( linearMipLinearClampSampler, L, sampleMipLevel ).rgb;

#if USE_N_DOT_L_WEIGHTING
		const float weight = saturate( dot( N, L ) );
#else // #if USE_N_DOT_L_WEIGHTING
		const float weight = 1.0f;
#endif // #else // #if USE_N_DOT_L_WEIGHTING

		result += sampleValue * weight;
		totalWeight += weight;
	}

	float resultWeight = ( totalWeight > 0.0f ) ? rcp( totalWeight ) : 1.0f;

	//if ( cbNormalizeResult )
	//{
	//	resultWeight *= CalcNormalizationFactor( outputPixelDir );
	//}

	result *= resultWeight;

	return result;
}


void WrapOctahedronReference( inout float2 texel )
{
	if ( texel.x < 0 && texel.y < 0 )
	{
		texel.x = texel.x + 1;
		texel.y = texel.y + 1;
	}
	else if ( texel.x > 1 && texel.y < 0 )
	{
		texel.x = texel.x - 1;
		texel.y = texel.y + 1;
	}
	else if ( texel.x > 1 && texel.y > 1 )
	{
		texel.x = texel.x - 1;
		texel.y = texel.y - 1;
	}
	else if ( texel.x < 0 && texel.y > 1 )
	{
		texel.x = texel.x + 1;
		texel.y = texel.y - 1;
	}
	else if ( texel.y <= 0 )
	{
		texel.x = 1 - texel.x;
		texel.y = -texel.y;
	}
	else if ( texel.y > 1 )
	{
		texel.x = 1 - texel.x;
		texel.y = 2 - texel.y;
	}
	else if ( texel.x <= 0 )
	{
		texel.x = -texel.x;
		texel.y = 1 - texel.y;
	}
	else if ( texel.x > 1 )
	{
		texel.x = 2 - texel.x;
		texel.y = 1 - texel.y;
	}
}


void WrapOctahedron( inout float2 texel )
{
	const bool mirrorX = saturate( texel.x ) != texel.x;
	const bool mirrorY = saturate( texel.y ) != texel.y;
	const bool mirrorXorY = mirrorX || mirrorY;
	const bool mirrorXandY = mirrorX && mirrorY;

	float2 texelPlus1 = texel + 1;
	float2 origin = floor( texelPlus1 );

	float2 t1 = mirrorXorY ? origin - texel : texel;
	float2 t2 = frac( texelPlus1 );

	texel = mirrorXandY ? t2 : t1;
}


[numthreads( 1, 1, 1 )]
void cs_pick_texel( uint3 dtid : SV_DispatchThreadID )
{
	outBuffer[0] = inTex.SampleLevel( pointMipClampSampler, picPosition.xy, sampleMipLevel.x );
}


float2 TexelOffsetForEdgeFixup( uint3 dtid, const uint dstSize )
{
	float2 texelOffset = float2( 0.5f, 0.5f );

	if ( dtid.x == 0 && dtid.y == 0 )
	{
		// left top corner
		texelOffset = float2( 0.0f, 0.0f );
	}
	else if ( dtid.x == 0 && dtid.y == dstSize - 1 )
	{
		// left bottom corner
		texelOffset = float2( 0.0f, 1.0f );
	}
	else if ( dtid.x == dstSize - 1 && dtid.y == dstSize - 1 )
	{
		// right bottom corner
		texelOffset = float2( 1.0f, 1.0f );
	}
	else if ( dtid.x == dstSize - 1 && dtid.y == 0 )
	{
		// right top corner
		texelOffset = float2( 1.0f, 0.0f );
	}
	else if ( dtid.x == 0 )
	{
		// left edge
		texelOffset = float2( 0.0f, 0.5f );
	}
	else if ( dtid.y == dstSize - 1 )
	{
		// bottom edge
		texelOffset = float2( 0.5f, 1.0f );
	}
	else if ( dtid.x == dstSize - 1 )
	{
		// right edge
		texelOffset = float2( 1.0f, 0.5f );
	}
	else if ( dtid.y == 0 )
	{
		// top edge
		texelOffset = float2( 0.5f, 0.0f );
	}

	return texelOffset;
}


float2 TexelOffsetForEdgeFixup2( uint3 dtid, float2 texelOffset, const uint dstSize )
{
	if ( dtid.x == 0 )
	{
		texelOffset.x -= 0.5f;
	}
	else if ( dtid.x == dstSize - 1 )
	{
		texelOffset.x += 0.5f;
	}

	if ( dtid.y == 0 )
	{
		texelOffset.y -= 0.5f;
	}
	else if ( dtid.y == dstSize - 1 )
	{
		texelOffset.y += 0.5f;
	}

	return texelOffset;
}


float4 SampleFace( float2 octahedronUV, const float sampleMipLevel )
{
	float2 uv = octahedronUV * 2 - 1;

	uint face;
	DecodeOctaNormalFace( uv, face );

	return float4( ColorCodeOctaFace( face ), 1.0f );
}


float4 SampleFaceWrap( float2 octahedronUV, const float sampleMipLevel )
{
	WrapOctahedron( octahedronUV );
	float2 uv = octahedronUV * 2 - 1;

	uint face;
	DecodeOctaNormalFace( uv, face );

	return float4( ColorCodeOctaFace( face ), 1.0f );
}


void AdjustLeftEdgeFaces( inout float4 sampleValue, uint3 dtid, float2 uv, float2 texelOffset )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float4 edgeSample0 = SampleFace( float2( texelOffset.x, uv.y ), sampleMipLevel.x );
	float4 edgeSample1 = SampleFaceWrap( float2( -texelOffset.x, uv.y ), sampleMipLevel.x );
	float4 sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
	sampleValue += sampleDiff * ( 4 - dtid.x ) * rcp( 4.0f );
}

void AdjustBottomEdgeFaces( inout float4 sampleValue, uint3 dtid, float2 uv, float2 texelOffset )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float4 edgeSample0 = SampleFace( float2( uv.x, 1.0f - texelOffset.y ), sampleMipLevel.x );
	float4 edgeSample1 = SampleFaceWrap( float2( uv.x, 1.0f + texelOffset.y ), sampleMipLevel.x );
	float4 sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
	sampleValue += sampleDiff * ( 4 - ( dstSize - 1 - dtid.y ) ) * rcp( 4.0f );
}

void AdjustRightEdgeFaces( inout float4 sampleValue, uint3 dtid, float2 uv, float2 texelOffset )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float4 edgeSample0 = SampleFaceWrap( float2( 1.0f - texelOffset.x, uv.y ), sampleMipLevel.x );
	float4 edgeSample1 = SampleFaceWrap( float2( 1.0f + texelOffset.x, uv.y ), sampleMipLevel.x );
	float4 edgeSample = SampleFaceWrap( float2( 1.0f, uv.y ), sampleMipLevel.x );
	float4 sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
	//sampleValue += sampleDiff * ( 1 - ( dstSize - 1 - dtid.x ) - 0.0f ) * rcp( 1.0f );
	//float4 avg = ( edgeSample0 + edgeSample1 ) * 0.5f;
	//sampleValue = lerp( edgeSample, sampleValue, ( 1 - ( dstSize - 1 - dtid.x ) + 0.5f ) * rcp( 1.0f ) );
	//sampleValue = SampleFaceWrap( float2( 1.0f, uv.y ), sampleMipLevel.x );
}

void AdjustTopEdgeFaces( inout float4 sampleValue, uint3 dtid, float2 uv, float2 texelOffset )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float4 edgeSample0 = SampleFace( float2( uv.x, texelOffset.y ), sampleMipLevel.x );
	float4 edgeSample1 = SampleFaceWrap( float2( uv.x, -texelOffset.y ), sampleMipLevel.x );
	float4 sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
	sampleValue += sampleDiff * ( 4 - dtid.y ) * rcp( 4.0f );
}


[numthreads( 8, 8, 1 )]
void cs_color_code_faces( uint3 dtid : SV_DispatchThreadID )
{
	outTex[dtid.xy] = float4( 1, 1, 0, 1 );

	const float dstSize = texSize.x;
	const float dstSizeRcp = 1.0f / dstSize;
	float2 texelOffset = float2( 0.5f, 0.5f );
	//const float2 texelOffset = TexelOffsetForEdgeFixup( dtid, dstSize );
	//texelOffset = TexelOffsetForEdgeFixup2( dtid, texelOffset, dstSize );

	const float2 texelCoord = ( float2 )dtid.xy + texelOffset;
	float2 uv = texelCoord * dstSizeRcp;

	float mipBorderWidth = borderWidth.x;
	uv = uv * 2 - 1;
	float scale = dstSize / ( dstSize - mipBorderWidth * 2 );
	uv *= scale;
	uv = uv * 0.5 + 0.5;

	WrapOctahedron( uv );
	uv = uv * 2 - 1;

	uint face;
	DecodeOctaNormalFace( uv, face );

	outTex[dtid.xy] = float4( ColorCodeOctaFace( face ), 1.0f );
}


[numthreads( 8, 8, 1 )]
void cs_color_code_faces_pull_fixup( uint3 dtid : SV_DispatchThreadID )
{
	outTex[dtid.xy] = float4( 1, 1, 0, 1 );

	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;
	const float dstSizeRcp = 1.0f / dstSize;

	const float2 texelCoord = ( float2 )dtid.xy + float2( 0.5f, 0.5f );
	float2 uv = texelCoord * dstSizeRcp;
	float2 texelOffset = float2( 0.5f, 0.5f ) * dstSizeRcp;

	const bool leftEdge = dtid.x < 4;
	const bool bottomEdge = dtid.y > dstSizeU - 1 - 4;
	const bool rightEdge = dtid.x > dstSizeU - 1 - 1;
	const bool topEdge = dtid.y < 4;

	const bool leftTopCorner = leftEdge && topEdge;
	const bool leftBottomCorner = leftEdge && bottomEdge;
	const bool rightBottomCorner = rightEdge && bottomEdge;
	const bool rightTopCorner = rightEdge && topEdge;

	const bool leftTopTexel = dtid.x == 0 && dtid.y == 0;
	const bool leftBottomTexel = dtid.x == 0 && dtid.y == dstSizeU - 1;
	const bool rightBottomTexel = dtid.x == dstSizeU - 1 && dtid.y == dstSizeU - 1;
	const bool rightTopTexel = dtid.x == dstSizeU - 1 && dtid.y == 0;

	const bool edge = leftEdge || bottomEdge || rightEdge || topEdge;
	const bool corner = leftTopCorner || leftBottomCorner || rightBottomCorner || rightTopCorner;
	const bool cornerTexel = leftTopTexel || leftBottomTexel || rightBottomTexel || rightTopTexel;

	float4 sampleValue;
	if ( cornerTexel )
	{
		float2 baseCoords;
		if ( leftTopTexel )
		{
			baseCoords = float2( 0, 0 );
		}
		else if ( leftBottomTexel )
		{
			baseCoords = float2( 0, 1 );
		}
		else if ( rightBottomTexel )
		{
			baseCoords = float2( 1, 1 );
		}
		else // if ( rightTopTexel )
		{
			baseCoords = float2( 1, 0 );
		}

		float4 edgeSample0 = SampleFaceWrap( baseCoords + float2( -texelOffset.x, -texelOffset.y ), sampleMipLevel.x );
		float4 edgeSample1 = SampleFaceWrap( baseCoords + float2( -texelOffset.x, texelOffset.y ), sampleMipLevel.x );
		float4 edgeSample2 = SampleFaceWrap( baseCoords + float2( texelOffset.x, texelOffset.y ), sampleMipLevel.x );
		float4 edgeSample3 = SampleFaceWrap( baseCoords + float2( texelOffset.x, -texelOffset.y ), sampleMipLevel.x );
		sampleValue = ( edgeSample0 + edgeSample1 + edgeSample2 + edgeSample3 ) * 0.25f;
	}
	else
	{
		sampleValue = SampleFace( uv, sampleMipLevel.x );

		//if ( leftEdge )
		//{
		//	AdjustLeftEdgeFaces( sampleValue, dtid, uv, texelOffset );
		//}

		//if ( bottomEdge )
		//{
		//	AdjustBottomEdgeFaces( sampleValue, dtid, uv, texelOffset );
		//}

		if ( rightEdge )
		{
			AdjustRightEdgeFaces( sampleValue, dtid, uv, texelOffset );
		}

		//if ( topEdge )
		//{
		//	AdjustTopEdgeFaces( sampleValue, dtid, uv, texelOffset );
		//}
	}


	outTex[dtid.xy] = sampleValue;
}


[numthreads( 8, 8, 1 )]
void cs_octahedron_encode_normal( uint3 dtid : SV_DispatchThreadID )
{
	outTex[dtid.xy] = float4( 1, 1, 0, 1 );

	const float dstSize = texSize.x;
	const float dstSizeRcp = 1.0f / dstSize;
	float2 texelOffset = float2( 0.5f, 0.5f );

	const float2 texelCoord = ( float2 )dtid.xy + texelOffset;
	float2 uv = texelCoord * dstSizeRcp;

	float mipBorderWidth = borderWidth.x;
	uv = uv * 2 - 1;
	float scale = dstSize / ( dstSize - mipBorderWidth * 2 );
	uv *= scale;
	uv = uv * 0.5 + 0.5;

	WrapOctahedron( uv );
	uv = uv * 2 - 1;

	float3 normal;
	DecodeOctaNormal( uv, normal );

	normal = normal * 0.5 + 0.5;
	outTex[dtid.xy] = float4( normal, 1.0f );
}


[numthreads( 8, 8, 1 )]
void cs_octahedron_encode_scene( uint3 dtid : SV_DispatchThreadID )
{
	outTex[dtid.xy] = float4( 1, 1, 0, 1 );

	const float dstSize = texSize.x;
	const float dstSizeRcp = 1.0f / dstSize;
	float2 texelOffset = float2( 0.5f, 0.5f );
	const float2 texelCoord = ( float2 )dtid.xy + texelOffset;
	float2 uv = texelCoord * dstSizeRcp;

	const int dstMip = (int)texSize.z;
	int borderMode = ( int )borderWidth.y;
	float mipBorderWidth = borderWidth.x;

	if ( borderMode == 0 )
	{
		mipBorderWidth = 0;
	}
	else if ( borderMode == 1 )
	{

	}
	else if ( borderMode == 2 )
	{
		// The idea is that mips 0, 1, 2, 3 have border 4. Mips 4 and 5 have border 2 and 1 respectively.
		// Mip 4 and 5 are so small that using border 4 would leave no space for actual data
		const int mipBias = 3;
		int borderWidthShift = max( (int)dstMip - mipBias, 0 );
		mipBorderWidth = (float)( 4 >> borderWidthShift );
	}

	//uv = uv * 2 - 1;
	//float scale = dstSize / ( dstSize - mipBorderWidth * 2 );
	//uv *= scale;
	//uv = uv * 0.5 + 0.5;

	//float offset = borderWidth / texSize;
	//float scale = 1.0f - 2 * offset;
	//return octahedronMapUVs * scale + offset;

	//float scale = dstSize / ( dstSize - mipBorderWidth * 2 );
	////uv *= scale;
	////uv -= dstSizeRcp * mipBorderWidth;
	//uv = uv * scale - 0.5f * scale + 0.5f;

	WrapOctahedron( uv );
	uv = uv * 2 - 1;

	float3 normal;
	DecodeOctaNormal( uv, normal );

	outTex[dtid.xy] = inCubeMap.SampleLevel( linearMipLinearClampSampler, normal, sampleMipLevel.x ) * 0.5f;
}


[numthreads( 8, 8, 1 )]
void cs_octahedron_importance_sample( uint3 dtid : SV_DispatchThreadID )
{
	outTex[dtid.xy] = float4( 1, 1, 0, 1 );

	const float dstSize = texSize.x;
	const float dstSizeRcp = 1.0f / dstSize;
	float2 texelOffset = float2( 0.5f, 0.5f );

	const float2 texelCoord = ( float2 )dtid.xy + texelOffset;
	float2 uv = texelCoord * dstSizeRcp;

	float mipBorderWidth = borderWidth.x;
	uv = uv * 2 - 1;
	float scale = dstSize / ( dstSize - mipBorderWidth * 2 );
	uv *= scale;
	uv = uv * 0.5 + 0.5;

	WrapOctahedron( uv );
	uv = uv * 2 - 1;

	float3 normal;
	DecodeOctaNormal( uv, normal );

	//const uint srcSize = 1024;// cbSrcImageSize;
	const uint cbSampleCount = 1024;
	const float alpha2 = SpecParamFromGloss( cbSpecularGloss.x );
	//const uint srcSize = importanceSampleParams.x;
	const uint srcSize = 128;
	//const uint cbSampleCount = importanceSampleParams.y;
	//const float alpha2 = SpecParamFromGloss( asfloat( importanceSampleParams.z ) );
	const float3 result = EvaluateReflectionMipPixel_ImportanceSampling( normal, srcSize, alpha2, cbSampleCount );

	//outTex[dtid.xy] = inCubeMap.SampleLevel( linearMipLinearClampSampler, normal, sampleMipLevel.x ) * 0.5f;
	outTex[dtid.xy] = float4( result.rgb * 0.22f, 1.0f );
}


// CubeMapFaceID - returns ID of cubemap face that would be sampled using vec as lookup direction 
float CubeMapFaceID( const float3 vec )
{
	float3 v = vec;
	float faceID;

	if ( abs( v.z ) >= abs( v.x ) && abs( v.z ) >= abs( v.y ) )

	{
		faceID = ( v.z < 0.0 ) ? 5.0 : 4.0;
	}
	else if ( abs( v.y ) >= abs( v.x ) )

	{
		faceID = ( v.y < 0.0 ) ? 3.0 : 2.0;
	}
	else
	{
		faceID = ( v.x < 0.0 ) ? 1.0 : 0.0;
	}

	return faceID;
}


static const uint CUBE_FACE_POS_X = 0;
static const uint CUBE_FACE_NEG_X = 1;
static const uint CUBE_FACE_POS_Y = 2;
static const uint CUBE_FACE_NEG_Y = 3;
static const uint CUBE_FACE_POS_Z = 4;
static const uint CUBE_FACE_NEG_Z = 5;
static const uint CUBE_FACE_COUNT = 6;


float3 CubeMap_UVWFromDir( const in float3 dir, const uint faceIndex )
{
	switch ( faceIndex )
	{
	default: // fallthrough
	case CUBE_FACE_POS_X:	return float3( -dir.z, -dir.y, dir.x );
	case CUBE_FACE_NEG_X:	return float3( dir.z, -dir.y, -dir.x );
	case CUBE_FACE_POS_Y:	return float3( dir.x, dir.z, dir.y );
	case CUBE_FACE_NEG_Y:	return float3( dir.x, -dir.z, -dir.y );
	case CUBE_FACE_POS_Z:	return float3( dir.x, -dir.y, dir.z );
	case CUBE_FACE_NEG_Z:	return float3( -dir.x, -dir.y, -dir.z );
	}
}


float2 CubeMap_DirToUV( const in float3 dir )
{
	const uint faceIndex = ( uint )CubeMapFaceID( dir );

	const float3 uvw = CubeMap_UVWFromDir( dir, faceIndex );

	const float2 signedUV = uvw.xy * rcp( abs( uvw.z ) );
	const float2 uv = signedUV * 0.5f + 0.5f;

	return uv;
}


float CubeMapTexelSolidAngle( uint2 texelCoord, const float n )
{
	const float rcp_n = rcp( n );

	// calculate differential solid angle dW
	// dW = cos(theta_y) / rxy^2 * dAy
	//    = dAy /(pow(rxy), 1.5)
	float u = ( texelCoord.x + 0.5f ) * rcp_n * 2.0f - 1.0f;
	float v = ( texelCoord.y + 0.5f ) * rcp_n * 2.0f - 1.0f;
	float rxy2 = 1.0f + u * u + v * v;
	float dAy = 4.0f * rcp_n * rcp_n;
	float dW = dAy * rcp( sqrt( rxy2 ) * rxy2 );

	return dW;
}



static float AreaElement( const in float x, const in float y )
{
	return atan2( x * y, sqrt( x * x + y * y + 1.0f ) );
}


float CubeMap_SolidAngle( const in float invImageSize, const in float2 uv )
{
	// http://www.rorydriscoll.com/2012/01/15/cubemap-texel-solid-angle/

	const float s = 2.0f * uv.x - 1.0f;
	const float t = 2.0f * uv.y - 1.0f;

	const float x0 = s - invImageSize;
	const float y0 = t - invImageSize;
	const float x1 = s + invImageSize;
	const float y1 = t + invImageSize;

	const float areaA = AreaElement( x0, y0 );
	const float areaB = AreaElement( x1, y0 );
	const float areaC = AreaElement( x0, y1 );
	const float areaD = AreaElement( x1, y1 );

	// y
	// ^
	// |
	// |.......C-----D
	// |       |     |
	// |       |     |
	// |.......A-----B
	// |       :     :
	// |       :     :
	// |       :     :
	// +-----------------> x

	const float solidAngle = areaA - areaB - areaC + areaD;

	return solidAngle;
}


float TriArea( float3 A, float3 B, float3 C )
{
	float3 AB = B - A;
	float3 AC = C - A;
	return 0.5f * length( cross( AB, AC ) );
	//float3 cr = cross( AB, AC );
	//return 0.5f * sqrt( dot(cr, cr) );
}


float3 CalcTangent( float3 p0, float3 p1 )
{
	float3 p, r, t;

	p = p1 - p0;
	r = cross( p0, p );
	t = cross( r, p0 );
	t = normalize( t );

	return t;
}


float AngleRadBetween( float3 a, float3 b )
{
	const float d = clamp( dot( a, b ), -1.0f, 1.0f );
	const float angleBetween = acos( d );
	return angleBetween;
}


float TriangleSolidAngle( float3 C0, float3 C1, float3 C2 )
{
	float3 C0C1Tangent = CalcTangent( C0, C1 );
	float3 C0C2Tangent = CalcTangent( C0, C2 );

	float3 C1C0Tangent = CalcTangent( C1, C0 );
	float3 C1C2Tangent = CalcTangent( C1, C2 );

	float3 C2C0Tangent = CalcTangent( C2, C0 );
	float3 C2C1Tangent = CalcTangent( C2, C1 );

	float rad0 = AngleRadBetween( C0C1Tangent, C0C2Tangent );
	float rad1 = AngleRadBetween( C1C0Tangent, C1C2Tangent );
	float rad2 = AngleRadBetween( C2C0Tangent, C2C1Tangent );

	return rad0 + rad1 + rad2 - PI;
}


float OctahedronTexelSolidAngle( float2 texelUvs01, float mipSize, float mipSizeRcp, float mipBorderWidth )
{
	float2 baseUv = texelUvs01;
	float ht = 0.5f * mipSizeRcp;

	float2 uvOffs[4];
	float3 sampleDir[4];

	uvOffs[0] = float2( -ht, -ht );
	uvOffs[1] = float2( -ht, ht );
	uvOffs[2] = float2( ht, ht );
	uvOffs[3] = float2( ht, -ht );

	for ( uint iSample = 0; iSample < 4; ++iSample )
	{
		float2 uv = baseUv + uvOffs[iSample];

		uv = uv * 2 - 1;
		float scale = mipSize / ( mipSize - mipBorderWidth * 2 );
		uv *= scale;
		uv = uv * 0.5 + 0.5;

		WrapOctahedron( uv );
		uv = uv * 2 - 1;

		DecodeOctaNormal( uv, sampleDir[iSample] );
	}

	float texelArea = TriArea( sampleDir[0], sampleDir[1], sampleDir[2] );
	texelArea += TriArea( sampleDir[0], sampleDir[2], sampleDir[3] );

	//float texelArea = TriangleSolidAngle( sampleDir[0], sampleDir[1], sampleDir[2] );
	//texelArea += TriangleSolidAngle( sampleDir[0], sampleDir[2], sampleDir[3] );

	return texelArea;
}

float CubeMapTexelSolidAngleImpl( float2 texelUvs01, float mipSize, float mipSizeRcp, float mipBorderWidth )
{
	float2 uv = texelUvs01 * 2 - 1;
	float scale = mipSize / ( mipSize - mipBorderWidth * 2 );
	uv *= scale;
	uv = uv * 0.5 + 0.5;

	WrapOctahedron( uv );
	uv = uv * 2 - 1;

	float3 sampleDir;
	DecodeOctaNormal( uv, sampleDir );

	float2 cubeMapUv = CubeMap_DirToUV( sampleDir );

	//return CubeMapTexelSolidAngle( cubeMapUv * mipSize, mipSize );
	return CubeMapTexelSolidAngle( texelUvs01 * mipSize, mipSize );
	//return CubeMap_SolidAngle( mipSizeRcp, cubeMapUv );
}

[numthreads( 8, 8, 1 )]
void cs_octahedron_solid_angle( uint3 dtid : SV_DispatchThreadID )
{
	outTex[dtid.xy] = float4( 1, 1, 0, 1 );

	const float dstSize = texSize.x;
	const float dstSizeRcp = 1.0f / dstSize;
	const float mipBorderWidth = borderWidth.x;

	const float2 texelCoord = ( float2 )dtid.xy + 0.5f;
	float2 baseUv = texelCoord * dstSizeRcp;

	float result = 0;
	if ( solidAngleMode.x == 0 )
	{
		float cubeMapSolidAngle = CubeMapTexelSolidAngleImpl( baseUv, dstSize, dstSizeRcp, mipBorderWidth );
		result = cubeMapSolidAngle;
	}
	else if ( solidAngleMode.x == 1 )
	{
		float octahedronSolidAngle = OctahedronTexelSolidAngle( baseUv, dstSize, dstSizeRcp, mipBorderWidth );
		result = octahedronSolidAngle;
	}

	result *= solidAngleMode.y;

	outTex[dtid.xy] = float4( result.xxx, 1.0f );
}


void BoxFilter( const in uint3 dtid, const in bool flipFaces )
{
	const uint dstSize = uint( texSize.x );
	const uint cbFirstFaceIndex = 0;
	const uint cbFaceCount = 6;
	const uint cbSrcImageSize = uint( texSize.w );

	const uint3 dstXYFace = int3( dtid.x, dtid.y, dtid.z + cbFirstFaceIndex );

	if ( ( dstXYFace.x >= dstSize ) ||
		( dstXYFace.y >= dstSize ) ||
		( dstXYFace.z >= ( cbFirstFaceIndex + cbFaceCount ) ) )
	{
		return;
	}

	const uint srcSize = cbSrcImageSize;
	const float rcpSrcDimension = rcp( (float)srcSize );

	const uint2 srcMin = uint2( dstXYFace.xy * srcSize / (float)dstSize );
	const uint boxSize = 1 * srcSize / (float)dstSize;

	float totalWeight = 0.0f;
	float3 result = float3( 0.0f, 0.0f, 0.0f );
	for ( uint boxY = 0; boxY < boxSize; boxY++ )
	{
		for ( uint boxX = 0; boxX < boxSize; boxX++ )
		{
			int3 srcXYFace = int3( srcMin.x + boxX, srcMin.y + boxY, dstXYFace.z );
			//if ( flipFaces )
			//{
			//	srcXYFace = Cubemap_FlipSides( srcXYFace, srcSize );
			//}
			const float2 sampleUV = ( ( float2 )srcXYFace.xy + 0.5f ) * rcpSrcDimension;
			const float solidAngle = CubeMap_SolidAngle( rcpSrcDimension, sampleUV );
			const float weight = solidAngle;
			result += inTexArray[srcXYFace].rgb * weight;
			totalWeight += weight;
		}
	}

	float resultWeight = ( totalWeight > 0.0f ) ? rcp( totalWeight ) : 1.0f;

	//if ( cbNormalizeResult )
	//{
	//	const float2 dstUV = ( ( float2 )dstXYFace.xy + 0.5f ) / (float)dstSize;
	//	const float3 dstDir = normalize( CubeMap_DirFromUVFace( dstUV, dstXYFace.z ) );
	//	resultWeight *= CalcNormalizationFactor( dstDir );
	//}

	result *= resultWeight;

	outTexArray[dstXYFace] = float4( result * 0.75f, 1.0f );
}


[numthreads( 8, 8, 1 )]
void cs_cubemap_box_filter( uint3 dtid : SV_DispatchThreadID )
{
	BoxFilter( dtid, false /*flipFaces*/ );
}

float4 SampleCubemap( float2 octahedronUV, const float sampleMipLevel )
{
	float2 uv = octahedronUV * 2 - 1;

	float3 sampleDir;
	DecodeOctaNormal( uv, sampleDir );

	return inCubeMap.SampleLevel( linearMipLinearClampSampler, sampleDir, sampleMipLevel ) * 0.5f;
}


float4 SampleCubemapWrap( float2 octahedronUV, const float sampleMipLevel )
{
	WrapOctahedron( octahedronUV );
	float2 uv = octahedronUV * 2 - 1;

	float3 sampleDir;
	DecodeOctaNormal( uv, sampleDir );

	return inCubeMap.SampleLevel( linearMipLinearClampSampler, sampleDir, sampleMipLevel ) * 0.5f;
}


// Mitchell Netravali Reconstruction Filter

// B = 1,   C = 0   - cubic B-spline

// B = 1/3, C = 1/3 - recommended

// B = 0,   C = 1/2 - Catmull-Rom spline


float MitchellNetravali( float x, float B, float C )
{
	float ax = abs( x );
	if ( ax < 1 )
	{
		return ( ( 12 - 9 * B - 6 * C ) * ax * ax * ax +
			( -18 + 12 * B + 6 * C ) * ax * ax + ( 6 - 2 * B ) ) / 6;
	}
	else if ( ( ax >= 1 ) && ( ax < 2 ) )
	{
		return ( ( -B - 6 * C ) * ax * ax * ax +
			( 6 * B + 30 * C ) * ax * ax + ( -12 * B - 48 * C ) *
			ax + ( 8 * B + 24 * C ) ) / 6;
	}
	else
	{
		return 0;
	}
}

float FilterWeight( float x )
{
	return MitchellNetravali( x, 1, 0 );
}


static const uint pullFixupWidth = 2;

float CalcFixupWeightLeftTop( uint d )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float fixupFrac = ( pullFixupWidth - d ) * rcp( pullFixupWidth );
	float fixupWeight = ( ( -2.0 * fixupFrac + 3.0 ) * fixupFrac * fixupFrac );
	//float fixupWeight = fixupFrac;
	return fixupWeight;
}

float CalcFixupWeightRightBottom( uint d )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float fixupFrac = ( pullFixupWidth - ( dstSizeU - 1 - d ) ) * rcp( pullFixupWidth );
	float fixupWeight = ( ( -2.0 * fixupFrac + 3.0 ) * fixupFrac * fixupFrac );
	//float fixupWeight = fixupFrac;
	return fixupWeight;
}

void AdjustLeftEdge( inout float4 sampleValue, uint3 dtid, float2 uv, float2 texelOffset )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float4 edgeSample0 = SampleCubemap( float2( texelOffset.x, uv.y ), sampleMipLevel.x );
	float4 edgeSample1 = SampleCubemapWrap( float2( -texelOffset.x, uv.y ), sampleMipLevel.x );
	float4 sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
	//sampleValue += sampleDiff * ( 4 - dtid.x ) * rcp( 4.0f );
	sampleValue += sampleDiff * CalcFixupWeightLeftTop( dtid.x );
}

void AdjustBottomEdge( inout float4 sampleValue, uint3 dtid, float2 uv, float2 texelOffset )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float4 edgeSample0 = SampleCubemap( float2( uv.x, 1.0f - texelOffset.y ), sampleMipLevel.x );
	float4 edgeSample1 = SampleCubemapWrap( float2( uv.x, 1.0f + texelOffset.y ), sampleMipLevel.x );
	float4 sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
	//sampleValue += sampleDiff * ( 4 - ( dstSize - 1 - dtid.y ) ) * rcp( 4.0f );
	sampleValue += sampleDiff * CalcFixupWeightRightBottom( dtid.y );
}

void AdjustRightEdge( inout float4 sampleValue, uint3 dtid, float2 uv, float2 texelOffset )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float4 edgeSample0 = SampleCubemap( float2( 1.0f - texelOffset.x, uv.y ), sampleMipLevel.x );
	float4 edgeSample1 = SampleCubemapWrap( float2( 1.0f + texelOffset.x, uv.y ), sampleMipLevel.x );
	float4 sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
	//float fixupFrac = ( 4 - ( dstSize - 1 - dtid.x ) ) * rcp( 4.0f );
	//float fixupWeight = ( ( -2.0 * fixupFrac + 3.0 ) * fixupFrac * fixupFrac );
	//float fixupWeight = fixupFrac;
	//sampleValue += sampleDiff * fixupWeight;
	sampleValue += sampleDiff * CalcFixupWeightRightBottom( dtid.x );
	//sampleValue = lerp( sampleValue + sampleDiff, sampleValue, factor );
	//sampleValue = SampleCubemapWrap( float2( 1.0f, uv.y ), sampleMipLevel.x );

	//float4 avg = ( edgeSample0 + edgeSample1 ) * 0.5f;
	//float4 dev0 = edgeSample0 - avg;
	//float4 dev1 = edgeSample1 - avg;

	//sampleValue -= dev0 * fixupWeight;
}

void AdjustTopEdge( inout float4 sampleValue, uint3 dtid, float2 uv, float2 texelOffset )
{
	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;

	float4 edgeSample0 = SampleCubemap( float2( uv.x, texelOffset.y ), sampleMipLevel.x );
	float4 edgeSample1 = SampleCubemapWrap( float2( uv.x, -texelOffset.y ), sampleMipLevel.x );
	float4 sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
	//sampleValue += sampleDiff * ( 4 - dtid.y ) * rcp( 4.0f );
	sampleValue += sampleDiff * CalcFixupWeightLeftTop( dtid.y );
}


float4 SampleFiltered( float2 texelCoord )
{
	const float dstSize = texSize.x;
	const float dstSizeRcp = 1.0f / dstSize;

	const int filterRadius = 2;
	const float filterRadiusRcp = filterRadius > 0 ? 2.0f / filterRadius : 1.0f;
	//const float filterRadiusRcp = 1;

	float3 sampleSum = 0;
	float weightSum = 0;

	[unroll]
	for ( int y = -filterRadius; y <= filterRadius; ++y )
	{
		float yy = y * filterRadiusRcp;

		float weightYY = FilterWeight( yy );

		[unroll]
		for ( int x = -filterRadius; x <= filterRadius; ++x )
		{
			float xx = x * filterRadiusRcp;

			float2 uv = texelCoord + float2( x, y ) * 0.5f;
			uv *= dstSizeRcp;

			//uv = uv * 2 - 1;
			//uv *= ( dstSize + mipBorderWidth * 2 ) * dstSizeRcp; // borderWidth * 2 because uv is in <-1,1> range
			//uv = uv * 0.5 + 0.5;

			WrapOctahedron( uv );
			uv = uv * 2 - 1;

			float3 sampleDir;
			DecodeOctaNormal( uv, sampleDir );

			const float3 sampleValue = inCubeMap.SampleLevel( linearMipLinearClampSampler, sampleDir, sampleMipLevel.x ).rgb * 0.5f;

			float weightXX = FilterWeight( xx );

			sampleSum += sampleValue * weightXX * weightYY;
			weightSum += weightXX * weightYY;
		}
	}

	float3 sampleValue = weightSum > 0 ? sampleSum / weightSum : sampleSum;

	return float4( sampleValue, 0 );
}

[numthreads( 8, 8, 1 )]
void cs_octahedron_encode_scene_pull_fixup( uint3 dtid : SV_DispatchThreadID )
{
	outTex[dtid.xy] = float4( 1, 1, 0, 1 );

	const float dstSize = texSize.x;
	const uint dstSizeU = ( uint )dstSize;
	const float dstSizeRcp = 1.0f / dstSize;
	//float2 texelOffset = float2( 0.5f, 0.5f );

	//const float2 texelCoord = ( float2 )dtid.xy + texelOffset;
	//float2 uv = texelCoord * dstSizeRcp;

	const float2 texelCoord = ( float2 )dtid.xy + float2( 0.5f, 0.5f );
	float2 uv = texelCoord * dstSizeRcp;
	float2 texelOffset = float2( 0.5f, 0.5f ) * dstSizeRcp;

	const bool leftEdge = dtid.x < pullFixupWidth;
	const bool bottomEdge = dtid.y > dstSizeU - 1 - pullFixupWidth;
	const bool rightEdge = dtid.x > dstSizeU - 1 - pullFixupWidth;
	const bool topEdge = dtid.y < pullFixupWidth;

	const bool leftTopCorner = leftEdge && topEdge;
	const bool leftBottomCorner = leftEdge && bottomEdge;
	const bool rightBottomCorner = rightEdge && bottomEdge;
	const bool rightTopCorner = rightEdge && topEdge;

	const bool leftTopTexel = dtid.x == 0 && dtid.y == 0;
	const bool leftBottomTexel = dtid.x == 0 && dtid.y == dstSizeU - 1;
	const bool rightBottomTexel = dtid.x == dstSizeU - 1 && dtid.y == dstSizeU - 1;
	const bool rightTopTexel = dtid.x == dstSizeU - 1 && dtid.y == 0;

	const bool edge = leftEdge || bottomEdge || rightEdge || topEdge;
	const bool corner = leftTopCorner || leftBottomCorner || rightBottomCorner || rightTopCorner;
	const bool cornerTexel = leftTopTexel || leftBottomTexel || rightBottomTexel || rightTopTexel;

	float4 sampleValue;
	if ( cornerTexel )
	{
		float2 baseCoords;
		if ( leftTopTexel )
		{
			baseCoords = float2( 0, 0 );
		}
		else if ( leftBottomTexel )
		{
			baseCoords = float2( 0, 1 );
		}
		else if ( rightBottomTexel )
		{
			baseCoords = float2( 1, 1 );
		}
		else // if ( rightTopTexel )
		{
			baseCoords = float2( 1, 0 );
		}

		float4 edgeSample0 = SampleCubemapWrap( baseCoords + float2( -texelOffset.x, -texelOffset.y ), sampleMipLevel.x );
		float4 edgeSample1 = SampleCubemapWrap( baseCoords + float2( -texelOffset.x,  texelOffset.y ), sampleMipLevel.x );
		float4 edgeSample2 = SampleCubemapWrap( baseCoords + float2(  texelOffset.x,  texelOffset.y ), sampleMipLevel.x );
		float4 edgeSample3 = SampleCubemapWrap( baseCoords + float2(  texelOffset.x, -texelOffset.y ), sampleMipLevel.x );
		sampleValue = ( edgeSample0 + edgeSample1 + edgeSample2 + edgeSample3 ) * 0.25f;
	}
	else
	{
		sampleValue = SampleCubemap( uv, sampleMipLevel.x );
		//if ( corner )
		//{
		//	if ( leftTopCorner )
		//	{
		//		AdjustLeftEdge( sampleValue, dtid, uv, texelOffset );
		//		AdjustTopEdge( sampleValue, dtid, uv, texelOffset );
		//	}
		//	else if ( leftBottomCorner )
		//	{
		//		AdjustLeftEdge( sampleValue, dtid, uv, texelOffset );
		//		AdjustBottomEdge( sampleValue, dtid, uv, texelOffset );
		//	}
		//	else if ( rightBottomCorner )
		//	{
		//		AdjustRightEdge( sampleValue, dtid, uv, texelOffset );
		//		AdjustBottomEdge( sampleValue, dtid, uv, texelOffset );
		//	}
		//	else
		//	{
		//		AdjustRightEdge( sampleValue, dtid, uv, texelOffset );
		//		AdjustTopEdge( sampleValue, dtid, uv, texelOffset );
		//	}
		//}
		//else if ( edge )
		//{
			if ( leftEdge )
			{
				AdjustLeftEdge( sampleValue, dtid, uv, texelOffset );
			}
			//else if ( bottomEdge )
			if ( bottomEdge )
			{
				AdjustBottomEdge( sampleValue, dtid, uv, texelOffset );
			}
			//else if ( rightEdge )
			if ( rightEdge )
			{
				AdjustRightEdge( sampleValue, dtid, uv, texelOffset );
			}
			//else // if ( topEdge )
			if ( topEdge )
			{
				AdjustTopEdge( sampleValue, dtid, uv, texelOffset );
			}

			//float3 s1 = SampleCubemapWrap( uv + offset, sampleMipLevel.x );
			//sampleValue = ( sampleValue + s1 ) * 0.5f;
		//}

		//if ( rightEdge )
		//{
		//	//float4 edgeSample0 = SampleCubemap( float2( 1.0f - texelOffset.x, uv.y ), sampleMipLevel.x );
		//	//float4 edgeSample1 = SampleFiltered( float2( dstSize, texelCoord.y ) );
		//	//float4 edgeSample0 = SampleFiltered( float2( dstSize - 0.5f, texelCoord.y ) );
		//	//float4 edgeSample1 = SampleFiltered( float2( dstSize + 0.5f, texelCoord.y ) );
		//	//float4 edgeSample1 = SampleCubemapWrap( float2( 1.0f + texelOffset.x, uv.y ), sampleMipLevel.x );
		//	float4 sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.25f;
		//	sampleValue += sampleDiff * ( 4 - ( dstSize - 1 - dtid.x ) ) * rcp( 4.0f );
		//	//sampleValue = edgeSample1;
		//}
	}


	outTex[dtid.xy] = sampleValue;
}

//[numthreads( 8, 8, 1 )]
//void cs_octahedron_encode_scene_pull_fixup_pass2( uint3 dtid : SV_DispatchThreadID )
//{
//	outTex[dtid.xy] = float4( 1, 1, 0, 1 );
//
//	const float dstSize = texSize.x;
//	const uint dstSizeU = ( uint )dstSize;
//	const float dstSizeRcp = 1.0f / dstSize;
//
//	const float2 texelCoord = ( float2 )dtid.xy + float2( 0.5f, 0.5f );
//	float2 uv = texelCoord * dstSizeRcp;
//	float2 texelOffset = float2( 0.5f, 0.5f ) * dstSizeRcp;
//
//	const bool leftEdge = dtid.x < 4;
//	const bool bottomEdge = dtid.y > dstSizeU - 1 - 4;
//	const bool rightEdge = dtid.x > dstSizeU - 1 - 4;
//	const bool topEdge = dtid.y < 4;
//
//	const bool leftTopCorner = leftEdge && topEdge;
//	const bool leftBottomCorner = leftEdge && bottomEdge;
//	const bool rightBottomCorner = rightEdge && bottomEdge;
//	const bool rightTopCorner = rightEdge && topEdge;
//
//	const bool edge = leftEdge || bottomEdge || rightEdge || topEdge;
//	const bool corner = leftTopCorner || leftBottomCorner || rightBottomCorner || rightTopCorner;
//
//	float4 sampleValue = SampleCubemap( uv, sampleMipLevel.x );
//	if ( corner )
//	{
//		float4 edgeSample0;
//		float4 edgeSample1;
//		float4 sampleDiff;
//
//		if ( leftTopCorner || rightTopCorner )
//		{
//			// pass 2
//			// pull data from top edge
//			edgeSample0 = SampleCubemap( float2( uv.x, texelOffset.y ), sampleMipLevel.x );
//			edgeSample1 = SampleCubemapWrap( float2( uv.x, -texelOffset.y ), sampleMipLevel.x );
//			sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
//			sampleValue += sampleDiff * ( 4 - dtid.y ) * rcp( 4.0f );
//		}
//		else
//		{
//			// pass 1
//			// pull data from bottom edge
//			edgeSample0 = SampleCubemap( float2( uv.x, 1.0f - texelOffset.y ), sampleMipLevel.x );
//			edgeSample1 = SampleCubemapWrap( float2( uv.x, 1.0f + texelOffset.y ), sampleMipLevel.x );
//			sampleDiff = ( edgeSample1 - edgeSample0 ) * 0.5f;
//			sampleValue += sampleDiff * ( 4 - ( dstSize - 1 - dtid.y ) ) * rcp( 4.0f );
//		}
//	}
//
//	outTex[dtid.xy] = sampleValue;
//}

//float2 AdjustSampleUVsForBorder( float2 octahedronMapUVs )
//{
//	//// octahedronMapUVs must be in <-1,1> range
//	//octahedronMapUVs *= ( texSize.x - borderWidth.x * 2 ) * ( 1.0f / (texSize.x - borderWidth.x) );
//	//octahedronMapUVs = octahedronMapUVs * 0.5 + 0.5;
//	//return octahedronMapUVs;
//
//	float offset = borderWidth.x / texSize.x;
//	float scale = 1.0f - 2 * offset;
//	return octahedronMapUVs * scale + offset;
//}

static const uint dualParaboloidWidthScale = 1;


float4 SampleDualParaboloid( float2 texelCoord )
{
	const float2 dstSize = float2( texSize.x * dualParaboloidWidthScale, texSize.x );
	const float2 dstSizeRcp = 1.0f / dstSize;

	//const float2 texelCoord = ( float2 )dtid.xy;// +texelOffset;
	float2 baseUVs = texelCoord * dstSizeRcp;

	float2 uv = baseUVs;
	if ( baseUVs.x < 0.5f )
	{
		uv.x *= 2;
	}
	else
	{
		uv.x = uv.x * 2 - 1;
	}

	float mipBorderWidth = borderWidth.x;
	uv = uv * 2 - 1;
	float scale = dstSize.y / ( dstSize.y - mipBorderWidth * 2 );
	uv *= scale;
	uv = uv * 0.5 + 0.5;

	float3 sampleDir;

	if ( baseUVs.x < 0.5f )
	{
		float2 stn = float2( uv ) * 2 - 1;
		sampleDir = normalize( float3( stn, -( 0.5f - 0.5f * ( stn.x * stn.x + stn.y * stn.y ) ) ) );
	}
	else
	{
		float2 stn = float2( uv ) * 2 - 1;
		sampleDir = normalize( float3( stn, ( 0.5f - 0.5f * ( stn.x * stn.x + stn.y * stn.y ) ) ) );
	}

	return inCubeMap.SampleLevel( linearMipLinearClampSampler, sampleDir, sampleMipLevel.x ) * 0.5f;
}


[numthreads( 8, 8, 1 )]
void cs_dual_paraboloid_sample( uint3 dtid : SV_DispatchThreadID )
{
	outTex[dtid.xy] = float4( 1, 1, 0, 1 );

	//const float2 dstSize = float2( texSize.x * 2, texSize.x );
	//const float2 dstSizeRcp = 1.0f / dstSize;
	float2 hp = float2( 0.5f, 0.5f );

	const float2 texelCoord = ( float2 )dtid.xy + hp;
	//float2 baseUVs = texelCoord * dstSizeRcp;

	//float2 uv = baseUVs;
	//if ( baseUVs.x < 0.5f )
	//{
	//	uv.x *= 2;
	//}
	//else
	//{
	//	uv.x = uv.x * 2 - 1;
	//}

	//float mipBorderWidth = borderWidth.x;
	//uv = uv * 2 - 1;
	//float scale = dstSize.y / ( dstSize.y - mipBorderWidth * 2 );
	//uv *= scale;
	//uv = uv * 0.5 + 0.5;

	//float3 sampleDir;

	//if ( baseUVs.x < 0.5f )
	//{
	//	//uv.x *= 0.5f;

	//	//float s = uv.x * 2.0f;
	//	//float t = uv.y;

	//	float2 stn = float2( uv ) * 2 - 1;
	//	sampleDir = normalize( float3( stn, -( 0.5f - 0.5f * ( stn.x * stn.x + stn.y * stn.y ) ) ) );
	//}
	//else
	//{
	//	//uv.x = uv.x * 0.5f + 0.5f;
	//	//sampleDir = DualParaboloidalUVToDir( uv, 1.0f );

	//	float2 stn = float2( uv ) * 2 - 1;
	//	sampleDir = normalize( float3( stn,  ( 0.5f - 0.5f * ( stn.x * stn.x + stn.y * stn.y ) ) ) );
	//}

	////float3 sampleDir = DualParaboloidalUVToDir( uv, 1.0f );

	//outTex[dtid.xy] = inCubeMap.SampleLevel( linearMipLinearClampSampler, sampleDir, sampleMipLevel.x ) * 0.5f;
	////outTex[dtid.xy] = float4( sampleDir.xyz, 1.0f );
	////outTex[dtid.xy] = float4( uv.xy, 0, 1 );
	
	//float bias = 0.25f;

	//float4 sum = SampleDualParaboloid( texelCoord + float2( -bias, -bias ) );
	//sum +=		 SampleDualParaboloid( texelCoord + float2( -bias,  bias ) );
	//sum +=		 SampleDualParaboloid( texelCoord + float2(  bias,  bias ) );
	//sum +=		 SampleDualParaboloid( texelCoord + float2(  bias, -bias ) );

	//outTex[dtid.xy] = sum * 0.25f;
	outTex[dtid.xy] = SampleDualParaboloid( texelCoord );
}




[numthreads( 8, 8, 1 )]
void cs_dual_paraboloid_importance_sample( uint3 dtid : SV_DispatchThreadID )
{
	const float2 dstSize = float2( texSize.x * 2, texSize.x );
	const float2 dstSizeRcp = 1.0f / dstSize;
	float2 texelOffset = float2( 0.5f, 0.5f );

	const float2 texelCoord = ( float2 )dtid.xy + texelOffset;
	float2 baseUVs = texelCoord * dstSizeRcp;

	float2 uv = baseUVs;
	if ( baseUVs.x < 0.5f )
	{
		uv.x *= 2;
	}
	else
	{
		uv.x = uv.x * 2 - 1;
	}

	float mipBorderWidth = borderWidth.x;
	uv = uv * 2 - 1;
	float scale = dstSize.y / ( dstSize.y - mipBorderWidth * 2 );
	uv *= scale;
	uv = uv * 0.5 + 0.5;

	float3 sampleDir;

	if ( baseUVs.x < 0.5f )
	{
		//uv.x *= 0.5f;

		//float s = uv.x * 2.0f;
		//float t = uv.y;

		float2 stn = float2( uv ) * 2 - 1;
		sampleDir = normalize( float3( stn, -( 0.5f - 0.5f * ( stn.x * stn.x + stn.y * stn.y ) ) ) );
	}
	else
	{
		//uv.x = uv.x * 0.5f + 0.5f;
		//sampleDir = DualParaboloidalUVToDir( uv, 1.0f );

		float2 stn = float2( uv ) * 2 - 1;
		sampleDir = normalize( float3( stn, ( 0.5f - 0.5f * ( stn.x * stn.x + stn.y * stn.y ) ) ) );
	}

	//float3 sampleDir = DualParaboloidalUVToDir( uv, 1.0f );

	const uint cbSampleCount = 1024;
	const float alpha2 = SpecParamFromGloss( cbSpecularGloss.x * 1.0f );
	const uint srcSize = 128;
	const float3 result = EvaluateReflectionMipPixel_ImportanceSampling( sampleDir, srcSize, alpha2, cbSampleCount );

	outTex[dtid.xy] = float4( result.rgb * 0.22f, 1.0f );
}


float2 AdjustSampleUVsForBorder( float2 octahedronMapUVs, float borderWidth, float texSize )
{
	float offset = borderWidth / texSize;
	float scale = 1.0f - 2 * offset;
	return octahedronMapUVs * scale + offset;
}

// See http://developer.download.nvidia.com/books/HTML/gpugems/gpugems_ch24.html
float4 GenerateCubicBSplineWeightsOptimized( float x )
{
	float x2 = x * x;
	float x3 = x2 * x;
	return float4( ( 1.0f / 6.0f ) * ( -x3 + 3 * x2 - 3.f * x + 1.f ),
		( 1.0f / 6.0f ) * ( 3.f * x3 - 6.f * x2 + 4.f ),
		( 1.0f / 6.0f ) * ( -3.f * x3 + 3.f * x2 + 3.f * x + 1.f ),
		( 1.0f / 6.0f ) * ( x3 ) );
}

float4 FilterOctahedronBicubic( float2 texCoord, const float lod, float2 texSize, float2 texSizeRcp, SamplerState ss )
{
	float2 xy = frac( texCoord.xy * texSize.xy - 0.5f );

	float4 wx = GenerateCubicBSplineWeightsOptimized( xy.x );
	float4 wy = GenerateCubicBSplineWeightsOptimized( xy.y );

	// "x" components bend uv for samples 0 and 1,
	// "y" components bend uv for samples 2 and 3,
	// "z" components interpolate between "x" and "y".
	float3 hg_x = float3( 1.0f + xy.x - ( wx.y / ( wx.x + wx.y ) ),
		1.0f - xy.x + ( wx.w / ( wx.z + wx.w ) ),
		wx.z + wx.w ); // == 1.0 - (wx.x + wx.y)
	float3 hg_y = float3( 1.0f + xy.y - ( wy.y / ( wy.x + wy.y ) ),
		1.0f - xy.y + ( wy.w / ( wy.z + wy.w ) ),
		wy.x + wy.y ); // == 1.0 - (wx.z + wx.w)

	float2 uv00 = texCoord.xy - float2( hg_x.x * texSizeRcp.x, 0.0f );
	float2 uv10 = texCoord.xy + float2( hg_x.y * texSizeRcp.x, 0.0f );
	float2 uv01 = uv00 - float2( 0.0f, hg_y.x * texSizeRcp.y );
	float2 uv11 = uv10 - float2( 0.0f, hg_y.x * texSizeRcp.y );
	uv00 = uv00 + float2( 0.0f, hg_y.y* texSizeRcp.y );
	uv10 = uv10 + float2( 0.0f, hg_y.y* texSizeRcp.y );

	//float4 tap00 = inTex.SampleLevel(linearMipLinearClampSampler, uv00.xy, lod );
	//float4 tap10 = inTex.SampleLevel(linearMipLinearClampSampler, uv10.xy, lod );
	//float4 tap01 = inTex.SampleLevel(linearMipLinearClampSampler, uv01.xy, lod );
	//float4 tap11 = inTex.SampleLevel(linearMipLinearClampSampler, uv11.xy, lod );
	float4 tap00 = inTex.SampleLevel( ss, uv00.xy, lod );
	float4 tap10 = inTex.SampleLevel( ss, uv10.xy, lod );
	float4 tap01 = inTex.SampleLevel( ss, uv01.xy, lod );
	float4 tap11 = inTex.SampleLevel( ss, uv11.xy, lod );

	// Weight along y direction.
	tap00 = lerp( tap00, tap01, hg_y.z );
	tap10 = lerp( tap10, tap11, hg_y.z );
	// Weight along x direction.
	return lerp( tap00, tap10, hg_x.z );
}


struct vs_output
{
	float4 hpos			: SV_POSITION;
	float2 uv			: TEXCOORD0;
};

vs_output draw_texture_fullscreen_vp( uint vertexId : SV_VertexID )
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
		OUT.uv = float2( 2, 1 );
	}
	else // if ( vertexId == 2 )
	{
		OUT.hpos = float4( -1, 3, 0, 1 );
		OUT.uv = float2( 0, -1 );
	}

	return OUT;
}


vs_output draw_texture_preview_vp( uint vertexId : SV_VertexID )
{
	vs_output OUT = (vs_output)0;

	float xl = 0.5f;
	float xr = 1.0f;
	float yb = 0.5f;
	float yt = 1.0f;

	if ( vertexId == 0 )
	{
		OUT.hpos = float4( xl, yb, 0, 1 );
		OUT.uv = float2( 0, 1 );
	}
	else if ( vertexId == 1 )
	{
		OUT.hpos = float4( xr, yb, 0, 1 );
		OUT.uv = float2( 1, 1 );
	}
	else if ( vertexId == 2 )
	{
		OUT.hpos = float4( xl, yt, 0, 1 );
		OUT.uv = float2( 0, 0 );
	}
	else // if ( vertexId == 3 )
	{
	OUT.hpos = float4( xr, yt, 0, 1 );
	OUT.uv = float2( 1, 0 );
	}

	return OUT;
}


vs_output draw_texture_preview_dual_paraboloid_vp( uint vertexId : SV_VertexID )
{
	vs_output OUT = (vs_output)0;

	float xl = 0.5f;
	float xr = 1.0f;
	float yb = 0.75f;
	float yt = 1.0f;

	if ( vertexId == 0 )
	{
		OUT.hpos = float4( xl, yb, 0, 1 );
		OUT.uv = float2( 0, 1 );
	}
	else if ( vertexId == 1 )
	{
		OUT.hpos = float4( xr, yb, 0, 1 );
		OUT.uv = float2( 1, 1 );
	}
	else if ( vertexId == 2 )
	{
		OUT.hpos = float4( xl, yt, 0, 1 );
		OUT.uv = float2( 0, 0 );
	}
	else // if ( vertexId == 3 )
	{
		OUT.hpos = float4( xr, yt, 0, 1 );
		OUT.uv = float2( 1, 0 );
	}

	return OUT;
}


vs_output draw_dual_paraboloidal_map_vs( uint vertexId : SV_VertexID )
{
	vs_output OUT = (vs_output)0;

	float xl = -1.0f;
	float xr =  1.0f;
	float yb = -0.5f;
	float yt =  0.5f;

	if ( vertexId == 0 )
	{
		OUT.hpos = float4( xl, yb, 0, 1 );
		OUT.uv = float2( 0, 1 );
	}
	else if ( vertexId == 1 )
	{
		OUT.hpos = float4( xr, yb, 0, 1 );
		OUT.uv = float2( 1, 1 );
	}
	else if ( vertexId == 2 )
	{
		OUT.hpos = float4( xl, yt, 0, 1 );
		OUT.uv = float2( 0, 0 );
	}
	else // if ( vertexId == 3 )
	{
		OUT.hpos = float4( xr, yt, 0, 1 );
		OUT.uv = float2( 1, 0 );
	}

	return OUT;
}


float4 draw_texture_fullscreen_fp( in vs_output IN ) : SV_Target
{
	return inTex.SampleLevel( pointMipClampSampler, IN.uv, sampleMipLevel.x );
}

float3 CreateEyeRay( float2 clipSpaceCoords )
{
	float3 eyeRay = eyeAxisX.xyz * clipSpaceCoords.xxx +
		eyeAxisY.xyz * clipSpaceCoords.yyy -
		eyeAxisZ.xyz;

	return normalize( eyeRay );
}


bool IntersectRaySphere( float3 origin, float3 direction, float3 sphereCenter, float radius, out float t, out float3 outHitPoint )
{
	t = 0;
	outHitPoint = float3( 0, 0, 0 );

	float3 m;

	m = origin - sphereCenter;

	float b = dot( m, direction );
	float c = dot( m, m ) - radius * radius;

	if ( c > 0.0f && b > 0.0f )
	{
		return false;
	}

	float discr = b * b - c;

	if ( discr < 0.0f )
	{
		return false;
	}

	t = -b - sqrt( discr );

	// Ray inside sphere
	if ( t < 0.0f )
	{
		t = 0.0f;
	}

	outHitPoint = origin + t * direction;

	return true;
}


struct Lighting
{
	float3 Diffuse;
	float3 Specular;
};

struct PointLight
{
	float3 position;
	float3 diffuseColor;
	float  diffusePower;
	float3 specularColor;
	float  specularPower;
};

Lighting GetPointLight( PointLight light, float3 pos3D, float3 viewDir, float3 normal )
{
	Lighting OUT;
	if ( light.diffusePower > 0 )
	{
		float3 lightDir = light.position - pos3D; //3D position in space of the surface
		float distance = 1;// length( lightDir );
		lightDir = lightDir / distance; // = normalize( lightDir );
		distance = distance * distance; //This line may be optimised using Inverse square root

		//Intensity of the diffuse light. Saturate to keep within the 0-1 range.
		float NdotL = dot( normal, lightDir );
		float intensity = saturate( NdotL );

		// Calculate the diffuse light factoring in light color, power and the attenuation
		OUT.Diffuse = intensity * light.diffuseColor * light.diffusePower / distance;

		//Calculate the half vector between the light vector and the view vector.
		//This is typically slower than calculating the actual reflection vector
		// due to the normalize function's reciprocal square root
		float3 H = normalize( lightDir + viewDir );

		//Intensity of the specular light
		float NdotH = dot( normal, H );
		float specularHardness = 100.0f;
		intensity = pow( saturate( NdotH ), specularHardness );

		//Sum up the specular light factoring
		OUT.Specular = intensity * light.specularColor * light.specularPower / distance;
	}
	return OUT;
}


bool SphereIntersection( float2 uv01, out float3 outNormal )
{
	float2 clipSpaceCoords = uv01 * 2 - 1;
	clipSpaceCoords.y *= -1;

	float3 sphereCenterWorld = float3( 0, 0, 0 );
	float3 eyeRayWorld = CreateEyeRay( clipSpaceCoords );
	float3 eyeOriginWorld = eyeOrigin.xyz;

	float t;
	float3 hitPoint;
	if ( IntersectRaySphere( eyeOriginWorld.xyz, eyeRayWorld, sphereCenterWorld, 1.0f, t, hitPoint ) )
	{
		float3 sphereNormal = normalize( hitPoint - sphereCenterWorld );
		//sphereNormal = mul( ( float3x3 )normalRotation, sphereNormal );
		outNormal = sphereNormal;

		return true;
	}

	return false;
}


float4 draw_sphere_color_cube_fp( in vs_output IN ) : SV_Target
{
	float4 outColor = float4( 0.2f, 0.2f, 0.2f, 1 );

	float3 normal;
	if ( SphereIntersection( IN.uv, normal ) )
	{
		if ( (int)manualMipLerp.y == 0 )
		{
			// linear
			outColor = inCubeMap.SampleLevel( linearMipLinearClampSampler, normal, sampleMipLevel.x ) * 0.5f;
		}
		else
		{
			// point
			outColor = inCubeMap.SampleLevel( pointMipClampSampler, normal, sampleMipLevel.x ) * 0.5f;
		}
	}

	return outColor;
}


float4 draw_sphere_normal_fp( in vs_output IN ) : SV_Target
{
	float4 outColor = float4( 0.2f, 0.2f, 0.2f, 1 );

	float3 normal;
	if ( SphereIntersection( IN.uv, normal ) )
	{
		outColor = float4( normal * 0.5 + 0.5, 1 );
		//outColor = float4( normal, 1 );
	}

	return outColor;
}


float4 draw_sphere_octahedron_fp( in vs_output IN ) : SV_Target
{
	float4 outColor = float4( 0.2f, 0.2f, 0.2f, 1 );

	float3 normal;
	if ( SphereIntersection( IN.uv, normal ) )
	{
		float2 octahedronUv;
		EncodeOctaNormal( normal, octahedronUv );
		octahedronUv = octahedronUv * 0.5f + 0.5f;

		if ( manualMipLerp.x > 0 )
		{
			float mipA = floor( sampleMipLevel.x );
			float mipB = mipA + 1; //ceil( sampleMipLevel.x );

			//uint texSizeA = (uint)(texSize.x) >> ( uint )mipA;
			//uint texSizeB = texSizeA / 2;

			//uint bw = ( uint )borderWidth.x;
			//const int borderWidthMipBias = 3;
			//const int mipABiasedA = max( ( int )mipA - borderWidthMipBias, 0 );
			//const int mipABiasedB = max( ( int )mipB - borderWidthMipBias, 0 );
			//int bwA = bw >> mipABiasedA;
			//int bwB = bw >> mipABiasedB;

			//float2 octahedronUvA = AdjustSampleUVsForBorder( octahedronUv, (float)bwA, (float)texSizeA );
			//float2 octahedronUvB = AdjustSampleUVsForBorder( octahedronUv, (float)bwB, (float)texSizeB );

			uint texSizeA = texSize.x;
			uint texSizeB = texSize.x;

			int bw = ( int )borderWidth.x;
			const int borderWidthMipBias = 3;
			//const int mipAOffset = mipA >= 2 ? 1 : 0; // the same must be done when encoding octahedron
			//const int mipBOffset = mipB >= 2 ? 1 : 0;
			int mipAClamped = min( (int)mipA /*+ mipAOffset*/, borderWidthMipBias );
			int mipBClamped = min( (int)mipB /*+ mipBOffset*/, borderWidthMipBias );
			int bwA = bw << (int)mipAClamped;
			int bwB = bw << (int)mipBClamped;

			float2 octahedronUvA = AdjustSampleUVsForBorder( octahedronUv, (float)bwA, (float)texSizeA );
			float2 octahedronUvB = AdjustSampleUVsForBorder( octahedronUv, (float)bwB, (float)texSizeB );

			float4 colorA, colorB;
			if ( (int)manualMipLerp.y == 0 )
			{
				// linear
				colorA = inTex.SampleLevel( linearMipClampSampler, octahedronUvA, mipA );
				colorB = inTex.SampleLevel( linearMipClampSampler, octahedronUvB, mipB );
			}
			else if ( (int)manualMipLerp.y == 1 )
			{
				// point
				colorA = inTex.SampleLevel( pointMipClampSampler, octahedronUvA, mipA );
				colorB = inTex.SampleLevel( pointMipClampSampler, octahedronUvB, mipB );
			}
			else
			{
				// bicubic
				colorA = FilterOctahedronBicubic( octahedronUvA, mipA, texSize.xx, rcp( texSize.xx ), linearMipClampSampler );
				colorB = FilterOctahedronBicubic( octahedronUvB, mipB, texSize.xx * 0.5f, rcp( texSize.xx * 0.5f ), linearMipClampSampler );
			}

			float lerpFactor = frac( sampleMipLevel.x );
			outColor = lerp( colorA, colorB, lerpFactor );
		}
		else
		{
			octahedronUv = AdjustSampleUVsForBorder( octahedronUv, borderWidth.x, texSize.x );
			if ( (int)manualMipLerp.y == 0 )
			{
				// linear
				outColor = inTex.SampleLevel( linearMipLinearClampSampler, octahedronUv, sampleMipLevel.x );
			}
			else if ( (int)manualMipLerp.y == 1 )
			{
				// point
				outColor = inTex.SampleLevel( pointMipClampSampler, octahedronUv, sampleMipLevel.x );
			}
			else
			{
				// bicubic
				outColor = FilterOctahedronBicubic( octahedronUv, sampleMipLevel.x, texSize.xx, rcp( texSize.xx ), linearMipLinearClampSampler );
			}
		}

		//outColor = FilterOctahedronBicubic( octahedronUv, sampleMipLevel.x, 0, texSize.xx, rcp( texSize.xx ) );

		//outColor = float4( octahedronUv, 0, 1 );

		//PointLight pl;
		////pl.position = eyeOrigin.xyz;
		//pl.position = float3( 5, 5, -5 );
		//pl.diffuseColor = 1;
		//pl.diffusePower = 0.1f;
		//pl.specularColor = 1;
		//pl.specularPower = 1;

		//Lighting light = GetPointLight( pl, eyeOrigin.xyz, eyeAxisZ.xyz, normal );
		//outColor = float4( light.Diffuse + light.Specular, 1.0f );
	}

	return outColor;
}


float NoiseSpatialInterleavedGradient( float2 position, float minValue, float maxValue )
{
	float3 magic = float3( 0.06711056, 0.00583715, 52.9829189 );
	return lerp( minValue, maxValue, frac( magic.z * frac( dot( position, magic.xy ) ) ) );
}


float4 draw_sphere_dual_paraboloid_fp( in vs_output IN, float4 hpos : SV_Position ) : SV_Target
{
	float4 outColor = float4( 0.2f, 0.2f, 0.2f, 1 );

	float3 normal;
	if ( SphereIntersection( IN.uv, normal ) )
	{
		//float2 octahedronUv;
		//EncodeOctaNormal( normal, octahedronUv );
		//octahedronUv = octahedronUv * 0.5f + 0.5f;

		float2 dualParaboloidUv = DirectionDualParaboloidalUV( normal, 1.0f );

		if ( manualMipLerp.x > 0 )
		{
			float mipA = floor( sampleMipLevel.x );
			float mipB = mipA + 1; //ceil( sampleMipLevel.x );

			//uint texSizeA = (uint)(texSize.x) >> ( uint )mipA;
			//uint texSizeB = texSizeA / 2;

			//uint bw = ( uint )borderWidth.x;
			//const int borderWidthMipBias = 3;
			//const int mipABiasedA = max( ( int )mipA - borderWidthMipBias, 0 );
			//const int mipABiasedB = max( ( int )mipB - borderWidthMipBias, 0 );
			//int bwA = bw >> mipABiasedA;
			//int bwB = bw >> mipABiasedB;

			//float2 octahedronUvA = AdjustSampleUVsForBorder( octahedronUv, (float)bwA, (float)texSizeA );
			//float2 octahedronUvB = AdjustSampleUVsForBorder( octahedronUv, (float)bwB, (float)texSizeB );

			uint texSizeA = texSize.x;
			uint texSizeB = texSize.x;

			int bw = (int)borderWidth.x;
			const int borderWidthMipBias = 3;
			//const int mipAOffset = mipA >= 2 ? 1 : 0; // the same must be done when encoding octahedron
			//const int mipBOffset = mipB >= 2 ? 1 : 0;
			int mipAClamped = min( (int)mipA /*+ mipAOffset*/, borderWidthMipBias );
			int mipBClamped = min( (int)mipB /*+ mipBOffset*/, borderWidthMipBias );
			int bwA = bw << (int)mipAClamped;
			int bwB = bw << (int)mipBClamped;

			float2 dualParaboloidUvA = AdjustSampleUVsForBorder( dualParaboloidUv, (float)bwA, (float)texSizeA );
			float2 dualParaboloidUvB = AdjustSampleUVsForBorder( dualParaboloidUv, (float)bwB, (float)texSizeB );

			float b = 1;
			if ( normal.z < 0 )
			{
				float s = 1.0f / ( 2.0f * b ) * ( normal.x / ( 1 - normal.z ) ) + 0.5f;
				float t = 1.0f / ( 2.0f * b ) * ( normal.y / ( 1 - normal.z ) ) + 0.5f;
				//return float2( s * 0.5f, t );
				dualParaboloidUvA = AdjustSampleUVsForBorder( float2( s, t ), (float)bwA, (float)texSizeA );
				dualParaboloidUvB = AdjustSampleUVsForBorder( float2( s, t ), (float)bwB, (float)texSizeB );
				dualParaboloidUvA.x *= 0.5f;
				dualParaboloidUvB.x *= 0.5f;
			}
			else
			{
				float s = 1.0f / ( 2.0f * b ) * ( normal.x / ( 1 + normal.z ) ) + 0.5f;
				float t = 1.0f / ( 2.0f * b ) * ( normal.y / ( 1 + normal.z ) ) + 0.5f;
				dualParaboloidUvA = AdjustSampleUVsForBorder( float2( s, t ), (float)bwA, (float)texSizeA );
				dualParaboloidUvB = AdjustSampleUVsForBorder( float2( s, t ), (float)bwB, (float)texSizeB );
				dualParaboloidUvA.x = dualParaboloidUvA.x * 0.5f + 0.5f;
				dualParaboloidUvB.x = dualParaboloidUvB.x * 0.5f + 0.5f;
			}

			//float dithA = NoiseSpatialInterleavedGradient( hpos.xy, 0.0f, 0.25f * 2.0f / texSizeA );
			//float dithB = NoiseSpatialInterleavedGradient( -hpos.xy, 0.0f, 0.25f * 4.0f / texSizeB );
			//dualParaboloidUvA.xy += dithA;
			//dualParaboloidUvB.xy -= dithB;

			float4 colorA, colorB;
			if ( (int)manualMipLerp.y == 0 )
			{
				// linear
				colorA = inTex.SampleLevel( linearMipClampSampler, dualParaboloidUvA, mipA );
				colorB = inTex.SampleLevel( linearMipClampSampler, dualParaboloidUvB, mipB );
			}
			else if ( (int)manualMipLerp.y == 1 )
			{
				// point
				colorA = inTex.SampleLevel( pointMipClampSampler, dualParaboloidUvA, mipA );
				colorB = inTex.SampleLevel( pointMipClampSampler, dualParaboloidUvB, mipB );
			}
			else
			{
				// bicubic
				colorA = FilterOctahedronBicubic( dualParaboloidUvA, mipA, float2( texSize.x * 2, texSize.x ), rcp( float2( texSize.x * 2, texSize.x ) ), linearMipClampSampler );
				colorB = FilterOctahedronBicubic( dualParaboloidUvB, mipB, float2( texSize.x * 1, texSize.x * 0.5f ), rcp( float2( texSize.x * 1, texSize.x * 0.5f ) ), linearMipClampSampler );
			}

			float lerpFactor = frac( sampleMipLevel.x );
			outColor = lerp( colorA, colorB, lerpFactor );
			//outColor = float4( dualParaboloidUvA.xy, 0, 1 );
		}
		else
		{
			//octahedronUv = AdjustSampleUVsForBorder( octahedronUv, borderWidth.x, texSize.x );
			
			float b = 1;
			if ( normal.z < 0 )
			{
				float s = 1.0f / ( 2.0f * b ) * ( normal.x / ( 1 - normal.z ) ) + 0.5f;
				float t = 1.0f / ( 2.0f * b ) * ( normal.y / ( 1 - normal.z ) ) + 0.5f;
				//return float2( s * 0.5f, t );
				dualParaboloidUv = AdjustSampleUVsForBorder( float2( s, t ), borderWidth.x, texSize.x );
				dualParaboloidUv.x *= 0.5f;
			}
			else
			{
				float s = 1.0f / ( 2.0f * b ) * ( normal.x / ( 1 + normal.z ) ) + 0.5f;
				float t = 1.0f / ( 2.0f * b ) * ( normal.y / ( 1 + normal.z ) ) + 0.5f;
				//return float2( s * 0.5f + 0.5f, t );
				dualParaboloidUv = AdjustSampleUVsForBorder( float2( s, t ), borderWidth.x, texSize.x );
				dualParaboloidUv.x = dualParaboloidUv.x * 0.5f + 0.5f;
			}

			if ( (int)manualMipLerp.y == 0 )
			{
				// linear
				outColor = inTex.SampleLevel( linearMipLinearClampSampler, dualParaboloidUv, sampleMipLevel.x );
			}
			else if ( (int)manualMipLerp.y == 1 )
			{
				// point
				outColor = inTex.SampleLevel( pointMipClampSampler, dualParaboloidUv, sampleMipLevel.x );
			}
			else
			{
				// bicubic
				outColor = FilterOctahedronBicubic( dualParaboloidUv, sampleMipLevel.x, float2( texSize.x * 2, texSize.x ), rcp( float2( texSize.x * 2, texSize.x ) ), linearMipLinearClampSampler );
			}
		}

		//outColor = FilterOctahedronBicubic( octahedronUv, sampleMipLevel.x, 0, texSize.xx, rcp( texSize.xx ) );

		//outColor = float4( octahedronUv, 0, 1 );

		//PointLight pl;
		////pl.position = eyeOrigin.xyz;
		//pl.position = float3( 5, 5, -5 );
		//pl.diffuseColor = 1;
		//pl.diffusePower = 0.1f;
		//pl.specularColor = 1;
		//pl.specularPower = 1;

		//Lighting light = GetPointLight( pl, eyeOrigin.xyz, eyeAxisZ.xyz, normal );
		//outColor = float4( light.Diffuse + light.Specular, 1.0f );
	}

	return outColor;
}
