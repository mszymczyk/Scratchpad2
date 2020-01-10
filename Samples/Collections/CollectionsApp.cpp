#include "Collections_pch.h"
#include "CollectionsApp.h"
#include <AppBase/Input.h>
#include <Gfx\Dx11/Dx11DeviceStates.h>
#include <Gfx\DebugDraw.h>
#include <random>
#include <Imgui\imgui_include.h>
#include <Util\Bits.h>
#include <Gfx\Math\HLSLEmulation.h>
#include <Gfx\Math\ViewFrustum.h>
#include <fstream>
#include <unordered_map>
#include <numeric>


namespace spad
{
	#define MAX_MAP_TRANSIENT_ZONES 1280
	#define MAX_TRANSIENT_LEVELS 3

	#define SIZEOF_POINTER				8
	#define ARRAY_COUNT( array ) ( sizeof( array ) / ( sizeof( array[0] ) * ( sizeof( array ) != SIZEOF_POINTER || sizeof( array[0] ) <= SIZEOF_POINTER ) ) )

	#define _printf printf

	constexpr uint INVALID_STATIC_MODEL_ID                  = 0xffffffff;
	constexpr uint INVALID_TRANSIENT_INDEX                  = 0xffff;
	constexpr uint INVALID_COLLECTION_INDEX                 = 0xffffffff;
	constexpr size_t NUM_MATERIAL_BUCKETS	                = 64;
	constexpr size_t MAX_TRANSIENTS			                = MAX_MAP_TRANSIENT_ZONES;
	constexpr size_t MAX_TRANSIENTS_PER_COLLECTION          = 255;
	constexpr float OVERLAP_EPSILON			                = 1.0f;
	constexpr float INITIAL_COLLECTION_AREA_SCALE		    = 1.0f / 64.0f;
	constexpr float INITIAL_COLLECTION_VOLUME_SCALE		    = 1.0f / 64.0f;
	constexpr uint INITIAL_COLLECTION_MAX_TRIANGLES		    = 200 * 1000;
	constexpr uint COLLECTION_MAX_TRIANGLES_HARD_LIMIT	    = 500 * 1000;
	constexpr float COLLECTION_AREA_INCREASE_ON_FAIL	    = 0.25f;
	constexpr float COLLECTION_TRI_COUNT_INCREASE_ON_FAIL	= 0.25f;


	template <typename T1, typename T2>
	T1 truncate_cast( T2 a )
	{
		assert( sizeof( T2 ) >= sizeof( T1 ) );
		T1 b = (T1)a;
		assert( (T2)b == a );
		return b;
	}

	typedef float3 vec3_t;

	typedef unsigned short ushort;

	inline void Vec3Sub( const vec3_t& a, const vec3_t& b, _Out_ vec3_t& diff )
	{
		diff[0] = a[0] - b[0];
		diff[1] = a[1] - b[1];
		diff[2] = a[2] - b[2];
	}

	inline void Vec3Min( const vec3_t& a, const vec3_t& b, _Out_ vec3_t& result )
	{
		result[0] = a[0] < b[0] ? a[0] : b[0];
		result[1] = a[1] < b[1] ? a[1] : b[1];
		result[2] = a[2] < b[2] ? a[2] : b[2];
	}

	inline void Vec3Max( const vec3_t& a, const vec3_t& b, _Out_ vec3_t& result )
	{
		result[0] = a[0] > b[0] ? a[0] : b[0];
		result[1] = a[1] > b[1] ? a[1] : b[1];
		result[2] = a[2] > b[2] ? a[2] : b[2];
	}

	inline void Vec3Clear( _Out_ vec3_t& v )
	{
		v[0] = 0;
		v[1] = 0;
		v[2] = 0;
	}

	void Error( const char * /*pFormat*/, ... )
	{
		assert( false );
	}

	struct orientation_t
	{
		vec3_t origin;
		//mat33_t axis;
	};

	struct StaticModel
	{
		std::string prefixedModelName;
		uint transientIndex;
		uint transientLod;
		orientation_t worldTransform;
		uint numVerts;
		uint lod0TriCount;
		float volume;
		bool candidateForCollection;
	};

	typedef std::vector<uint> StaticModelArray;

	struct StaticModelInstances
	{
		StaticModelArray instances;
	};

	struct StaticModelCount
	{
		std::string prefixedModelName;
		uint instanceCount;
	};

	typedef std::unordered_map<std::string, StaticModelInstances> StaticModelInstancesMap;
	typedef std::set<uint> TransientIndexSet;


	struct StaticModelCollection
	{
		StaticModelArray models;
		TransientIndexSet transients;

		vec3_t minCorner = { FLT_MAX, FLT_MAX, FLT_MAX };
		vec3_t maxCorner = { -FLT_MAX, -FLT_MAX, -FLT_MAX };

		float volume = 0;
		float area = 0;

		uint totalTris = 0;
		uint totalVerts = 0;
	};

	typedef std::unordered_map<std::string, StaticModelCollection> StaticModelCollectionMap;

	struct Transient
	{
		std::string transientName;
		byte transientLOD = 0;

		StaticModelCollectionMap perModelCollections;

		vec3_t minCorner = { FLT_MAX, FLT_MAX, FLT_MAX };
		vec3_t maxCorner = { -FLT_MAX, -FLT_MAX, -FLT_MAX };

