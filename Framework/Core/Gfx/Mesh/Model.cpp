#include "Gfx_pch.h"

#include "Model.h"

#include "SDKmesh.h"
#include "..\..\..\3rdParty\assimp-4.1.0\include\assimp\Importer.hpp"
#include "..\..\..\3rdParty\assimp-4.1.0\include\assimp\Exporter.hpp"
#include "..\..\..\3rdParty\assimp-4.1.0\include\assimp\scene.h"
#include "..\..\..\3rdParty\assimp-4.1.0\include\assimp\postprocess.h"
#include <Util\Exceptions.h>
#include <Util/StdHelp.h>
#include <Util/Hash/HashUtil.h>


// Gets an index from an index buffer
inline uint32_t GetIndex( const void* indices, uint32_t idx, uint32_t indexSize )
{
	if ( indexSize == 2 )
		return reinterpret_cast<const uint16_t*>( indices )[idx];
	else
		return reinterpret_cast<const uint32_t*>( indices )[idx];
}

//using std::string;
//using std::wstring;
//using std::vector;
//using std::map;
//using std::wifstream;

namespace spad
{

static const D3D11_INPUT_ELEMENT_DESC VertexInputs[5] =
{
    { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "NORMAL", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 24, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "TANGENT", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 32, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "BITANGENT", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 44, D3D11_INPUT_PER_VERTEX_DATA, 0 },
};

Mesh::Mesh() :  inputElementsHash(0),
				vertexStride(0),
                numVertices(0),
                numIndices(0)
{
}

Mesh::~Mesh()
{
}

void Mesh::Initialize(ID3D11Device* device, SDKMesh& sdkMesh, uint32_t meshIdx, bool generateTangents)
{
    const SDKMESH_MESH& sdkMeshData = *sdkMesh.GetMesh(meshIdx);

    uint32_t indexSize = 2;
    indexType = Mesh::Index16Bit;
    if(sdkMesh.GetIndexType(meshIdx) == IT_32BIT)
    {
        indexSize = 4;
        indexType = Mesh::Index32Bit;
    }

    vertexStride = sdkMesh.GetVertexStride(meshIdx, 0);
    numVertices = static_cast<uint32_t>(sdkMesh.GetNumVertices(meshIdx, 0));
    numIndices = static_cast<uint32_t>(sdkMesh.GetNumIndices(meshIdx));
    const uint32_t vbIdx = sdkMeshData.VertexBuffers[0];
    const uint32_t ibIdx = sdkMeshData.IndexBuffer;

    CreateInputElements(sdkMesh.VBElements(0));

    vertices.resize(vertexStride * numVertices, 0);
    memcpy(vertices.data(), sdkMesh.GetRawVerticesAt(vbIdx), vertexStride * numVertices);

    indices.resize(indexSize * numIndices, 0);
    memcpy(indices.data(), sdkMesh.GetRawIndicesAt(ibIdx), indexSize * numIndices);

    if(generateTangents)
        GenerateTangentFrame();

    D3D11_BUFFER_DESC bufferDesc;
    bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
    bufferDesc.ByteWidth = vertexStride * numVertices;
    bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    bufferDesc.CPUAccessFlags = 0;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    D3D11_SUBRESOURCE_DATA initData;
    initData.pSysMem = vertices.data();
    initData.SysMemPitch = 0;
    initData.SysMemSlicePitch = 0;
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &vertexBuffer));

    bufferDesc.ByteWidth = indexSize * numIndices;
    bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    initData.pSysMem = indices.data();
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &indexBuffer));

    const uint32_t numSubsets = sdkMesh.GetNumSubsets(meshIdx);
    meshParts.resize(numSubsets);
    for(uint32_t i = 0; i < numSubsets; ++i)
    {
        const SDKMESH_SUBSET& subset = *sdkMesh.GetSubset(meshIdx, i);
        MeshPart& part = meshParts[i];
        part.IndexStart = static_cast<uint32_t>(subset.IndexStart);
        part.IndexCount = static_cast<uint32_t>(subset.IndexCount);
        part.VertexStart = static_cast<uint32_t>(subset.VertexStart);
        part.VertexCount = static_cast<uint32_t>(subset.VertexCount);
        part.MaterialIdx = subset.MaterialID;
    }
}

