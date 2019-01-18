#ifndef DECAL_VOLUME_CSHARED_HLSL
#define DECAL_VOLUME_CSHARED_HLSL

#include "HlslFrameworkInterop.h"

#define DECAL_VOLUME_CLUSTER_GCN			0

#if COMPILING_SHADER_CODE

uint DecalVolume_PackHeader( uint decalCount, uint offsetToFirstDecalIndex )
{
	return ( decalCount & 0x3ff ) | ( ( offsetToFirstDecalIndex & 0xffffff ) << 10 );
}


void DecalVolume_UnpackHeader( uint packedHeader, out uint decalCount, out uint offsetToFirstDecalIndex )
{
	decalCount = packedHeader & 0x3ff;
	offsetToFirstDecalIndex = packedHeader >> 10;
}


uint DecalVolume_GetCellFlatIndex3D( uint3 cellID, uint3 numCells )
{
	return safe_mad24( cellID.z, safe_mul24( numCells.x, numCells.y ), safe_mad24( cellID.y, numCells.x, cellID.x ) );
}


uint DecalVolume_GetCellFlatIndex2D( uint2 cellID, uint2 numCells )
{
	return safe_mad24( cellID.y, numCells.x, cellID.x );
}


float LogBase( float base, float x )
{
	return log2( x ) * rcp( log2( base ) );
}


// pixelPosition is in range <0, renderTargetSize>
uint2 DecalVolume_GetCellXYFromScreenPosition( float2 pixelPosition, float2 renderTargetSizeRcp, float2 nCellsXY )
{
	float2 pixelUV = pixelPosition * renderTargetSizeRcp;
	uint2 tileXY = uint2( pixelUV * nCellsXY );
	return min( tileXY, uint2( nCellsXY - 1 ) );
}


uint DecalVolume_GetCellZFromCameraZLog( float cameraZ, float nearPlaneRcp, float farPlaneOverNearPlane, float nCellsZ )
{
	float base = farPlaneOverNearPlane;
	return ( uint ) min( floor( LogBase( base, cameraZ * nearPlaneRcp ) * nCellsZ ), nCellsZ - 1 );
}


uint DecalVolume_GetCellZFromCameraZUniform( float cameraZ, float zScale, float zBias, float nCellsZ )
{
	// float slice = ( cameraZ - nearPlane ) * ( 1.0f / (farPlane - nearPlane) ) * nCellsZ;
	// zScale = nCellsZ * ( 1.0f / (farPlane - nearPlane) )
	// zBias = zScale * nearPlane
	float slice = cameraZ * zScale - zBias;
	return (uint) min( slice, nCellsZ - 1 );
}


//uint3 DecalVolume_GetCellFromViewPos( float2 pixelPosition, float cameraZ, float2 renderTargetSizeRcp, float3 nCellsXYZ, float nearPlaneRcp, float farPlaneOverNearPlane )
//{
//	return uint3(
//		DecalVolume_GetCellXYFromScreenPosition( pixelPosition, renderTargetSizeRcp, nCellsXYZ.xy ),
//		DecalVolume_GetCellZFromCameraZ( cameraZ, nearPlaneRcp, farPlaneOverNearPlane, nCellsXYZ.z )
//		);
//}

#endif // #if COMPILING_SHADER_CODE

#if DECAL_VOLUME_CLUSTER_GCN
#define ulong uint2
ulong BallotMask( const in uint condition ) { return condition.xx; }
uint CountSetBits64( const in ulong v ) { return countbits( v.x ) + countbits( v.y ); }
uint MaskBitCnt( const in ulong mask ) { return countbits( mask.x ) + countbits( mask.y ); }
uint ReadLane( const in uint _val, const in uint _laneID ) { return _val; }
ulong shlU64( const ulong u0, const uint  u1 ) { return u0.xy << u1; }
ulong shrU64( const ulong u0, const uint  u1 ) { return u0.xy >> u1; }
ulong andU64( const ulong u0, const ulong u1 ) { return uint2( u0.x & u1.x, u0.y & u1.y ); }
bool cmpNeqU64( const ulong u0, const ulong u1 ) { return u0.x != u1.x || u0.y != u1.y; }
#endif // #if DECAL_VOLUME_CLUSTER_GCN

#endif // DECAL_VOLUME_CSHARED_HLSL