#include <Core/AppBase/AppBase.h>
#include <Core/Gfx/Mesh/Model.h>
#include <Shaders/hlsl/PassConstants.h>
#include <Shaders/hlsl/cs_decal_volume_cshared.hlsl>
#include <Shaders/hlsl/decal_volume_rendering_cshared.h>
#include <Core/Gfx/Camera.h>
#include <Core\Gfx\Dx11\Dx11Shader.h>

namespace spad
{
	constexpr uint maxBuckets = 7;

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
			ClipSpace,
			ClipSpaceFromDecal,
			SAT,
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

		enum TileSize : int
		{
			TileSize_512x512,
			TileSize_256x256,
			TileSize_128x128,
			TileSize_64x64,
			TileSize_48x48,
			TileSize_32x32,
			TileSize_16x16,
			TileSize_8x8,
			TileSizeCount
		};

		void ShutDown();
		void StartUpBox();
		void StartUpAxes();
		void UpdateCamera( const Timer& timer );
		void KeyPressed( uint key, bool shift, bool alt, bool ctrl ) override;
		void UpdateAndRender( const Timer& timer ) override;
		void UpdateImGui( const Timer& timer ) override;
		//void RenderFrustum();
		void RenderFrustum3();
		void SceneReset();
		void ModelStartUp();
		void ModelRender( Dx11DeviceContext& deviceContext );
		void CullDecalVolumes( Dx11DeviceContext& deviceContext );
		void DownsampleDepth( Dx11DeviceContext& deviceContext );

		void GenDecalVolumesRandom();
		void GenDecalVolumesModel();
		void ClearDecalVolumes();

		Matrix4 ProjMatrixForDecalVolumes() const;

		//void RenderFrustum2();
		void DrawClusteringHeatmap( Dx11DeviceContext& deviceContext );
		void DrawDepth( Dx11DeviceContext& deviceContext );
		void DrawBoxesAndAxesFillIndirectArgs( Dx11DeviceContext& deviceContext );
		void DrawDecalBoxes( Dx11DeviceContext& deviceContext );
		void DrawDecalAxes( Dx11DeviceContext& deviceContext );
		void DrawDecalFarPlane( Dx11DeviceContext& deviceContext );
		void DrawScreenSpaceGrid( Dx11DeviceContext& deviceContext );

		static void GetRenderTargetSize( RenderTargetSize rtSize, uint &rtWidth, uint &rtHeight );
		void GetRenderTargetSize( uint &rtWidth, uint &rtHeight ) const;

		RenderTarget2D mainRT_ = RenderTarget2D( "mainRT_" );
		DepthStencil mainDS_ = DepthStencil( "mainDS_" );
		CodeTexture clusterDS_ = CodeTexture( "clusterDS_" );

		//RenderTargetSize rtSize_ = RTW_1920_1080;
		//RenderTargetSize rtSize_ = RTW_64_64;
		//RenderTargetSize rtSize_ = RTW_128_128;
		RenderTargetSize rtSize_ = RTW_1024_1024;
		TileSize tileSizeForTiling_ = TileSize_64x64;
		//TileSize tileSizeForClustering_ = TileSize_32x32;
		TileSize tileSizeForClustering_ = TileSize_16x16;
		int numPassesForTiling_ = 1;
		int numPassesForClustering_ = 4;

		HlslShaderPtr decalVolumeRenderingShader_;
		HlslShaderPtr decalVolumeCullShader_;

		Model sceneModel_;
		SceneRenderMode sceneRenderMode_ = Solid;
		
		ConstantBuffer<CbPassConstants> passConstants_;
		ConstantBuffer<CbObjectConstants> objectConstants_;
		ConstantBuffer<CbDecalVolumeRenderingConstants> decalVolumeRenderingConstants_;

		// Decal volumes
		int maxDecalVolumes_ = 1;// 1024 * 4;
		int numDecalVolumes_ = 0;
		float decalVolumesAreaThreshold_ = 2.0f;
		float decalVolumesModelScale_ = 1.0f;
		float decalVolumesRandomScale_ = 8.0f;
		float decalVolumeFarPlane_ = 1000.0f;
		DecalVolume *decalVolumesCPU_ = nullptr;
		StructuredBuffer<DecalVolume> decalVolumesGPU_;
		StructuredBuffer<DecalVolume> decalVolumesCulledGPU_;
		StructuredBuffer<DecalVolumeTest> decalVolumesTestCulledGPU_;
		StructuredBuffer<uint> decalVolumesCulledCountGPU_;
		ConstantBuffer<DecalVolumeCsCullConstants> decalVolumeCullConstants_;
		uint decalVolumesCulledCount_ = 0;

