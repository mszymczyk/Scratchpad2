#include "DirectDeltaMushSkinning_pch.h"
#include "DirectDeltaMushSkinning.h"
#include <Gfx\Dx11/Dx11DeviceStates.h>
#include <Gfx\DebugDraw.h>
#include <Util/Hash/HashUtil.h>
#include <Gfx\Math\HLSLEmulation.h>
#include "..\..\..\3rdParty\assimp-4.1.0\include\assimp\Importer.hpp"
#include "..\..\..\3rdParty\assimp-4.1.0\include\assimp\Exporter.hpp"
#include "..\..\..\3rdParty\assimp-4.1.0\include\assimp\scene.h"
#include "..\..\..\3rdParty\assimp-4.1.0\include\assimp\postprocess.h"


namespace spad
{
	bool DirectDeltaMushSkinning::StartUp()
	{
		ID3D11Device* dxDevice = dx11_->getDevice();

		shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\skinning.hlslc_packed" );
		passConstants_.Initialize( dxDevice );
		objectConstants_.Initialize( dxDevice );
		skinningConstants_.Initialize( dxDevice );

		viewMatrixForCamera_ = ( Matrix4::lookAt( Point3( 7, 7, 7 ), Point3( 0, 0, 0 ), Vector3::yAxis() ) );

		const float aspect = (float)dx11_->getBackBufferWidth() / (float)dx11_->getBackBufferHeight();
		projMatrixForCamera_ = perspectiveProjectionDxStyle( deg2rad( 60.0f ), aspect, 1.0f, 1000.0f );

		LoadModelsWithAssimp( dxDevice, "Assets\\DirectDeltaMushSkinning\\ddm_box_smooth.fbx" );
		//PrecomputeDDM( meshes[0] );

		return true;
	}

	void DirectDeltaMushSkinning::ShutDown()
	{
	}

	void DirectDeltaMushSkinning::UpdateCamera( const Timer& timer )
	{
		const float dt = timer.getDeltaSeconds();

		Matrix4 world = inverse( viewMatrixForCamera_ );
		AppBase::UpdateCamera( world, dt * 5.0f );
		viewMatrixForCamera_ = inverse( world );
	}

	void DirectDeltaMushSkinning::UpdateAndRender( const Timer& timer )
	{
		UpdateCamera( timer );

		Dx11DeviceContext& immediateContextWrapper = dx11_->getImmediateContextWrapper();
		ID3D11DeviceContext* immediateContext = immediateContextWrapper.context;
		immediateContext->ClearState();

		// Set default render targets
		ID3D11RenderTargetView* rtviews[1] = { dx11_->getBackBufferRTV() };
		immediateContext->OMSetRenderTargets( 1, rtviews, nullptr );

		// Setup the viewport
		D3D11_VIEWPORT vp;
		vp.Width = static_cast<float>( dx11_->getBackBufferWidth() );
		vp.Height = static_cast<float>( dx11_->getBackBufferHeight() );
		vp.MinDepth = 0.0f;
		vp.MaxDepth = 1.0f;
		vp.TopLeftX = 0;
		vp.TopLeftY = 0;
		immediateContext->RSSetViewports( 1, &vp );

		const float clearColor[] = { 0.1f, 0.1f, 0.1f, 1 };
		immediateContext->ClearRenderTargetView( dx11_->getBackBufferRTV(), clearColor );

		SkinMesh( meshes[0], timer );
		DrawMesh( meshes[0] );

		Vector4 plane( 0, 1, 0, 0 );
		debugDraw::AddPlaneWS( plane, 6, 6, 6, 6, 0xff0000ff, 1, false );
		debugDraw::AddAxes( Vector3( 0.0f ), Vector3( 3.0f ), Matrix3::identity(), 1.0f );

		debugDraw::DontTouchThis::Draw( immediateContextWrapper, viewMatrixForCamera_, projMatrixForCamera_, dx11_->getBackBufferWidth(), dx11_->getBackBufferHeight() );
		debugDraw::DontTouchThis::Clear();
	}


