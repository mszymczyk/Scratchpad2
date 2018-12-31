#pragma once

#include <Dx11Util\DxPointers.h>
#include <Gfx\Math\DirectXMathWrap.h>

namespace spad
{
	using namespace dxmath;

	class SDKMesh;

	struct MeshMaterial
	{
		Float3 AmbientAlbedo;
		Float3 DiffuseAlbedo;
		Float3 SpecularAlbedo;
		Float3 Emissive;
		float SpecularPower;
		float Alpha;
		std::string DiffuseMapName;
		std::string NormalMapName;
		ID3D11ShaderResourceViewPtr DiffuseMap;
		ID3D11ShaderResourceViewPtr NormalMap;

		MeshMaterial() : SpecularPower( 1.0f ), Alpha( 1.0f )
		{
		}
	};

	struct MeshPart
	{
		uint32_t VertexStart;
		uint32_t VertexCount;
		uint32_t IndexStart;
		uint32_t IndexCount;
		uint32_t MaterialIdx;

		MeshPart() : VertexStart( 0 ), VertexCount( 0 ), IndexStart( 0 ), IndexCount( 0 ), MaterialIdx( 0 )
		{
		}
	};

	class CubeMesh
	{
	public:
		// Init from loaded files
		void Initialize( ID3D11Device* device );

		// Accessors
		ID3D11Buffer* VertexBuffer() { return vertexBuffer; }
		const ID3D11Buffer* VertexBuffer() const { return vertexBuffer; }
		ID3D11Buffer* IndexBuffer() { return indexBuffer; }
		const ID3D11Buffer* IndexBuffer() const { return indexBuffer; }

		std::vector<MeshPart>& MeshParts() { return meshParts; }
		const std::vector<MeshPart>& MeshParts() const { return meshParts; }

		const D3D11_INPUT_ELEMENT_DESC* InputElements() const { return &inputElements[0]; }
		uint32_t NumInputElements() const { return static_cast<uint32_t>( inputElements.size() ); }
		uint32_t InputElementsHash() const { return inputElementsHash; }

		uint32_t VertexStride() const { return vertexStride; }
		uint32_t NumVertices() const { return numVertices; }
		uint32_t NumIndices() const { return numIndices; }

		IndexType IndexBufferType() const { return indexType; }
		DXGI_FORMAT IndexBufferFormat() const { return indexType == Index32Bit ? DXGI_FORMAT_R32_UINT : DXGI_FORMAT_R16_UINT; }
		uint32_t IndexSize() const { return indexType == Index32Bit ? 4 : 2; }

		const uint8_t* Vertices() const { return vertices.data(); }
		const uint8_t* Indices() const { return indices.data(); }

	protected:

		void GenerateTangentFrame();
		void CreateInputElements( const D3DVERTEXELEMENT9* declaration );

		ID3D11BufferPtr vertexBuffer;
		ID3D11BufferPtr indexBuffer;

		std::vector<MeshPart> meshParts;
		std::vector<D3D11_INPUT_ELEMENT_DESC> inputElements;
		uint32_t inputElementsHash;

		uint32_t vertexStride;
		uint32_t numVertices;
		uint32_t numIndices;

		IndexType indexType;

		std::vector<std::string> inputElementNames;

		std::vector<uint8_t> vertices;
		std::vector<uint8_t> indices;
	};

} // namespace spad