// Initializes the mesh as a box
void Mesh::InitBox(ID3D11Device* device, const Float3& dimensions, const Float3& position,
                   const Quaternion& orientation, uint32_t materialIdx)
{
    const uint64_t NumBoxVerts = 24;
    const uint64_t NumBoxIndices = 36;

    std::vector<MeshVertex> boxVerts(NumBoxVerts);
    std::vector<u16> boxIndices(NumBoxIndices, 0);

    uint64_t vIdx = 0;

    // Top
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, 1.0f, 1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(0.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, 1.0f, 1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(1.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, 1.0f, -1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, 1.0f, -1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(0.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));

    // Bottom
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, -1.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f), Float2(0.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, -1.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f), Float2(1.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, -1.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f), Float2(1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, -1.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f), Float2(0.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f));

    // Front
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, 1.0f, -1.0f), Float3(0.0f, 0.0f, -1.0f), Float2(0.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, 1.0f, -1.0f), Float3(0.0f, 0.0f, -1.0f), Float2(1.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, -1.0f, -1.0f), Float3(0.0f, 0.0f, -1.0f), Float2(1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, -1.0f, -1.0f), Float3(0.0f, 0.0f, -1.0f), Float2(0.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));

    // Back
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, 1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float2(0.0f, 0.0f), Float3(-1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, 1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float2(1.0f, 0.0f), Float3(-1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, -1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float2(1.0f, 1.0f), Float3(-1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, -1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float2(0.0f, 1.0f), Float3(-1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));

    // Left
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, 1.0f, 1.0f), Float3(-1.0f, 0.0f, 0.0f), Float2(0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, 1.0f, -1.0f), Float3(-1.0f, 0.0f, 0.0f), Float2(1.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, -1.0f, -1.0f), Float3(-1.0f, 0.0f, 0.0f), Float2(1.0f, 1.0f), Float3(0.0f, 0.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(-1.0f, -1.0f, 1.0f), Float3(-1.0f, 0.0f, 0.0f), Float2(0.0f, 1.0f), Float3(0.0f, 0.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f));

    // Right
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, 1.0f, -1.0f), Float3(1.0f, 0.0f, 0.0f), Float2(0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, 1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float2(1.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, -1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float2(1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = MeshVertex(Float3(1.0f, -1.0f, -1.0f), Float3(1.0f, 0.0f, 0.0f), Float2(0.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f));

    for(uint64_t i = 0; i < NumBoxVerts; ++i)
        boxVerts[i].Transform(position, dimensions * 0.5f, orientation);

    uint64_t iIdx = 0;

    // Top
    boxIndices[iIdx++] = 0;
    boxIndices[iIdx++] = 1;
    boxIndices[iIdx++] = 2;
    boxIndices[iIdx++] = 2;
    boxIndices[iIdx++] = 3;
    boxIndices[iIdx++] = 0;

    // Bottom
    boxIndices[iIdx++] = 4 + 0;
    boxIndices[iIdx++] = 4 + 1;
    boxIndices[iIdx++] = 4 + 2;
    boxIndices[iIdx++] = 4 + 2;
    boxIndices[iIdx++] = 4 + 3;
    boxIndices[iIdx++] = 4 + 0;

    // Front
    boxIndices[iIdx++] = 8 + 0;
    boxIndices[iIdx++] = 8 + 1;
    boxIndices[iIdx++] = 8 + 2;
    boxIndices[iIdx++] = 8 + 2;
    boxIndices[iIdx++] = 8 + 3;
    boxIndices[iIdx++] = 8 + 0;

    // Back
    boxIndices[iIdx++] = 12 + 0;
    boxIndices[iIdx++] = 12 + 1;
    boxIndices[iIdx++] = 12 + 2;
    boxIndices[iIdx++] = 12 + 2;
    boxIndices[iIdx++] = 12 + 3;
    boxIndices[iIdx++] = 12 + 0;

    // Left
    boxIndices[iIdx++] = 16 + 0;
    boxIndices[iIdx++] = 16 + 1;
    boxIndices[iIdx++] = 16 + 2;
    boxIndices[iIdx++] = 16 + 2;
    boxIndices[iIdx++] = 16 + 3;
    boxIndices[iIdx++] = 16 + 0;

    // Right
    boxIndices[iIdx++] = 20 + 0;
    boxIndices[iIdx++] = 20 + 1;
    boxIndices[iIdx++] = 20 + 2;
    boxIndices[iIdx++] = 20 + 2;
    boxIndices[iIdx++] = 20 + 3;
    boxIndices[iIdx++] = 20 + 0;

    const uint32_t indexSize = 2;
    indexType = Mesh::Index16Bit;

    vertexStride = sizeof(MeshVertex);
    numVertices = uint32_t(NumBoxVerts);
    numIndices = uint32_t(NumBoxIndices);

    inputElements.clear();
    inputElements.resize(sizeof(VertexInputs) / sizeof(D3D11_INPUT_ELEMENT_DESC));
    memcpy(inputElements.data(), VertexInputs, sizeof(VertexInputs));

	memstream ms;
	ms.write( reinterpret_cast<const u8*>( &inputElements[0] ), inputElements.size() * sizeof( D3D11_INPUT_ELEMENT_DESC ) );
	for ( const auto& e : inputElements )
		ms.write( e.SemanticName );

	inputElementsHash = MurmurHash3( ms.data(), (int)ms.size() );

    const uint32_t vbSize = vertexStride * numVertices;
    vertices.resize(vbSize, 0);
    memcpy(vertices.data(), boxVerts.data(), vbSize);

    const uint32_t ibSize = indexSize * numIndices;
    indices.resize(ibSize, 0);
    memcpy(indices.data(), boxIndices.data(), ibSize);

    D3D11_BUFFER_DESC bufferDesc;
    bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
    bufferDesc.ByteWidth = vbSize;
    bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    bufferDesc.CPUAccessFlags = 0;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    D3D11_SUBRESOURCE_DATA initData;
    initData.pSysMem = vertices.data();
    initData.SysMemPitch = 0;
    initData.SysMemSlicePitch = 0;
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &vertexBuffer));

    bufferDesc.ByteWidth = ibSize;
    bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    initData.pSysMem = indices.data();
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &indexBuffer));

    meshParts.resize(1);

    MeshPart& part = meshParts[0];
    part.IndexStart = 0;
    part.IndexCount = numIndices;
    part.VertexStart = 0;
    part.VertexCount = numVertices;
    part.MaterialIdx = materialIdx;
}

