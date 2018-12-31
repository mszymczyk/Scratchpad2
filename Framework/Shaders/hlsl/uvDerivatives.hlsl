#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	Derivatives = {
		VertexProgram = "Vp";
		FragmentProgram = "Fp";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "PassConstants.h"
#include "UvDerivativesConstants.h"

Texture2D diffuseTex : register( t0 );
SamplerState sampAniso : register( s0 );
SamplerState sampAniso4x : register( s1 );
SamplerState sampLinear : register( s2 );
SamplerState sampLinearNoMips : register( s3 );
SamplerState sampPoint : register( s4 );

#define ddxImpl(x) ddx(x)
#define ddyImpl(x) ddy(x)
//#define ddxImpl(x) ddx_fine(x)
//#define ddyImpl(x) ddy_fine(x)
//#define ddxImpl(x) ddx_coarse(x)
//#define ddyImpl(x) ddy_coarse(x)

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

float2 projPoint( float3 position )
{
	float4 positionWorld = mul( World, float4( position, 1 ) );
	float4 hpos = mul( ViewProjection, positionWorld );
	float2 posM11 = hpos.xy / hpos.w;
	return posM11 * 0.5 + 0.5f;
}

//float4 Fp( in vs_output IN ) : SV_Target
//{
//	//return float4( 1, 0, 0, 1 );
//	//return float4( diffuseTex.Sample( diffuseTexSamp, IN.texCoord0 ).xyz, 1 );
//	float2 uv = IN.texCoord0.xy;
//	float dudx = ddx( uv.x );
//	float dudy = ddy( uv.x );
//	float dvdx = ddx( uv.y );
//	float dvdy = ddy( uv.y );
//
//	const float hsX = 100;
//	const float hsY = 1;
//	const float3 p0i = float3( -hsX, -hsY, 0 );
//	const float3 p1i = float3(  hsX, -hsY, 0 );
//	const float3 p2i = float3(  hsX,  hsY, 0 );
//	const float2 rtSize = float2( 1280, 720 );
//	const float2 rtHSize = rtSize * 0.5f;
//
//	//const float3 ep1p0 = normalize( p1i - p0i );
//	//const float3 ep2p0 = normalize( p2i - p1i );
//	const float3 ep1p0 = float3( 1, 0, 0 );
//	const float3 ep2p0 = float3( 0, 1, 0 );
//
//	const float deltaWorld = 0.0001f;
//	const float deltaU = deltaWorld / ( hsX * 2 );
//	const float deltaV = deltaWorld / ( hsY * 2 );
//	const float3 p0 = IN.posWS;
//	const float3 p1 = p0 + ep1p0 * deltaWorld;
//	const float3 p2 = p0 + ep2p0 * deltaWorld;
//
//	float2 proj0 = projPoint( p0 );
//	float2 proj1 = projPoint( p1 );
//	float2 proj2 = projPoint( p2 );
//
//	float2 e0 = abs(proj1 - proj0);
//	float2 e0pix = max( e0 * rtSize, float2( 0.00001, 0.00001 ) );
//	float2 e1 = abs( proj2 - proj0 );
//	float2 e1pix = max( e1 * rtSize, float2( 0.00001, 0.00001 ) );
//
//	//float dudxManual = delta / e0pix.x;
//	//float dudyManual = delta / e0pix.y;
//	float dudxManual = deltaU / e0pix.x;
//	float dudyManual = deltaU / e0pix.y;
//
//	float dvdxManual = deltaV / e1pix.x;
//	float dvdyManual = deltaV / e1pix.y;
//	
//	//float2 uv = float2( dudx, dudy );
//	//return float4( uv * 100, 0, 1 );
//	float diffux = abs( dudx - dudxManual );
//	float diffuy = abs( dudy - dudyManual );
//	float diffvx = abs( dvdx - dvdxManual );
//	float diffvy = abs( dvdy - dvdyManual );
//
//	//return float4( diffux.xxx * 1000, 1 );
//	//return float4( diffuy.xxx * 1000, 1 );
//	//return float4( diffvx.xxx * 1000, 1 );
//	//return float4( diffvy.xxx * 1000, 1 );
//
//	//return float4( abs( dudxManual.xxx ) * 10, 1 );
//	//return float4( abs( dudyManual.xxx ) * 10, 1 );
//	//return float4( abs( dvdxManual.xxx ) * 10, 1 );
//	//return float4( abs( dvdyManual.xxx ) * 10, 1 );
//
//
//	//return float4( IN.texCoord0.xy, 0, 1 );
//
//	//return float4( dudx.xxx * 10, 1 );
//	//return float4( abs(dudy.xxx) * 1000, 1 );
//	//return float4( abs( dvdx.xxx ) * 10, 1 );
//	//return float4( abs(dvdy.xxx) * 10, 1 );
//
//	//return float4( abs( dudyManual.xxx ) * 1000, 1 );
//
//	//float len = length( proj1 - proj0 );
//	//return float4( len.xxx * 10, 1 );
//	return float4( abs(ddx( IN.hpos.z ).xxx) * 100, 1 );
//}

