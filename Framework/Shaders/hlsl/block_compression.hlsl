#ifdef FX_HEADER
#ifdef FX_PASSES
passes :
{
	cs_bc6_compress_array_hq = {
		ComputeProgram = "cs_bc6_compress_array_hq";
	}
};
#endif // FX_PASSES
#endif // FX_HEADER

//#ifndef __CS_RUNTIME_COMPRESSION_HLSL__
//#define __CS_RUNTIME_COMPRESSION_HLSL__

//#include "lib/common/config.hlsl"
//#include "lib/global_samplers.hlsl"
//#include "lib/extern/block_compress.hlsl"
//#include "lib/color.hlsl"
#include "block_compression_cshared.hlsl"
#include "global_samplers.hlsl"

#if PS4
#define LOW_MIP_ARRAY 0
#else // #if PS4
#define LOW_MIP_ARRAY 1
#endif // #else // #if PS4

// resources for xdk compression code

//Texture2D			inUncompressedTexture			: register( RC_REGISTER_UNCOMPRESSED_TEXTURE );

//RWTexture2DArray<uint2>	outCompressedMip_UINT2			: register( RC_REGISTER_MIP_OUTPUT );
//RWTexture2DArray<uint2>	outSecondCompressedMip_UINT2	: register( RC_REGISTER_SECOND_MIP_OUTPUT );
//
//RWTexture2DArray<uint4>	outCompressedMip_UINT4			: register( RC_REGISTER_MIP_OUTPUT );
//RWTexture2DArray<uint4>	outSecondCompressedMip_UINT4	: register( RC_REGISTER_SECOND_MIP_OUTPUT );
//
//RWTexture2DArray<uint2>	out16Mip_UINT2					: register( RC_REGISTER_16_MIP_OUTPUT );
//RWTexture2DArray<uint2>	out8Mip_UINT2					: register( RC_REGISTER_8_MIP_OUTPUT );
//RWTexture2DArray<uint2>	out4Mip_UINT2					: register( RC_REGISTER_4_MIP_OUTPUT );
//#if LOW_MIP_ARRAY
//RWTexture2DArray<uint2>	out2Mip_UINT2					: register( RC_REGISTER_2_MIP_OUTPUT );
//RWTexture2DArray<uint2>	out1Mip_UINT2					: register( RC_REGISTER_1_MIP_OUTPUT );
//#else // #if LOW_MIP_ARRAY
//RWTexture2D<uint2>		out2Mip_UINT2					: register( RC_REGISTER_2_MIP_OUTPUT );
//RWTexture2D<uint2>		out1Mip_UINT2					: register( RC_REGISTER_1_MIP_OUTPUT );
//#endif // #else // #if LOW_MIP_ARRAY
//
//RWTexture2DArray<uint4>	out16Mip_UINT4					: register( RC_REGISTER_16_MIP_OUTPUT );
//RWTexture2DArray<uint4>	out8Mip_UINT4					: register( RC_REGISTER_8_MIP_OUTPUT );
//RWTexture2DArray<uint4>	out4Mip_UINT4					: register( RC_REGISTER_4_MIP_OUTPUT );
//#if LOW_MIP_ARRAY
//RWTexture2DArray<uint4>	out2Mip_UINT4					: register( RC_REGISTER_2_MIP_OUTPUT );
//RWTexture2DArray<uint4>	out1Mip_UINT4					: register( RC_REGISTER_1_MIP_OUTPUT );
//#else // #if LOW_MIP_ARRAY
//RWTexture2D<uint4>		out2Mip_UINT4					: register( RC_REGISTER_2_MIP_OUTPUT );
//RWTexture2D<uint4>		out1Mip_UINT4					: register( RC_REGISTER_1_MIP_OUTPUT );
//#endif // #else // #if LOW_MIP_ARRAY
//
//RWTexture2D<uint4>		out1MipConstantColor_UINT4		: register( RC_REGISTER_1_MIP_OUTPUT );

// resources for mipgen code

//Texture2D<float4>	inMipLevel						: register( RC_REGISTER_UNCOMPRESSED_TEXTURE );
//RWTexture2D<float4> outMipLevel						: register( RC_REGISTER_MIP_OUTPUT );
Texture2DArray<float4>	inArrayMipLevel				: register( RC_REGISTER_UNCOMPRESSED_TEXTURE );

// resources for bc6 compression
RWTexture2DArray<uint4>	outArrayMipLevel_UINT4		: register( RC_REGISTER_MIP_OUTPUT );


