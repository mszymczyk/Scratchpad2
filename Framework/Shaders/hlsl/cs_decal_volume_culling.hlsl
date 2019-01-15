#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	cs_decal_volume_culling = {
		ComputeProgram = "cs_decal_volume_culling";
	}

	cs_copy_depth = {
		ComputeProgram = "cs_copy_depth";
	}

	cs_downsample_depth = {
		ComputeProgram = "cs_downsample_depth";
	}

};
#endif // FX_PASSES
#endif // FX_HEADER

#include "cs_decal_volume_cshared.hlsl"
#include "cs_decal_volume_util.hlsl"

RWStructuredBuffer<DecalVolume> outDecalVolumes				REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS;
RWStructuredBuffer<DecalVolumeTest> outDecalVolumesTest		REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS_TEST;
RWStructuredBuffer<uint> outDecalVolumeCount				REGISTER_BUFFER_DECAL_VOLUME_OUT_DECALS_COUNT;

Texture2D<float> inDepth									REGISTER_TEXTURE_DECAL_VOLUME_IN_DEPTH;
RWTexture2D<float> outDepth									REGISTER_TEXTURE_DECAL_VOLUME_OUT_DEPTH;
SamplerState inDepthSamp									REGISTER_SAMPLER_DECAL_VOLUME_IN_DEPTH;

[numthreads( DECAL_VOLUME_CULL_NUM_THREADS_PER_GROUP, 1, 1 )]
void cs_decal_volume_culling( uint3 dtid : SV_DispatchThreadID )
{
	uint decalVolumeIndex = dtid.x;

	if ( decalVolumeIndex >= numDecalsToCull.x )
		return;

	DecalVolume dv = inDecalVolumes[decalVolumeIndex];

	Frustum frustum;
	frustum.planes[0] = frustumPlane0;
	frustum.planes[1] = frustumPlane1;
	frustum.planes[2] = frustumPlane2;
	frustum.planes[3] = frustumPlane3;
	frustum.planes[4] = frustumPlane4;
	frustum.planes[5] = frustumPlane5;

	//if ( frustumOBBIntersectSimpleOptimized( frustum.planes, dv.position.xyz, dv.halfSize.xyz, dv.x.xyz, dv.y.xyz, dv.z.xyz ) )
	{
		uint globalIndex;
		InterlockedAdd( outDecalVolumeCount[0], 1, globalIndex );

		outDecalVolumes[globalIndex] = dv;

		float3 center = dv.position;
		float3 xs = dv.x * dv.halfSize.x;
		float3 ys = dv.y * dv.halfSize.y;
		float3 zs = dv.z * dv.halfSize.z;

		float3 v0 = center - xs - ys + zs;
		float3 v4 = center - xs - ys - zs;
		float3 v5 = center + xs - ys - zs;
		float3 v7 = center - xs + ys - zs;

		float3 v1 = center + xs - ys + zs;
		float3 v2 = center + xs + ys + zs;
		float3 v3 = center - xs + ys + zs;
		float3 v6 = center + xs + ys - zs;

#if DECAL_VOLUME_USE_XYW_CORNERS

		DecalVolumeTest dvt;
		dvt.v0 = mul( ViewProjMatrix, float4( v0, 1 ) ).xyw;
		dvt.v4 = mul( ViewProjMatrix, float4( v4, 1 ) ).xyw;
		dvt.v5 = mul( ViewProjMatrix, float4( v5, 1 ) ).xyw;
		dvt.v7 = mul( ViewProjMatrix, float4( v7, 1 ) ).xyw;

#else // #if DECAL_VOLUME_USE_XYW_CORNERS

		DecalVolumeTest dvt;
		dvt.v0 = mul( ViewProjMatrix, float4( v0, 1 ) );
		dvt.v4 = mul( ViewProjMatrix, float4( v4, 1 ) );
		dvt.v5 = mul( ViewProjMatrix, float4( v5, 1 ) );
		dvt.v7 = mul( ViewProjMatrix, float4( v7, 1 ) );

		//dvt.v1 = mul( ViewProjMatrix, float4( v1, 1 ) );
		//dvt.v2 = mul( ViewProjMatrix, float4( v2, 1 ) );
		//dvt.v3 = mul( ViewProjMatrix, float4( v3, 1 ) );
		//dvt.v6 = mul( ViewProjMatrix, float4( v6, 1 ) );

#endif // #else // #if DECAL_VOLUME_USE_XYW_CORNERS

		outDecalVolumesTest[globalIndex] = dvt;
	}
}