//// Initializes the mesh as a plane
//void Mesh::InitPlane(ID3D11Device* device, const Float2& dimensions, const Float3& position,
//                   const Quaternion& orientation, uint32_t materialIdx)
//{
//    const uint64_t NumPlaneVerts = 4;
//    const uint64_t NumPlaneIndices = 6;
//
//    std::vector<Vertex> planeVerts(NumPlaneVerts);
//    std::vector<uint16> planeIndices(NumPlaneIndices, 0);
//
//    uint64_t vIdx = 0;
//
//    planeVerts[vIdx++] = Vertex(Float3(-1.0f, 0.0f, 1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(0.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
//    planeVerts[vIdx++] = Vertex(Float3(1.0f, 0.0f, 1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(1.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
//    planeVerts[vIdx++] = Vertex(Float3(1.0f, 0.0f, -1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
//    planeVerts[vIdx++] = Vertex(Float3(-1.0f, 0.0f, -1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(0.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
//
//    for(uint64_t i = 0; i < NumPlaneVerts; ++i)
//        planeVerts[i].Transform(position, Float3(dimensions.x, 1.0f, dimensions.y) * 0.5f, orientation);
//
//    uint64_t iIdx = 0;
//    planeIndices[iIdx++] = 0;
//    planeIndices[iIdx++] = 1;
//    planeIndices[iIdx++] = 2;
//    planeIndices[iIdx++] = 2;
//    planeIndices[iIdx++] = 3;
//    planeIndices[iIdx++] = 0;
//
//    const uint32_t indexSize = 2;
//    indexType = Mesh::Index16Bit;
//
//    vertexStride = sizeof(Vertex);
//    numVertices = uint32_t(NumPlaneVerts);
//    numIndices = uint32_t(NumPlaneIndices);
//
//    inputElements.clear();
//    inputElements.resize(sizeof(VertexInputs) / sizeof(D3D11_INPUT_ELEMENT_DESC));
//    memcpy(inputElements.data(), VertexInputs, sizeof(VertexInputs));
//
//    const uint32_t vbSize = vertexStride * numVertices;
//    vertices.resize(vbSize, 0);
//    memcpy(vertices.data(), planeVerts.data(), vbSize);
//
//    const uint32_t ibSize = indexSize * numIndices;
//    indices.resize(ibSize, 0);
//    memcpy(indices.data(), planeIndices.data(), ibSize);
//
//    D3D11_BUFFER_DESC bufferDesc;
//    bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
//    bufferDesc.ByteWidth = vbSize;
//    bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
//    bufferDesc.CPUAccessFlags = 0;
//    bufferDesc.MiscFlags = 0;
//    bufferDesc.StructureByteStride = 0;
//
//    D3D11_SUBRESOURCE_DATA initData;
//    initData.pSysMem = vertices.data();
//    initData.SysMemPitch = 0;
//    initData.SysMemSlicePitch = 0;
//    DXCall(device->CreateBuffer(&bufferDesc, &initData, &vertexBuffer));
//
//    bufferDesc.ByteWidth = ibSize;
//    bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
//    bufferDesc.MiscFlags = 0;
//    bufferDesc.StructureByteStride = 0;
//
//    initData.pSysMem = indices.data();
//    DXCall(device->CreateBuffer(&bufferDesc, &initData, &indexBuffer));
//
//    meshParts.resize(1);
//
//    MeshPart& part = meshParts[0];
//    part.IndexStart = 0;
//    part.IndexCount = numIndices;
//    part.VertexStart = 0;
//    part.VertexCount = numVertices;
//    part.MaterialIdx = materialIdx;
//}

void Mesh::GenerateTangentFrame()
{
    // Make sure that we have a position + texture coordinate + normal
    uint32_t posOffset = 0xFFFFFFFF;
    uint32_t nmlOffset = 0xFFFFFFFF;
    uint32_t tcOffset = 0xFFFFFFFF;
    for(uint32_t i = 0; i < inputElements.size(); ++i)
    {
        const std::string semantic = inputElements[i].SemanticName;
        const uint32_t offset = inputElements[i].AlignedByteOffset;
        if(semantic == "POSITION")
            posOffset = offset;
        else if(semantic == "NORMAL")
            nmlOffset = offset;
        else if(semantic == "TEXCOORD")
            tcOffset = offset;
    }

    if(posOffset == 0xFFFFFFFF || nmlOffset == 0xFFFFFFFF || tcOffset == 0xFFFFFFFF)
        THROW_MESSAGE( "Can't generate a tangent frame, mesh doesn't have positions, normals, and texcoords");

    // Clone the mesh
    std::vector<MeshVertex> newVertices(numVertices);

    const uint8_t* vtxData = vertices.data();
    for(uint32_t i = 0; i < numVertices; ++i)
    {
        newVertices[i].Position = *reinterpret_cast<const Float3*>(vtxData + posOffset);
        newVertices[i].Normal = *reinterpret_cast<const Float3*>(vtxData + nmlOffset);
        newVertices[i].TexCoord = *reinterpret_cast<const Float2*>(vtxData + tcOffset);
        vtxData += vertexStride;
    }

    // Compute the tangent frame for each vertex. The following code is based on
    // "Computing Tangent Space Basis Vectors for an Arbitrary Mesh", by Eric Lengyel
    // http://www.terathon.com/code/tangent.html

    // Make temporary arrays for the tangent and the bitangent
    std::vector<Float3> tangents(numVertices);
    std::vector<Float3> bitangents(numVertices);

    // Loop through each triangle
    const uint32_t indexSize = indexType == Index16Bit ? 2 : 4;
    for (uint32_t i = 0; i < numIndices; i += 3)
    {
        uint32_t i1 = GetIndex(indices.data(), i + 0, indexSize);
        uint32_t i2 = GetIndex(indices.data(), i + 1, indexSize);
        uint32_t i3 = GetIndex(indices.data(), i + 2, indexSize);

        const Float3& v1 = newVertices[i1].Position;
        const Float3& v2 = newVertices[i2].Position;
        const Float3& v3 = newVertices[i3].Position;

        const Float2& w1 = newVertices[i1].TexCoord;
        const Float2& w2 = newVertices[i2].TexCoord;
        const Float2& w3 = newVertices[i3].TexCoord;

        float x1 = v2.x - v1.x;
        float x2 = v3.x - v1.x;
        float y1 = v2.y - v1.y;
        float y2 = v3.y - v1.y;
        float z1 = v2.z - v1.z;
        float z2 = v3.z - v1.z;

        float s1 = w2.x - w1.x;
        float s2 = w3.x - w1.x;
        float t1 = w2.y - w1.y;
        float t2 = w3.y - w1.y;

        float r = 1.0f / (s1 * t2 - s2 * t1);
        Float3 sDir((t2 * x1 - t1 * x2) * r, (t2 * y1 - t1 * y2) * r, (t2 * z1 - t1 * z2) * r);
        Float3 tDir((s1 * x2 - s2 * x1) * r, (s1 * y2 - s2 * y1) * r, (s1 * z2 - s2 * z1) * r);

        tangents[i1] += sDir;
        tangents[i2] += sDir;
        tangents[i3] += sDir;

        bitangents[i1] += tDir;
        bitangents[i2] += tDir;
        bitangents[i3] += tDir;
    }

    for (uint32_t i = 0; i < numVertices; ++i)
    {
        Float3& n = newVertices[i].Normal;
        Float3& t = tangents[i];

        // Gram-Schmidt orthogonalize
        Float3 tangent = (t - n * Float3::Dot(n, t));
        bool zeroTangent = false;
        if(tangent.Length() > 0.00001f)
            Float3::Normalize(tangent);
        else if(n.Length() > 0.00001f)
        {
            tangent = Float3::Perpendicular(n);
            zeroTangent = true;
        }

        float sign = 1.0f;

        if(!zeroTangent)
        {
            Float3 b;
            b = Float3::Cross(n, t);
            sign = (Float3::Dot(b, bitangents[i]) < 0.0f) ? -1.0f : 1.0f;
        }

        // Store the tangent + bitangent
        newVertices[i].Tangent = Float3::Normalize(tangent);

        newVertices[i].Bitangent = Float3::Normalize(Float3::Cross(n, tangent));
        newVertices[i].Bitangent *= sign;
    }

    inputElements.clear();
    inputElements.resize(sizeof(VertexInputs) / sizeof(D3D11_INPUT_ELEMENT_DESC));
    memcpy(inputElements.data(), VertexInputs, sizeof(VertexInputs));

    vertexStride = sizeof(MeshVertex);
    vertices.clear();
    vertices.resize(numVertices * vertexStride);
    memcpy(vertices.data(), newVertices.data(), numVertices * vertexStride);
}

