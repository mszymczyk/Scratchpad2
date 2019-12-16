#include <Core/AppBase/AppBase.h>
#include <Core/Gfx/Mesh/Model.h>
#include <Shaders/hlsl/octahedron_cshared.h>
#include <Shaders/hlsl/block_compression_cshared.hlsl>
#include <Core/Gfx/Camera.h>
#include <Core\Gfx\Dx11\Dx11Shader.h>

namespace spad
{
	class SettingsTestApp : public AppBase
	{
	public:
		~SettingsTestApp()
		{
			ShutDown();
		}

		bool StartUp();

	protected:

		void ShutDown();
		void UpdateCamera( const Timer& timer );
		void KeyPressed( uint key, bool shift, bool alt, bool ctrl ) override;
		void MousePressed( uint mouseX, uint mouseY ) override;
		void UpdateAndRender( const Timer& timer ) override;
		void UpdateImGui( const Timer& timer ) override;
		
		FpsCounter fpsCounter_;
		RenderTarget2D mainRT_ = RenderTarget2D( "mainRT_" );
		DepthStencil mainDS_ = DepthStencil( "mainDS_" );

		Matrix4 viewMatrixForCamera_;
		Matrix4 projMatrixForCamera_;
		Vector3 cameraDistance_;

		HlslShaderPtr shader_;
		ConstantBuffer<CbOctahedronConstants> octahedronConstants_;

		enum SamplerType : int
		{
			Sampler_Linear,
			Sampler_Point,
			Sampler_Bicubic,
			Sampler_Count
		};

		//bool enableCompression_ = false;
		//SamplerType samplerType_ = Sampler_Linear;
	};
}

