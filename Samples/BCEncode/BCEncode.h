#include <Core/AppBase/AppBase.h>
#include <Core/Gfx/Mesh/Model.h>
#include <shaders/hlsl/PassConstants.h>
#include <Core/Gfx/Camera.h>
#include <Core/Gfx/Text/TextRenderer.h>
#include <Core\Gfx\Dx11\Dx11Shader.h>

namespace spad
{
	class BCEncode : public AppBase
	{
	public:
		~BCEncode()
		{
			ShutDown();
		}

		bool StartUp();

	protected:
		void ShutDown();
		void UpdateAndRender( const Timer& timer ) override;

		RenderTarget2D mainRT_ = RenderTarget2D( "mainRT_" );
		HlslShaderPtr shader_;

		ID3D11Texture2D* texture_ = nullptr;
		ID3D11ShaderResourceView* srv_ = nullptr;

		ID3D11Texture2D* tmpBC7_ = nullptr;
		ID3D11ShaderResourceView* tmpBC7SRV_ = nullptr;
		ID3D11UnorderedAccessView* tmpBC7UAV_ = nullptr;
	};
}