void Mesh::CreateInputElements(const D3DVERTEXELEMENT9* declaration)
{
    std::map<BYTE, LPCSTR> nameMap;
    nameMap[D3DDECLUSAGE_POSITION] = "POSITION";
    nameMap[D3DDECLUSAGE_BLENDWEIGHT] = "BLENDWEIGHT";
    nameMap[D3DDECLUSAGE_BLENDINDICES] = "BLENDINDICES";
    nameMap[D3DDECLUSAGE_NORMAL] = "NORMAL";
    nameMap[D3DDECLUSAGE_TEXCOORD] = "TEXCOORD";
    nameMap[D3DDECLUSAGE_TANGENT] = "TANGENT";
    nameMap[D3DDECLUSAGE_BINORMAL] = "BITANGENT";
    nameMap[D3DDECLUSAGE_COLOR] = "COLOR";

    std::map<BYTE, DXGI_FORMAT> formatMap;
    formatMap[D3DDECLTYPE_FLOAT1] = DXGI_FORMAT_R32_FLOAT;
    formatMap[D3DDECLTYPE_FLOAT2] = DXGI_FORMAT_R32G32_FLOAT;
    formatMap[D3DDECLTYPE_FLOAT3] = DXGI_FORMAT_R32G32B32_FLOAT;
    formatMap[D3DDECLTYPE_FLOAT4] = DXGI_FORMAT_R32G32B32A32_FLOAT;
    formatMap[D3DDECLTYPE_D3DCOLOR] = DXGI_FORMAT_R8G8B8A8_UNORM;
    formatMap[D3DDECLTYPE_UBYTE4] = DXGI_FORMAT_R8G8B8A8_UINT;
    formatMap[D3DDECLTYPE_SHORT2] = DXGI_FORMAT_R16G16_SINT;
    formatMap[D3DDECLTYPE_SHORT4] = DXGI_FORMAT_R16G16B16A16_SINT;
    formatMap[D3DDECLTYPE_UBYTE4N] = DXGI_FORMAT_R8G8B8A8_UNORM;
    formatMap[D3DDECLTYPE_SHORT2N] = DXGI_FORMAT_R16G16_SNORM;
    formatMap[D3DDECLTYPE_SHORT4N] = DXGI_FORMAT_R16G16B16A16_SNORM;
    formatMap[D3DDECLTYPE_USHORT2N] = DXGI_FORMAT_R16G16_UNORM;
    formatMap[D3DDECLTYPE_USHORT4N] = DXGI_FORMAT_R16G16B16A16_UNORM;
    formatMap[D3DDECLTYPE_UDEC3] = DXGI_FORMAT_R10G10B10A2_UINT;
    formatMap[D3DDECLTYPE_DEC3N] = DXGI_FORMAT_R10G10B10A2_UNORM;
    formatMap[D3DDECLTYPE_FLOAT16_2] = DXGI_FORMAT_R16G16_FLOAT;
    formatMap[D3DDECLTYPE_FLOAT16_4] = DXGI_FORMAT_R16G16B16A16_FLOAT;

    // Figure out the number of elements
    uint32_t numInputElements = 0;
    while(declaration[numInputElements].Stream != 0xFF)
    {
        const D3DVERTEXELEMENT9& element9 = declaration[numInputElements];
        D3D11_INPUT_ELEMENT_DESC element11;
        element11.InputSlot = 0;
        element11.InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
        element11.InstanceDataStepRate = 0;
        element11.SemanticName = nameMap[element9.Usage];
        element11.Format = formatMap[element9.Type];
        element11.AlignedByteOffset = element9.Offset;
        element11.SemanticIndex = element9.UsageIndex;
        inputElements.push_back(element11);

        numInputElements++;
    }

	memstream ms;
	ms.write( reinterpret_cast<const u8*>( &inputElements[0] ), inputElements.size() * sizeof( D3D11_INPUT_ELEMENT_DESC ) );
	for ( const auto& e : inputElements )
		ms.write( e.SemanticName );

	inputElementsHash = MurmurHash3( ms.data(), (int)ms.size() );
}