[numthreads( 8, 8, 1 )]
void cs_copy_depth( uint3 dtid : SV_DispatchThreadID )
{
	//float w, h, nl;
	//inDepth.GetDimensions( 0, w, h, nl );
	//float2 uv = float2( dtid.xy + 0.5f ) / float2( w, h );
	float2 uv = dtid.xy * dvcRenderTargetSize.zw;

	float nonLinearDepth = inDepth.SampleLevel( inDepthSamp, uv, 0 ).x;

	float d = dvcProjMatrixParams.w / ( nonLinearDepth + dvcProjMatrixParams.z ); // formula doesn't work for Stereo/VR projections
	d *= 0.01f;
	//float d = nonLinearDepth;

	outDepth[dtid.xy] = d;
}


[numthreads( 8, 8, 1 )]
void cs_downsample_depth( uint3 dispatchThreadID : SV_DispatchThreadID )
{
	int2 ssP = int2( dispatchThreadID.xy ) * 2;
	float depth0 = inDepth.Load( int3( ssP + int2( 0, 0 ), 0 ) );
	float depth1 = inDepth.Load( int3( ssP + int2( 1, 0 ), 0 ) );
	float depth2 = inDepth.Load( int3( ssP + int2( 0, 1 ), 0 ) );
	float depth3 = inDepth.Load( int3( ssP + int2( 1, 1 ), 0 ) );

	float depth01 = max( depth0, depth1 );
	float depth23 = max( depth2, depth3 );
	float depth = max( depth01, depth23 );

	// properly downsampling depth texture is crucial for this technique to work correctly
	// imagine downsampling 1920x1080, at some point, LOD==10 will have size of 3x2
	// naive downsample (as written above) will lead to sampling only 2x2 upper left portion, ignoring values in right-most column
	// it may happen, and happen often, that those texels contain maximum depth
	//
	// no need to do it this way because I've fixed occlusion map resolution to 256x256
	//

	//// if we are reducing an odd-width texture then the edge fragments have to fetch additional texels
	////
	//if ( ( prevMipWidth & 1 ) != 0 && ( ssP.x == prevMipWidth - 3 ) )
	//{
	//	float extraDepth_20 = InputTexture2D.Load( int3( ssP + int2( 2, 0 ), 0 ) );
	//	float extraDepth_21 = InputTexture2D.Load( int3( ssP + int2( 2, 1 ), 0 ) );
	//	depth = max3( depth, extraDepth_20, extraDepth_21 );

	//	// if both sizes are odd, fetch bottom row additionally
	//	//
	//	if ( ( prevMipHeight & 1 ) != 0 && ( ssP.y == prevMipHeight - 3 ) )
	//	{
	//		float extraDepth_02 = InputTexture2D.Load( int3( ssP + int2( 0, 2 ), 0 ) );
	//		float extraDepth_12 = InputTexture2D.Load( int3( ssP + int2( 1, 2 ), 0 ) );
	//		float extraDepth_22 = InputTexture2D.Load( int3( ssP + int2( 2, 2 ), 0 ) );
	//		depth = max3( depth, extraDepth_02, extraDepth_12 );
	//		depth = max( depth, extraDepth_22 );
	//	}
	//}
	//// if we are reducing an odd-height texture then the edge fragments have to fetch additional texels
	////
	//else if ( ( prevMipHeight & 1 ) != 0 && ( ssP.y == prevMipHeight - 3 ) )
	//{
	//	float extraDepth_02 = InputTexture2D.Load( int3( ssP + int2( 0, 2 ), 0 ) );
	//	float extraDepth_12 = InputTexture2D.Load( int3( ssP + int2( 1, 2 ), 0 ) );
	//	depth = max3( depth, extraDepth_02, extraDepth_12 );
	//}

	outDepth[dispatchThreadID.xy] = depth;
}