	void DirectDeltaMushSkinning::KeyPressed( uint key, bool shift, bool alt, bool ctrl )
	{
		(void)shift;
		(void)alt;
		(void)ctrl;

		if ( key == 'R' || key == 'r' )
		{
			shader_ = LoadCompiledFxFile( "DataWin\\Shaders\\hlsl\\compiled\\skinning.hlslc_packed" );
		}
	}

	Matrix4 EvaluateBoneAnim( const DDMMesh::BoneAnimation &banim, float time )
	{
		Vector3 trans;
		Quat rot;

		{
			if ( time <= banim.translateKeys.front().getW().getAsFloat() )
			{
				trans = banim.translateKeys.front().getXYZ();
			}
			else if ( time >= banim.translateKeys.back().getW().getAsFloat() )
			{
				trans = banim.translateKeys.back().getXYZ();
			}
			else
			{
				size_t iKey = banim.translateKeys.size() - 1;
				float keyTime = 0;
				for ( ; iKey-- > 0; )
				{
					keyTime = banim.translateKeys[iKey].getW().getAsFloat();
					if ( time >= keyTime )
					{
						break;
					}
				}

				size_t iKeyNext = iKey + 1;
				float keyNextTime = banim.translateKeys[iKeyNext].getW().getAsFloat();

				float r = keyNextTime - keyTime;
				float t = ( time - keyTime ) / std::max( r, FLT_EPSILON );
				t = std::min( t, 1.0f );

				trans = lerp( t, banim.translateKeys[iKey].getXYZ(), banim.translateKeys[iKeyNext].getXYZ() );
			}
		}

		{
			if ( time <= banim.rotateKeyTimes.front() )
			{
				rot = banim.rotateKeys.front();
			}
			else if ( time >= banim.rotateKeyTimes.back() )
			{
				rot = banim.rotateKeys.back();
			}
			else
			{
				size_t iKey = banim.rotateKeyTimes.size() - 1;
				float keyTime = 0;
				for ( ; iKey-- > 0; )
				{
					keyTime = banim.rotateKeyTimes[iKey];
					if ( time >= keyTime )
					{
						break;
					}
				}

				size_t iKeyNext = iKey + 1;
				float keyNextTime = banim.rotateKeyTimes[iKeyNext];

				float r = keyNextTime - keyTime;
				float t = ( time - keyTime ) / std::max( r, FLT_EPSILON );
				t = std::min( t, 1.0f );

				rot = slerp( t, banim.rotateKeys[iKey], banim.rotateKeys[iKeyNext] );
			}
		}

		return Matrix4( rot, trans );
	}

	void DirectDeltaMushSkinning::SkinMesh( DDMMesh &mesh, const Timer& timer )
	{
		Dx11DeviceContext& deviceContext = dx11_->getImmediateContextWrapper();

		deviceContext.BeginMarker( "SkinMesh" );

		const HlslShaderPass& fxPass = *shader_->getPass( "cs_linear_blend_skinning" );
		fxPass.setCS( deviceContext.context );

		const uint numVertices = truncate_cast<uint>( mesh.vertices.size() );

		skinningConstants_.data.numVertices = numVertices;
		skinningConstants_.updateGpu( deviceContext.context );
		skinningConstants_.setCS( deviceContext.context, REGISTER_CBUFFER_SKINNING_CONSTANTS );

		Matrix4 *bonesScratch = mesh.bonesScratch.data();

		if ( !mesh.animations.empty() )
		{
			const DDMMesh::Animation &anim = mesh.animations[0];

			for ( size_t iBoneAnim = 0; iBoneAnim < anim.boneAnims.size(); ++iBoneAnim )
			{
				const DDMMesh::BoneAnimation &banim = anim.boneAnims[iBoneAnim];
				Matrix4 m = EvaluateBoneAnim( banim, animTime_ );
				mesh.graph.localPoses[banim.graphNodeIndex] = m;
			}

			mesh.graph.globalPoses[0] = mesh.graph.localPoses[0];
			for ( size_t iNode = 1; iNode < mesh.graph.globalPoses.size(); ++iNode )
			{
				int parentIndex = mesh.graph.parents[iNode];
				mesh.graph.globalPoses[iNode] = mesh.graph.globalPoses[parentIndex] * mesh.graph.localPoses[iNode];
			}

			for ( size_t iBone = 0; iBone < mesh.bones.size(); ++iBone )
			{
				const DDMMesh::Bone &bone = mesh.bones[iBone];
				bonesScratch[iBone] = mesh.graph.globalPoses[bone.graphNodeIndex] * bone.bindMatrix;
			}

			animTime_ += timer.getDeltaSeconds();
			animTime_ = fmodf( animTime_, anim.durationSeconds );
		}
		else
		{
			for ( size_t iBone = 0; iBone < mesh.bones.size(); ++iBone )
			{
				bonesScratch[iBone] = Matrix4::identity();
			}
		}

		mesh.bonesBuffer.updateGpu( deviceContext.context, bonesScratch );
		mesh.bonesBuffer.setCS_SRV( deviceContext.context, REGISTER_BUFFER_SKINNING_IN_SKINNING_MATRICES );

		mesh.baseVertices.setCS_SRV( deviceContext.context, REGISTER_BUFFER_SKINNING_IN_BASE_VERTICES );
		mesh.skinnedVertices.setCS_UAV( deviceContext.context, REGISTER_BUFFER_SKINNING_OUT_SKINNED_VERTICES );

		uint nGroupsX = ( numVertices + SKINNING_NUM_THREADS_X - 1 ) / SKINNING_NUM_THREADS_X;
		deviceContext.context->Dispatch( nGroupsX, 1, 1 );

		deviceContext.UnbindCSUAVs();

		deviceContext.EndMarker();
	}

