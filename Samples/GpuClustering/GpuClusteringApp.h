#include <Core/AppBase/AppBase.h>
#include <Core/Gfx/Mesh/Model.h>
#include <Shaders/hlsl/PassConstants.h>
//#include <Shaders/hlsl/MeshConstants.h>
//#include <Shaders/hlsl/gpuClusteringConstants.h>
#include <Shaders/hlsl/cs_decal_volume_cshared.hlsl>
#include <Shaders/hlsl/decal_volume_rendering_cshared.h>
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

		// config
		enum IntersectionMethod : int
		{
			Standard,
			TwoPassInigo,
			IntersectionMethodCount
		};

		enum SceneRenderMode : int
		{
			Solid,
			Wireframe,
			SceneRenderModeCount
		};

		enum RenderTargetSize : int
		{
			RTW_1920_1080,
			RTW_1280_720,
			RTW_3840_2160,
			RTW_4096_4096,
			RTW_2048_2048,
			RTW_1024_1024,
			RTW_512_512,
			RTW_128_128,
			RTW_64_64,
			RenderTargetSizeCount
		};

		void ShutDown();
		void StartUpBox();
		void StartUpAxes();
		void UpdateCamera( const Timer& timer );
		void KeyPressed( uint key, bool shift, bool alt, bool ctrl ) override;
		void UpdateAndRender( const Timer& timer ) override;
		void UpdateImGui( const Timer& timer ) override;
		//void RenderFrustum();
		void SceneReset();
		void ModelStartUp();
		void ModelRender( Dx11DeviceContext& deviceContext );
		void CullDecalVolumes( Dx11DeviceContext& deviceContext );

		void GenDecalVolumesRandom();
		void GenDecalVolumesModel();
		void ClearDecalVolumes();

		Matrix4 ProjMatrixForDecalVolumes() const;

		//void RenderFrustum2();
		void DrawClusteringHeatmap( Dx11DeviceContext& deviceContext );
		void DrawBoxesAndAxesFillIndirectArgs( Dx11DeviceContext& deviceContext );
		void DrawDecalBoxes( Dx11DeviceContext& deviceContext );
		void DrawDecalAxes( Dx11DeviceContext& deviceContext );
		void DrawDecalFarPlane( Dx11DeviceContext& deviceContext );
		void DrawScreenSpaceGrid( Dx11DeviceContext& deviceContext );

		void GetRenderTargetSize( uint &rtWidth, uint &rtHeight ) const;

		RenderTarget2D mainRT_ = RenderTarget2D( "mainRT_" );
		DepthStencil mainDS_ = DepthStencil( "mainDS_" );

		RenderTargetSize rtSize_ = RTW_1920_1080;
		//RenderTargetSize rtSizeCur_ = RTW_1920_1080;
		//RenderTargetSize rtSize_ = RTW_64_64;
		//RenderTargetSize rtSize_ = RTW_128_128;

		//HlslShaderPtr gpuClusteringShader_;
		HlslShaderPtr decalVolumeRenderingShader_;
		HlslShaderPtr decalVolumeCullShader_;

		Model sceneModel_;
		//HlslShaderPtr meshShader_;
		SceneRenderMode sceneRenderMode_ = Solid;
		
		ConstantBuffer<CbPassConstants> passConstants_;
		ConstantBuffer<CbObjectConstants> objectConstants_;
		ConstantBuffer<CbDecalVolumeRenderingConstants> decalVolumeRenderingConstants_;

		// Decal volumes
		int maxDecalVolumes_ = 1024;// 1024 * 4;
		int numDecalVolumes_ = 0;
		float decalVolumesAreaThreshold_ = 2.0f;
		float decalVolumesModelScale_ = 1.0f;
		float decalVolumeFarPlane_ = 1000.0f;
		DecalVolume *decalVolumesCPU_ = nullptr;
		StructuredBuffer<DecalVolume> decalVolumesGPU_;
		StructuredBuffer<DecalVolume> decalVolumesCulledGPU_;
		StructuredBuffer<DecalVolumeTest> decalVolumesTestCulledGPU_;
		StructuredBuffer<uint> decalVolumesCulledCountGPU_;
		ConstantBuffer<DecalVolumeCsCullConstants> decalVolumeCullConstants_;
		uint decalVolumesCulledCount_ = 0;
		//float decalVolumesAreaThresholdReq_ = 200.0f;

		struct Stats
		{
			uint totalMem;
			uint decalsPerCellMem;
			uint numCellIndirections;
			uint numWaves;
			uint numDecalsInAllCells;
			float avgDecalsPerCell;
			uint maxDecalsPerCell;
			uint minDecalsPerCell;
			uint memAllocated;

			std::vector<float> countPerCellHistogram;
		};

		struct DecalVolumeClusteringPass
		{
			uint nCellsX;
			uint nCellsY;
			uint nCellsZ;
			uint maxDecalsPerCell;

			StructuredBuffer<uint> decalPerCell;
			StructuredBuffer<CellIndirection> cellIndirection;
			StructuredBuffer<uint> cellIndirectionCount;
			StructuredBuffer<uint> indirectArgs;
			StructuredBuffer<uint> memAlloc;
			StructuredBuffer<GroupToBucket> groupToBucket;
			GpuTimerQuery timer;

			Stats stats;
		};

		struct DecalVolumeShared
		{
			uint totalMemUsed_ = 0;
			IntersectionMethod intersectionMethod_ = Standard;
			bool enableBuckets_ = false;
			bool dynamicBuckets_ = false;
			bool dynamicBucketsMerge_ = false;
			bool enablePassTiming_ = true;
		};

		void PopulateStats( Dx11DeviceContext& deviceContext, DecalVolumeShared &shared, std::vector<DecalVolumeClusteringPass> &passes );
		void ImGuiPrintClusteringInfo( DecalVolumeShared &shared, const std::vector<DecalVolumeClusteringPass> &passes, const GpuTimerQuery &totalTimer );

		struct DecalVolumeTilingData
		{
			std::vector<DecalVolumeClusteringPass> tilingPasses_;
			ConstantBuffer<DecalVolumeCsConstants> tilingConstants_;
			GpuTimerQuery decalVolumesTilingTimer_;
			HlslShaderPtr decalVolumesTilingShader_;
			DecalVolumeShared tiling_;
		};

		typedef std::unique_ptr<DecalVolumeTilingData> DecalVolumeTilingDataPtr;
		DecalVolumeTilingDataPtr tiling_;

		struct DecalVolumeClusteringData
		{
			std::vector<DecalVolumeClusteringPass> clusteringPasses_;
			ConstantBuffer<DecalVolumeCsConstants> clusteringConstants_;
			GpuTimerQuery decalVolumesClusteringTimer_;
			HlslShaderPtr decalVolumesClusteringShader_;
			DecalVolumeShared clustering_;
		};

		typedef std::unique_ptr<DecalVolumeClusteringData> DecalVolumeClusteringDataPtr;
		DecalVolumeClusteringDataPtr clustering_;

		FpsCounter fpsCounter_;
		RingBuffer vertices_;

		Matrix4 viewMatrixForCamera_;
		Matrix4 projMatrixForCamera_;
		Matrix4 viewMatrixForDecalVolumes_;
		Matrix4 projMatrixForDecalVolumes_;

		// box
		ID3D11BufferPtr boxVertexBuffer_;
		ID3D11BufferPtr boxIndexBuffer_;
		StructuredBuffer<uint> boxIndirectArgs_;
		// axes
		ID3D11BufferPtr axesVertexBuffer_;
		StructuredBuffer<uint> axesIndirectArgs_;

		// config
		enum AppMode : int
		{
			Tiling,
			Clustering,
			Scene,
			AppModeCount
		};

		//AppMode appMode_ = Tiling;
		AppMode appMode_ = Clustering;
		//AppMode appMode_ = Scene;

		enum OutputView : int
		{
			ExternalCamera,
			GpuHeatmap,
			CpuHeatmap,
			DecalVolumesAccum,
			OutputViewCount
		};

		OutputView currentView_ = GpuHeatmap;

		bool showExtendedStats_ = true;

		DecalVolumeTilingDataPtr DecalVolumeTilingStartUp();
		void DecalVolumeTilingRun( Dx11DeviceContext& deviceContext );

		DecalVolumeClusteringDataPtr DecalVolumeClusteringStartUp();
		void DecalVolumeClusteringRun( Dx11DeviceContext& deviceContext );
	};
}