////--------------------------------------------------------------------------------------
//// Name: BC1CompressOneMipCS
//// Desc: Compress one mip level
////--------------------------------------------------------------------------------------
//[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc1_compress_one_mip( uint2 threadIDWithinDispatch : SV_DispatchThreadID )
//{
//	float3 block[16];
//	LoadTexelsRGB( inUncompressedTexture, pointMipClampSampler, g_oneOverTextureWidth, threadIDWithinDispatch, block );
//
//	outCompressedMip_UINT2[uint3(threadIDWithinDispatch, arraySlice)] = CompressBC1Block(block);
//}
//
//
//groupshared float3 gs_mip1Blocks[ MIP1_BLOCKS_PER_ROW * MIP1_BLOCKS_PER_ROW ][16];
//
////--------------------------------------------------------------------------------------
//// Name: DownsampleMip
//// Desc: Calculate the texels for mip level 1
////--------------------------------------------------------------------------------------
//void DownsampleMip( uint2 threadIDWithinGroup, float3 block[16] )
//{
//	// Find the block and texel index for this thread within the group
//	uint2 blockID = threadIDWithinGroup / 2;
//	uint2 texelID = 2 * (threadIDWithinGroup - 2 * blockID);
//	uint blockIndex = blockID.y * MIP1_BLOCKS_PER_ROW + blockID.x;
//	uint texelIndex = texelID.y * 4 + texelID.x;  // A block is 4x4 texels
//
//												  // We average the colors later by passing a scale value into CompressBC1Block. This allows
//												  //  us to avoid scaling all 16 colors in the block: we really only need to scale the min
//												  //  and max values.
//	gs_mip1Blocks[blockIndex][texelIndex]        = block[0] + block[1] + block[4] + block[5];    
//	gs_mip1Blocks[blockIndex][texelIndex + 1]    = block[2] + block[3] + block[6] + block[7];
//	gs_mip1Blocks[blockIndex][texelIndex + 4]    = block[8] + block[9] + block[12] + block[13];
//	gs_mip1Blocks[blockIndex][texelIndex + 5]    = block[10] + block[11] + block[14] + block[15];
//}
//
////--------------------------------------------------------------------------------------
//// Name: BC1CompressTwoMipsCS
//// Desc: Compress two mip levels at once by downsampling into LDS
////--------------------------------------------------------------------------------------
//[ numthreads( COMPRESS_TWO_MIPS_THREADGROUP_WIDTH, COMPRESS_TWO_MIPS_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc1_compress_two_mips( uint2 threadIDWithinDispatch : SV_DispatchThreadID,
//	uint2 threadIDWithinGroup : SV_GroupThreadID,
//	uint threadIndexWithinGroup : SV_GroupIndex,
//	uint2 groupIDWithinDispatch : SV_GroupID )
//{
//	// Load the texels in our mip 0 block
//	float3 block[16];
//	LoadTexelsRGB( inUncompressedTexture, pointMipClampSampler, g_oneOverTextureWidth, threadIDWithinDispatch, block );
//
//	// Downsample from mip 0 to mip 1
//	DownsampleMip( threadIDWithinGroup, block );
//	GroupMemoryBarrierWithGroupSync();
//
//	outCompressedMip_UINT2[uint3(threadIDWithinDispatch, arraySlice)] = CompressBC1Block( block, 1.0f );
//
//	// When compressing two mips at a time, we use a group size of 16x16. This produces four 64-thread wavefronts.
//	// The first wavefronts will execute the code below and the other three will retire.
//	if( threadIndexWithinGroup < MIP1_BLOCKS_PER_ROW * MIP1_BLOCKS_PER_ROW )
//	{ 
//		uint2 texelID = uint2( threadIndexWithinGroup % MIP1_BLOCKS_PER_ROW, threadIndexWithinGroup / MIP1_BLOCKS_PER_ROW );
//
//		// Pass a scale value of 0.25 to CompressBC1 block to average the four source values contributing to each pixel
//		//  in the block. See the comment in DownsampleMip, above.
//		outSecondCompressedMip_UINT2[uint3(groupIDWithinDispatch * MIP1_BLOCKS_PER_ROW + texelID, arraySlice)] = CompressBC1Block( gs_mip1Blocks[threadIndexWithinGroup], 0.25f );
//	}
//}
//
//
//
////--------------------------------------------------------------------------------------
//// Name: BC1CompressTailMipsCS
//// Desc: BC1 compress the tail mips of a texture
////--------------------------------------------------------------------------------------
//[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc1_compress_tail_mips( uint2 threadIDWithinDispatch : SV_DispatchThreadID )
//{
//	float3 block[16];
//	uint mipBias = 0;
//	float oneOverTextureSize = 1.0f;
//	uint2 blockID = threadIDWithinDispatch;
//
//	// Different threads in the threadgroup work on different mip levels
//	CalcTailMipsParams( threadIDWithinDispatch, oneOverTextureSize, blockID, mipBias );
//	LoadTexelsRGBBias( inUncompressedTexture, pointMipClampSampler, oneOverTextureSize, blockID, mipBias, block );
//	uint2 compressed = CompressBC1Block( block, 1.0f );
//
//	if(mipBias == 0)
//	{
//		out16Mip_UINT2[uint3(blockID, arraySlice)] = compressed;
//	}
//	else if(mipBias == 1)
//	{
//		out8Mip_UINT2[uint3(blockID, arraySlice)] = compressed;
//	}
//	else if(mipBias == 2)
//	{
//		out4Mip_UINT2[uint3(blockID, arraySlice)] = compressed;
//	}
//	else if(mipBias == 3)
//	{
//#if LOW_MIP_ARRAY
//		out2Mip_UINT2[uint3(blockID, arraySlice)] = compressed;
//#else // #if LOW_MIP_ARRAY
//		out2Mip_UINT2[blockID] = compressed;
//#endif // #else // #if LOW_MIP_ARRAY
//	}
//	else if(mipBias == 4)
//	{
//#if LOW_MIP_ARRAY
//		out1Mip_UINT2[uint3(blockID, arraySlice)] = compressed;
//#else // #if LOW_MIP_ARRAY
//		out1Mip_UINT2[blockID] = compressed;
//#endif // #else // #if LOW_MIP_ARRAY
//	}
//}
//
//
////--------------------------------
//// BEGIN BC3 COMPRESSION KERNELS
////------------------------------
//
//
////--------------------------------------------------------------------------------------
//// Name: BC3CompressOneMipCS
//// Desc: Compress one mip level
////--------------------------------------------------------------------------------------
//[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc3_compress_one_mip( uint2 threadIDWithinDispatch : SV_DispatchThreadID )
//{
//	float3 blockRGB[16];
//	float blockA[16];
//	LoadTexelsRGBA( inUncompressedTexture, threadIDWithinDispatch, blockRGB, blockA );
//
//	outCompressedMip_UINT4[uint3(threadIDWithinDispatch.xy, arraySlice)] = CompressBC3Block( blockRGB, blockA, 1.0f ); 
//}
//
//
//groupshared float3 gs_mip1BlocksRGB[ MIP1_BLOCKS_PER_ROW * MIP1_BLOCKS_PER_ROW ][16];
//groupshared float gs_mip1BlocksA[ MIP1_BLOCKS_PER_ROW * MIP1_BLOCKS_PER_ROW ][16];
//
////--------------------------------------------------------------------------------------
//// Name: DownsampleMip_BC3
//// Desc: Calculate the texels for mip level 1
////--------------------------------------------------------------------------------------
//void DownsampleMip_BC3( uint2 threadIDWithinGroup, float3 blockRGB[16], float blockA[16] )
//{
//	// Find the block and texel index for this thread within the group
//	uint2 blockID = threadIDWithinGroup.xy/2;
//	uint2 texelID = 2 * ( threadIDWithinGroup.xy - 2 * blockID );
//	uint blockIndex = blockID.y * MIP1_BLOCKS_PER_ROW + blockID.x;
//	uint texelIndex = texelID.y * 4 + texelID.x;  // A block is 4x4 texels
//
//												  // We average the colors later by passing a scale value into CompressBC3Block. This allows
//												  //  us to avoid scaling all 16 colors in the block: we really only need to scale the min
//												  //  and max values.
//	gs_mip1BlocksRGB[blockIndex][texelIndex]        = blockRGB[0] + blockRGB[1] + blockRGB[4] + blockRGB[5];  
//	gs_mip1BlocksRGB[blockIndex][texelIndex + 1]    = blockRGB[2] + blockRGB[3] + blockRGB[6] + blockRGB[7];
//	gs_mip1BlocksRGB[blockIndex][texelIndex + 4]    = blockRGB[8] + blockRGB[9] + blockRGB[12] + blockRGB[13];
//	gs_mip1BlocksRGB[blockIndex][texelIndex + 5]    = blockRGB[10] + blockRGB[11] + blockRGB[14] + blockRGB[15];
//	gs_mip1BlocksA[blockIndex][texelIndex]          = blockA[0] + blockA[1] + blockA[4] + blockA[5];    
//	gs_mip1BlocksA[blockIndex][texelIndex + 1]      = blockA[2] + blockA[3] + blockA[6] + blockA[7];
//	gs_mip1BlocksA[blockIndex][texelIndex + 4]      = blockA[8] + blockA[9] + blockA[12] + blockA[13];
//	gs_mip1BlocksA[blockIndex][texelIndex + 5]      = blockA[10] + blockA[11] + blockA[14] + blockA[15];
//}
//
//
////--------------------------------------------------------------------------------------
//// Name: BC3CompressTwoMipsCS
//// Desc: Compress two mip levels at once by downsampling into LDS
////--------------------------------------------------------------------------------------
//[ numthreads( COMPRESS_TWO_MIPS_THREADGROUP_WIDTH, COMPRESS_TWO_MIPS_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc3_compress_two_mips( uint2 threadIDWithinDispatch : SV_DispatchThreadID,
//	uint2 threadIDWithinGroup : SV_GroupThreadID,
//	uint threadIndexWithinGroup : SV_GroupIndex,
//	uint2 groupIDWithinDispatch : SV_GroupID )
//{
//	// Load the texels in our block
//	float3 blockRGB[16];
//	float blockA[16];
//	LoadTexelsRGBA( inUncompressedTexture, threadIDWithinDispatch, blockRGB, blockA );
//
//	// Downsample from mip 0 to mip 1
//	DownsampleMip_BC3( threadIDWithinGroup, blockRGB, blockA );
//	GroupMemoryBarrierWithGroupSync();
//
//	outCompressedMip_UINT4[uint3(threadIDWithinDispatch.xy, arraySlice)] = CompressBC3Block( blockRGB, blockA ); 
//
//	// When compressing two mips at a time, we use a group size of 16x16. This produces four 64-thread shader vectors.
//	// The first shader vector will execute the code below and the other three will retire.
//	if( threadIndexWithinGroup < MIP1_BLOCKS_PER_ROW * MIP1_BLOCKS_PER_ROW )
//	{ 
//		uint2 texelID = uint2( threadIndexWithinGroup % MIP1_BLOCKS_PER_ROW, threadIndexWithinGroup / MIP1_BLOCKS_PER_ROW );
//
//		// Pass a scale value of 0.25 to CompressBC3 block to average the four source values contributing to each pixel
//		//  in the block. See the comment in DownsampleMip, above.
//		uint4 compressed = CompressBC3Block( gs_mip1BlocksRGB[threadIndexWithinGroup], gs_mip1BlocksA[threadIndexWithinGroup], 0.25f );
//		outSecondCompressedMip_UINT4[ uint3( groupIDWithinDispatch.xy * MIP1_BLOCKS_PER_ROW + texelID, arraySlice )] = compressed;
//	}
//}
//
//
////--------------------------------------------------------------------------------------
//// Name: BC3CompressTailMipsCS
//// Desc: BC3 compress the tail mips of a texture
////--------------------------------------------------------------------------------------
//[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc3_compress_tail_mips( uint2 threadIDWithinDispatch : SV_DispatchThreadID )
//{
//	float3 blockRGB[16];
//	float blockA[16];
//	uint mipBias = 0;
//	float oneOverTextureSize = 1.0f;
//	uint2 blockID = threadIDWithinDispatch;
//
//	// Different threads in the threadgroup work on different mip levels
//	CalcTailMipsParams( threadIDWithinDispatch, oneOverTextureSize, blockID, mipBias );
//	LoadTexelsRGBABias( inUncompressedTexture, pointMipClampSampler, oneOverTextureSize, blockID, mipBias, blockRGB, blockA );
//	uint4 compressed = CompressBC3Block( blockRGB, blockA, 1.0f );
//
//	if(mipBias == 0)
//	{
//		out16Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//	}
//	else if(mipBias == 1)
//	{
//		out8Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//	}
//	else if(mipBias == 2)
//	{
//		out4Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//	}
//	else if(mipBias == 3)
//	{
//#if LOW_MIP_ARRAY
//		out2Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//#else // #if LOW_MIP_ARRAY
//		out2Mip_UINT4[blockID] = compressed;
//#endif // #else // #if LOW_MIP_ARRAY
//	}
//	else if(mipBias == 4)
//	{
//#if LOW_MIP_ARRAY
//		out1Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//#else // #if LOW_MIP_ARRAY
//		out1Mip_UINT4[blockID] = compressed;
//#endif // #else // #if LOW_MIP_ARRAY
//	}
//}
//
//
//
////---------------------------------
//// BEGIN BC5 COMPRESSION KERNELS
////---------------------------------
//
//
////--------------------------------------------------------------------------------------
//// Name: BC5CompressOneMipCS
//// Desc: Compute shader entry point
////--------------------------------------------------------------------------------------
//[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc5_compress_one_mip( uint2 threadIDWithinDispatch : SV_DispatchThreadID )
//{
//	float blockU[16], blockV[16];
//	LoadTexelsUV( inUncompressedTexture, pointMipClampSampler, g_oneOverTextureWidth, threadIDWithinDispatch, blockU, blockV );
//
//	outCompressedMip_UINT4[uint3(threadIDWithinDispatch, arraySlice)] = CompressBC5Block( blockU, blockV );
//}
//
//
//groupshared float gs_mip1BlocksU[ MIP1_BLOCKS_PER_ROW * MIP1_BLOCKS_PER_ROW ][16];
//groupshared float gs_mip1BlocksV[ MIP1_BLOCKS_PER_ROW * MIP1_BLOCKS_PER_ROW ][16];
//
////--------------------------------------------------------------------------------------
//// Name: DownsampleMip
//// Desc: Calculate the texels for mip level 1
////--------------------------------------------------------------------------------------
//void DownsampleMip_BC5( uint2 threadIDWithinGroup, float blockU[16], float blockV[16] )
//{
//	// Find the block and texel index for this thread within the group
//	uint2 blockID = threadIDWithinGroup / 2;
//	uint2 texelID = 2 * ( threadIDWithinGroup - 2 * blockID );
//	uint blockIndex = blockID.y * MIP1_BLOCKS_PER_ROW + blockID.x;
//	uint texelIndex = texelID.y * 4 + texelID.x;  // A block is 4x4 texels
//
//												  // We average the colors later by passing a scale value into CompressBC1Block. This allows
//												  //  us to avoid scaling all 16 colors in the block: we really only need to scale the min
//												  //  and max values.
//	gs_mip1BlocksU[blockIndex][texelIndex]        = blockU[0] + blockU[1] + blockU[4] + blockU[5];  
//	gs_mip1BlocksU[blockIndex][texelIndex + 1]    = blockU[2] + blockU[3] + blockU[6] + blockU[7];
//	gs_mip1BlocksU[blockIndex][texelIndex + 4]    = blockU[8] + blockU[9] + blockU[12] + blockU[13];
//	gs_mip1BlocksU[blockIndex][texelIndex + 5]    = blockU[10] + blockU[11] + blockU[14] + blockU[15];
//	gs_mip1BlocksV[blockIndex][texelIndex]          = blockV[0] + blockV[1] + blockV[4] + blockV[5];    
//	gs_mip1BlocksV[blockIndex][texelIndex + 1]      = blockV[2] + blockV[3] + blockV[6] + blockV[7];
//	gs_mip1BlocksV[blockIndex][texelIndex + 4]      = blockV[8] + blockV[9] + blockV[12] + blockV[13];
//	gs_mip1BlocksV[blockIndex][texelIndex + 5]      = blockV[10] + blockV[11] + blockV[14] + blockV[15];
//}
//
////--------------------------------------------------------------------------------------
//// Name: BC5CompressTwoMipsCS
//// Desc: Compute shader entry point at once by downsampling into LDS
////--------------------------------------------------------------------------------------
//[ numthreads( COMPRESS_TWO_MIPS_THREADGROUP_WIDTH, COMPRESS_TWO_MIPS_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc5_compress_two_mips( uint2 threadIDWithinDispatch : SV_DispatchThreadID,
//	uint2 threadIDWithinGroup : SV_GroupThreadID,
//	uint threadIndexWithinGroup : SV_GroupIndex,
//	uint2 groupIDWithinDispatch : SV_GroupID )
//{
//	// Load the texels in our block
//	float blockU[16], blockV[16];
//	LoadTexelsUV( inUncompressedTexture, pointMipClampSampler, g_oneOverTextureWidth, threadIDWithinDispatch, blockU, blockV );
//
//	// Downsample from mip 0 to mip 1
//	DownsampleMip_BC5( threadIDWithinGroup, blockU, blockV );
//	GroupMemoryBarrierWithGroupSync();
//
//	outCompressedMip_UINT4[uint3(threadIDWithinDispatch, arraySlice)] = CompressBC5Block( blockU, blockV, 1.0f );
//
//	// When compressing two mips at a time, we use a group size of 16x16. This produces four 64-thread shader vectors.
//	// The first shader vector will execute the code below and the other three will retire.
//	if(threadIndexWithinGroup < MIP1_BLOCKS_PER_ROW*MIP1_BLOCKS_PER_ROW)
//	{ 
//		uint2 texelID = uint2( threadIndexWithinGroup % MIP1_BLOCKS_PER_ROW, threadIndexWithinGroup / MIP1_BLOCKS_PER_ROW );
//
//		// Pass a scale value of 0.25 to CompressBC5 block to average the four source values contributing to each pixel
//		//  in the block. See the comment in DownsampleMip, above.
//		uint4 compressed = CompressBC5Block( gs_mip1BlocksU[threadIndexWithinGroup], gs_mip1BlocksV[threadIndexWithinGroup], 0.25f );
//		outSecondCompressedMip_UINT4[uint3(groupIDWithinDispatch * MIP1_BLOCKS_PER_ROW + texelID, arraySlice)] = compressed;
//	}
//}
//
//
////--------------------------------------------------------------------------------------
//// Name: BC5CompressTailMipsCS
//// Desc: BC5 compress the tail mips of a texture
////--------------------------------------------------------------------------------------
//[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc5_compress_tail_mips( uint2 threadIDWithinDispatch : SV_DispatchThreadID )
//{
//	float blockU[16], blockV[16];
//	uint mipBias = 0;
//	float oneOverTextureSize = 1.0f;
//	uint2 blockID = threadIDWithinDispatch;
//
//	// Different threads in the threadgroup work on different mip levels
//	CalcTailMipsParams( threadIDWithinDispatch, oneOverTextureSize, blockID, mipBias );
//	LoadTexelsUVBias( inUncompressedTexture, pointMipClampSampler, oneOverTextureSize, blockID, mipBias, blockU, blockV );
//	uint4 compressed = CompressBC5Block( blockU, blockV, 1.0f );
//
//	if(mipBias == 0)
//	{
//		out16Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//	}
//	else if(mipBias == 1)
//	{
//		out8Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//	}
//	else if(mipBias == 2)
//	{
//		out4Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//	}
//	else if(mipBias == 3)
//	{
//#if LOW_MIP_ARRAY
//		out2Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//#else // #if LOW_MIP_ARRAY
//		out2Mip_UINT4[blockID] = compressed;
//#endif // #else // #if LOW_MIP_ARRAY
//	}
//	else if(mipBias == 4)
//	{
//#if LOW_MIP_ARRAY
//		out1Mip_UINT4[uint3(blockID, arraySlice)] = compressed;
//#else // #if LOW_MIP_ARRAY
//		out1Mip_UINT4[blockID] = compressed;
//#endif // #else // #if LOW_MIP_ARRAY
//	}
//}
//
//
//// ------------------
//// end ported code
//// ------------------
//
//
//float2 IndexToUV( uint2 index )
//{
//	return index * g_oneOverTextureWidth + float2( g_oneOverTextureWidth / 2.0f, g_oneOverTextureWidth / 2.0f );
//}
//
//
//[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
//void cs_bilinear_downsample( uint2 id : SV_DispatchThreadID )
//{
//	float2 uv = IndexToUV ( id );
//	float4 outColor = inMipLevel.SampleLevel( linearMipClampSampler, uv, 0 );
//	outMipLevel[id] = outColor;
//}