// Does a basic draw of all parts
void Mesh::Render(ID3D11DeviceContext* context)
{
    // Set the vertices and indices
    ID3D11Buffer* vertexBuffers[1] = { vertexBuffer };
    uint32_t vertexStrides[1] = { vertexStride };
    uint32_t offsets[1] = { 0 };
    context->IASetVertexBuffers(0, 1, vertexBuffers, vertexStrides, offsets);
    context->IASetIndexBuffer(indexBuffer, IndexBufferFormat(), 0);
    context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    // Draw each MeshPart
    for(size_t i = 0; i < meshParts.size(); ++i)
    {
        MeshPart& meshPart = meshParts[i];
        context->DrawIndexed(meshPart.IndexCount, meshPart.IndexStart, 0);
    }
}

// == Model =======================================================================================

Model::Model()
{
}

Model::~Model()
{
}

void Model::CreateFromSDKMeshFile(ID3D11Device* device, LPCSTR fileName, const char* normalMapSuffix,
                                  bool generateTangentFrame, bool overrideNormalMaps)
{
    SPAD_ASSERT(FileExists(fileName));

    // Use the SDKMesh class to load in the data
    SDKMesh sdkMesh;
    sdkMesh.Create(fileName);

    std::string directory = GetDirectoryFromFilePath(fileName);

    // Make materials
    uint32_t numMaterials = sdkMesh.GetNumMaterials();
    for(uint32_t i = 0; i < numMaterials; ++i)
    {
        MeshMaterial material;
        SDKMESH_MATERIAL* mat = sdkMesh.GetMaterial(i);
        memcpy(&material.AmbientAlbedo, &mat->Ambient, sizeof(Float4));
        memcpy(&material.DiffuseAlbedo, &mat->Diffuse, sizeof(Float4));
        memcpy(&material.SpecularAlbedo, &mat->Specular, sizeof(Float4));
        memcpy(&material.Emissive, &mat->Emissive, sizeof(Float4));
        material.Alpha = mat->Diffuse.w;
        material.SpecularPower = mat->Power;
        material.DiffuseMapName = mat->DiffuseTexture;
        material.NormalMapName = mat->NormalTexture;

        // Add the normal map prefix
        if (normalMapSuffix && material.DiffuseMapName.length() > 0
                && (material.NormalMapName.length() == 0 || overrideNormalMaps))
        {
            std::string base = GetFilePathWithoutExtension(material.DiffuseMapName.c_str());
            std::string extension = GetFileExtension(material.DiffuseMapName.c_str());
            material.NormalMapName = base + normalMapSuffix + "." + extension;
        }

        LoadMaterialResources(material, directory, device);

        meshMaterials.push_back(material);
    }

    uint32_t numMeshes = sdkMesh.GetNumMeshes();
    meshes.resize(numMeshes);
    for(uint32_t meshIdx = 0; meshIdx < numMeshes; ++meshIdx)
        meshes[meshIdx].Initialize(device, sdkMesh, meshIdx, generateTangentFrame);
}


static Float3 ConvertVector( const aiVector3D& vec )
{
	return Float3( vec.x, vec.y, vec.z );
}

//static Float3 ConvertColor( const aiColor3D& clr )
//{
//	return Float3( clr.r, clr.g, clr.b );
//}

//static Float4x4 ConvertMatrix( const aiMatrix4x4& mat )
//{
//	return Float4x4( Float4( mat.a1, mat.a2, mat.a3, mat.a4 ),
//		Float4( mat.b1, mat.b2, mat.b3, mat.b4 ),
//		Float4( mat.c1, mat.c2, mat.c3, mat.c4 ),
//		Float4( mat.d1, mat.d2, mat.d3, mat.d4 ) );
//}