	void DirectDeltaMushSkinning::DrawMesh( DDMMesh &mesh )
	{
		Dx11DeviceContext& deviceContext = dx11_->getImmediateContextWrapper();
		ID3D11DeviceContext* immediateContext = deviceContext.context;

		deviceContext.BeginMarker( "DrawMesh" );

		passConstants_.data.Projection = ToFloat4x4( projMatrixForCamera_ );
		passConstants_.data.View = ToFloat4x4( viewMatrixForCamera_ );
		passConstants_.data.ViewProjection = ToFloat4x4( projMatrixForCamera_ * viewMatrixForCamera_ );
		passConstants_.updateGpu( deviceContext.context );
		passConstants_.setVS( deviceContext.context, REGISTER_CBUFFER_PASS_CONSTANTS );
		passConstants_.setPS( deviceContext.context, REGISTER_CBUFFER_PASS_CONSTANTS );

		objectConstants_.data.World = ToFloat4x4( Matrix4::identity() );
		objectConstants_.data.WorldIT = ToFloat4x4( Matrix4::identity() ); // transpose( inverse( world ) );
		objectConstants_.updateGpu( deviceContext.context );
		objectConstants_.setVS( deviceContext.context, REGISTER_CBUFFER_OBJECT_CONSTANTS );
		objectConstants_.setPS( deviceContext.context, REGISTER_CBUFFER_OBJECT_CONSTANTS );

		const HlslShaderPass& fxPass = *shader_->getPass( "draw_model" );
		fxPass.setVS( deviceContext.context );
		fxPass.setPS( deviceContext.context );

		deviceContext.context->RSSetState( RasterizerStates::WireframeBackFaceCull() );
		deviceContext.context->OMSetBlendState( BlendStates::blendDisabled, nullptr, 0xffffffff );
		deviceContext.context->IASetPrimitiveTopology( D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST );
		deviceContext.context->OMSetDepthStencilState( DepthStencilStates::DepthEnabled(), 0 );

		deviceContext.context->IASetInputLayout( nullptr );
		deviceContext.context->IASetIndexBuffer( mesh.indexBuffer, DXGI_FORMAT_R32_UINT, 0 );

		mesh.skinnedVertices.setVS_SRV( immediateContext, REGISTER_BUFFER_SKINNING_IN_SKINNED_VERTICES );

		deviceContext.context->DrawIndexed( truncate_cast<uint>( mesh.indices.size() ), 0, 0 );

		deviceContext.EndMarker();
	}

	//const aiNode *FindAiNode_r( const aiNode *node, const aiString &nodeName )
	//{
	//	if ( node->mName == nodeName )
	//	{
	//		return node;
	//	}

	//	for ( uint iChild = 0; iChild < node->mNumChildren; ++iChild )
	//	{
	//		const aiNode *res = FindAiNode_r( node->mChildren[iChild], nodeName );
	//		if ( res )
	//		{
	//			return res;
	//		}
	//	}