// code for bc6 compression

static const float HALF_MAX = 65504.0f;
static const uint PATTERN_NUM = 32;

float CalcMSLE( float3 a, float3 b )
{
	float3 err = log2( ( b + 1.0f ) / ( a + 1.0f ) );;
	err = err * err;
	return err.x + err.y + err.z;
}

uint PatternFixupID( uint i )
{
	uint ret = 15;
	ret = ( ( 3441033216 >> i ) & 0x1 ) ? 2 : ret;
	ret = ( ( 845414400  >> i ) & 0x1 ) ? 8 : ret;
	return ret;
}

uint Pattern( uint p, uint i )
{
	uint p2 = p / 2;
	uint p3 = p - p2 * 2;

	uint enc = 0;
	enc = p2 == 0  ? 2290666700 : enc;
	enc = p2 == 1  ? 3972591342 : enc;
	enc = p2 == 2  ? 4276930688 : enc;
	enc = p2 == 3  ? 3967876808 : enc;
	enc = p2 == 4  ? 4293707776 : enc;
	enc = p2 == 5  ? 3892379264 : enc;
	enc = p2 == 6  ? 4278255592 : enc;
	enc = p2 == 7  ? 4026597360 : enc;
	enc = p2 == 8  ? 9369360    : enc;
	enc = p2 == 9  ? 147747072  : enc;
	enc = p2 == 10 ? 1930428556 : enc;
	enc = p2 == 11 ? 2362323200 : enc;
	enc = p2 == 12 ? 823134348  : enc;
	enc = p2 == 13 ? 913073766  : enc;
	enc = p2 == 14 ? 267393000  : enc;
	enc = p2 == 15 ? 966553998  : enc;

	enc = p3 ? enc >> 16 : enc;
	uint ret = ( enc >> i ) & 0x1;
	return ret;
}


