#include <Core/AppBase/AppBase.h>
#include <Core/Gfx/Mesh/Model.h>
//#include <Shaders/hlsl/PassConstants.h>
#include <Shaders/hlsl/octahedron_cshared.h>
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

		void RecreateTexture();
		void ShutDown();
		void UpdateCamera( const Timer& timer );
		void KeyPressed( uint key, bool shift, bool alt, bool ctrl ) override;
		void MousePressed( uint mouseX, uint mouseY ) override;
		void UpdateAndRender( const Timer& timer ) override;
		void UpdateImGui( const Timer& timer ) override;

		FpsCounter fpsCounter_;
		RenderTarget2D mainRT_ = RenderTarget2D( "mainRT_" );
		DepthStencil mainDS_ = DepthStencil( "mainDS_" );

		HlslShaderPtr shader_;
		ID3D11ShaderResourceViewPtr cubeMapSrv_;
		//ConstantBuffer<CbPassConstants> passConstants_;
		//ConstantBuffer<CbObjectConstants> objectConstants_;
		ConstantBuffer<CbOctahedronConstants> octahedronConstants_;
		//ConstantBuffer<CbOctahedronGenConstants> octahedronGenConstants_;

		//ID3D11Texture2D* tex_ = nullptr;
		//ID3D11ShaderResourceView* texSrv_ = nullptr;
		//ID3D11UnorderedAccessView* texUav_ = nullptr;
		CodeTexture octahedronTex_ = CodeTexture( "octahedronTex_" );
		StructuredBuffer<float4> pickBuffer_;

		Matrix4 viewMatrixForCamera_;
		Matrix4 projMatrixForCamera_;
		Vector3 cameraDistance_;

		enum DisplayMode : int
		{
			//OctahedronFacesTexture,
			//OctahedronNormalTexture,
			SphereNormal,
			SphereNormalOctahedron,
			SphereFacesOctahedron,
			SceneCubemap,
			SceneOctahedron,
			DisplayModeCount
		};

		enum TextureSize : int
		{
			TextureSize_16,
			TextureSize_32,
			TextureSize_64,
			TextureSize_128,
			TextureSize_256,
			TextureSize_512,
			TextureSize_Count
		};

		DisplayMode displayMode_ = SphereNormalOctahedron;
		bool octahedronOverlay_ = false;
		TextureSize textureSize_ = TextureSize_16;
		float sampleMipLevel_ = 2.0f;
		int borderWidth_ = 0;

		int mousePixelPosX_ = 0;
		int mousePixelPosY_ = 0;

		bool pickColor_ = false;
		uint pickColorIndex_ = 0;

		struct ColorPick
		{
			float r, g, b, a;
			int pixelX;
			int pixelY;
		};

		static constexpr uint NumColorPick = 4;
		ColorPick colorPickQueue[NumColorPick];
	};
}

