#include <Core/AppBase/AppBase.h>
#include <Core/Gfx/Mesh/Model.h>
#include <shaders/hlsl/PassConstants.h>
#include <shaders/hlsl/skinning_cshared.h>
#include <Core/Gfx/Camera.h>
#include <Core/Gfx/Text/TextRenderer.h>
#include <Core\Gfx\Dx11\Dx11Shader.h>
#include "DirectDeltaMushSkinningPrecompute.h"

namespace spad
{

	struct DDMMesh
	{
		struct Graph
		{
			std::vector<std::string> nodes;
			std::vector<int> parents;
			Matrix4Vector origPoses;
			Matrix4Vector localPoses;
			Matrix4Vector globalPoses;
		};

		struct Bone
		{
			Matrix4 bindMatrix;
			std::string name;
			uint graphNodeIndex;
		};

		struct BoneAnimation
		{
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
		std::vector<BaseVertexPrecompute> verticesPrecompute;
		std::vector<uint> verticesPrecomputeMap;
		std::vector<uint> indicesPrecompute;

		Graph graph;
		std::vector<Bone, stdutil::aligned_allocator<Bone, alignof( Bone )>> bones;
		std::vector<Animation, stdutil::aligned_allocator<Animation, alignof( Bone )>> animations;

		ID3D11BufferPtr indexBuffer;
		StructuredBuffer<BaseVertex> baseVerticesBuffer;

		OmegaRefVector omegaRefs;
		Matrix4Vector omegas;
		std::vector<uint> transformIndices;

		StructuredBuffer<OmegaRef> omegaRefsBuffer;
		StructuredBuffer<Matrix4> omegasBuffer;
		StructuredBuffer<uint> transformIndicesBuffer;

		StructuredBuffer<SkinnedVertex> skinnedVerticesBuffer;
		StructuredBuffer<Matrix4> bonesBuffer;
		Matrix4Vector bonesScratch;
		std::vector<SkinnedVertex> skinnedVerticesScratch;

		std::vector<DebugOutput> debugOutputScratch;
		StructuredBuffer<DebugOutput> debugOutputBuffer;
		StructuredBuffer<float3x3> svdBuffer;
	};


	class DirectDeltaMushSkinning : public AppBase
	{
	public:
		~DirectDeltaMushSkinning()
		{
			ShutDown();
		}

		bool StartUp();

	protected:
		void ShutDown();
		void UpdateCamera( const Timer& timer );
		void UpdateAndRender( const Timer& timer ) override;
		void KeyPressed( uint key, bool shift, bool alt, bool ctrl ) override;

		void SkinMesh( DDMMesh &mesh, const Timer& timer );
		void DrawMesh( DDMMesh &mesh );

		void LoadModelsWithAssimp( ID3D11Device* device, const char* fileName );
		void PrecomputeDDM( ID3D11Device* device, DDMMesh &mesh );

		RenderTarget2D mainRT_ = RenderTarget2D( "mainRT_" );
		HlslShaderPtr shader_;

		ConstantBuffer<CbPassConstants> passConstants_;
		ConstantBuffer<CbObjectConstants> objectConstants_;
		ConstantBuffer<CbSkinningConstants> skinningConstants_;

		Matrix4 viewMatrixForCamera_;
		Matrix4 projMatrixForCamera_;

		std::vector<DDMMesh> meshes;
		float animTime_ = 0;
	};
}