float3 Quantize7( float3 x )
{
	return ( f32tof16( x ) * 128.0f ) / ( 0x7bff + 1.0f );
}

float3 Quantize9( float3 x )
{
	return ( f32tof16( x ) * 512.0f ) / ( 0x7bff + 1.0f );
}

float3 Quantize10( float3 x )
{
	return ( f32tof16( x ) * 1024.0f ) / ( 0x7bff + 1.0f );
}

float3 Unquantize7( float3 x )
{
	return ( x * 65536.0f + 0x8000 ) / 128.0f;
}

float3 Unquantize9( float3 x )
{
	return ( x * 65536.0f + 0x8000 ) / 512.0f;
}

float3 Unquantize10( float3 x )
{
	return ( x * 65536.0f + 0x8000 ) / 1024.0f;
}

float3 FinishUnquantize( float3 endpoint0Unq, float3 endpoint1Unq, float weight )
{
	float3 comp = ( endpoint0Unq * ( 64.0f - weight ) + endpoint1Unq * weight + 32.0f ) * ( 31.0f / 4096.0f );
	return f16tof32( uint3( comp ) );
}

void Swap( inout float3 a, inout float3 b )
{
	float3 tmp = a;
	a = b;
	b = tmp;
}

void Swap( inout float a, inout float b )
{
	float tmp = a;
	a = b;
	b = tmp;
}