//float4 Fp( in vs_output IN ) : SV_Target
//{
//	float3 worldPos = IN.posWS;
//	float3 wpdx = ddx_fine( worldPos );
//	float3 wpdy = ddy_fine( worldPos );
//
//	const float hsX = 100;
//	const float hsY = 1;
//	const float2 rtSize = float2( 1280, 720 );
//	const float2 rtHSize = rtSize * 0.5f;
//	const float aspect = rtSize.x / rtSize.y;
//
//	//const float3 p0 = IN.posWS;
//	//const float3 p1 = p0 + wpdx;
//	//const float3 p2 = p0 + wpdy;
//	//
//	//float2 proj0 = projPoint( p0 );
//	//float2 proj1 = projPoint( p1 );
//	//float2 proj2 = projPoint( p2 );
//
//	//const float deltaU = wpdx.x / ( hsX * 2 );
//	//const float deltaV = wpdy.y / ( hsY * 2 );
//
//	//float2 e0 = abs(proj1 - proj0);
//	//float2 e0pix = max( e0 * rtSize, float2( 0.00001, 0.00001 ) );
//	//float2 e1 = abs( proj2 - proj0 );
//	//float2 e1pix = max( e1 * rtSize, float2( 0.00001, 0.00001 ) );
//	
//	float dudxManual = wpdx.x / ( hsX * 2 );
//	float dudyManual = wpdy.x / ( hsX * 2 );
//
//	float dvdxManual = -wpdx.y / ( hsY * 2 );
//	float dvdyManual = -wpdy.y / ( hsY * 2 );
//	//dvdyManual /= aspect;
//
//	float2 uv = IN.texCoord0.xy;
//	float dudx = ddx_fine( uv.x );
//	float dudy = ddy_fine( uv.x );
//	float dvdx = ddx_fine( uv.y );
//	float dvdy = ddy_fine( uv.y );
//
//	float diffux = abs( dudx - dudxManual );
//	float diffuy = abs( dudy - dudyManual );
//	float diffvx = abs( dvdx - dvdxManual );
//	float diffvy = abs( dvdy - dvdyManual );
//	
//	//return float4( diffux.xxx * 1000, 1 );
//	//return float4( diffuy.xxx * 1000, 1 );
//	//return float4( diffvx.xxx * 1000, 1 );
//	//return float4( diffvy.xxx * 1000, 1 );
//	
//	//return float4( abs( dudxManual.xxx ) * 10, 1 );
//	//return float4( abs( dudyManual.xxx ) * 10, 1 );
//	//return float4( abs( dvdxManual.xxx ) * 10, 1 );
//	//return float4( abs( dvdyManual.xxx ) * 10, 1 );
//	
//	
//	//return float4( abs(dudx.xxx) * 10, 1 );
//	//return float4( abs(dudy.xxx) * 10, 1 );
//	//return float4( abs(dvdx.xxx) * 10, 1 );
//	//return float4( abs(dvdy.xxx) * 10, 1 );
//
//	return float4( wpdx.xyz * 10, 1 );
//}

float3 TransformToDecal( float3 worldPos )
{
	return mul( WorldToDecal, float4( worldPos, 1 ) ).xyz;
}