		float volume = 0;
		float area = 0;
	};

	typedef std::vector<StaticModelCollection> CollectionArray;
	typedef std::map< std::string, ushort > TransientNameToIndexMap;

	typedef std::unordered_map<uint, uint> StaticModelIDToStaticModelIndex;

	struct CollectionsBuildInput
	{
		StaticModelInstancesMap perModelInstances;
		std::vector<StaticModelCount> perModelInstanceCount; // count of instances per unique models
		std::unordered_map<std::string, uint> modelNameToUniqueModelIndex;

		TransientNameToIndexMap transientNameToIndex;
		std::vector<Transient> transients;

		vec3_t worldMinCorner = { FLT_MAX, FLT_MAX, FLT_MAX };
		vec3_t worldMaxCorner = { -FLT_MAX, -FLT_MAX, -FLT_MAX };

		float avgTransientVolume = 0;
		float avgTransientArea = 0;

		uint numStaticModelsInClutterCollections = 0;

		uint numSuitableForCollection = 0;
		uint numFailed_nullXmodel = 0;
		uint numFailed_proxyLOD = 0;
		uint numFailed_generatedProxy = 0;
		uint numFailed_no_model_collection_kvp = 0;
		uint numSModels_occluderKVP = 0;
		uint numSModels_nonOccluder = 0;

		std::vector<uint> materialBuckets;
	};

	struct CollectionsBuildParam
	{
		uint maxCollectionsToGenerate = 0;
		bool multiTransientCollections = false;
		bool printDetailedInfo = false;
		bool printDetailedInfoOnSuccess = false;
	};

	struct TransientState
	{
		std::vector<uint> collectionIndices;
	};

	struct CollectionsBuildState
	{
		CollectionArray collections;
		std::vector<TransientState> transients;

		uint maxTriangles = 0;
		float maxVolume = 0;
		float maxArea = 0;

		uint modelsInCollectionsCount = 0;
		uint numFailedTotalTris = 0;
		uint numFailedVolume = 0;
		uint numFailedArea = 0;

		uint64_t totalTrianglesInAllCollections = 0;
		uint minTrianglesPerCollection = 0xffffffff;
		uint maxTrianglesPerCollection = 0;

		CollectionsBuildParam param;
	};

	struct CollectionsBuildOutput
	{
		CollectionArray collections;
	};


	static std::vector<StaticModel> s_modelsInMapOrder;
	static StaticModelIDToStaticModelIndex s_staticModelIdToStaticModelIndex;
	static uint numStaticModelsInClutterCollections = 0;

	static CollectionsBuildOutput s_smodelCollectionsOutput;

	void LoadStaticModelCollectionsData( CollectionsBuildInput &cinput )
	{
		std::cout << "Loading collections file" << std::endl;

		//std::ifstream infile( "Data/pbr_whitebox_static_model_collections_dump.txt" );
		std::ifstream infile( "Data/mp_donetsk_static_model_collections_dump.txt" );
		//std::ifstream infile( "Data/mp_br_transient_static_model_collections_dump.txt" );
		//std::ifstream infile( "Data/cp_donetsk_static_model_collections_dump.txt" );
		std::string tmp;
		
		std::getline( infile, tmp );
		
		uint numModels, maxCollections;
		infile >> tmp >> numModels >> tmp >> maxCollections;
		s_modelsInMapOrder.resize( numModels );

		uint modelIndex = 0;
		uint maxTransientIndex = 0;

		cinput.worldMinCorner = vec3_t( FLT_MAX, FLT_MAX, FLT_MAX );
		cinput.worldMaxCorner = vec3_t( -FLT_MAX, -FLT_MAX, -FLT_MAX );

		while ( infile && modelIndex < numModels )
		{
			StaticModel &sm = s_modelsInMapOrder[modelIndex];
			//sm.mapOrderIndex = modelIndex;
			modelIndex += 1;

			infile >> sm.prefixedModelName;
			infile >> sm.transientIndex;
			infile >> sm.transientLod;
			infile >> sm.worldTransform.origin.x;
			infile >> sm.worldTransform.origin.y;
			infile >> sm.worldTransform.origin.z;
			infile >> sm.numVerts;
			infile >> sm.lod0TriCount;
			infile >> sm.volume;
			//sm.collectionIndex = 0xffffffff;

			if ( sm.lod0TriCount > 0 )
			{
				maxTransientIndex = std::max( sm.transientIndex, maxTransientIndex );
				sm.candidateForCollection = true;
			}

			cinput.worldMinCorner.x = std::min( cinput.worldMinCorner.x, sm.worldTransform.origin.x );
			cinput.worldMinCorner.y = std::min( cinput.worldMinCorner.y, sm.worldTransform.origin.y );
			cinput.worldMinCorner.z = std::min( cinput.worldMinCorner.z, sm.worldTransform.origin.z );
			cinput.worldMaxCorner.x = std::max( cinput.worldMaxCorner.x, sm.worldTransform.origin.x );
			cinput.worldMaxCorner.y = std::max( cinput.worldMaxCorner.y, sm.worldTransform.origin.y );
			cinput.worldMaxCorner.z = std::max( cinput.worldMaxCorner.z, sm.worldTransform.origin.z );

			std::string transientName = "tr_" + std::to_string( sm.transientIndex );

			TransientNameToIndexMap::iterator it = cinput.transientNameToIndex.find( transientName );
			ushort transientIndex;
			if ( it == cinput.transientNameToIndex.end() )
			{
				transientIndex = truncate_cast<ushort>( cinput.transientNameToIndex.size() );
				if ( transientIndex >= MAX_TRANSIENTS )
				{
					Error( "Transient limit reached. Max %u\n", MAX_TRANSIENTS );
				}

				cinput.transientNameToIndex[transientName] = transientIndex;

				cinput.transients.emplace_back();
				Transient &newTransient = cinput.transients[transientIndex];
				newTransient.transientName = transientName;
				newTransient.transientLOD = truncate_cast<byte>( sm.transientLod );
			}
			else
			{
				transientIndex = it->second;
			}

			//sm.transientIndex = transientIndex;
			//sm.transientLod = cinput.transients[transientIndex].transientLOD;
		}

		//AssignModelsToTransients( cinput, maxTransientIndex + 1 );

		std::cout << "Collections file loaded. Num instances " << s_modelsInMapOrder.size() << std::endl;
	}