uint ComputeIndex3( float texelPos, float endPoint0Pos, float endPoint1Pos )
{
	float r = ( texelPos - endPoint0Pos ) / ( endPoint1Pos - endPoint0Pos );
	return (uint) clamp( r * 6.98182f + 0.00909f + 0.5f, 0.0f, 7.0f );
}

uint ComputeIndex4( float texelPos, float endPoint0Pos, float endPoint1Pos )
{
	float r = ( texelPos - endPoint0Pos ) / ( endPoint1Pos - endPoint0Pos );
	return (uint) clamp( r * 14.93333f + 0.03333f + 0.5f, 0.0f, 15.0f );
}

void SignExtend( inout float3 v1, uint mask, uint signFlag )
{
	int3 v = (int3) v1;
	v.x = ( v.x & mask ) | ( v.x < 0 ? signFlag : 0 );
	v.y = ( v.y & mask ) | ( v.y < 0 ? signFlag : 0 );
	v.z = ( v.z & mask ) | ( v.z < 0 ? signFlag : 0 );
	v1 = v;
}

void EncodeP1( inout uint4 block, inout float blockMSLE, float3 texels[ 16 ] )
{
	// compute endpoints (min/max RGB bbox)
	float3 blockMin = texels[ 0 ];
	float3 blockMax = texels[ 0 ];
	uint i = 0;

	for ( i = 1; i < 16; ++i )
	{
		blockMin = min( blockMin, texels[ i ] );
		blockMax = max( blockMax, texels[ i ] );
	}


	// refine endpoints in log2 RGB space
	float3 refinedBlockMin = blockMax;
	float3 refinedBlockMax = blockMin;
	for ( i = 0; i < 16; ++i ) 
	{
		refinedBlockMin = min( refinedBlockMin, texels[ i ] == blockMin ? refinedBlockMin : texels[ i ] );
		refinedBlockMax = max( refinedBlockMax, texels[ i ] == blockMax ? refinedBlockMax : texels[ i ] );
	}

	float3 logBlockMax          = log2( blockMax + 1.0f );
	float3 logBlockMin          = log2( blockMin + 1.0f );
	float3 logRefinedBlockMax   = log2( refinedBlockMax + 1.0f );
	float3 logRefinedBlockMin   = log2( refinedBlockMin + 1.0f );
	float3 logBlockMaxExt       = ( logBlockMax - logBlockMin ) * ( 1.0f / 32.0f );
	logBlockMin += min( logRefinedBlockMin - logBlockMin, logBlockMaxExt );
	logBlockMax -= min( logBlockMax - logRefinedBlockMax, logBlockMaxExt );
	blockMin = exp2( logBlockMin ) - 1.0f;
	blockMax = exp2( logBlockMax ) - 1.0f;
	
	float3 blockDir = blockMax - blockMin;
	blockDir = blockDir / ( blockDir.x + blockDir.y + blockDir.z );

	float3 endpoint0    = Quantize10( blockMin );
	float3 endpoint1    = Quantize10( blockMax );
	float endPoint0Pos  = f32tof16( dot( blockMin, blockDir ) );
	float endPoint1Pos  = f32tof16( dot( blockMax, blockDir ) );


	// check if endpoint swap is required
	float fixupTexelPos = f32tof16( dot( texels[ 0 ], blockDir ) );
	uint fixupIndex = ComputeIndex4( fixupTexelPos, endPoint0Pos, endPoint1Pos );
	if ( fixupIndex > 7 )
	{
		Swap( endPoint0Pos, endPoint1Pos );
		Swap( endpoint0, endpoint1 );
	}

	// compute indices
	uint indices[ 16 ] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	for ( i = 0; i < 16; ++i )
	{
		float texelPos = f32tof16( dot( texels[ i ], blockDir ) );
		indices[ i ] = ComputeIndex4( texelPos, endPoint0Pos, endPoint1Pos );
	}

	// compute compression error (MSLE)
	float3 endpoint0Unq = Unquantize10( endpoint0 );
	float3 endpoint1Unq = Unquantize10( endpoint1 );
	float msle = 0.0f;
	for ( i = 0; i < 16; ++i )
	{
		float weight = floor( ( indices[ i ] * 64.0f ) / 15.0f + 0.5f );
		float3 texelUnc = FinishUnquantize( endpoint0Unq, endpoint1Unq, weight );

		msle += CalcMSLE( texels[ i ], texelUnc );
	}


	// encode block for mode 11
	blockMSLE = msle;
	block.x = 0x03;

	// endpoints
	block.x |= (uint) endpoint0.x << 5;
	block.x |= (uint) endpoint0.y << 15;
	block.x |= (uint) endpoint0.z << 25;
	block.y |= (uint) endpoint0.z >> 7;
	block.y |= (uint) endpoint1.x << 3;
	block.y |= (uint) endpoint1.y << 13;
	block.y |= (uint) endpoint1.z << 23;
	block.z |= (uint) endpoint1.z >> 9;

	// indices
	block.z |= indices[ 0 ] << 1;
	block.z |= indices[ 1 ] << 4;
	block.z |= indices[ 2 ] << 8;
	block.z |= indices[ 3 ] << 12;
	block.z |= indices[ 4 ] << 16;
	block.z |= indices[ 5 ] << 20;
	block.z |= indices[ 6 ] << 24;
	block.z |= indices[ 7 ] << 28;
	block.w |= indices[ 8 ] << 0;
	block.w |= indices[ 9 ] << 4;
	block.w |= indices[ 10 ] << 8;
	block.w |= indices[ 11 ] << 12;
	block.w |= indices[ 12 ] << 16;
	block.w |= indices[ 13 ] << 20;
	block.w |= indices[ 14 ] << 24;
	block.w |= indices[ 15 ] << 28;
}