	//	return nullptr;
	//}

	//const aiNode *FindAiNode( const aiScene *scene, const aiString &nodeName )
	//{
	//	return FindAiNode_r( scene->mRootNode, nodeName );
	//}

	static void CountNodes_r( const aiNode *node, uint &outNodeCount )
	{
		outNodeCount += 1;

		for ( uint iChild = 0; iChild < node->mNumChildren; ++iChild )
		{
			CountNodes_r( node->mChildren[iChild], outNodeCount );
		}
	}

	static void FillGraph_r( const aiNode *node, DDMMesh::Graph &graph, int &nodeIndex, int parentIndex )
	{
		nodeIndex += 1;

		graph.nodes[nodeIndex] = node->mName.C_Str();
		graph.parents[nodeIndex] = parentIndex;
		memcpy( &graph.origPoses[nodeIndex], &node->mTransformation, sizeof( Matrix4 ) );
		graph.localPoses[nodeIndex] = graph.origPoses[nodeIndex];

		int newParentIndex = nodeIndex;
		for ( uint iChild = 0; iChild < node->mNumChildren; ++iChild )
		{
			FillGraph_r( node->mChildren[iChild], graph, nodeIndex, newParentIndex );
		}
	}

	uint FindGraphNodeIndex( const DDMMesh::Graph &graph, const char *name )
	{
		for ( size_t i = 0; i < graph.nodes.size(); ++i )
		{
			if ( graph.nodes[i] == name )
			{
				return truncate_cast<uint>( i );
			}
		}

		SPAD_ASSERTMSG( "node not found" );
		return 0xffffffff;
	}