	static void CalculateCollectionBounds( const CollectionsBuildInput &/*cinput*/, StaticModelCollection &collection )
	{
		collection.minCorner = { FLT_MAX, FLT_MAX, FLT_MAX };
		collection.maxCorner = { -FLT_MAX, -FLT_MAX, -FLT_MAX };

		const StaticModel *sm0 = &s_modelsInMapOrder[collection.models[0]];
		collection.totalTris = truncate_cast<uint>( collection.models.size() * sm0->lod0TriCount );

		for ( size_t iModel = 0; iModel < collection.models.size(); ++iModel )
		{
			uint mapModelIndex = collection.models[iModel];
			const StaticModel *sm = &s_modelsInMapOrder[mapModelIndex];
			Vec3Min( collection.minCorner, sm->worldTransform.origin, collection.minCorner );
			Vec3Max( collection.maxCorner, sm->worldTransform.origin, collection.maxCorner );

			collection.transients.insert( sm->transientIndex );
		}

		vec3_t size;
		Vec3Sub( collection.maxCorner, collection.minCorner, size );
		collection.volume = size.x * size.y * size.z;
		collection.area = size.x * size.y;
	}


	static void BuildModelLists( CollectionsBuildInput &cinput )
	{
		for ( uint iModel = 0; iModel < truncate_cast<uint>( s_modelsInMapOrder.size() ); ++iModel )
		{
			const StaticModel &sm = s_modelsInMapOrder[iModel];

			StaticModelInstancesMap::iterator it = cinput.perModelInstances.find( sm.prefixedModelName );
			if ( it == cinput.perModelInstances.end() )
			{
				StaticModelInstances instances;
				instances.instances.push_back( iModel );
				cinput.perModelInstances[sm.prefixedModelName] = instances;
			}
			else
			{
				it->second.instances.push_back( iModel );
			}
		}

		cinput.perModelInstanceCount.reserve( cinput.perModelInstances.size() );

		for ( StaticModelInstancesMap::const_iterator it = cinput.perModelInstances.begin(); it != cinput.perModelInstances.end(); ++it )
		{
			cinput.modelNameToUniqueModelIndex[it->first] = truncate_cast<uint>( cinput.perModelInstanceCount.size() );
			cinput.perModelInstanceCount.push_back( { it->first, truncate_cast<uint>( it->second.instances.size() ) } );
		}
	}


	static void BuildTransientLists( CollectionsBuildInput &cinput )
	{
		// Assign all models to respective transients and use that to estimate transient size
		for ( uint iModel = 0; iModel < truncate_cast<uint>( s_modelsInMapOrder.size() ); ++iModel )
		{
			const StaticModel &sm = s_modelsInMapOrder[iModel];

			Transient &tr = cinput.transients[sm.transientIndex];
			StaticModelCollectionMap::iterator it = tr.perModelCollections.find( sm.prefixedModelName );
			if ( it == tr.perModelCollections.end() )
			{
				StaticModelCollection cell;
				cell.models.push_back( iModel );
				tr.perModelCollections[sm.prefixedModelName] = cell;
			}
			else
			{
				assert( sm.transientIndex == s_modelsInMapOrder[it->second.models[0]].transientIndex );
				it->second.models.push_back( iModel );
			}
		}

		double transientTotalVolume = 0;
		double transientTotalArea = 0;

		for ( size_t iTransient = 0; iTransient < cinput.transients.size(); ++iTransient )
		{
			Transient &tr = cinput.transients[iTransient];

			if ( tr.perModelCollections.size() )
			{
				for ( StaticModelCollectionMap::iterator it = tr.perModelCollections.begin(); it != tr.perModelCollections.end(); ++it )
				{
					StaticModelCollection &collection = it->second;

					CalculateCollectionBounds( cinput, collection );

					Vec3Min( collection.minCorner, tr.minCorner, tr.minCorner );
					Vec3Max( collection.maxCorner, tr.maxCorner, tr.maxCorner );
				}

				vec3_t size;
				Vec3Sub( tr.maxCorner, tr.minCorner, size );
				tr.volume = size.x * size.y * size.z;
				tr.area = size.x * size.y;

				transientTotalVolume += tr.volume;
				transientTotalArea += tr.area;
			}
			else
			{
				Vec3Clear( tr.minCorner );
				Vec3Clear( tr.maxCorner );
			}

			Vec3Min( cinput.worldMinCorner, tr.minCorner, cinput.worldMinCorner );
			Vec3Max( cinput.worldMaxCorner, tr.maxCorner, cinput.worldMaxCorner );

			vec3_t size;
			Vec3Sub( tr.maxCorner, tr.minCorner, size );
			tr.volume = size.x * size.y * size.z;
			tr.area = size.x * size.y;

			transientTotalVolume += tr.volume;
			transientTotalArea += tr.area;
		}

		cinput.avgTransientVolume = static_cast<float>( transientTotalVolume / cinput.transients.size() );
		cinput.avgTransientArea = static_cast<float>( transientTotalArea / cinput.transients.size() );
	}