void Mesh::InitFromAssimpMesh( ID3D11Device* device, const aiMesh& assimpMesh, float sceneScale )
{
	numVertices = assimpMesh.mNumVertices;
	SPAD_ASSERT( numVertices <= 0xFFFF );

	{
		vertexStride = sizeof( MeshVertex );
		vertices.resize( numVertices * vertexStride );

		MeshVertex *dstVertices = reinterpret_cast<MeshVertex*>( vertices.data() );

		if ( assimpMesh.HasPositions() )
		{
			for ( uint i = 0; i < numVertices; ++i )
			{
				Float3 position = ConvertVector( assimpMesh.mVertices[i] ) * sceneScale;
				dstVertices[i].Position = position;
			}
		}

		if ( assimpMesh.HasNormals() )
		{
			for ( uint i = 0; i < numVertices; ++i )
				dstVertices[i].Normal = ConvertVector( assimpMesh.mNormals[i] );
		}

		if ( assimpMesh.HasTextureCoords( 0 ) )
		{
			for ( uint i = 0; i < numVertices; ++i )
			{
				Float3 tc = ConvertVector( assimpMesh.mTextureCoords[0][i] );
				dstVertices[i].TexCoord = Float2( tc.x, tc.y );
			}
		}

		if ( assimpMesh.HasTangentsAndBitangents() )
		{
			for ( uint i = 0; i < numVertices; ++i )
			{
				dstVertices[i].Tangent = ConvertVector( assimpMesh.mTangents[i] );
				dstVertices[i].Bitangent = ConvertVector( assimpMesh.mBitangents[i] ) * -1.0f;
			}
		}

		D3D11_BUFFER_DESC bufferDesc;
		ZeroMemory( &bufferDesc, sizeof( bufferDesc ) );
		bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
		bufferDesc.ByteWidth = numVertices * sizeof( MeshVertex );
		bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
		bufferDesc.CPUAccessFlags = 0;
		bufferDesc.MiscFlags = 0;
		bufferDesc.StructureByteStride = 0;

		D3D11_SUBRESOURCE_DATA initData;
		initData.pSysMem = vertices.data();
		initData.SysMemPitch = 0;
		initData.SysMemSlicePitch = 0;
		DXCall( device->CreateBuffer( &bufferDesc, &initData, &vertexBuffer ) );
	}

	const uint numTriangles = assimpMesh.mNumFaces;
	const uint indexSize = 2;
	numIndices = numTriangles * 3;
	indexType = Index16Bit;

	{
		indices.resize( numIndices * indexSize );
		u16 *dstIndices = reinterpret_cast<u16*>( indices.data() );
		for ( uint triIdx = 0; triIdx < numTriangles; ++triIdx )
		{
			dstIndices[triIdx * 3 + 0] = static_cast<u16>( assimpMesh.mFaces[triIdx].mIndices[0] );
			dstIndices[triIdx * 3 + 1] = static_cast<u16>( assimpMesh.mFaces[triIdx].mIndices[1] );
			dstIndices[triIdx * 3 + 2] = static_cast<u16>( assimpMesh.mFaces[triIdx].mIndices[2] );
		}


		D3D11_BUFFER_DESC bufferDesc;
		ZeroMemory( &bufferDesc, sizeof( bufferDesc ) );
		bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
		bufferDesc.ByteWidth = numIndices * indexSize;
		bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
		bufferDesc.CPUAccessFlags = 0;
		bufferDesc.MiscFlags = 0;
		bufferDesc.StructureByteStride = 0;

		D3D11_SUBRESOURCE_DATA initData;
		initData.pSysMem = indices.data();
		initData.SysMemPitch = 0;
		initData.SysMemSlicePitch = 0;
		DXCall( device->CreateBuffer( &bufferDesc, &initData, &indexBuffer ) );

		meshParts.resize( 1 );
		MeshPart& part = meshParts[0];
		part.IndexStart = 0;
		part.IndexCount = numTriangles * 3;
		part.VertexStart = 0;
		part.VertexCount = numVertices;
		part.MaterialIdx = assimpMesh.mMaterialIndex;
	}

	// Figure out the number of elements
	inputElements.resize( 5 );
	for ( uint i = 0; i < 5; ++i )
	{
		inputElements[i] = VertexInputs[i];
	}

	memstream ms;
	ms.write( reinterpret_cast<const u8*>( &inputElements[0] ), inputElements.size() * sizeof( D3D11_INPUT_ELEMENT_DESC ) );
	for ( const auto& e : inputElements )
		ms.write( e.SemanticName );

	inputElementsHash = MurmurHash3( ms.data(), (int)ms.size() );
}


void Model::CreateWithAssimp( ID3D11Device* device, const char* fileName, float sceneScale )
{
	SPAD_ASSERT( meshes.empty() && meshMaterials.empty() );
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
		flags |= aiProcess_PreTransformVertices;
		//flags |= aiProcess_OptimizeMeshes;

		scene = importer.ApplyPostProcessing( flags );

		Assimp::Exporter exporter;
		aiReturn ret = exporter.Export( scene, "assbin", assbinFileName.c_str(), 0, nullptr );
		if ( ret != aiReturn_SUCCESS )
		{
			THROW_MESSAGE( "Couldn't export %s to %s", fileName, assbinFileName.c_str() );
		}
	}

	// Load the materials
	const uint numMaterials = scene->mNumMaterials;
	//meshMaterials.Init( numMaterials );
	meshMaterials.resize( numMaterials );
	for ( uint i = 0; i < numMaterials; ++i )
	{
		MeshMaterial& material = meshMaterials[i];
		const aiMaterial& mat = *scene->mMaterials[i];

		aiString diffuseTexPath;
		aiString normalMapPath;
		aiString roughnessMapPath;
		aiString metallicMapPath;
		if ( mat.GetTexture( aiTextureType_DIFFUSE, 0, &diffuseTexPath ) == aiReturn_SUCCESS )
		{
			//material.TextureNames[uint64( MaterialTextures::Albedo )] = GetFileName( AnsiToWString( diffuseTexPath.C_Str() ).c_str() );
			material.DiffuseMapName = diffuseTexPath.C_Str();
			std::string filePath = fileDirectory + material.DiffuseMapName;
			material.DiffuseMap = LoadTexture( device, filePath.c_str() );
		}

		//if ( mat.GetTexture( aiTextureType_NORMALS, 0, &normalMapPath ) == aiReturn_SUCCESS
		//	|| mat.GetTexture( aiTextureType_HEIGHT, 0, &normalMapPath ) == aiReturn_SUCCESS )
		//{
		//	//material.TextureNames[uint64( MaterialTextures::Normal )] = GetFileName( AnsiToWString( normalMapPath.C_Str() ).c_str() );
		//	material.NormalMapName = normalMapPath.C_Str();
		//	material.NormalMap = LoadTexture( device, material.NormalMapName.c_str() );
		//}

		//if ( mat.GetTexture( aiTextureType_SHININESS, 0, &roughnessMapPath ) == aiReturn_SUCCESS )
		//	material.TextureNames[uint64( MaterialTextures::Roughness )] = GetFileName( AnsiToWString( roughnessMapPath.C_Str() ).c_str() );

		//if ( mat.GetTexture( aiTextureType_AMBIENT, 0, &metallicMapPath ) == aiReturn_SUCCESS )
		//	material.TextureNames[uint64( MaterialTextures::Metallic )] = GetFileName( AnsiToWString( metallicMapPath.C_Str() ).c_str() );
	}

	// Initialize the meshes
	const uint numMeshes = scene->mNumMeshes;
	//uint numVertices = 0;
	//uint numIndices = 0;
	//for ( uint i = 0; i < numMeshes; ++i )
	//{
	//	const aiMesh& assimpMesh = *scene->mMeshes[i];

	//	numVertices += assimpMesh.mNumVertices;
	//	numIndices += assimpMesh.mNumFaces * 3;
	//}

	meshes.resize( numMeshes );

	//std::vector<Vertex> vertices( numVertices );
	//std::vector<u16> indices( numIndices );

	for ( uint i = 0; i < numMeshes; ++i )
	{
		const aiMesh& assimpMesh = *scene->mMeshes[i];

		Mesh &mesh = meshes[i];
		mesh.InitFromAssimpMesh( device, assimpMesh, sceneScale );
	}
}


