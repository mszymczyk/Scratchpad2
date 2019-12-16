#include <Core/AppBase/AppBase.h>
#include <Core/Gfx/Mesh/Model.h>
//#include <Shaders/hlsl/PassConstants.h>
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

		void RecreateTexture();
		void ShutDown();
		void UpdateCamera( const Timer& timer );
		void KeyPressed( uint key, bool shift, bool alt, bool ctrl ) override;
		void MousePressed( uint mouseX, uint mouseY ) override;
		void UpdateAndRender( const Timer& timer ) override;
		void UpdateImGui( const Timer& timer ) override;

		ID3D11ShaderResourceView *GetOctahedronSRV() const
		{
			if ( enableCompression_ )
				return octahedronCompressedTex_.srv_;
			else
				return octahedronTex_.srv_;
		}
		
		ID3D11ShaderResourceView *GetDualParaboloidSRV() const
		{
			if ( enableCompression_ )
				return dualParaboloidCompressedTex_.srv_;
			else
				return dualParaboloidTex_.srv_;
		}

		FpsCounter fpsCounter_;
		RenderTarget2D mainRT_ = RenderTarget2D( "mainRT_" );
		DepthStencil mainDS_ = DepthStencil( "mainDS_" );

		HlslShaderPtr shader_;
		HlslShaderPtr compressionShader_;
		ID3D11ShaderResourceViewPtr srcCubeMapSrv_;
		ID3D11ShaderResourceViewPtr srcCubeMapUnfilteredSrv_;
		//ConstantBuffer<CbPassConstants> passConstants_;
		//ConstantBuffer<CbObjectConstants> objectConstants_;
		ConstantBuffer<CbOctahedronConstants> octahedronConstants_;
		//ConstantBuffer<CbOctahedronGenConstants> octahedronGenConstants_;
		ConstantBuffer<ConstantBufferRuntimeCompression> compressionConstants_;	

		//ID3D11Texture2D* tex_ = nullptr;
		//ID3D11ShaderResourceView* texSrv_ = nullptr;
		//ID3D11UnorderedAccessView* texUav_ = nullptr;
		CodeTexture octahedronTex_ = CodeTexture( "octahedronTex_" );
		CodeTexture cubeMapTex_ = CodeTexture( "cubeMapTex_" );
		CodeTexture dualParaboloidTex_ = CodeTexture( "dualParaboloidTex_" );
		CodeTexture octahedronCompressedTex_ = CodeTexture( "octahedronCompressedTex_" );
		CodeTexture octahedronCompressTempTex_ = CodeTexture( "octahedronCompressTempTex_" );
		CodeTexture dualParaboloidCompressedTex_ = CodeTexture( "dualParaboloidCompressedTex_" );
		CodeTexture dualParaboloidCompressTempTex_ = CodeTexture( "dualParaboloidCompressTempTex_" );
		StructuredBuffer<float4> pickBuffer_;

		std::vector<ID3D11ShaderResourceView*> srvMipsSrcCubeMapUnfilteredAsArray_;
		//std::vector<ID3D11UnorderedAccessView*> uavMipsSrcCubeMapUnfilteredAsArray_;
		std::vector<ID3D11ShaderResourceView*> srvMipsCubeMapAsArray_;
		std::vector<ID3D11UnorderedAccessView*> uavMipsCubeMapAsArray_;

		Matrix4 viewMatrixForCamera_;
		Matrix4 projMatrixForCamera_;
		Vector3 cameraDistance_;

		enum Parametrization : int
		{
			Parametrization_Octahedron,
			Parametrization_DualParaboloid,
			Parametrization_Count
		};

		enum DisplayMode : int
		{
			//OctahedronFacesTexture,
			//OctahedronNormalTexture,
			//SphereNormal,
			//SphereNormalOctahedron,
			//SphereFacesOctahedron,
			//SceneCubemap,
			//SceneOctahedron,
			DisplayMode_Faces,
			DisplayMode_Normal,
			DisplayMode_Scene,
			DisplayMode_Count
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

		enum OctahedronSeamMode : int
		{
			OctahedronSeam_None,
			OctahedronSeam_Wideborder,
			OctahedronSeam_Thinborder,
			OctahedronSeam_PullFixup,
			OctahedronSeam_Count
		};

		enum SolidAngle : int
		{
			SolidAngle_None,
			SolidAngle_CubeMap,
			SolidAngle_Octahedron,
			SolidAngle_Diff,
			SolidAngle_Count
		};

		enum SamplerType : int
		{
			Sampler_Linear,
			Sampler_Point,
			Sampler_Bicubic,
			Sampler_Count
		};

		//DisplayMode displayMode_ = SphereNormalOctahedron;
		Parametrization parametrization_ = Parametrization_Octahedron;
		DisplayMode displayMode_ = DisplayMode_Scene;
		OctahedronSeamMode octahedronSeamMode_ = OctahedronSeam_Wideborder;
		bool displayOctahedron_ = true;
		bool importanceSample_ = false;
		bool importanceSampleBoxFilter_ = false;
		bool octahedronOverlay_ = false;
		bool enableCompression_ = false;
		SamplerType samplerType_ = Sampler_Linear;
		TextureSize textureSize_ = TextureSize_256;
		float sampleMipLevel_ = 2.0f;
		int sampleMipLevelInt_ = 2;
		int borderWidth_ = 32;
		SolidAngle solidAngle_ = SolidAngle_None;
		int solidAngleScale_ = 1;

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