void EncodeP2Pattern( inout uint4 block, inout float blockMSLE, int pattern, float3 texels[ 16 ] )
{
	float3 p0BlockMin = float3( HALF_MAX, HALF_MAX, HALF_MAX );
	float3 p0BlockMax = float3( 0.0f, 0.0f, 0.0f );
	float3 p1BlockMin = float3( HALF_MAX, HALF_MAX, HALF_MAX );
	float3 p1BlockMax = float3( 0.0f, 0.0f, 0.0f );
	uint i = 0;

	[loop] for ( i = 0; i < 16; ++i )
	{
		uint paletteID = Pattern( pattern, i );
		if ( paletteID == 0 )
		{
			p0BlockMin = min( p0BlockMin, texels[ i ] );
			p0BlockMax = max( p0BlockMax, texels[ i ] );
		}
		else
		{
			p1BlockMin = min( p1BlockMin, texels[ i ] );
			p1BlockMax = max( p1BlockMax, texels[ i ] );
		}
	}
	
	float3 p0BlockDir = p0BlockMax - p0BlockMin;
	float3 p1BlockDir = p1BlockMax - p1BlockMin;
	p0BlockDir = p0BlockDir / ( p0BlockDir.x + p0BlockDir.y + p0BlockDir.z );
	p1BlockDir = p1BlockDir / ( p1BlockDir.x + p1BlockDir.y + p1BlockDir.z );


	float p0Endpoint0Pos = f32tof16( dot( p0BlockMin, p0BlockDir ) );
	float p0Endpoint1Pos = f32tof16( dot( p0BlockMax, p0BlockDir ) );
	float p1Endpoint0Pos = f32tof16( dot( p1BlockMin, p1BlockDir ) );
	float p1Endpoint1Pos = f32tof16( dot( p1BlockMax, p1BlockDir ) );


	uint fixupID = PatternFixupID( pattern );
	float p0FixupTexelPos = f32tof16( dot( texels[ 0 ], p0BlockDir ) );
	float p1FixupTexelPos = f32tof16( dot( texels[ fixupID ], p1BlockDir ) );
	uint p0FixupIndex = ComputeIndex3( p0FixupTexelPos, p0Endpoint0Pos, p0Endpoint1Pos );
	uint p1FixupIndex = ComputeIndex3( p1FixupTexelPos, p1Endpoint0Pos, p1Endpoint1Pos );
	if ( p0FixupIndex > 3 )
	{
		Swap( p0Endpoint0Pos, p0Endpoint1Pos );
		Swap( p0BlockMin, p0BlockMax );
	}
	if ( p1FixupIndex > 3 )
	{
		Swap( p1Endpoint0Pos, p1Endpoint1Pos );
		Swap( p1BlockMin, p1BlockMax );
	}

	uint indices[ 16 ] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	[loop] for ( i = 0; i < 16; ++i )
	{
		float p0TexelPos = f32tof16( dot( texels[ i ], p0BlockDir ) );
		float p1TexelPos = f32tof16( dot( texels[ i ], p1BlockDir ) );
		uint p0Index = ComputeIndex3( p0TexelPos, p0Endpoint0Pos, p0Endpoint1Pos );
		uint p1Index = ComputeIndex3( p1TexelPos, p1Endpoint0Pos, p1Endpoint1Pos );

		uint paletteID = Pattern( pattern, i );
		indices[ i ] = paletteID == 0 ? p0Index : p1Index;
	}

	float3 endpoint760 = floor( Quantize7( p0BlockMin ) );
	float3 endpoint761 = floor( Quantize7( p0BlockMax ) );
	float3 endpoint762 = floor( Quantize7( p1BlockMin ) );
	float3 endpoint763 = floor( Quantize7( p1BlockMax ) );

	float3 endpoint950 = floor( Quantize9( p0BlockMin ) );
	float3 endpoint951 = floor( Quantize9( p0BlockMax ) );
	float3 endpoint952 = floor( Quantize9( p1BlockMin ) );
	float3 endpoint953 = floor( Quantize9( p1BlockMax ) );

	endpoint761 = endpoint761 - endpoint760;
	endpoint762 = endpoint762 - endpoint760;
	endpoint763 = endpoint763 - endpoint760;

	endpoint951 = endpoint951 - endpoint950;
	endpoint952 = endpoint952 - endpoint950;
	endpoint953 = endpoint953 - endpoint950;

	int maxVal76 = 0x1F;
	endpoint761 = clamp( endpoint761, -maxVal76, maxVal76 );
	endpoint762 = clamp( endpoint762, -maxVal76, maxVal76 );
	endpoint763 = clamp( endpoint763, -maxVal76, maxVal76 );

	int maxVal95 = 0xF;
	endpoint951 = clamp( endpoint951, -maxVal95, maxVal95 );
	endpoint952 = clamp( endpoint952, -maxVal95, maxVal95 );
	endpoint953 = clamp( endpoint953, -maxVal95, maxVal95 );

	float3 endpoint760Unq = Unquantize7( endpoint760 );
	float3 endpoint761Unq = Unquantize7( endpoint760 + endpoint761 );
	float3 endpoint762Unq = Unquantize7( endpoint760 + endpoint762 );
	float3 endpoint763Unq = Unquantize7( endpoint760 + endpoint763 );
	float3 endpoint950Unq = Unquantize9( endpoint950 );
	float3 endpoint951Unq = Unquantize9( endpoint950 + endpoint951 );
	float3 endpoint952Unq = Unquantize9( endpoint950 + endpoint952 );
	float3 endpoint953Unq = Unquantize9( endpoint950 + endpoint953 );

	float msle76 = 0.0f;
	float msle95 = 0.0f;
	[loop] for ( i = 0; i < 16; ++i )
	{
		uint paletteID = Pattern( pattern, i );

		float3 tmp760Unq = paletteID == 0 ? endpoint760Unq : endpoint762Unq;
		float3 tmp761Unq = paletteID == 0 ? endpoint761Unq : endpoint763Unq;
		float3 tmp950Unq = paletteID == 0 ? endpoint950Unq : endpoint952Unq;
		float3 tmp951Unq = paletteID == 0 ? endpoint951Unq : endpoint953Unq;

		float weight = floor( ( indices[ i ] * 64.0f ) / 7.0f + 0.5f );
		float3 texelUnc76 = FinishUnquantize( tmp760Unq, tmp761Unq, weight );
		float3 texelUnc95 = FinishUnquantize( tmp950Unq, tmp951Unq, weight );

		msle76 += CalcMSLE( texels[ i ], texelUnc76 );
		msle95 += CalcMSLE( texels[ i ], texelUnc95 );
	}

	SignExtend( endpoint761, 0x1F, 0x20 );
	SignExtend( endpoint762, 0x1F, 0x20 );
	SignExtend( endpoint763, 0x1F, 0x20 );

	SignExtend( endpoint951, 0xF, 0x10 );
	SignExtend( endpoint952, 0xF, 0x10 );
	SignExtend( endpoint953, 0xF, 0x10 );

	// encode block
	float p2MSLE = min( msle76, msle95 );
	if ( p2MSLE < blockMSLE )
	{
		blockMSLE   = p2MSLE;
		block       = uint4( 0, 0, 0, 0 );

		if ( p2MSLE == msle76 )
		{
			// 7.6
			block.x = 0x1;
			block.x |= ( (uint) endpoint762.y & 0x20 ) >> 3;
			block.x |= ( (uint) endpoint763.y & 0x10 ) >> 1;
			block.x |= ( (uint) endpoint763.y & 0x20 ) >> 1;
			block.x |= (uint) endpoint760.x << 5;
			block.x |= ( (uint) endpoint763.z & 0x01 ) << 12;
			block.x |= ( (uint) endpoint763.z & 0x02 ) << 12;
			block.x |= ( (uint) endpoint762.z & 0x10 ) << 10;
			block.x |= (uint) endpoint760.y << 15;
			block.x |= ( (uint) endpoint762.z & 0x20 ) << 17;
			block.x |= ( (uint) endpoint763.z & 0x04 ) << 21;
			block.x |= ( (uint) endpoint762.y & 0x10 ) << 20;
			block.x |= (uint) endpoint760.z << 25;
			block.y |= ( (uint) endpoint763.z & 0x08 ) >> 3;
			block.y |= ( (uint) endpoint763.z & 0x20 ) >> 4;
			block.y |= ( (uint) endpoint763.z & 0x10 ) >> 2;
			block.y |= (uint) endpoint761.x << 3;
			block.y |= ( (uint) endpoint762.y & 0x0F ) << 9;
			block.y |= (uint) endpoint761.y << 13;
			block.y |= ( (uint) endpoint763.y & 0x0F ) << 19;
			block.y |= (uint) endpoint761.z << 23;
			block.y |= ( (uint) endpoint762.z & 0x07 ) << 29;
			block.z |= ( (uint) endpoint762.z & 0x08 ) >> 3;
			block.z |= (uint) endpoint762.x << 1;
			block.z |= (uint) endpoint763.x << 7;
		}
		else
		{
			// 9.5
			block.x = 0xE;
			block.x |= (uint) endpoint950.x << 5;
			block.x |= ( (uint) endpoint952.z & 0x10 ) << 10;
			block.x |= (uint) endpoint950.y << 15;
			block.x |= ( (uint) endpoint952.y & 0x10 ) << 20;
			block.x |= (uint) endpoint950.z << 25;
			block.y |= (uint) endpoint950.z >> 7;
			block.y |= ( (uint) endpoint953.z & 0x10 ) >> 2;
			block.y |= (uint) endpoint951.x << 3;
			block.y |= ( (uint) endpoint953.y & 0x10 ) << 4;
			block.y |= ( (uint) endpoint952.y & 0x0F ) << 9;
			block.y |= (uint) endpoint951.y << 13;
			block.y |= ( (uint) endpoint953.z & 0x01 ) << 18;
			block.y |= ( (uint) endpoint953.y & 0x0F ) << 19;
			block.y |= (uint) endpoint951.z << 23;
			block.y |= ( (uint) endpoint953.z & 0x02 ) << 27;
			block.y |= (uint) endpoint952.z << 29;
			block.z |= ( (uint) endpoint952.z & 0x08 ) >> 3;
			block.z |= (uint) endpoint952.x << 1;
			block.z |= ( (uint) endpoint953.z & 0x04 ) << 4;
			block.z |= (uint) endpoint953.x << 7;
			block.z |= ( (uint) endpoint953.z & 0x08 ) << 9;
		}

		block.z |= pattern << 13;
		uint blockFixupID = PatternFixupID( pattern );
		if ( blockFixupID == 15 )
		{
			block.z |= indices[ 0 ] << 18;
			block.z |= indices[ 1 ] << 20;
			block.z |= indices[ 2 ] << 23;
			block.z |= indices[ 3 ] << 26;
			block.z |= indices[ 4 ] << 29;
			block.w |= indices[ 5 ] << 0;
			block.w |= indices[ 6 ] << 3;
			block.w |= indices[ 7 ] << 6;
			block.w |= indices[ 8 ] << 9;
			block.w |= indices[ 9 ] << 12;
			block.w |= indices[ 10 ] << 15;
			block.w |= indices[ 11 ] << 18;
			block.w |= indices[ 12 ] << 21;
			block.w |= indices[ 13 ] << 24;
			block.w |= indices[ 14 ] << 27;
			block.w |= indices[ 15 ] << 30;
		}
		else if ( blockFixupID == 2 )
		{
			block.z |= indices[ 0 ] << 18;
			block.z |= indices[ 1 ] << 20;
			block.z |= indices[ 2 ] << 23;
			block.z |= indices[ 3 ] << 25;
			block.z |= indices[ 4 ] << 28;
			block.z |= indices[ 5 ] << 31;
			block.w |= indices[ 5 ] >> 1;
			block.w |= indices[ 6 ] << 2;
			block.w |= indices[ 7 ] << 5;
			block.w |= indices[ 8 ] << 8;
			block.w |= indices[ 9 ] << 11;
			block.w |= indices[ 10 ] << 14;
			block.w |= indices[ 11 ] << 17;
			block.w |= indices[ 12 ] << 20;
			block.w |= indices[ 13 ] << 23;
			block.w |= indices[ 14 ] << 26;
			block.w |= indices[ 15 ] << 29;
		}
		else
		{
			block.z |= indices[ 0 ] << 18;
			block.z |= indices[ 1 ] << 20;
			block.z |= indices[ 2 ] << 23;
			block.z |= indices[ 3 ] << 26;
			block.z |= indices[ 4 ] << 29;
			block.w |= indices[ 5 ] << 0;
			block.w |= indices[ 6 ] << 3;
			block.w |= indices[ 7 ] << 6;
			block.w |= indices[ 8 ] << 9;
			block.w |= indices[ 9 ] << 11;
			block.w |= indices[ 10 ] << 14;
			block.w |= indices[ 11 ] << 17;
			block.w |= indices[ 12 ] << 20;
			block.w |= indices[ 13 ] << 23;
			block.w |= indices[ 14 ] << 26;
			block.w |= indices[ 15 ] << 29;
		}
	}
}


