#ifndef DIRECTDELTAMUSHSKINNINGPRECOMPUTE_H
#define DIRECTDELTAMUSHSKINNINGPRECOMPUTE_H

#pragma once

#include <shaders/hlsl/skinning_cshared.h>
#include <Util\StdHelp.h>

namespace spad
{
	struct DDMMesh
	{
		struct Graph
		{
			std::vector<std::string> nodes;
			std::vector<int> parents;
			std::vector<Matrix4, stdutil::aligned_allocator<Matrix4, alignof( Matrix4 )>> origPoses;
			std::vector<Matrix4, stdutil::aligned_allocator<Matrix4, alignof( Matrix4 )>> localPoses;
			std::vector<Matrix4, stdutil::aligned_allocator<Matrix4, alignof( Matrix4 )>> globalPoses;
		};

		struct Bone
		{
			Matrix4 bindMatrix;
			std::string name;
			uint graphNodeIndex;
		};

		struct BoneAnimation
		{
			//uint boneIndex;
			uint graphNodeIndex;
			std::vector<Vector4, stdutil::aligned_allocator<Vector4, alignof( Vector4 )>> translateKeys;
			std::vector<Quat, stdutil::aligned_allocator<Quat, alignof( Quat )>> rotateKeys;
			std::vector<float> rotateKeyTimes;
		};

		struct Animation
		{
			float durationSeconds;
			std::vector<BoneAnimation> boneAnims;
		};

		std::vector<uint> indices;
		std::vector<BaseVertex> vertices;

		Graph graph;
		std::vector<Bone, stdutil::aligned_allocator<Bone, alignof( Bone )>> bones;

		std::vector<Animation, stdutil::aligned_allocator<Animation, alignof( Bone )>> animations;

		std::vector<Matrix4, stdutil::aligned_allocator<Matrix4, alignof( Matrix4 )>> bonesScratch;

		//ID3D11BufferPtr vertexBuffer;
		ID3D11BufferPtr indexBuffer;
		StructuredBuffer<BaseVertex> baseVertices;
		StructuredBuffer<SkinnedVertex> skinnedVertices;
		StructuredBuffer<Matrix4> bonesBuffer;
		//std::vector<D3D11_INPUT_ELEMENT_DESC> inputElements;
		//uint32_t inputElementsHash;
	};

	void PrecomputeDDM( DDMMesh &mesh );
}

#endif // DIRECTDELTAMUSHSKINNINGPRECOMPUTE_H