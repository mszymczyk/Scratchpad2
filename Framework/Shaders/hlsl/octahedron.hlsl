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

	cs_octahedron_encode_normal = {
		ComputeProgram = "cs_octahedron_encode_normal";
	}

	cs_octahedron_encode_scene = {
		ComputeProgram = "cs_octahedron_encode_scene";
	}

	draw_texture = {
		VertexProgram = "draw_texture_fullscreen_vp";
		FragmentProgram = "draw_texture_fullscreen_fp";
	}

	draw_texture_preview = {
		VertexProgram = "draw_texture_preview_vp";
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
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "octahedron_cshared.h"

Texture2D   inTex							MAKE_REGISTER_SRV( 0 );
TextureCube inCubeMap						MAKE_REGISTER_SRV( 1 );
RWTexture2D<float4> outTex					MAKE_REGISTER_UAV( 0 );
RWStructuredBuffer<float4> outBuffer		MAKE_REGISTER_UAV( 0 );


SamplerState inTexSamp						REGISTER_SAMPLER_TEX_SAMPLER;
SamplerState inCubeMapSamp					REGISTER_SAMPLER_CUBE_MAP_SAMPLER;

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




void WrapOctahedronReference( inout float2 texel, float texelSize )
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
		texel.y = -texel.y + texelSize;
	}
	else if ( texel.y > 1 )
	{
		texel.x = 1 - texel.x;
		texel.y = 2 - texel.y - texelSize;
	}
	else if ( texel.x <= 0 )
	{
		texel.x = -texel.x + texelSize;
		texel.y = 1 - texel.y;
	}
	else if ( texel.x > 1 )
	{
		texel.x = 2 - texel.x - texelSize;
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
	outBuffer[0] = inTex.SampleLevel( inTexSamp, picPosition.xy, sampleMipLevel.x );
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

	float mipBorderWidth = borderWidth.x;
	uv = uv * 2 - 1;
	float scale = dstSize / ( dstSize - mipBorderWidth * 2 );
	uv *= scale;
	uv = uv * 0.5 + 0.5;

	WrapOctahedron( uv );
	uv = uv * 2 - 1;

	float3 normal;
	DecodeOctaNormal( uv, normal );

	outTex[dtid.xy] = inCubeMap.SampleLevel( inCubeMapSamp, normal, sampleMipLevel.x ) * 0.5f;
}


float2 AdjustSampleUVsForBorder( float2 octahedronMapUVs )
{
	//// octahedronMapUVs must be in <-1,1> range
	//octahedronMapUVs *= ( texSize.x - borderWidth.x * 2 ) * ( 1.0f / (texSize.x - borderWidth.x) );
	//octahedronMapUVs = octahedronMapUVs * 0.5 + 0.5;
	//return octahedronMapUVs;

	float offset = borderWidth.x / texSize.x;
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

float4 FilterOctahedronBicubic( float2 texCoord, const float lod, const float probeImageIndex, float2 texSize, float2 texSizeRcp )
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

	float4 tap00 = inTex.SampleLevel( inTexSamp, uv00.xy, lod );
	float4 tap10 = inTex.SampleLevel( inTexSamp, uv10.xy, lod );
	float4 tap01 = inTex.SampleLevel( inTexSamp, uv01.xy, lod );
	float4 tap11 = inTex.SampleLevel( inTexSamp, uv11.xy, lod );

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


float4 draw_texture_fullscreen_fp( in vs_output IN ) : SV_Target
{
	return inTex.SampleLevel( inTexSamp, IN.uv, sampleMipLevel.x );
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
		outColor = inCubeMap.SampleLevel( inCubeMapSamp, normal, sampleMipLevel.x ) * 0.5f;
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

		octahedronUv = AdjustSampleUVsForBorder( octahedronUv );

		outColor = inTex.SampleLevel( inTexSamp, octahedronUv, sampleMipLevel.x );
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