bool InsideDecal( float3 decalPos )
{
	if (	decalPos.x >= -1 && decalPos.x <= 1
		&&	decalPos.y >= -1 && decalPos.y <= 1
		&&	decalPos.z >= -1 && decalPos.z <= 1
		)
	{
		return true;
	}

	return false;
}

void SampleTexture( SamplerState sstate, float2 uv,
	float2 dx, float2 dy,
	float2 dxManual, float2 dyManual,
	out float3 texSample, out float3 texAuto, out float3 texManual
)
{
	texSample = diffuseTex.Sample( sstate, uv ).xyz;

	texAuto = diffuseTex.SampleGrad( sstate, uv,
		dx, dy ).xyz;

	texManual = diffuseTex.SampleGrad( sstate, uv,
		dxManual, dyManual ).xyz;

}

float3 ColorizeTexLevel( float level )
{
	int lev = clamp( (int)level, 0, 9 );
	float3 colors[10] = 
	{
		float3( 1, 1, 1 ),

		float3( 1, 0, 0 ),
		float3( 0, 1, 0 ),
		float3( 0, 0, 1 ),

		float3( 1, 0, 1 ),
		float3( 1, 1, 0 ),
		float3( 0, 1, 1 ),

		float3( 0, 1, 0.5 ),
		float3( 0, 0.5, 1 ),
		float3( 1, 0.5, 0.5 ),
	};

	return colors[lev];
}