//[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
//void cs_bc6_compress( uint2 id : SV_DispatchThreadID )
//{
//	// gather texels for current 4x4 block
//	// 0 1 2 3
//	// 4 5 6 7
//	// 8 9 10 11
//	// 12 13 14 15
//	float2 uv		= id.xy * g_oneOverTextureWidth.xx * 4.0f - g_oneOverTextureWidth.xx;
//	float2 block0UV	= uv;
//	float2 block1UV	= uv + float2( 2.0f * g_oneOverTextureWidth, 0.0f );
//	float2 block2UV	= uv + float2( 0.0f, 2.0f * g_oneOverTextureWidth );
//	float2 block3UV	= uv + float2( 2.0f * g_oneOverTextureWidth, 2.0f * g_oneOverTextureWidth );
//	float4 block0X	= inMipLevel.GatherRed( pointMipClampSampler, block0UV );
//	float4 block1X	= inMipLevel.GatherRed( pointMipClampSampler, block1UV );
//	float4 block2X	= inMipLevel.GatherRed( pointMipClampSampler, block2UV );
//	float4 block3X	= inMipLevel.GatherRed( pointMipClampSampler, block3UV );
//	float4 block0Y	= inMipLevel.GatherGreen( pointMipClampSampler, block0UV );
//	float4 block1Y	= inMipLevel.GatherGreen( pointMipClampSampler, block1UV );
//	float4 block2Y	= inMipLevel.GatherGreen( pointMipClampSampler, block2UV );
//	float4 block3Y	= inMipLevel.GatherGreen( pointMipClampSampler, block3UV );
//	float4 block0Z	= inMipLevel.GatherBlue( pointMipClampSampler, block0UV );
//	float4 block1Z	= inMipLevel.GatherBlue( pointMipClampSampler, block1UV );
//	float4 block2Z	= inMipLevel.GatherBlue( pointMipClampSampler, block2UV );
//	float4 block3Z	= inMipLevel.GatherBlue( pointMipClampSampler, block3UV );
//					  
//	float3 texels[ 16 ];
//	texels[ 0 ]		= float3( block0X.w, block0Y.w, block0Z.w );
//	texels[ 1 ]		= float3( block0X.z, block0Y.z, block0Z.z );
//	texels[ 2 ]		= float3( block1X.w, block1Y.w, block1Z.w );
//	texels[ 3 ]		= float3( block1X.z, block1Y.z, block1Z.z );
//	texels[ 4 ]		= float3( block0X.x, block0Y.x, block0Z.x );
//	texels[ 5 ]		= float3( block0X.y, block0Y.y, block0Z.y );
//	texels[ 6 ]		= float3( block1X.x, block1Y.x, block1Z.x );
//	texels[ 7 ]		= float3( block1X.y, block1Y.y, block1Z.y );
//	texels[ 8 ]		= float3( block2X.w, block2Y.w, block2Z.w );
//	texels[ 9 ]		= float3( block2X.z, block2Y.z, block2Z.z );
//	texels[ 10 ]	= float3( block3X.w, block3Y.w, block3Z.w );
//	texels[ 11 ]	= float3( block3X.z, block3Y.z, block3Z.z );
//	texels[ 12 ]	= float3( block2X.x, block2Y.x, block2Z.x );
//	texels[ 13 ]	= float3( block2X.y, block2Y.y, block2Z.y );
//	texels[ 14 ]	= float3( block3X.x, block3Y.x, block3Z.x );
//	texels[ 15 ]	= float3( block3X.y, block3Y.y, block3Z.y );
//
//	uint4 block     = uint4( 0, 0, 0, 0 );
//
//	float blockMSLE = 0.0f;
//
//	EncodeP1( block, blockMSLE, texels );
//
//	#ifdef QUALITY // check out https://github.com/knarkowicz/GPURealTimeBC6H for more details on this switch.
//	for ( uint blockIndex = 0; blockIndex < 32; ++blockIndex )
//	{
//		EncodeP2Pattern( block, blockMSLE, blockIndex, texels );
//	}
//	#endif
//
//	outArrayMipLevel_UINT4[uint3(id, arraySlice)] = block;
//}