	static bool CollectionStopCondition( CollectionsBuildState &state, const StaticModelCollection &cell )
	{
		if ( cell.models.size() == 1 )
		{
			return true;
		}

		if ( cell.transients.size() > MAX_TRANSIENTS_PER_COLLECTION )
		{
			return false;
		}

		if ( cell.totalTris >= state.maxTriangles )
		{
			state.numFailedTotalTris += 1;
			return false;
		}

		if ( cell.area >= state.maxArea )
		{
			state.numFailedArea += 1;
			return false;
		}

		return true;
	}


	static void AddCollection( const CollectionsBuildInput &/*cinput*/, CollectionsBuildState &state, StaticModelCollection &collection )
	{
		state.modelsInCollectionsCount += truncate_cast<uint>( collection.models.size() );
		state.totalTrianglesInAllCollections += collection.totalTris;
		state.minTrianglesPerCollection = std::min( state.minTrianglesPerCollection, collection.totalTris );
		state.maxTrianglesPerCollection = std::max( state.maxTrianglesPerCollection, collection.totalTris );

		uint collectionIndex = truncate_cast<uint>( state.collections.size() );

		for ( TransientIndexSet::const_iterator it = collection.transients.begin(); it != collection.transients.end(); ++it )
		{
			state.transients[*it].collectionIndices.push_back( collectionIndex );
		}

		state.collections.push_back( std::move( collection ) );
	}


	static void BuildCollectionRecurse( const CollectionsBuildInput &cinput, CollectionsBuildState &state, StaticModelCollection &collection )
	{
		if ( CollectionStopCondition( state, collection ) )
		{
			AddCollection( cinput, state, collection );

			return;
		}

		// Split cell in 4
		vec3_t cellSize;
		Vec3Sub( collection.maxCorner, collection.minCorner, cellSize );
		vec3_t cellSizeRcp;
		cellSizeRcp.x = cellSize.x > 0.001f ? 1.0f / cellSize.x : 0.0f;
		cellSizeRcp.y = cellSize.y > 0.001f ? 1.0f / cellSize.y : 0.0f;
		cellSizeRcp.z = cellSize.z > 0.001f ? 1.0f / cellSize.z : 0.0f;

		StaticModelCollection newCells[4];

		for ( size_t iModel = 0; iModel < collection.models.size(); ++iModel )
		{
			uint mapModelIndex = collection.models[iModel];
			const StaticModel *sm = &s_modelsInMapOrder[mapModelIndex];

			float px = sm->worldTransform.origin.x - collection.minCorner.x;
			float py = sm->worldTransform.origin.y - collection.minCorner.y;
			px = px * cellSizeRcp.x * 2;
			py = py * cellSizeRcp.y * 2;

			int x = std::min( (int)px, 1 );
			int y = std::min( (int)py, 1 );
			assert( x >= 0 && y >= 0 );

			uint cellIndex = y * 2 + x;
			assert( cellIndex < 4 );
			newCells[cellIndex].models.push_back( mapModelIndex );
		}

		for ( uint iCell = 0; iCell < 4; ++iCell )
		{
			if ( newCells[iCell].models.empty() )
			{
				continue;
			}

			CalculateCollectionBounds( cinput, newCells[iCell] );
			BuildCollectionRecurse( cinput, state, newCells[iCell] );
		}
	}


	static void SortCollections( CollectionsBuildState &state )
	{
		// Put single model collections at the start of the list
		// Just sorting collections is not enough. TransientState contains indices of the collections that need to be patched.
		std::vector<uint> sortedIndices( state.collections.size() );
		std::iota( sortedIndices.begin(), sortedIndices.end(), 0 );

		std::stable_sort( sortedIndices.begin(), sortedIndices.end(), [&]( uint a, uint b ) {
			return state.collections[a].models.size() < state.collections[b].models.size();
		} );

		std::vector<uint> sortedIndicesInv( sortedIndices.size() );
		for ( size_t i = 0; i < sortedIndices.size(); ++i )
			sortedIndicesInv[sortedIndices[i]] = truncate_cast<uint>( i );

		for ( TransientState &ts : state.transients )
		{
			std::vector<uint> sortedCollectionIndices( ts.collectionIndices.size() );
			for ( size_t iCollection = 0; iCollection < ts.collectionIndices.size(); ++iCollection )
			{
				sortedCollectionIndices[iCollection] = sortedIndicesInv[ts.collectionIndices[iCollection]];
			}
			ts.collectionIndices = std::move( sortedCollectionIndices );
		}

		CollectionArray sortedCollections( state.collections.size() );
		for ( size_t iCollection = 0; iCollection < state.collections.size(); ++iCollection )
		{
			sortedCollections[iCollection] = std::move( state.collections[sortedIndices[iCollection]] );
		}

		state.collections = std::move( sortedCollections );

		// Validate cross references are correct
		for ( size_t iTransient = 0; iTransient < state.transients.size(); ++iTransient )
		{
			const TransientState &ts = state.transients[iTransient];
			for ( size_t iCollection = 0; iCollection < ts.collectionIndices.size(); ++iCollection )
			{
				uint collectionIndex = ts.collectionIndices[iCollection];
				const StaticModelCollection &collection = state.collections[collectionIndex];
				TransientIndexSet::const_iterator it = collection.transients.find( truncate_cast<uint>( iTransient ) );
				if ( it == collection.transients.end() )
				{
					Error( "transient and collection don't match after sort\n" );
				}
			}
		}
	}