float4 Fp( in vs_output IN ) : SV_Target
{
	float2 uv = IN.texCoord0.xy;

	float3 worldPos = IN.posWS;
	float3 wpdx = ddxImpl( worldPos );
	float3 wpdy = ddyImpl( worldPos );

	const float hsX = 100;
	const float hsY = 1;
	const float2 rtSize = float2( 1280, 720 );
	const float2 rtHSize = rtSize * 0.5f;
	const float aspect = rtSize.x / rtSize.y;

	const float3 p0 = IN.posWS;
	const float3 p1 = p0 + wpdx;
	const float3 p2 = p0 + wpdy;

	//float dudx = ddxImpl( uv.x );
	//float dudy = ddyImpl( uv.x );

	//float dvdx = ddxImpl( uv.y );
	//float dvdy = ddyImpl( uv.y );

	//float derivToShow = dudx;

	const float3 ep1p0 = float3( 1, 0, 0 );
	const float3 ep2p0 = float3( 0, 1, 0 );
	
	const float deltaWorld = 256;
	const float deltaU = deltaWorld / ( hsX * 2 );
	const float deltaV = deltaWorld / ( hsY * 2 );
	const float3 p0a = IN.posWS;
	const float3 p1a = p0a + ep1p0 * deltaWorld;
	const float3 p2a = p0a + ep2p0 * deltaWorld;
	
	float2 proj0 = projPoint( p0a );
	float2 proj1 = projPoint( p1a );
	float2 proj2 = projPoint( p2a );
	
	float2 e0 = abs(proj1 - proj0);
	float2 e0pix = max( e0 * rtSize, float2( 0.00001, 0.00001 ) );
	float2 e1 = abs( proj2 - proj0 );
	float2 e1pix = max( e1 * rtSize, float2( 0.00001, 0.00001 ) );
	
	//float dudxManual = delta / e0pix.x;
	//float dudyManual = delta / e0pix.y;
	float dudxManual = deltaU / e0pix.x * IN.hpos.w * 0.05;
	float dudyManual = deltaU / e0pix.y;
	
	float dvdxManual = deltaV / e1pix.x;
	float dvdyManual = deltaV / e1pix.y;


	const float3 dp0 = TransformToDecal( p0 );
	float3 color = float3( 0, 1, 0 );
	[branch]
	if ( InsideDecal( dp0 ) )
	{
		color = float3( 1, 0, 0 );
		uv = dp0.xy * 0.5 + 0.5;

		float3 dp1 = TransformToDecal( p1 );
		float3 dp2 = TransformToDecal( p2 );


		//float dudxManual = ( dp1.x - dp0.x ) * 0.5;
		float dudxAuto = ddxImpl( uv.x );
		float dudxDiff = abs( dudxAuto - dudxManual ) *100;

		float dudyManual = ( dp2.x - dp0.x ) * 0.5;
		float dudyAuto = ddyImpl( uv.x );
		float dudyDiff = abs( dudyAuto - dudyManual ) * 100000;

		float dvdxManual = ( dp1.y - dp0.y ) * 0.5;
		float dvdxAuto = ddxImpl( uv.y );
		float dvdxDiff = abs( dvdxAuto - dvdxManual ) * 100000;

		float dvdyManual = ( dp2.y - dp0.y ) * 0.5;
		float dvdyAuto = ddyImpl( uv.y );
		float dvdyDiff = abs( dvdyAuto - dvdyManual ) * 100000;

		float derivToShow = 0;

		switch ( derivativesMode )
		{
		case 0:
			derivToShow = dudxAuto;
			break;
		case 1:
			derivToShow = dudxManual;
			break;
		case 2:
			derivToShow = dudxDiff;
			break;

		case 3:
			derivToShow = dudyAuto;
			break;
		case 4:
			derivToShow = dudyManual;
			break;
		case 5:
			derivToShow = dudyDiff;
			break;

		case 6:
			derivToShow = dvdxAuto;
			break;
		case 7:
			derivToShow = dvdxManual;
			break;
		case 8:
			derivToShow = dvdxDiff;
			break;

		case 9:
			derivToShow = dvdyAuto;
			break;
		case 10:
			derivToShow = dvdyManual;
			break;
		case 11:
			derivToShow = dvdyDiff;
			break;

		case 12:
			derivToShow = max( max( dudxDiff, dudyDiff ), max(dvdxDiff, dvdyDiff) );
			break;

		};

		float3 texSample, texAuto, texManual;
		float2 dx = float2( dudxAuto, dvdxAuto );
		float2 dy = float2( dudyAuto, dvdyAuto );
		float2 dxManual = float2( dudxManual, dvdxManual );
		float2 dyManual = float2( dudyManual, dvdyManual );
		//dy = dx;

		switch ( samplerMode )
		{
		case 0:
			SampleTexture( sampAniso, uv, dx, dy, dxManual, dyManual, texSample, texAuto, texManual );
			break;
		case 1:
			SampleTexture( sampAniso4x, uv, dx, dy, dxManual, dyManual, texSample, texAuto, texManual );
			break;
		case 2:
			SampleTexture( sampLinear, uv, dx, dy, dxManual, dyManual, texSample, texAuto, texManual );
			break;
		case 3:
			SampleTexture( sampLinearNoMips, uv, dx, dy, dxManual, dyManual, texSample, texAuto, texManual );
			break;
		case 4:
			SampleTexture( sampPoint, uv, dx, dy, dxManual, dyManual, texSample, texAuto, texManual );
			break;
		};

		float3 texToShow = float3( 1, 0, 0 );

		switch ( textureMode )
		{
		case 0:
			texToShow = texSample;
			break;
		case 1:
			texToShow = texAuto;
			break;
		case 2:
			texToShow = texManual;
			break;
		case 3:
			texToShow = abs( texSample - texAuto ) * 10000;
			break;
		case 4:
			texToShow = abs( texAuto - texManual ) * 10000;
			break;
		case 5:
			texToShow = abs( texSample - texManual ) * 10000;
			break;
		};

		switch ( outputMode )
		{
		case 0:
			color = texToShow;
			break;
		case 1:
			color = derivToShow.xxx * 10;
			break;
		};

		//float texLevel = diffuseTex.CalculateLevelOfDetail( sampLinear, uv );
		//color = ColorizeTexLevel( texLevel );
	}

	//dudx = ddx( uv.x );
	//dvdy = ddy( uv.y );

	//return float4( wpdx.xyz * 10, 1 );
	return float4( color, 1 );
	//return float4( uv, 0, 1 );

	//return float4( dudx.xxx * 10, 1 );
	//return float4( dudy.xxx * 10, 1 );
	//return float4( dvdx.xxx * 10, 1 );
	//return float4( dvdy.xxx * 10, 1 );
	//return float4( derivToShow.xxx * 10, 1 );
}