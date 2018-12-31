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

RWStructuredBuffer<DecalVolume> outDecalVolumes		REGISTER_U( DECAL_VOLUME_OUT_DECALS_BINDING );
RWStructuredBuffer<uint> outDecalVolumeCount		REGISTER_U( DECAL_VOLUME_OUT_DECALS_COUNT_BINDING );

[numthreads( DECAL_VOLUME_CULL_NUM_THREADS_PER_GROUP, 1, 1 )]
void DecalVolumeCulling( uint3 dtid : SV_DispatchThreadID )
{
	uint decalVolumeIndex = dtid.x;

	if ( decalVolumeIndex >= numDecalsToCull.x )
		return;

	DecalVolume dv = inDecalVolumes[decalVolumeIndex];

	Frustum frustum;
	frustum.twoTests = false;
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
	}
}
