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
		void PrecomputeDDM( DDMMesh &mesh );

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

