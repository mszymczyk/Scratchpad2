#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	cs_decal_volume_indirect_args = {
		ComputeProgram = "cs_decal_volume_indirect_args";
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
#include "cs_decal_volume_cshared.hlsl"

StructuredBuffer<DecalVolume> inDecalVolumes		REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS;
StructuredBuffer<uint> inDecalVolumesCount			REGISTER_BUFFER_DECAL_VOLUME_IN_DECALS_COUNT;
StructuredBuffer<uint> inDecalVolumeIndices			REGISTER_BUFFER_DECAL_VOLUME_IN_DECAL_INDICES;
RWByteAddressBuffer outIndirectArgs					REGISTER_BUFFER_DECAL_VOLUME_OUT_INDIRECT_ARGS;

Texture2D diffuseTex								REGISTER_TEXTURE_DIFFUSE_TEXTURE;
SamplerState diffuseTexSamp							REGISTER_SAMPLER_DIFFUSE_SAMPLER;


[numthreads( 1, 1, 1 )]
void cs_decal_volume_indirect_args()
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
	float2 pixelCoordNormalized = pixelCoord * dvdRenderTargetSize.zw;
	uint2 screenTile = min( uint2( pixelCoordNormalized * float2( dvdCellCount.xy ) ), dvdCellCount.xy - 1 );

	uint mode = dvdMode.x;

	if ( mode == DECAL_VOLUME_CLUSTER_DISPLAY_MODE_3D )
	{
		uint decalCount = 0;

		for ( uint slice = 0; slice < dvdCellCount.z; ++slice )
		{
			uint3 cellID = uint3( screenTile, slice );
			uint clusterIndex = DecalVolume_GetCellFlatIndex3D( cellID, uint3( dvdCellCount.xy, 1 ) );

			uint node = inDecalVolumeIndices[clusterIndex];
			uint cellDecalCount;
			uint offsetToFirstDecalIndex;
			DecalVolume_UnpackHeader( node, cellDecalCount, offsetToFirstDecalIndex );

			decalCount += cellDecalCount;
		}

		float3 color = GetColorMap( decalCount );

		//color = 0;
		//if ( screenTile.x & 1 )
		//	color.x = 1;
		//if ( screenTile.y & 1 )
		//	color.y = 1;

		return float4( color, 0.25f );
	}
	else if ( mode == DECAL_VOLUME_CLUSTER_DISPLAY_MODE_2D )
	{
		uint clusterIndex = DecalVolume_GetCellFlatIndex2D( screenTile, dvdCellCount.xy );

		uint node = inDecalVolumeIndices[clusterIndex];
		uint cellDecalCount;
		uint offsetToFirstDecalIndex;
		DecalVolume_UnpackHeader( node, cellDecalCount, offsetToFirstDecalIndex );

		uint decalCount = cellDecalCount;

		float3 color = GetColorMap( decalCount );

		//color = 0;
		//if ( screenTile.x & 1 )
		//	color.x = 1;
		//if ( screenTile.y & 1 )
		//	color.y = 1;

		return float4( color, 0.25f );
	}
	else if ( mode == DECAL_VOLUME_CLUSTER_DISPLAY_MODE_DEPTH )
	{
		float4 t = diffuseTex.SampleLevel( diffuseTexSamp, pixelCoordNormalized, dvdMode.y );

		return float4( t.xxx, 1 );
	}

	return float4( 1, 0, 1, 1 );
}


vs_output DecalVolumeFarPlaneVp( uint vertexId : SV_VertexID )
{
	vs_output OUT = (vs_output)0;

	float farPlane = dvdNearFarPlane.y;

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
	return dvdColorMultiplier;
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
