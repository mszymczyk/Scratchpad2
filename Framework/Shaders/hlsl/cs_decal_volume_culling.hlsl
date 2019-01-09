#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	DecalVolumeCulling = {
		ComputeProgram = "DecalVolumeCulling";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

#include "cs_decal_volume_common.hlsl"

RWStructuredBuffer<DecalVolume> outDecalVolumes				REGISTER_U( DECAL_VOLUME_OUT_DECALS_BINDING );
RWStructuredBuffer<DecalVolumeTest> outDecalVolumesTest		REGISTER_U( DECAL_VOLUME_OUT_DECALS_TEST_BINDING );
RWStructuredBuffer<uint> outDecalVolumeCount				REGISTER_U( DECAL_VOLUME_OUT_DECALS_COUNT_BINDING );

[numthreads( DECAL_VOLUME_CULL_NUM_THREADS_PER_GROUP, 1, 1 )]
void DecalVolumeCulling( uint3 dtid : SV_DispatchThreadID )
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

	if ( frustumOBBIntersectSimpleOptimized( frustum.planes, dv.position.xyz, dv.halfSize.xyz, dv.x.xyz, dv.y.xyz, dv.z.xyz ) )
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