		struct Stats
		{
			uint totalMem;
			uint numCellIndirections[maxBuckets];
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
			float nCellsXF;
			float nCellsYF;
			float nCellsZF;
			float nCellsXRcp;
			float nCellsYRcp;
			float nCellsZRcp;
			uint maxDecalIndices;
			uint maxDecalIndicesPerCellFirstPass;
			uint maxCellIndirectionsPerBucket;

			StructuredBuffer<uint> decalIndices;
			StructuredBuffer<CellIndirection> cellIndirection;
			StructuredBuffer<uint> cellIndirectionCount;
			StructuredBuffer<uint> indirectArgs;
			StructuredBuffer<uint> decalIndicesCount;
			StructuredBuffer<GroupToBucket> groupToBucket;
			GpuTimerQuery timer;

			Stats stats;
		};

		//struct DecalVolumeShared
		//{
		//	uint totalMemUsed_ = 0;
		//	IntersectionMethod intersectionMethod_ = ClipSpace;
		//	bool enableBuckets_ = true;
		//	bool dynamicBuckets_ = false;
		//	bool dynamicBucketsMerge_ = true;
		//	bool enablePassTiming_ = true;
		//	bool needsReset_ = false;
		//};

		//struct DecalVolumeTilingData
		//{
		//	std::vector<DecalVolumeClusteringPass> tilingPasses_;
		//	ConstantBuffer<DecalVolumeCsConstants> tilingConstants_;
		//	GpuTimerQuery decalVolumesTilingTimer_;
		//	HlslShaderPtr decalVolumesTilingShader_;
		//	DecalVolumeShared tiling_;
		//};

		struct DecalVolumeClusteringData
		{
			std::vector<DecalVolumeClusteringPass> passes_;
			ConstantBuffer<DecalVolumeCsConstants> constants_;
			GpuTimerQuery timer_;
			HlslShaderPtr shader_;
			//DecalVolumeShared clustering_;
			uint totalMemUsed_ = 0;
			//IntersectionMethod intersectionMethod_ = ClipSpace;
			//IntersectionMethod intersectionMethod_ = Standard;
			IntersectionMethod intersectionMethod_ = SAT;
			bool clustering_ = false;
			bool enableBuckets_ = true;
			bool dynamicBuckets_ = false;
			bool dynamicBucketsMerge_ = true;
			bool enablePassTiming_ = true;
			bool needsReset_ = false;
		};

		typedef std::unique_ptr<DecalVolumeClusteringData> DecalVolumeClusteringDataPtr;
		DecalVolumeClusteringDataPtr clustering_;
		DecalVolumeClusteringDataPtr tiling_;

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

		AppMode appMode_ = Tiling;
		//AppMode appMode_ = Clustering;
		//AppMode appMode_ = Scene;

		enum OutputView : int
		{
			ExternalCamera,
			GpuHeatmap,
			CpuHeatmap,
			DecalVolumesAccum,
			DepthBuffer,
			OutputViewCount
		};

		OutputView currentView_ = GpuHeatmap;
		//OutputView currentView_ = DepthBuffer;
		int depthBufferMip_ = 0;
		bool depthBufferShowMin_ = true;

		bool showExtendedStats_ = true;

		void PopulateStats( Dx11DeviceContext& deviceContext, DecalVolumeClusteringData &data );
		void ImGuiPrintClusteringInfo( DecalVolumeClusteringData &data );

		static void GetTileSize( TileSize tileSize, uint &outTileSize );
		void CalculateCellCount( uint rtWidth, uint rtHeight, uint tileSize, uint numPasses, uint &outCellsX, uint &outCellsY, uint &outCellsZ );
		DecalVolumeClusteringDataPtr DecalVolumeClusteringStartUp( bool clustering );
		void DecalVolumeClusteringRun( Dx11DeviceContext& deviceContext, DecalVolumeClusteringData &data );

		//DecalVolumeTilingDataPtr DecalVolumeTilingStartUp();
		//void DecalVolumeTilingRun( Dx11DeviceContext& deviceContext );
	};
}