	static void BuildCollectionsPassMultiTransient( const CollectionsBuildInput &cinput, CollectionsBuildState &state )
	{
		state.transients.resize( cinput.transients.size() );

		StaticModelCollectionMap initialCollectionsPerLevel[MAX_TRANSIENT_LEVELS];

		for ( uint iModel = 0; iModel < truncate_cast<uint>( s_modelsInMapOrder.size() ); ++iModel )
		{
			const StaticModel &sm = s_modelsInMapOrder[iModel];
			if ( !sm.candidateForCollection )
			{
				StaticModelCollection collection;
				collection.models.push_back( iModel );
				CalculateCollectionBounds( cinput, collection );
				AddCollection( cinput, state, collection );
				continue;
			}

			StaticModelCollectionMap &initialCollections = initialCollectionsPerLevel[sm.transientLod];

			StaticModelCollectionMap::iterator it = initialCollections.find( sm.prefixedModelName );
			if ( it == initialCollections.end() )
			{
				StaticModelCollection collection;
				collection.models.push_back( iModel );
				initialCollections[sm.prefixedModelName] = collection;
			}
			else
			{
				it->second.models.push_back( iModel );
			}
		}

		for ( size_t iLevel = 0; iLevel < ARRAY_COUNT( initialCollectionsPerLevel ); ++iLevel )
		{
			StaticModelCollectionMap &initialCollections = initialCollectionsPerLevel[iLevel];

			for ( StaticModelCollectionMap::iterator it = initialCollections.begin(); it != initialCollections.end(); ++it )
			{
				StaticModelCollection &collection = it->second;

				CalculateCollectionBounds( cinput, collection );
				BuildCollectionRecurse( cinput, state, collection );
			}
		}

		SortCollections( state );
	}


	static void BuildCollectionsPassSingleTransient( const CollectionsBuildInput &cinput, CollectionsBuildState &state )
	{
		state.transients.resize( cinput.transients.size() );

		for ( uint iModel = 0; iModel < truncate_cast<uint>( s_modelsInMapOrder.size() ); ++iModel )
		{
			const StaticModel &sm = s_modelsInMapOrder[iModel];
			if ( !sm.candidateForCollection )
			{
				StaticModelCollection collection;
				collection.models.push_back( iModel );
				CalculateCollectionBounds( cinput, collection );
				AddCollection( cinput, state, collection );
			}
		}

		// Create collections within transients, so SP transient loading/unloading works correct
		for ( size_t iTransient = 0; iTransient < cinput.transients.size(); ++iTransient )
		{
			const Transient &tr = cinput.transients[iTransient];

			for ( StaticModelCollectionMap::const_iterator it = tr.perModelCollections.begin(); it != tr.perModelCollections.end(); ++it )
			{
				StaticModelCollection collection = it->second;

				CalculateCollectionBounds( cinput, collection );
				BuildCollectionRecurse( cinput, state, collection );
			}
		}

		for ( size_t iCollection = 0; iCollection < state.collections.size(); ++iCollection )
		{
			const StaticModelCollection &collection = state.collections[iCollection];
			assert( collection.transients.size() == 1 );
			if ( collection.transients.size() != 1 )
			{
				Error( "SModelCollections: collection must belong to only one transient. %u \n", iCollection );
			}
		}

		SortCollections( state );
	}


