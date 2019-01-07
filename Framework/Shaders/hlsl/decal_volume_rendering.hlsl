#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	DecalVolumeCopyIndirectArgs = {
		ComputeProgram = "DecalVolumeCopyIndirectArgs";
	}

	DecalVolumeCopyIndirectArgsIndexed = {
		ComputeProgram = "DecalVolumeCopyIndirectArgsIndexed";
	}

	DecalVolumeHeatmapTile = {
		VertexProgram = "HeatmapVp";
		FragmentProgram = "HeatmapTileFp";
	}

	DecalVolumeFarPlane = {
		VertexProgram = "DecalVolumeFarPlaneVp";
		FragmentProgram = "DecalVolumeFarPlaneFp";
	}

	DecalVolumesAccum = {
		VertexProgram = "DecalVolumesAccumVp";
		FragmentProgram = "DecalVolumesAccumFp";
	}

	DecalVolumeAxes = {
		VertexProgram = "DecalVolumeAxesVp";
		FragmentProgram = "DecalVolumeAxesFp";
	}

	ModelDiffuse = {
		VertexProgram = "ModelVp";
		FragmentProgram = "ModelDiffuseFp";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "PassConstants.h"
#include "decal_volume_rendering_cshared.h"

StructuredBuffer<DecalVolume> inDecalVolumes		REGISTER_T( DECAL_VOLUME_IN_DECALS_BINDING );
StructuredBuffer<uint> inDecalVolumesCount			REGISTER_T( DECAL_VOLUME_IN_DECALS_COUNT_BINDING );
StructuredBuffer<uint> inDecalsPerCell				REGISTER_T( DECAL_VOLUME_IN_DECALS_PER_CELL_BINDING );
RWByteAddressBuffer outIndirectArgs					REGISTER_U( DECAL_VOLUME_OUT_INDIRECT_ARGS_BINDING );

Texture2D diffuseTex								REGISTER_T( DIFFUSE_TEXTURE_REGISTER_BINDING );
SamplerState diffuseTexSamp							REGISTER_S( DIFFUSE_SAMPLER_REGISTER_BINDING );


[numthreads( 1, 1, 1 )]
void DecalVolumeCopyIndirectArgs()
{
	uint n = inDecalVolumesCount[0];
	uint4 arg0;
	arg0.x = 6; // num vertices per instance
	arg0.y = n; // num instances
	arg0.z = 0; // base vertex
	arg0.w = 0; // base instance
	outIndirectArgs.Store4( 0, arg0 );
}


[numthreads( 1, 1, 1 )]
void DecalVolumeCopyIndirectArgsIndexed()
{
	uint n = inDecalVolumesCount[0];
	uint4 arg0;
	arg0.x = 36; // num indices per instance
	arg0.y = n; // num instances
	arg0.z = 0; // base index
	arg0.w = 0; // base vertex
	uint arg1 = 0; // base instance
	outIndirectArgs.Store4( 0, arg0 );
	outIndirectArgs.Store( 16, arg1 );
}


struct vs_output
{
	float4 hpos			: SV_POSITION;
};

vs_output HeatmapVp( uint vertexId : SV_VertexID )
{
	vs_output OUT = (vs_output)0;

	if ( vertexId == 0 )
	{
		OUT.hpos = float4( -1, -1, 0, 1 );
	}
	else if ( vertexId == 1 )
	{
		OUT.hpos = float4( 3, -1, 0, 1 );
	}
	else // if ( vertexId == 2 )
	{
		OUT.hpos = float4( -1, 3, 0, 1 );
	}

	return OUT;
}

float3 GetColorMap( uint count )
{
	float3 black =	float3( 0.0, 0.0, 0.0 );
	float3 blue =	float3( 0.0, 0.0, 1.0 );
	float3 cyan =	float3( 0.0, 1.0, 1.0 );
	float3 green =	float3( 0.0, 1.0, 0.0 );
	float3 yellow = float3( 1.0, 1.0, 0.0 );
	float3 red =	float3( 1.0, 0.0, 0.0 );

	if ( count == 0 )
	{
		return 0;
	}
	else if ( count == 1 )
	{
		return blue;
	}
	else if ( count == 2 )
	{
		return cyan;
	}
	else if ( count == 3 )
	{
		return green;
	}
	else if ( count == 4 )
	{
		return yellow;
	}
	else
	{
		return red;
	}

}

float4 HeatmapTileFp( in vs_output IN ) : SV_Target
{
	uint2 pixelCoord = IN.hpos.xy;
	float2 pixelCoordNormalized = pixelCoord * renderTargetSize.zw;
	uint2 screenTile = min( uint2( pixelCoordNormalized * float2( cellCountA.xy ) ), cellCountA.xy - 1 );

	uint decalCount = 0;

	for ( uint slice = 0; slice < cellCountA.z; ++slice )
	{
		uint3 cellID = uint3( screenTile, slice );
		uint clusterIndex = DecalVolume_GetCellFlatIndex( cellID, uint3( cellCountA.xy, 1 ) );

		uint node = inDecalsPerCell[clusterIndex];
		uint cellDecalCount;
		uint offsetToFirstDecalIndex;
		DecalVolume_UnpackHeader( node, cellDecalCount, offsetToFirstDecalIndex );

		decalCount += cellDecalCount;
	}

	float3 color = GetColorMap( decalCount );

	return float4( color, 0.25f );
}


vs_output DecalVolumeFarPlaneVp( uint vertexId : SV_VertexID )
{
	vs_output OUT = (vs_output)0;

	float farPlane = nearFarPlane.y;

	if ( vertexId == 0 )
	{
		OUT.hpos = float4( -1, -1, farPlane, 1 );
	}
	else if ( vertexId == 1 )
	{
		OUT.hpos = float4( 3, -1, farPlane, 1 );
	}
	else // if ( vertexId == 2 )
	{
		OUT.hpos = float4( -1, 3, farPlane, 1 );
	}

	return OUT;
}


float4 DecalVolumeFarPlaneFp( in vs_output IN ) : SV_Target
{
	return float4( 1, 0, 0, 0.5f );
}


vs_output DecalVolumesAccumVp( /*uint vertexId : SV_VertexID,*/ float3 position : POSITION, uint instanceId : SV_InstanceID )
{
	vs_output OUT;

	//float4 positionWorld = mul( World, float4( position, 1 ) );
	DecalVolume dv = inDecalVolumes[instanceId];
	float3 posWorld = position * dv.halfSize * 2;
	posWorld = mul( transpose( float3x3( dv.x, dv.y, dv.z ) ), posWorld );
	posWorld = posWorld + dv.position;
	//float3 posWorld = position;// dv.position;

	OUT.hpos = mul( ViewProjection, float4(posWorld, 1) );

	return OUT;
}


float4 DecalVolumesAccumFp( in vs_output IN ) : SV_Target
{
	//float v = 0.25f;
	//return float4( v.xxxx );
	return colorMultiplier;
	//return float4( 1, 0, 0, 1 );
	//return float4( 1, 0, 0, 1 );
}


struct vs_axes_output
{
	float4 hpos		: SV_POSITION;
	float3 color	: COLOR;
};


vs_axes_output DecalVolumeAxesVp( float3 position : POSITION, uint instanceId : SV_InstanceID, uint vertexId : SV_VertexID )
{
	vs_axes_output OUT;

	DecalVolume dv = inDecalVolumes[instanceId];
	float3 posWorld = position * dv.halfSize * 2 * 0.6f;
	posWorld = mul( transpose( float3x3( dv.x, dv.y, dv.z ) ), posWorld );
	posWorld = posWorld + dv.position;

	OUT.hpos = mul( ViewProjection, float4( posWorld, 1 ) );

	uint lineNo = vertexId / 2;
	if ( lineNo == 0 )
		OUT.color = float3( 1, 0, 0 );
	else if ( lineNo == 1 )
		OUT.color = float3( 0, 1, 0 );
	else // if ( lineNo == 2 )
		OUT.color = float3( 0, 0, 1 );

	return OUT;
}


float4 DecalVolumeAxesFp( in vs_axes_output IN ) : SV_Target
{
	return float4( IN.color, 1 );
}


struct vs_model_output
{
	float4 hpos			: SV_POSITION; // vertex position in clip space
	float3 normalWS		: NORMAL;      // vertex normal in world space
	float2 texCoord0	: TEXCOORD0;   // vertex texture coords 
};

vs_model_output ModelVp(
	float3 position : POSITION
	, float3 normal : NORMAL
	, float2 texCoord0 : TEXCOORD0
)
{
	vs_model_output OUT;

	float4 positionWorld = mul( World, float4( position, 1 ) );

	OUT.hpos = mul( ViewProjection, positionWorld );
	OUT.normalWS = mul( ( float3x3 )WorldIT, normal );
	OUT.texCoord0 = texCoord0;

	return OUT;
}

float4 ModelDiffuseFp( in vs_model_output IN ) : SV_Target
{
	//return float4( 1, 0, 1, 1 );
	return float4( diffuseTex.Sample( diffuseTexSamp, IN.texCoord0 ).xyz, 1 );
}