	void DirectDeltaMushSkinning::LoadModelsWithAssimp( ID3D11Device* device, const char* fileName )
	{
		SPAD_ASSERT( FileExists( fileName ) );

		std::string fileDirectory = GetDirectoryFromFilePath( fileName );

		const aiScene* scene = nullptr;

		std::string assbinFileName = fileName;
		assbinFileName.append( ".assbin" );

		Assimp::Importer importer;

		if ( FileExists( assbinFileName.c_str() ) )
		{
			scene = importer.ReadFile( assbinFileName.c_str(), 0 );

			if ( scene == nullptr )
			{
				THROW_MESSAGE( "Failed to load model %s. Err: ", fileName, importer.GetErrorString() );
			}
		}
		else
		{
			scene = importer.ReadFile( fileName, 0 );

			if ( scene == nullptr )
			{
				THROW_MESSAGE( "Failed to load model %s. Err: ", fileName, importer.GetErrorString() );
			}

			if ( scene->mNumMeshes == 0 )
				THROW_MESSAGE( "Scene %s has no meshes", fileName );

			if ( scene->mNumMaterials == 0 )
				THROW_MESSAGE( "Scene %s has no materials" );

			// Post-process the scene
			uint flags = 0;
			//flags |= aiProcess_CalcTangentSpace;
			flags |= aiProcess_Triangulate;
			flags |= aiProcess_JoinIdenticalVertices;
			//flags |= aiProcess_MakeLeftHanded;
			flags |= aiProcess_RemoveRedundantMaterials;
			flags |= aiProcess_FlipUVs;
			//flags |= aiProcess_FlipWindingOrder;
			//flags |= aiProcess_PreTransformVertices;
			//flags |= aiProcess_OptimizeMeshes;
			flags |= aiProcess_LimitBoneWeights;

			scene = importer.ApplyPostProcessing( flags );

			Assimp::Exporter exporter;
			aiReturn ret = exporter.Export( scene, "assbin", assbinFileName.c_str(), 0, nullptr );
			if ( ret != aiReturn_SUCCESS )
			{
				THROW_MESSAGE( "Couldn't export %s to %s", fileName, assbinFileName.c_str() );
			}
		}

		const uint numMeshes = scene->mNumMeshes;
		meshes.resize( numMeshes );

		for ( uint iMesh = 0; iMesh < numMeshes; ++iMesh )
		{
			const aiMesh &assimpMesh = *scene->mMeshes[iMesh];

			SPAD_ASSERT( assimpMesh.HasPositions() );
			SPAD_ASSERT( assimpMesh.HasNormals() );
			SPAD_ASSERT( assimpMesh.HasBones() );

			DDMMesh &mesh = meshes[iMesh];

			const uint numVertices = assimpMesh.mNumVertices;
			const uint numTriangles = assimpMesh.mNumFaces;

			mesh.vertices.resize( numVertices );

			for ( uint iVert = 0; iVert < numVertices; ++iVert )
			{
				const aiVector3D &aip = assimpMesh.mVertices[iVert];
				const aiVector3D &ain = assimpMesh.mNormals[iVert];

				BaseVertex &dst = mesh.vertices[iVert];
				dst.numWeights = 0;

				dst.x = aip.x;
				dst.y = aip.y;
				dst.z = aip.z;
				dst.nx = ain.x;
				dst.ny = ain.y;
				dst.nz = ain.z;

				if ( assimpMesh.HasTextureCoords( 0 ) )
				{
					const aiVector3D &ait = assimpMesh.mTextureCoords[0][iVert];
					dst.tx = ait.x;
					dst.ty = ait.y;
				}
				else
				{
					dst.tx = 0;
					dst.ty = 0;
				}
			}

			//{
			//	D3D11_BUFFER_DESC bufferDesc;
			//	ZeroMemory( &bufferDesc, sizeof( bufferDesc ) );
			//	bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
			//	bufferDesc.ByteWidth = numVertices * sizeof( float ) * 8;
			//	bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
			//	bufferDesc.CPUAccessFlags = 0;
			//	bufferDesc.MiscFlags = 0;
			//	bufferDesc.StructureByteStride = 0;

			//	D3D11_SUBRESOURCE_DATA initData;
			//	initData.pSysMem = mesh.vertices;
			//	initData.SysMemPitch = 0;
			//	initData.SysMemSlicePitch = 0;
			//	DXCall( device->CreateBuffer( &bufferDesc, &initData, &mesh.vertexBuffer ) );
			//}

			//mesh.inputElements.resize( 3 );
			//mesh.inputElements[0] = { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 };
			//mesh.inputElements[1] = { "NORMAL", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 };
			//mesh.inputElements[2] = { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 24, D3D11_INPUT_PER_VERTEX_DATA, 0 };

			//memstream ms;
			//ms.write( reinterpret_cast<const u8*>( &mesh.inputElements[0] ), mesh.inputElements.size() * sizeof( D3D11_INPUT_ELEMENT_DESC ) );
			//for ( const auto& e : mesh.inputElements )
			//	ms.write( e.SemanticName );

			//mesh.inputElementsHash = MurmurHash3( ms.data(), (int)ms.size() );

			mesh.indices.resize( numTriangles * 3 );
			uint *dstIndices = mesh.indices.data();

			for ( uint triIdx = 0; triIdx < numTriangles; ++triIdx )
			{
				dstIndices[triIdx * 3 + 0] = static_cast<u16>( assimpMesh.mFaces[triIdx].mIndices[0] );
				dstIndices[triIdx * 3 + 1] = static_cast<u16>( assimpMesh.mFaces[triIdx].mIndices[1] );
				dstIndices[triIdx * 3 + 2] = static_cast<u16>( assimpMesh.mFaces[triIdx].mIndices[2] );
			}

			{
				D3D11_BUFFER_DESC bufferDesc;
				ZeroMemory( &bufferDesc, sizeof( bufferDesc ) );
				bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
				bufferDesc.ByteWidth = numTriangles * 3 * sizeof( uint );
				bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
				bufferDesc.CPUAccessFlags = 0;
				bufferDesc.MiscFlags = 0;
				bufferDesc.StructureByteStride = 0;

				D3D11_SUBRESOURCE_DATA initData;
				initData.pSysMem = mesh.indices.data();
				initData.SysMemPitch = 0;
				initData.SysMemSlicePitch = 0;
				DXCall( device->CreateBuffer( &bufferDesc, &initData, &mesh.indexBuffer ) );
			}

			uint nodeCount = 0;
			CountNodes_r( scene->mRootNode, nodeCount );

			mesh.graph.nodes.resize( nodeCount );
			mesh.graph.parents.resize( nodeCount );
			mesh.graph.origPoses.resize( nodeCount );
			mesh.graph.localPoses.resize( nodeCount );
			mesh.graph.globalPoses.resize( nodeCount );

			int nodeIndex = -1, parentIndex = -1;
			FillGraph_r( scene->mRootNode, mesh.graph, nodeIndex, parentIndex );

			const uint numBones = assimpMesh.mNumBones;
			mesh.bones.resize( numBones );
			mesh.bonesScratch.resize( numBones );

			for ( uint boneIdx = 0; boneIdx < numBones; ++boneIdx )
			{
				const aiBone *aib = assimpMesh.mBones[boneIdx];
				DDMMesh::Bone &bone = mesh.bones[boneIdx];

				bone.name = aib->mName.C_Str();
				bone.graphNodeIndex = FindGraphNodeIndex( mesh.graph, bone.name.c_str() );

				memcpy( &bone.bindMatrix, &aib->mOffsetMatrix, sizeof( float ) * 16 );

				for ( uint weightIdx = 0; weightIdx < aib->mNumWeights; ++weightIdx )
				{
					const aiVertexWeight &aiw = aib->mWeights[weightIdx];
					SPAD_ASSERT( aiw.mVertexId < numVertices );
					BaseVertex &dst = mesh.vertices[aiw.mVertexId];
					SPAD_ASSERT( dst.numWeights < 4 );
					dst.w[dst.numWeights] = aiw.mWeight;
					dst.b[dst.numWeights] = boneIdx;
					dst.numWeights += 1;
				}
			}

			mesh.baseVertices.Initialize( device, numVertices, mesh.vertices.data(), true, false, false, false );
			mesh.skinnedVertices.Initialize( device, numVertices, nullptr, false, true, false, false );

			mesh.bonesBuffer.Initialize( device, numBones, nullptr, false, false, false, false );

			if ( scene->HasAnimations() )
			{
				const uint numAnimations = scene->mNumAnimations;
				for ( uint iAnim = 0; iAnim < numAnimations; ++iAnim )
				{
					const aiAnimation *aiAnim = scene->mAnimations[iAnim];
					mesh.animations.emplace_back();
					DDMMesh::Animation &anim = mesh.animations.back();
					anim.durationSeconds = 0.0f;

					for ( uint iChannel = 0; iChannel < aiAnim->mNumChannels; ++iChannel )
					{
						const aiNodeAnim *aiChannel = aiAnim->mChannels[iChannel];

						anim.boneAnims.emplace_back();
						DDMMesh::BoneAnimation &banim = anim.boneAnims.back();

						banim.graphNodeIndex = FindGraphNodeIndex( mesh.graph, aiChannel->mNodeName.C_Str() );
						banim.translateKeys.resize( aiChannel->mNumPositionKeys );
						banim.rotateKeys.resize( aiChannel->mNumRotationKeys );
						banim.rotateKeyTimes.resize( aiChannel->mNumRotationKeys );

						for ( uint iKey = 0; iKey < aiChannel->mNumPositionKeys; ++iKey )
						{
							const aiVectorKey &key = aiChannel->mPositionKeys[iKey];
							const float timeSeconds = static_cast<float>( key.mTime / aiAnim->mTicksPerSecond );
							banim.translateKeys[iKey] = Vector4( key.mValue.x, key.mValue.y, key.mValue.z, timeSeconds );
							anim.durationSeconds = std::max( anim.durationSeconds, timeSeconds );
						}

						for ( uint iKey = 0; iKey < aiChannel->mNumRotationKeys; ++iKey )
						{
							const aiQuatKey &key = aiChannel->mRotationKeys[iKey];
							const float timeSeconds = static_cast<float>( key.mTime / aiAnim->mTicksPerSecond );
							banim.rotateKeys[iKey] = Quat( key.mValue.x, key.mValue.y, key.mValue.z, key.mValue.w );
							banim.rotateKeyTimes[iKey] = timeSeconds;
							anim.durationSeconds = std::max( anim.durationSeconds, timeSeconds );
						}
					}
				}
			}
		}
	}

	void DirectDeltaMushSkinning::PrecomputeDDM( DDMMesh &mesh )
	{
		spad::PrecomputeDDM( mesh );
	}

}