	static bool BuildCollections( const CollectionsBuildInput &cinput, const CollectionsBuildParam &param, CollectionsBuildState &outState )
	{
		if ( cinput.perModelInstanceCount.size() > param.maxCollectionsToGenerate )
		{
			// Number of unique models is larger than max collections. Impossible to generate collections.
			return false;
		}

		_printf( "Static model collections input:\n" );
		_printf( "  %u model instances\n", truncate_cast<uint>( s_modelsInMapOrder.size() ) );
		_printf( "  %u model instances suitable for collections\n", cinput.numSuitableForCollection );
		_printf( "  %u model instances failed null xmodel\n", cinput.numFailed_nullXmodel );
		_printf( "  %u model instances failed proxyLOD kvp\n", cinput.numFailed_proxyLOD );
		_printf( "  %u model instances failed generatedProxy kvp\n", cinput.numFailed_generatedProxy );
		_printf( "  %u model instances failed no_model_collection kvp\n", cinput.numFailed_no_model_collection_kvp );
		_printf( "  %u model instances occluder kvp\n", cinput.numSModels_occluderKVP );
		_printf( "  %u model instances occluder kvp = 1\n", cinput.numSModels_nonOccluder );
		_printf( "  max allowed collections %u\n", param.maxCollectionsToGenerate );
		_printf( "  worst case collection count (one collection per unique model) %u\n", truncate_cast<uint>( cinput.perModelInstanceCount.size() ) );

		if ( param.printDetailedInfo )
		{
			std::vector<uint> sortedPerModelInstanceCount( cinput.perModelInstanceCount.size() );
			std::iota( sortedPerModelInstanceCount.begin(), sortedPerModelInstanceCount.end(), 0 );

			std::sort( sortedPerModelInstanceCount.begin(), sortedPerModelInstanceCount.end(), [&]( const uint a, const uint b ) {
				return cinput.perModelInstanceCount[a].instanceCount > cinput.perModelInstanceCount[b].instanceCount;
			} );

			_printf( "  Model instance counts:\n" );

			for ( uint iModel = 0; iModel < sortedPerModelInstanceCount.size(); ++iModel )
			{
				uint modelIndex = sortedPerModelInstanceCount[iModel];
				_printf( "    %5u instances of %s\n", cinput.perModelInstanceCount[modelIndex].instanceCount, cinput.perModelInstanceCount[modelIndex].prefixedModelName.c_str() );
			}
		}

		if ( param.printDetailedInfo )
		{
			_printf( "  Material histogram:\n" );
			for ( size_t i = 0; i < cinput.materialBuckets.size(); ++i )
			{
				if ( cinput.materialBuckets[i] > 0 )
				{
					if ( i == NUM_MATERIAL_BUCKETS - 1 )
					{
						_printf( "    %6u models with %3u or more materials \n", cinput.materialBuckets[i], truncate_cast<uint>( i ) );
					}
					else
					{
						_printf( "    %6u models with %3u materials\n", cinput.materialBuckets[i], truncate_cast<uint>( i ) );
					}
				}
			}
		}

		uint maxTriangles = INITIAL_COLLECTION_MAX_TRIANGLES;
		float maxVolume = cinput.avgTransientVolume * INITIAL_COLLECTION_VOLUME_SCALE;
		float maxArea = cinput.avgTransientArea * INITIAL_COLLECTION_AREA_SCALE;

		constexpr uint maxPasses = 64;

		for ( uint iPass = 0; iPass < maxPasses; ++iPass )
		{
			float areaSizeApprox = sqrtf( maxArea );
			_printf( "\nCollections pass %u: maxTris %u, maxArea %f - approx %f x %f\n", iPass, maxTriangles, maxArea, areaSizeApprox, areaSizeApprox );

			CollectionsBuildState state;
			state.param = param;
			state.maxTriangles = maxTriangles;
			state.maxVolume = maxVolume;
			state.maxArea = maxArea;

			if ( param.multiTransientCollections )
			{
				BuildCollectionsPassMultiTransient( cinput, state );
			}
			else
			{
				BuildCollectionsPassSingleTransient( cinput, state );
			}

			if ( state.collections.size() )
			{
				const bool solutionFound = state.collections.size() <= param.maxCollectionsToGenerate;
				_printf( "  %s\n", solutionFound ? "SUCCEEDED" : "FAILED" );

				_printf( "Collection count: %u / %u\n", truncate_cast<uint>( state.collections.size() ), param.maxCollectionsToGenerate );
				_printf( "Num failed tri count: %u\n", state.numFailedTotalTris );
				_printf( "Num failed area: %u\n", state.numFailedArea );
				_printf( "Min tris per collection: %u\n", state.minTrianglesPerCollection );
				_printf( "Max tris per collection: %u\n", state.maxTrianglesPerCollection );
				uint avgTrisPerCollection = truncate_cast<uint>( state.totalTrianglesInAllCollections / state.collections.size() );
				_printf( "Avg tris per collection: %u\n", avgTrisPerCollection );

				if ( state.modelsInCollectionsCount != truncate_cast<uint>( s_modelsInMapOrder.size() ) )
				{
					Error( "modelsInCollectionsCount != map model count. %u != %u\n", state.modelsInCollectionsCount, truncate_cast<uint>( s_modelsInMapOrder.size() ) );
				}

				if ( param.printDetailedInfo || ( param.printDetailedInfoOnSuccess && solutionFound ) )
				{
					{
						std::vector<uint> perModelCollectionCount( cinput.perModelInstanceCount.size(), 0 );
						std::vector<uint> perModelCollectionMinInstances( cinput.perModelInstanceCount.size(), 0xffffffff );
						std::vector<uint> perModelCollectionMaxInstances( cinput.perModelInstanceCount.size(), 0 );

						for ( size_t iCollection = 0; iCollection < state.collections.size(); ++iCollection )
						{
							const StaticModelCollection &c = state.collections[iCollection];
							const StaticModel *sm0 = &s_modelsInMapOrder[c.models[0]];
							std::unordered_map<std::string, uint>::const_iterator it = cinput.modelNameToUniqueModelIndex.find( sm0->prefixedModelName );
							assert( it != cinput.modelNameToUniqueModelIndex.end() );
							perModelCollectionCount[it->second] += 1;
							perModelCollectionMinInstances[it->second] = std::min( perModelCollectionMinInstances[it->second], truncate_cast<uint>( c.models.size() ) );
							perModelCollectionMaxInstances[it->second] = std::max( perModelCollectionMaxInstances[it->second], truncate_cast<uint>( c.models.size() ) );
						}

						std::vector<uint> sortedIndices( perModelCollectionCount.size() );
						std::iota( sortedIndices.begin(), sortedIndices.end(), 0 );

						std::sort( sortedIndices.begin(), sortedIndices.end(), [&]( uint a, uint b ) {
							return perModelCollectionCount[a] > perModelCollectionCount[b];
						} );

						_printf( "Model collection counts:\n" );

						for ( uint iModel = 0; iModel < perModelCollectionCount.size(); ++iModel )
						{
							uint uniqueModelIndex = sortedIndices[iModel];

							_printf( "%5u collections (min inst %6u, max inst %6u) of %s\n", perModelCollectionCount[uniqueModelIndex], perModelCollectionMinInstances[uniqueModelIndex], perModelCollectionMaxInstances[uniqueModelIndex], cinput.perModelInstanceCount[uniqueModelIndex].prefixedModelName.c_str() );
						}
					}

					{
						std::vector<uint> collectionsSortedByModelCount( state.collections.size() );
						std::iota( collectionsSortedByModelCount.begin(), collectionsSortedByModelCount.end(), 0 );

						std::sort( collectionsSortedByModelCount.begin(), collectionsSortedByModelCount.end(), [&]( uint a, uint b ) {
							return state.collections[a].models.size() > state.collections[b].models.size();
						} );

						_printf( "Collections by model count:\n" );
						uint lastModelCount = truncate_cast<uint>( state.collections[collectionsSortedByModelCount[0]].models.size() );
						uint numCollections = 1;

						for ( uint iCollection = 1; iCollection < collectionsSortedByModelCount.size(); ++iCollection )
						{
							const StaticModelCollection &collection = state.collections[collectionsSortedByModelCount[iCollection]];
							if ( collection.models.size() != lastModelCount )
							{
								_printf( "%5u collections with %6u models\n", numCollections, lastModelCount );
								numCollections = 0;
								lastModelCount = truncate_cast<uint>( collection.models.size() );
							}

							numCollections += 1;
						}

						_printf( "%5u collections with %6u models\n", numCollections, lastModelCount );
					}

					{
						std::vector<uint> collectionsSortedByTransientCount( state.collections.size() );
						std::iota( collectionsSortedByTransientCount.begin(), collectionsSortedByTransientCount.end(), 0 );

						std::sort( collectionsSortedByTransientCount.begin(), collectionsSortedByTransientCount.end(), [&]( uint a, uint b ) {
							return state.collections[a].transients.size() > state.collections[b].transients.size();
						} );


						_printf( "Collections by transient count:\n" );
						uint lastTransientCount = truncate_cast<uint>( state.collections[collectionsSortedByTransientCount[0]].transients.size() );
						uint numCollections = 1;

						for ( uint iCollection = 1; iCollection < collectionsSortedByTransientCount.size(); ++iCollection )
						{
							const StaticModelCollection &collection = state.collections[collectionsSortedByTransientCount[iCollection]];
							if ( collection.transients.size() != lastTransientCount )
							{
								_printf( "%5u collections intersecting %5u transients\n", numCollections, lastTransientCount );
								numCollections = 0;
								lastTransientCount = truncate_cast<uint>( collection.transients.size() );
							}

							numCollections += 1;
						}

						_printf( "%5u collections intersecting %5u transients\n", numCollections, lastTransientCount );
					}
				}

				if ( solutionFound )
				{
					// Found a solution
					outState = std::move( state );
					return true;
				}

				// Increase maxTriangles after even pass and area after odd pass
				bool increaseTriangleCount = iPass & 1;
				if ( increaseTriangleCount )
				{
					maxTriangles = maxTriangles + static_cast<uint>( maxTriangles * COLLECTION_TRI_COUNT_INCREASE_ON_FAIL );
					maxTriangles = std::min( COLLECTION_MAX_TRIANGLES_HARD_LIMIT, maxTriangles );
				}
				else
				{
					maxArea = maxArea + maxArea * COLLECTION_AREA_INCREASE_ON_FAIL;
				}
			}
		}

		return false;
	}