void cs_bc6_compress_array_common( uint3 id, const bool highQuality )
{
	// gather texels for current 4x4 block
	// 0 1 2 3
	// 4 5 6 7
	// 8 9 10 11
	// 12 13 14 15

	uint3 baseIndex = id * uint3(4, 4, 1);

	float3 texels[ 16 ];
	texels[ 0 ]		= inArrayMipLevel[ baseIndex + uint3( 0, 0, 0 ) ].rgb;
	texels[ 1 ]		= inArrayMipLevel[ baseIndex + uint3( 1, 0, 0 ) ].rgb;
	texels[ 2 ]		= inArrayMipLevel[ baseIndex + uint3( 2, 0, 0 ) ].rgb;
	texels[ 3 ]		= inArrayMipLevel[ baseIndex + uint3( 3, 0, 0 ) ].rgb;
	texels[ 4 ]		= inArrayMipLevel[ baseIndex + uint3( 0, 1, 0 ) ].rgb;
	texels[ 5 ]		= inArrayMipLevel[ baseIndex + uint3( 1, 1, 0 ) ].rgb;
	texels[ 6 ]		= inArrayMipLevel[ baseIndex + uint3( 2, 1, 0 ) ].rgb;
	texels[ 7 ]		= inArrayMipLevel[ baseIndex + uint3( 3, 1, 0 ) ].rgb;
	texels[ 8 ]		= inArrayMipLevel[ baseIndex + uint3( 0, 2, 0 ) ].rgb;
	texels[ 9 ]		= inArrayMipLevel[ baseIndex + uint3( 1, 2, 0 ) ].rgb;
	texels[ 10 ]	= inArrayMipLevel[ baseIndex + uint3( 2, 2, 0 ) ].rgb;
	texels[ 11 ]	= inArrayMipLevel[ baseIndex + uint3( 3, 2, 0 ) ].rgb;
	texels[ 12 ]	= inArrayMipLevel[ baseIndex + uint3( 0, 3, 0 ) ].rgb;
	texels[ 13 ]	= inArrayMipLevel[ baseIndex + uint3( 1, 3, 0 ) ].rgb;
	texels[ 14 ]	= inArrayMipLevel[ baseIndex + uint3( 2, 3, 0 ) ].rgb;
	texels[ 15 ]	= inArrayMipLevel[ baseIndex + uint3( 3, 3, 0 ) ].rgb;

	uint4 block     = uint4( 0, 0, 0, 0 );

	float blockMSLE = 0.0f;

	EncodeP1( block, blockMSLE, texels );
	
	// check out https://github.com/knarkowicz/GPURealTimeBC6H for more details on this switch.
	
	if ( highQuality )
	{
		[loop] for ( uint blockIndex = 0; blockIndex < 32; ++blockIndex )
		{
			EncodeP2Pattern( block, blockMSLE, blockIndex, texels );
		}
	}

	outArrayMipLevel_UINT4[id] = block;	
}

[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
void cs_bc6_compress_array( uint3 id : SV_DispatchThreadID )
{
	cs_bc6_compress_array_common( id, false );
}


[ numthreads( COMPRESS_ONE_MIP_THREADGROUP_WIDTH, COMPRESS_ONE_MIP_THREADGROUP_WIDTH, 1 ) ]
void cs_bc6_compress_array_hq( uint3 id : SV_DispatchThreadID )
{
	cs_bc6_compress_array_common( id, true );
}

//
//// https://docs.microsoft.com/en-us/windows/desktop/direct3d11/bc7-format-mode-reference
//uint4 EncodeConstantColorBC7Mode5( float4 color )
//{
//	uint4 res = 0;
//
//	// mode 5
//	uint mode = 0x20;
//	uint rotation = 0;
//
//	uint r = ( uint )( color.r * 127 );
//	uint g = ( uint )( color.g * 127 );
//	uint b = ( uint )( color.b * 127 );
//	uint a = ( uint )( color.a * 255 );
//
//	uint idxColor = 0;
//	uint idxAlpha = 0;
//
//	uint w0 = mode;
//	// 6
//	w0 |= rotation << 6;
//	// 8
//	w0 |= r << ( 6 + 2 );
//	// 15
//	w0 |= r << ( 6 + 2 + 7 );
//	// 22
//	w0 |= g << ( 6 + 2 + 7 + 7 );
//	// 29
//	w0 |= ( g & 0x7 ) << ( 6 + 2 + 7 + 7 + 7 );
//	// 32
//
//	uint w1 = g >> 3;
//	// 4
//	w1 |= b << 4;
//	// 11
//	w1 |= b << ( 4 + 7 );
//	// 18
//	w1 |= a << ( 4 + 7 + 7 );
//	// 26
//	w1 |= ( a & 0x3f ) << ( 4 + 7 + 7 + 8 );
//	// 32
//
//	uint w2 = a >> 6;
//	// 2
//	w2 |= ( idxColor & 0x3fffffff ) << 2;
//
//	uint w3 = idxColor >> 30;
//	// 1
//	w3 |= ( idxAlpha & 0x3fffffff ) << 1;
//
//	res.x = w0;
//	res.y = w1;
//	res.z = w2;
//	res.w = w3;
//
//	return res;
//}


//[numthreads( 8, 8, 1 )]
//void cs_bc7_compress_constant_color( uint3 position : SV_DispatchThreadID )
//{
//	if ( all( position.xy < outputSize ) )
//	{
//		float4 inColor = inUncompressedTexture.Load( int3( 0, 0, 0 ) );
//		float4 outColor;
//		outColor.rgb = (outputAsSRGB != 0) ? sRGBLinearToGamma( inColor.rgb ) : inColor.rgb;
//		outColor.a = inColor.a;
//		
//		uint4 block = EncodeConstantColorBC7Mode5( outColor );
//		out1MipConstantColor_UINT4[position.xy] = block;
//	}
//}
//#endif // #ifndef __CS_RUNTIME_COMPRESSION_HLSL__
