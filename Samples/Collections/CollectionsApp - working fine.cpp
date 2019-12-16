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

	struct StaticModel
	{
		std::string prefixedModelName;
		uint transientIndex;
		vec3_t origin;
		uint numVerts;
		uint lod0TriCount;
		float volume;
		bool candidateForCollection;
		//uint mapOrderIndex;
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

		vec3_t minCorner{};
		vec3_t maxCorner{};

		float volume;
		float area;

		uint totalTris{};
		uint totalVerts{};
	};

	typedef std::unordered_map<std::string, StaticModelCollection> StaticModelCollectionMap;

	struct Transient
	{
		StaticModelCollectionMap initialCollections;
		//std::vector<uint> collectionIndices;

		vec3_t minCorner = { FLT_MAX, FLT_MAX, FLT_MAX };
		vec3_t maxCorner = { -FLT_MAX, -FLT_MAX, -FLT_MAX };

		float volume = 0;
		float area = 0;
	};

	struct TransientState
	{
		std::vector<uint> collectionIndices;
	};

	typedef std::vector<StaticModelCollection> CollectionArray;
	typedef std::map< std::string, ushort > TransientNameToIndexMap;

	struct CollectionsBuildInput
	{
		std::vector<StaticModel> modelsInMapOrder;
		StaticModelInstancesMap perModelInstances;
		std::vector<StaticModelCount> perModelInstanceCount; // count of instances per unique models
		std::unordered_map<std::string, uint> modelNameToUniqueModelIndex;

		TransientNameToIndexMap transientNameToIndex;
		std::vector<Transient> transients;

		vec3_t worldMinCorner{};
		vec3_t worldMaxCorner{};

		float avgTransientVolume = 0;
		float avgTransientArea = 0;
	};

	struct CollectionsBuildParam
	{
		uint maxCollectionsToGenerate = 0;
		bool printDetailedInfo = false;
	};

	struct CollectionsBuildState
	{
		StaticModelCollectionMap initialCollections;
		std::vector<uint> perModelCollectionIndex;
		//std::vector<uint> looseLoadedModels;
		CollectionArray collections;
		std::vector<TransientState> transients;

		uint maxTriangles = 0;
		float maxVolume = 0;
		float maxArea = 0;

		uint modelsInCollectionsCount = 0;
		uint numFailedTotalTris = 0;
		uint numFailedVolume = 0;
		uint numFailedArea = 0;

		CollectionsBuildParam param;
	};

	constexpr uint INVALID_COLLECTION_INDEX = 0xffffffff;

	void CalculateCollectionBounds( const CollectionsBuildInput &cinput, StaticModelCollection &collection )
	{
		collection.minCorner = { FLT_MAX, FLT_MAX, FLT_MAX };
		collection.maxCorner = { -FLT_MAX, -FLT_MAX, -FLT_MAX };

		const StaticModel *sm0 = &cinput.modelsInMapOrder[collection.models[0]];
		collection.totalTris = (uint)collection.models.size() * sm0->lod0TriCount;
		collection.totalVerts = (uint)collection.models.size() * sm0->numVerts;

		for ( size_t iModel = 0; iModel < collection.models.size(); ++iModel )
		{
			const StaticModel *sm = &cinput.modelsInMapOrder[collection.models[iModel]];
			collection.minCorner.x = std::min( collection.minCorner.x, sm->origin.x );
			collection.minCorner.y = std::min( collection.minCorner.y, sm->origin.y );
			collection.minCorner.z = std::min( collection.minCorner.z, sm->origin.z );
			collection.maxCorner.x = std::max( collection.maxCorner.x, sm->origin.x );
			collection.maxCorner.y = std::max( collection.maxCorner.y, sm->origin.y );
			collection.maxCorner.z = std::max( collection.maxCorner.z, sm->origin.z );
		}

		vec3_t size;
		Vec3Sub( collection.maxCorner, collection.minCorner, size );
		collection.volume = size.x * size.y * size.z;
		collection.area = size.x * size.y;
	}

	void AssignModelsToTransients( CollectionsBuildInput &cinput, uint numTransients )
	{
		cinput.transients.resize( numTransients );

		for ( uint iModel = 0; iModel < truncate_cast<uint>( cinput.modelsInMapOrder.size() ); ++iModel )
		{
			StaticModel &sm = cinput.modelsInMapOrder[iModel];
			if ( !sm.candidateForCollection )
			{
				continue;
			}

			{
				Transient &tr = cinput.transients[sm.transientIndex];
				StaticModelCollectionMap::iterator it = tr.initialCollections.find( sm.prefixedModelName );
				if ( it == tr.initialCollections.end() )
				{
					StaticModelCollection cell;
					cell.models.push_back( iModel );
					tr.initialCollections[sm.prefixedModelName] = cell;
				}
				else
				{
					const StaticModel *sm0 = &cinput.modelsInMapOrder[it->second.models[0]];
					assert( sm.transientIndex == sm0->transientIndex );
					it->second.models.push_back( iModel );
				}
			}

			{
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
		}

		double transientTotalVolume = 0;
		double transientTotalArea = 0;

		for ( size_t iTransient = 0; iTransient < cinput.transients.size(); ++iTransient )
		{
			Transient &tr = cinput.transients[iTransient];

			for ( StaticModelCollectionMap::iterator it = tr.initialCollections.begin(); it != tr.initialCollections.end(); ++it )
			{
				StaticModelCollection &collection = it->second;

				CalculateCollectionBounds( cinput, collection );

				tr.minCorner.x = std::min( tr.minCorner.x, collection.minCorner.x );
				tr.minCorner.y = std::min( tr.minCorner.y, collection.minCorner.y );
				tr.minCorner.z = std::min( tr.minCorner.z, collection.minCorner.z );
				tr.maxCorner.x = std::max( tr.maxCorner.x, collection.maxCorner.x );
				tr.maxCorner.y = std::max( tr.maxCorner.y, collection.maxCorner.y );
				tr.maxCorner.z = std::max( tr.maxCorner.z, collection.maxCorner.z );
			}

			vec3_t size;
			Vec3Sub( tr.maxCorner, tr.minCorner, size );
			tr.volume = size.x * size.y * size.z;
			tr.area = size.x * size.y;

			transientTotalVolume += tr.volume;
			transientTotalArea += tr.area;
		}

		cinput.avgTransientVolume = static_cast<float>( transientTotalVolume / cinput.transients.size() );
		cinput.avgTransientArea = static_cast<float>( transientTotalArea / cinput.transients.size() );

		cinput.perModelInstanceCount.reserve( cinput.perModelInstances.size() );

		for ( StaticModelInstancesMap::const_iterator it = cinput.perModelInstances.begin(); it != cinput.perModelInstances.end(); ++it )
		{
			cinput.modelNameToUniqueModelIndex[it->first] = truncate_cast<uint>( cinput.perModelInstanceCount.size() );
			cinput.perModelInstanceCount.push_back( { it->first, truncate_cast<uint>( it->second.instances.size() ) } );
		}

		//{
		//	std::vector<uint> sortedPerModelInstanceCount( cinput.perModelInstanceCount.size() );
		//	std::iota( sortedPerModelInstanceCount.begin(), sortedPerModelInstanceCount.end(), 0 );

		//	std::sort( sortedPerModelInstanceCount.begin(), sortedPerModelInstanceCount.end(), [&]( const uint a, const uint b ) {
		//		return cinput.perModelInstanceCount[a].instanceCount > cinput.perModelInstanceCount[b].instanceCount;
		//	} );

		//	printf( "Model instance counts:\n" );

		//	for ( uint iModel = 0; iModel < cinput.perModelInstanceCount.size(); ++iModel )
		//	{
		//		printf( "%5u instances of %s\n", cinput.perModelInstanceCount[iModel].instanceCount, cinput.perModelInstanceCount[iModel].prefixedModelName.c_str() );
		//	}
		//}
	}

	void LoadStaticModelCollectionsData( CollectionsBuildInput &cinput )
	{
		std::cout << "Loading collections file" << std::endl;

		//std::ifstream infile( "Data/pbr_whitebox_static_model_collections_dump.txt" );
		//std::ifstream infile( "Data/mp_donetsk_static_model_collections_dump.txt" );
		std::ifstream infile( "Data/mp_br_transient_static_model_collections_dump.txt" );
		std::string tmp;
		
		std::getline( infile, tmp );
		
		uint numModels;
		infile >> tmp >> numModels;
		cinput.modelsInMapOrder.resize( numModels );

		uint modelIndex = 0;
		uint maxTransientIndex = 0;

		cinput.worldMinCorner = vec3_t( FLT_MAX, FLT_MAX, FLT_MAX );
		cinput.worldMaxCorner = vec3_t( -FLT_MAX, -FLT_MAX, -FLT_MAX );

		while ( infile && modelIndex < numModels )
		{
			StaticModel &sm = cinput.modelsInMapOrder[modelIndex];
			//sm.mapOrderIndex = modelIndex;
			modelIndex += 1;

			infile >> sm.prefixedModelName;
			infile >> sm.transientIndex;
			infile >> sm.origin.x;
			infile >> sm.origin.y;
			infile >> sm.origin.z;
			infile >> sm.numVerts;
			infile >> sm.lod0TriCount;
			infile >> sm.volume;
			//sm.collectionIndex = 0xffffffff;

			if ( sm.lod0TriCount > 0 )
			{
				maxTransientIndex = std::max( sm.transientIndex, maxTransientIndex );
				sm.candidateForCollection = true;
			}

			cinput.worldMinCorner.x = std::min( cinput.worldMinCorner.x, sm.origin.x );
			cinput.worldMinCorner.y = std::min( cinput.worldMinCorner.y, sm.origin.y );
			cinput.worldMinCorner.z = std::min( cinput.worldMinCorner.z, sm.origin.z );
			cinput.worldMaxCorner.x = std::max( cinput.worldMaxCorner.x, sm.origin.x );
			cinput.worldMaxCorner.y = std::max( cinput.worldMaxCorner.y, sm.origin.y );
			cinput.worldMaxCorner.z = std::max( cinput.worldMaxCorner.z, sm.origin.z );
		}

		AssignModelsToTransients( cinput, maxTransientIndex + 1 );

		std::cout << "Collections file loaded. Num instances " << cinput.modelsInMapOrder.size() << std::endl;
	}

	CollectionsBuildInput s_collectionsInput;

	bool CollectionStopCondition( CollectionsBuildState &state, const StaticModelCollection &collection )
	{
		if ( collection.models.size() == 1 )
		{
			return true;
		}

		//if ( cell.totalTris <= 100000 )
		//{
		//	return true;
		//}

		//return false;

		if ( collection.totalTris >= state.maxTriangles )
		{
			state.numFailedTotalTris += 1;
			return false;
		}

		//if ( cell.volume >= state.maxVolume )
		//{
		//	state.numFailedVolume += 1;
		//	return false;
		//}

		if ( collection.area >= state.maxArea )
		{
			state.numFailedArea += 1;
			return false;
		}

		//return false;

		return true;
	}

	void AddCollection( const CollectionsBuildInput &cinput, CollectionsBuildState &state, StaticModelCollection &collection )
	{
		//Transient &tr = state.transients[cell.models[0]->transientIndex];

		uint collectionIndex = truncate_cast<uint>( state.collections.size() );
		//tr.collectionIndices.push_back( collectionIndex );

		//Collection col;
		//col.models.reserve( cell.models.size() );

		for ( size_t iModel = 0; iModel < collection.models.size(); ++iModel )
		{
			uint mapModelIndex = collection.models[iModel];
			const StaticModel *sm = &cinput.modelsInMapOrder[mapModelIndex];
			//assert( sm->collectionIndex == 0xffffffff );
			//sm->collectionIndex = collectionIndex;
			//col.models.push_back( 
			assert( state.perModelCollectionIndex[mapModelIndex] == 0xffffffff );
			state.perModelCollectionIndex[mapModelIndex] = collectionIndex;

			collection.transients.insert( sm->transientIndex );
		}

		state.modelsInCollectionsCount += truncate_cast<uint>( collection.models.size() );

		for ( TransientIndexSet::const_iterator it = collection.transients.begin(); it != collection.transients.end(); ++it )
		{
			state.transients[*it].collectionIndices.push_back( collectionIndex );
		}

		//state.collections.push_back( std::move( col ) );
		state.collections.push_back( std::move( collection ) );
	}

	void BuildCollectionRecurse( const CollectionsBuildInput &cinput, CollectionsBuildState &state, StaticModelCollection &collection )
	{
		if ( CollectionStopCondition( state, collection ) )
		{
			AddCollection( cinput, state, collection );

			return;
		}

		// Split cell in 4
		//vec3_t cellHalfSizeSize = ( cell.maxCorner - cell.minCorner ) * 0.5f;
		vec3_t cellSize;
		Vec3Sub( collection.maxCorner, collection.minCorner, cellSize );
		vec3_t cellSizeRcp;
		cellSizeRcp.x = cellSize.x > 0.001f ? 1.0f / cellSize.x : 0.0f;
		cellSizeRcp.y = cellSize.y > 0.001f ? 1.0f / cellSize.y : 0.0f;
		cellSizeRcp.z = cellSize.z > 0.001f ? 1.0f / cellSize.z : 0.0f;

		StaticModelCollection newCells[4];
		//for ( uint iCell = 0; iCell < 4; ++iCell )
		//{
		//	newCells[iCell].model = cell.model;
		//}

		//for ( uint x = 0; x < 2; ++x )
		//{
		//	for ( uint y = 0; y < 2; ++y )
		//	{
		//		uint cellIndex = y * 2 + x;
		//		newCells[cellIndex].minCorner.x = cell.minCorner.x + cellHalfSizeSize.x * x;
		//		newCells[cellIndex].minCorner.y = cell.minCorner.y + cellHalfSizeSize.y * y;
		//		newCells[cellIndex].minCorner.z = cell.minCorner.z;

		//		newCells[cellIndex].maxCorner.x = cell.minCorner.x + cellHalfSizeSize.x * ( x + 1);
		//		newCells[cellIndex].maxCorner.y = cell.minCorner.y + cellHalfSizeSize.y * ( x + 1 );
		//		newCells[cellIndex].maxCorner.z = cell.maxCorner.z;
		//	}
		//}

		for ( size_t iModel = 0; iModel < collection.models.size(); ++iModel )
		{
			uint mapModelIndex = collection.models[iModel];
			const StaticModel *sm = &cinput.modelsInMapOrder[ mapModelIndex ];

			//vec3_t p = sm->origin - collection.minCorner;
			//vec3_t p02 = p * cellSizeRcp * 2.0f;
			float px = sm->origin.x - collection.minCorner.x;
			float py = sm->origin.y - collection.minCorner.y;
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

	//void BuildCollections( CollectionsInput &cinput, CollectionsState &state )
	//{
	//	state.transients.resize( cinput.numTransients );

	//	for ( size_t iModel = 0; iModel < cinput.models.size(); ++iModel )
	//	{
	//		StaticModel &sm = cinput.models[iModel];
	//		if ( 0 == sm.numTriangles )
	//		{
	//			continue;
	//		}

	//		Transient &tr = state.transients[sm.transientIndex];
	//		StaticModelMap::iterator it = tr.cellMap.find( sm.modelFullName );
	//		if ( it == tr.cellMap.end() )
	//		{
	//			GridCell cell;
	//			//cell.model = &sm;
	//			cell.models.push_back( &sm );
	//			tr.cellMap[sm.modelFullName] = cell;
	//		}
	//		else
	//		{
	//			assert( sm.transientIndex == it->second.models[0]->transientIndex );
	//			it->second.models.push_back( &sm );
	//		}
	//	}

	//	for ( size_t iTransient = 0; iTransient < state.transients.size(); ++iTransient )
	//	{
	//		Transient &tr = state.transients[iTransient];

	//		for ( StaticModelMap::iterator it = tr.cellMap.begin(); it != tr.cellMap.end(); ++it )
	//		{
	//			GridCell &cell = it->second;

	//			CalculateBounds( cell );
	//			BuildCell( state, cell );
	//		}
	//	}
	//}

	void BuildCollectionsPass( const CollectionsBuildInput &cinput, CollectionsBuildState &state )
	{
		state.perModelCollectionIndex.resize( cinput.modelsInMapOrder.size(), INVALID_COLLECTION_INDEX );
		state.transients.resize( cinput.transients.size() );

		for ( uint iModel = 0; iModel < truncate_cast<uint>( cinput.modelsInMapOrder.size() ); ++iModel )
		{
			const StaticModel &sm = cinput.modelsInMapOrder[iModel];
			if ( 0 == sm.lod0TriCount )
			{
				state.modelsInCollectionsCount += 1;
				continue;
			}

			StaticModelCollectionMap::iterator it = state.initialCollections.find( sm.prefixedModelName );
			if ( it == state.initialCollections.end() )
			{
				StaticModelCollection cell;
				cell.models.push_back( iModel );
				state.initialCollections[sm.prefixedModelName] = cell;
			}
			else
			{
				it->second.models.push_back( iModel );
			}
		}

		for ( StaticModelCollectionMap::iterator it = state.initialCollections.begin(); it != state.initialCollections.end(); ++it )
		{
			StaticModelCollection &cell = it->second;

			CalculateCollectionBounds( cinput, cell );
			BuildCollectionRecurse( cinput, state, cell );
		}

		// sort so single model collections are first
		std::vector<uint> sortedIndices( state.collections.size() );
		std::iota( sortedIndices.begin(), sortedIndices.end(), 0 );

		std::sort( sortedIndices.begin(), sortedIndices.end(), [&]( uint a, uint b ) {
			return state.collections[a].models.size() < state.collections[b].models.size();
		} );

		std::vector<uint> sortedIndicesInv( sortedIndices.size() );
		for ( size_t i = 0; i < sortedIndices.size(); ++i )
			sortedIndicesInv[sortedIndices[i]] = i;

		for ( TransientState &ts : state.transients )
		{
			std::vector<uint> sortedCollectionIndices( ts.collectionIndices.size() );
			for ( size_t iCollection = 0; iCollection < ts.collectionIndices.size(); ++iCollection )
			{
				//sortedCollectionIndices[iCollection] = sortedIndices[ts.collectionIndices[iCollection]];
				sortedCollectionIndices[iCollection] = sortedIndicesInv[ts.collectionIndices[iCollection]];
				//sortedCollectionIndices[iCollection] = sortedIndices[];
			}

			ts.collectionIndices = std::move( sortedCollectionIndices );
		}

		CollectionArray sortedCollections( state.collections.size() );
		for ( size_t iCollection = 0; iCollection < state.collections.size(); ++iCollection )
		{
			sortedCollections[iCollection] = std::move( state.collections[sortedIndices[iCollection]] );
			//sortedCollections[sortedIndices[iCollection]] = std::move( state.collections[iCollection] );
		}

		state.collections = std::move( sortedCollections );

		for ( size_t iTransient = 0; iTransient < state.transients.size(); ++iTransient )
		{
			const TransientState &ts = state.transients[iTransient];
			for ( size_t iCollection = 0; iCollection < ts.collectionIndices.size(); ++iCollection )
			{
				uint collectionIndex = ts.collectionIndices[iCollection];
				const StaticModelCollection &collection = state.collections[collectionIndex];
				TransientIndexSet::const_iterator it = collection.transients.find( iTransient );
				assert( it != collection.transients.end() );
			}
		}

		//std::stable_sort( state.collections.begin(), state.collections.end(), [&]( const StaticModelCollection &a, const StaticModelCollection &b ) {
		//	return a.models.size() < b.models.size();
		//} );
	}

	bool BuildCollections( const CollectionsBuildInput &cinput, const CollectionsBuildParam &param, CollectionsBuildState &outState )
	{
		if ( cinput.perModelInstanceCount.size() > param.maxCollectionsToGenerate )
		{
			// Number of unique models is larger than max collections. Impossible to generate collections.
			return false;
		}

		printf( "Static model collections: %u models, max allowed collections %u, ideal count %u\n", truncate_cast<uint>( cinput.modelsInMapOrder.size() ), param.maxCollectionsToGenerate, truncate_cast<uint>( cinput.perModelInstanceCount.size() ) );

		uint maxTrianglesLimit = 500 * 1000;
		uint maxTriangles = 1 * 100 * 1000;
		float maxVolume = cinput.avgTransientVolume / 64;
		float maxArea = cinput.avgTransientArea / 4;

		constexpr uint maxPasses = 16;

		for ( uint iPass = 0; iPass < maxPasses; ++iPass )
		{
			printf( "\nCollections pass %u: maxTris %u, maxArea %f\n", iPass, maxTriangles, maxArea );

			CollectionsBuildState state;
			state.param = param;
			state.maxTriangles = maxTriangles;
			state.maxVolume = maxVolume;
			state.maxArea = maxArea;

			BuildCollectionsPass( cinput, state );

			if ( state.collections.size() )
			{
				assert( state.modelsInCollectionsCount == truncate_cast<uint>( cinput.modelsInMapOrder.size() ) );

				printf( "Collection count: %u / %u\n", truncate_cast<uint>( state.collections.size() ), param.maxCollectionsToGenerate );
				printf( "Num failed tri count %u: %u\n", state.maxTriangles, state.numFailedTotalTris );
				float volumeSizeApprox = powf( state.maxVolume, 0.3333f );
				printf( "Num failed volume %f - approx %f x %f x %f: %u\n", state.maxVolume, volumeSizeApprox, volumeSizeApprox, volumeSizeApprox, state.numFailedVolume );
				float areaSizeApprox = sqrtf( state.maxArea );
				printf( "Num failed area %f - approx %f x %f: %u\n", state.maxArea, areaSizeApprox, areaSizeApprox, state.numFailedArea );

				//outState.looseLoadedModels.reserve( cinput.modelsInMapOrder.size() );
				//for ( uint iMapModelIndex = 0; iMapModelIndex < state.perModelCollectionIndex.size(); ++iMapModelIndex )
				//{
				//	if ( state.perModelCollectionIndex[iMapModelIndex] != invalidCollectionIndex )
				//	{

				//	}
				//}

				if ( param.printDetailedInfo )
				{
					{
						std::vector<uint> perModelCollectionCount( cinput.perModelInstanceCount.size(), 0 );
						std::vector<uint> perModelCollectionMinInstances( cinput.perModelInstanceCount.size(), 0xffffffff );
						std::vector<uint> perModelCollectionMaxInstances( cinput.perModelInstanceCount.size(), 0 );

						for ( size_t iCollection = 0; iCollection < state.collections.size(); ++iCollection )
						{
							const StaticModelCollection &c = state.collections[iCollection];
							const StaticModel *sm0 = &cinput.modelsInMapOrder[c.models[0]];
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

						printf( "Model collection counts:\n" );

						for ( uint iModel = 0; iModel < perModelCollectionCount.size(); ++iModel )
						{
							uint uniqueModelIndex = sortedIndices[iModel];

							printf( "%5u collections (min inst %6u, max inst %6u) of %s\n", perModelCollectionCount[uniqueModelIndex], perModelCollectionMinInstances[uniqueModelIndex], perModelCollectionMaxInstances[uniqueModelIndex], cinput.perModelInstanceCount[uniqueModelIndex].prefixedModelName.c_str() );
						}
					}

					{
						std::vector<uint> collectionsSortedByModelCount( state.collections.size() );
						std::iota( collectionsSortedByModelCount.begin(), collectionsSortedByModelCount.end(), 0 );

						std::sort( collectionsSortedByModelCount.begin(), collectionsSortedByModelCount.end(), [&]( uint a, uint b ) {
							return state.collections[a].models.size() > state.collections[b].models.size();
						} );

						printf( "Collections by model count:\n" );
						uint lastModelCount = truncate_cast<uint>( state.collections[collectionsSortedByModelCount[0]].models.size() );
						uint numCollections = 1;

						for ( uint iCollection = 1; iCollection < collectionsSortedByModelCount.size(); ++iCollection )
						{
							const StaticModelCollection &collection = state.collections[collectionsSortedByModelCount[iCollection]];
							if ( collection.models.size() != lastModelCount )
							{
								printf( "%5u collections with %6u models\n", numCollections, lastModelCount );
								numCollections = 0;
								lastModelCount = truncate_cast<uint>( collection.models.size() );
							}

							numCollections += 1;
						}

						printf( "%5u collections with %6u models\n", numCollections, lastModelCount );
					}

					{
						std::vector<uint> collectionsSortedByTransientCount( state.collections.size() );
						std::iota( collectionsSortedByTransientCount.begin(), collectionsSortedByTransientCount.end(), 0 );

						std::sort( collectionsSortedByTransientCount.begin(), collectionsSortedByTransientCount.end(), [&]( uint a, uint b ) {
							return state.collections[a].transients.size() > state.collections[b].transients.size();
						} );


						printf( "Collections by transient count:\n" );
						uint lastTransientCount = truncate_cast<uint>( state.collections[collectionsSortedByTransientCount[0]].transients.size() );
						uint numCollections = 1;

						for ( uint iCollection = 1; iCollection < collectionsSortedByTransientCount.size(); ++iCollection )
						{
							const StaticModelCollection &collection = state.collections[collectionsSortedByTransientCount[iCollection]];
							if ( collection.transients.size() != lastTransientCount )
							{
								printf( "%5u collections intersecting %5u transients\n", numCollections, lastTransientCount );
								numCollections = 0;
								lastTransientCount = truncate_cast<uint>( collection.transients.size() );
							}

							numCollections += 1;
						}

						printf( "%5u collections intersecting %5u transients\n", numCollections, lastTransientCount );
					}
				}

				if ( state.collections.size() <= param.maxCollectionsToGenerate )
				{
					// Found a solution
					outState = std::move( state );

					return true;
				}

				// Increase maxTriangles after even pass and area after odd pass
				if ( iPass & 1 )
				{
					//maxTriangles *= 2;
					maxTriangles += 50 * 1000;
					maxTriangles = std::min( maxTriangles, maxTrianglesLimit );
				}
				else
				{
					maxArea *= 2.0f;
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

		LoadStaticModelCollectionsData( s_collectionsInput );

		//if ( s_collectionsInput.modelInstances.size() )
		//{
		//	printf( "Num unique models %u\n", truncate_cast<uint>( s_collectionsInput.perModelInstances.size() ) );
		//}

		//CollectionsBuildState state;
		//InitCollectionState( s_collectionsInput, state );
		//state.maxTriangles = 1 * 200 * 1000;
		//state.maxVolume = s_collectionsInput.avgTransientVolume / 64;
		//state.maxArea = s_collectionsInput.avgTransientArea / 4;
		//BuildCollections2( s_collectionsInput, state );

		//if ( state.collections.size() )
		//{
		//	printf( "Collection count: %u (ideal %u)\n", truncate_cast<uint>( state.collections.size() ), truncate_cast<uint>( s_collectionsInput.perModelInstanceCount.size() ) );
		//	printf( "Num failed tri count %u: %u\n", state.maxTriangles, state.numFailedTotalTris );
		//	float volumeSizeApprox = powf( state.maxVolume, 0.3333f );
		//	printf( "Num failed volume %f - approx %f x %f x %f: %u\n", state.maxVolume, volumeSizeApprox, volumeSizeApprox, volumeSizeApprox, state.numFailedVolume );
		//	float areaSizeApprox = sqrtf( state.maxArea );
		//	printf( "Num failed area %f - approx %f x %f: %u\n", state.maxArea, areaSizeApprox, areaSizeApprox, state.numFailedArea );

		//	{
		//		std::vector<uint> perModelCollectionCount( s_collectionsInput.perModelInstanceCount.size(), 0 );
		//		std::vector<uint> perModelCollectionMinInstances( s_collectionsInput.perModelInstanceCount.size(), 0xffffffff );
		//		std::vector<uint> perModelCollectionMaxInstances( s_collectionsInput.perModelInstanceCount.size(), 0 );

		//		for ( size_t iCollection = 0; iCollection < state.collections.size(); ++iCollection )
		//		{
		//			const StaticModelCollection &c = state.collections[iCollection];
		//			std::unordered_map<std::string, size_t>::const_iterator it = s_collectionsInput.modelNameToUniqueModelIndex.find( c.models[0]->prefixedModelName );
		//			assert( it != s_collectionsInput.modelNameToUniqueModelIndex.end() );
		//			perModelCollectionCount[it->second] += 1;
		//			perModelCollectionMinInstances[it->second] = std::min( perModelCollectionMinInstances[it->second], truncate_cast<uint>( c.models.size() ) );
		//			perModelCollectionMaxInstances[it->second] = std::max( perModelCollectionMaxInstances[it->second], truncate_cast<uint>( c.models.size() ) );
		//		}
	
		//		std::vector<uint> sortedIndices( perModelCollectionCount.size() );
		//		std::iota( sortedIndices.begin(), sortedIndices.end(), 0 );

		//		std::sort( sortedIndices.begin(), sortedIndices.end(), [&]( uint a, uint b ) {
		//			return perModelCollectionCount[a] > perModelCollectionCount[b];
		//		} );

		//		printf( "Model collection counts:\n" );

		//		for ( uint iModel = 0; iModel < perModelCollectionCount.size(); ++iModel )
		//		{
		//			uint uniqueModelIndex = sortedIndices[iModel];

		//			printf( "%5u collections (min inst %6u, max inst %6u) of %s\n", perModelCollectionCount[uniqueModelIndex], perModelCollectionMinInstances[uniqueModelIndex], perModelCollectionMaxInstances[uniqueModelIndex], s_collectionsInput.perModelInstanceCount[uniqueModelIndex].prefixedModelName.c_str() );
		//		}
		//	}

		//	{
		//		std::vector<uint> collectionsSortedByModelCount( state.collections.size() );
		//		std::iota( collectionsSortedByModelCount.begin(), collectionsSortedByModelCount.end(), 0 );

		//		std::sort( collectionsSortedByModelCount.begin(), collectionsSortedByModelCount.end(), [&]( uint a, uint b ) {
		//			return state.collections[a].models.size() > state.collections[b].models.size();
		//		} );

		//		printf( "Collections by model count:\n" );
		//		uint lastModelCount = truncate_cast<uint>( state.collections[collectionsSortedByModelCount[0]].models.size() );
		//		uint numCollections = 1;

		//		for ( uint iCollection = 1; iCollection < collectionsSortedByModelCount.size(); ++iCollection )
		//		{
		//			const StaticModelCollection &collection = state.collections[collectionsSortedByModelCount[iCollection]];
		//			if ( collection.models.size() != lastModelCount )
		//			{
		//				printf( "%5u collections with %6u models\n", numCollections, lastModelCount );
		//				numCollections = 0;
		//				lastModelCount = truncate_cast<uint>( collection.models.size() );
		//			}

		//			numCollections += 1;
		//		}

		//		printf( "%5u collections with %6u models\n", numCollections, lastModelCount );
		//	}

		//	{
		//		std::vector<uint> collectionsSortedByTransientCount( state.collections.size() );
		//		std::iota( collectionsSortedByTransientCount.begin(), collectionsSortedByTransientCount.end(), 0 );

		//		std::sort( collectionsSortedByTransientCount.begin(), collectionsSortedByTransientCount.end(), [&]( uint a, uint b ) {
		//			return state.collections[a].transients.size() > state.collections[b].transients.size();
		//		} );


		//		printf( "Collections by transient count:\n" );
		//		uint lastTransientCount = truncate_cast<uint>( state.collections[collectionsSortedByTransientCount[0]].transients.size() );
		//		uint numCollections = 1;

		//		for ( uint iCollection = 1; iCollection < collectionsSortedByTransientCount.size(); ++iCollection )
		//		{
		//			const StaticModelCollection &collection = state.collections[collectionsSortedByTransientCount[iCollection]];
		//			if ( collection.transients.size() != lastTransientCount )
		//			{
		//				printf( "%5u collections intersecting %5u transients\n", numCollections, lastTransientCount );
		//				numCollections = 0;
		//				lastTransientCount = truncate_cast<uint>( collection.transients.size() );
		//			}

		//			numCollections += 1;
		//		}

		//		printf( "%5u collections intersecting %5u transients\n", numCollections, lastTransientCount );
		//	}
		//}

		CollectionsBuildParam param;
		//param.maxCollectionsToGenerate = ( 64 * 1024 ) / 4 * 3;
		param.maxCollectionsToGenerate = 10 * 1024;

		CollectionsBuildState compiledCollections;
		BuildCollections( s_collectionsInput, param, compiledCollections );

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