void Model::GenerateBoxScene(ID3D11Device* device)
{
    MeshMaterial material;
    material.DiffuseMapName = "checker.jpg";
    //material.NormalMapName = "checker.jpg";
    LoadMaterialResources(material, "Data\\Textures\\", device);
    meshMaterials.push_back(material);

    meshes.resize(2);
    meshes[0].InitBox(device, Float3(2.0f), Float3(0.0f, 1.5f, 0.0f), Quaternion(), 0);
    meshes[1].InitBox(device, Float3(10.0f, 0.25f, 10.0f), Float3(0.0f), Quaternion(), 0);
}

//void Model::GeneratePlaneScene(ID3D11Device* device, const Float2& dimensions, const Float3& position,
//                               const Quaternion& orientation)
//{
//    MeshMaterial material;
//    material.DiffuseMapName = L"White.png";
//    material.NormalMapName = L"Hex.png";
//    LoadMaterialResources(material, L"..\\Content\\Textures\\", device);
//    meshMaterials.push_back(material);
//
//    meshes.resize(1);
//    meshes[0].InitPlane(device, dimensions, position, orientation, 0);
//}

void Model::LoadMaterialResources(MeshMaterial& material, const std::string& directory, ID3D11Device* device)
{
    // Load the diffuse map
    std::string diffuseMapPath = directory + material.DiffuseMapName;
    if(material.DiffuseMapName.length() > 1 && FileExists(diffuseMapPath.c_str()))
        material.DiffuseMap = LoadTexture(device, diffuseMapPath.c_str());

    // Load the normal map
	std::string normalMapPath = directory + material.NormalMapName;

    if(material.NormalMapName.length() > 1 && FileExists(normalMapPath.c_str()))
        material.NormalMap = LoadTexture(device, normalMapPath.c_str());
}

//void Model::WriteToFile(const wchar* path, ID3D11Device* device, ID3D11DeviceContext* context)
//{
//    // If the file exists, delete it
//    if(FileExists(path))
//        Win32Call(DeleteFile(path));
//
//    // Create the file
//    HANDLE fileHandle = CreateFile(path, GENERIC_WRITE, 0, NULL, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, NULL);
//    if(fileHandle == INVALID_HANDLE_VALUE)
//        Win32Call(false);
//
//    // Write out the number of meshes
//    DWORD bytesWritten = 0;
//    uint32_t numMeshes = static_cast<uint32_t>(meshes.size());
//    SerializeWrite(fileHandle, numMeshes);
//
//    // Write out the meshes
//    for(uint32_t meshIdx = 0; meshIdx < meshes.size(); ++meshIdx)
//    {
//        Mesh& mesh = meshes[meshIdx];
//
//        // Write the mesh vertex data
//        uint32_t vbSize = mesh.numVertices * mesh.vertexStride;
//        SerializeWrite(fileHandle, vbSize);
//
//        StagingBuffer stagingVB;
//        stagingVB.Initialize(device, vbSize);
//        context->CopyResource(stagingVB.Buffer, mesh.vertexBuffer);
//        const void* vertexData = stagingVB.Map(context);
//        Win32Call(WriteFile(fileHandle, vertexData, vbSize, &bytesWritten, NULL));
//        stagingVB.Unmap(context);
//
//        // Write the mesh index buffer data
//        uint32_t ibSize = mesh.numIndices * (mesh.indexType == Mesh::Index16Bit ? 2 : 4);
//        SerializeWrite(fileHandle, ibSize);
//
//        StagingBuffer stagingIB;
//        stagingIB.Initialize(device, ibSize);
//        context->CopyResource(stagingIB.Buffer, mesh.indexBuffer);
//        const void* indexData = stagingIB.Map(context);
//        Win32Call(WriteFile(fileHandle, indexData, stagingIB.Size, &bytesWritten, NULL));
//        stagingIB.Unmap(context);
//
//        // Write out the other mesh members
//        SerializeWriteVector(fileHandle, mesh.meshParts);
//        SerializeWriteVector(fileHandle, mesh.inputElements);
//        SerializeWrite(fileHandle, mesh.vertexStride);
//        SerializeWrite(fileHandle, mesh.numVertices);
//        SerializeWrite(fileHandle, mesh.numIndices);
//
//        uint32_t ibType = static_cast<uint32_t>(mesh.indexType);
//        SerializeWrite(fileHandle, ibType);
//
//        // Write out the input element names
//        uint32_t numInputElements = static_cast<uint32_t>(mesh.inputElementNames.size());
//        SerializeWrite(fileHandle, numInputElements);
//        for(uint32_t i = 0; i < numInputElements; ++i)
//            SerializeWriteString(fileHandle, mesh.inputElementNames[i]);
//    }
//
//    // Write out the mesh material data
//    uint32_t numMaterials = static_cast<uint32_t>(meshMaterials.size());
//    SerializeWrite(fileHandle, numMaterials);
//
//    for(uint32_t materialIdx = 0; materialIdx < numMaterials; ++materialIdx)
//    {
//        const MeshMaterial& material = meshMaterials[materialIdx];
//
//        SerializeWrite(fileHandle, material.AmbientAlbedo);
//        SerializeWrite(fileHandle, material.DiffuseAlbedo);
//        SerializeWrite(fileHandle, material.SpecularAlbedo);
//        SerializeWrite(fileHandle, material.Emissive);
//        SerializeWrite(fileHandle, material.SpecularPower);
//        SerializeWrite(fileHandle, material.Alpha);
//        SerializeWriteString(fileHandle, material.DiffuseMapName);
//        SerializeWriteString(fileHandle, material.NormalMapName);
//    }
//
//    // Close the file
//    Win32Call(CloseHandle(fileHandle));
//}