	bool SettingsTestApp::StartUp()
	{
		const float aspect = (float)dx11_->getBackBufferWidth() / (float)dx11_->getBackBufferHeight();
		projMatrixForCamera_ = perspectiveProjectionDxStyle( deg2rad( 60.0f ), aspect, 1.0f, 100 );
		viewMatrixForCamera_ = ( Matrix4::lookAt( Point3( 5, 5, 5 ), Point3( 0, 0, 0 ), Vector3::yAxis() ) );
		cameraDistance_ = Vector3( 0.0f, 0.0f, 5.0f );

		ID3D11Device* dxDevice = dx11_->getDevice();

		mainDS_.Initialize( dxDevice, dx11_->getBackBufferWidth(), dx11_->getBackBufferHeight(), 1, DXGI_FORMAT_D24_UNORM_S8_UINT, 1, 0, true );

		shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\octahedron.hlslc_packed" );
		octahedronConstants_.Initialize( dxDevice );

		bool multiTransientCollections = true;// g_enableLargeMapBudgets;

		CollectionsBuildInput cinput;

		LoadStaticModelCollectionsData( cinput );

		BuildModelLists( cinput );
		BuildTransientLists( cinput );

		constexpr uint MAX_STATICMODELS = 64 * 1024;
		//uint maxRegularCollections = MAX_STATICMODELS * 2 / 4;
		uint maxRegularCollections = 10000;

		CollectionsBuildParam param;
		param.maxCollectionsToGenerate = maxRegularCollections;
		param.printDetailedInfo = false;
		param.printDetailedInfoOnSuccess = false;

		CollectionsBuildState state;

		if ( multiTransientCollections )
		{
			param.multiTransientCollections = false;

//#if USING( STATIC_MODEL_COLLECTIONS_TRY_SINGLE_TRANSIENT )
//			// First, try creating collections within transient
//			if ( BuildCollections( cinput, param, state ) )
//			{
//				multiTransientCollections = false;
//			}
//			else
//#endif // #if USING( STATIC_MODEL_COLLECTIONS_TRY_SINGLE_TRANSIENT )
			{
				param.multiTransientCollections = true;

				if ( !BuildCollections( cinput, param, state ) )
				{
					Error( "Static model collections failed.\n" );
				}
			}
		}
		else
		{
			if ( !BuildCollections( cinput, param, state ) )
			{
				Error( "Static model collections failed.\n" );
			}
		}

		return true;
	}