//void Model::ReadFromFile(const wchar* path, ID3D11Device* device)
//{
//    wstring directory = GetDirectoryFromFilePath(path);
//
//    // Open the file
//    HANDLE fileHandle = CreateFile(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
//    if(fileHandle == INVALID_HANDLE_VALUE)
//        Win32Call(false);
//
//    // Read in the number of meshes
//    uint32_t numMeshes = 0;
//    SerializeRead(fileHandle, numMeshes);
//
//    meshes.resize(numMeshes);
//    for(uint32_t meshIdx = 0; meshIdx < numMeshes; ++meshIdx)
//    {
//        Mesh& mesh = meshes[meshIdx];
//
//        // Read in the vertex data
//        uint32_t vbSize = 0;
//        SerializeRead(fileHandle, vbSize);
//
//        UINT8* vbData = new UINT8[vbSize];
//        DWORD bytesRead = 0;
//        Win32Call(ReadFile(fileHandle, vbData, vbSize, &bytesRead, NULL));
//
//        D3D11_BUFFER_DESC vbDesc;
//        vbDesc.ByteWidth = vbSize;
//        vbDesc.CPUAccessFlags = 0;
//        vbDesc.StructureByteStride = 0;
//        vbDesc.MiscFlags = 0;
//        vbDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
//        vbDesc.Usage = D3D11_USAGE_IMMUTABLE;
//
//        D3D11_SUBRESOURCE_DATA srData;
//        srData.pSysMem = vbData;
//        srData.SysMemPitch = 0;
//        srData.SysMemSlicePitch = 0;
//        DXCall(device->CreateBuffer(&vbDesc, &srData, &mesh.vertexBuffer));
//
//        delete [] vbData;
//
//        // Read in the index data
//        uint32_t ibSize = 0;
//        SerializeRead(fileHandle, ibSize);
//
//        UINT8* ibData = new UINT8[ibSize];
//        Win32Call(ReadFile(fileHandle, ibData, ibSize, &bytesRead, NULL));
//
//        D3D11_BUFFER_DESC ibDesc;
//        ibDesc.ByteWidth = ibSize;
//        ibDesc.CPUAccessFlags = 0;
//        ibDesc.StructureByteStride = 0;
//        ibDesc.MiscFlags = 0;
//        ibDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
//        ibDesc.Usage = D3D11_USAGE_IMMUTABLE;
//
//        srData.pSysMem = ibData;
//
//        DXCall(device->CreateBuffer(&ibDesc, &srData, &mesh.indexBuffer));
//
//        // Read in the other mesh members
//        SerializeReadVector(fileHandle, mesh.meshParts);
//        SerializeReadVector(fileHandle, mesh.inputElements);
//        SerializeRead(fileHandle, mesh.vertexStride);
//        SerializeRead(fileHandle, mesh.numVertices);
//        SerializeRead(fileHandle, mesh.numIndices);
//
//        uint32_t ibType = 0;
//        SerializeRead(fileHandle, ibType);
//        mesh.indexType = static_cast<Mesh::IndexType>(ibType);
//
//        // Read in the input element names
//        uint32_t numInputElements = 0;
//        SerializeRead(fileHandle, numInputElements);
//        mesh.inputElementNames.resize(numInputElements);
//        for(uint32_t i = 0; i < numInputElements; ++i)
//        {
//            SerializeReadString(fileHandle, mesh.inputElementNames[i]);
//            mesh.inputElements[i].SemanticName = mesh.inputElementNames[i].c_str();
//        }
//    }
//
//    // Read in the material data
//    uint32_t numMaterials = 0;
//    SerializeRead(fileHandle, numMaterials);
//    meshMaterials.resize(numMaterials);
//
//    for(uint32_t materialIdx = 0; materialIdx < numMaterials; ++materialIdx)
//    {
//        MeshMaterial& material = meshMaterials[materialIdx];
//
//        SerializeRead(fileHandle, material.AmbientAlbedo);
//        SerializeRead(fileHandle, material.DiffuseAlbedo);
//        SerializeRead(fileHandle, material.SpecularAlbedo);
//        SerializeRead(fileHandle, material.Emissive);
//        SerializeRead(fileHandle, material.SpecularPower);
//        SerializeRead(fileHandle, material.Alpha);
//        SerializeReadString(fileHandle, material.DiffuseMapName);
//        SerializeReadString(fileHandle, material.NormalMapName);
//
//        // Load the resources
//        LoadMaterialResources(material, directory, device);
//    }
//
//    // Close the file
//    Win32Call(CloseHandle(fileHandle));
//}

}