	void SettingsTestApp::ShutDown()
	{
	}

	void SettingsTestApp::UpdateCamera( const Timer& timer )
	{
		const float dt = timer.getDeltaSeconds();

		Matrix4 world = inverse( viewMatrixForCamera_ );
		AppBase::UpdateCameraOrbit( world, cameraDistance_, dt * 1.0f );
		viewMatrixForCamera_ = inverse( world );
	}

	void SettingsTestApp::KeyPressed( uint key, bool shift, bool alt, bool ctrl )
	{
		(void)shift;
		(void)alt;
		(void)ctrl;

		if ( key == 'R' || key == 'r' )
		{
			shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\octahedron.hlslc_packed" );
		}
	}

	void SettingsTestApp::MousePressed( uint /*mouseX*/, uint /*mouseY*/ )
	{
	}

	void SettingsTestApp::UpdateAndRender( const Timer& timer )
	{
		fpsCounter_.update(timer);

		Dx11DeviceContext& immediateContextWrapper = dx11_->getImmediateContextWrapper();
		ID3D11DeviceContext* immediateContext = immediateContextWrapper.context;
		immediateContext->ClearState();

		dx11_->SetBackBufferRT();
		// Set default render targets
		ID3D11RenderTargetView* rtviews[1] = { dx11_->getBackBufferRTV() };
		immediateContext->OMSetRenderTargets( 1, rtviews, mainDS_.dsv_ );

		// Setup the viewport
		D3D11_VIEWPORT vp;
		vp.Width = static_cast<float>( dx11_->getBackBufferWidth() );
		vp.Height = static_cast<float>( dx11_->getBackBufferHeight() );
		vp.MinDepth = 0.0f;
		vp.MaxDepth = 1.0f;
		vp.TopLeftX = 0;
		vp.TopLeftY = 0;
		immediateContext->RSSetViewports( 1, &vp );

		const float clearColor[] = { 0.2f, 0.2f, 0.2f, 1 };
		immediateContext->ClearRenderTargetView( dx11_->getBackBufferRTV(), clearColor );
		immediateContext->ClearDepthStencilView( mainDS_.dsv_, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 1, 0 );
		//immediateContext->ClearDepthStencilView( mainDS_.dsv_, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 0, 0 );

		immediateContext->RSSetState( RasterizerStates::BackFaceCull() );
		//immediateContext->OMSetDepthStencilState( DepthStencilStates::DepthWriteEnabled(), 0 );
		immediateContext->OMSetDepthStencilState( DepthStencilStates::DepthDisabled(), 0 );
		//immediateContext->OMSetDepthStencilState( DepthStencilStates::ReverseDepthWriteEnabled(), 0 );

		immediateContextWrapper.BindGlobalSamplers();

		UpdateCamera( timer );


	}

	void SettingsTestApp::UpdateImGui( const Timer& /*timer*/ )
	{
		//ImGui::Text( "Pixel pos [%4u %4u]", mousePixelPosX_, mousePixelPosY_ );

		//{
		//	ImGui::RadioButton( "Faces", reinterpret_cast<int*>( &displayMode_ ), DisplayMode_Faces ); ImGui::SameLine();
		//	ImGui::RadioButton( "Normal", reinterpret_cast<int*>( &displayMode_ ), DisplayMode_Normal ); ImGui::SameLine();
		//	ImGui::RadioButton( "Scene", reinterpret_cast<int*>( &displayMode_ ), DisplayMode_Scene );
		//}
		
		//{
		//	ImGui::Checkbox( "Display Octahedron", &displayOctahedron_ );
		//}

		//if ( ImGui::SliderFloat( "Sample mip level", &sampleMipLevel_, 0.0f, 5.0f ) )
		//{
		//	sampleMipLevelInt_ = static_cast<int>( floorf( sampleMipLevel_ ) );
		//}
		//{
		//	ImGui::SliderInt( "Border width", &borderWidth_, 0, 64 );
		//}

		//if ( ImGui::Button( "Clear color queue" ) )
		//{
		//}
	}
}
