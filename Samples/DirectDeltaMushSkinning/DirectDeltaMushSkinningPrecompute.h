#ifndef DIRECTDELTAMUSHSKINNINGPRECOMPUTE_H
#define DIRECTDELTAMUSHSKINNINGPRECOMPUTE_H

#pragma once

#include <shaders/hlsl/skinning_cshared.h>
#include <Util\StdHelp.h>

namespace spad
{
	typedef std::vector<Matrix4, stdutil::aligned_allocator<Matrix4, alignof( Matrix4 )>> Matrix4Vector;
	//typedef std::vector<Matrix4Vector, stdutil::aligned_allocator<Matrix4Vector, alignof( Matrix4Vector )>> Matrix4Matrix;
	typedef std::vector<OmegaRef> OmegaRefVector;
	typedef std::vector<float3x3> Float3x3Vector;

	//void PrecomputeDDM( DDMMesh &mesh );
	void PrecomputeDDM(
		  const std::vector<BaseVertexPrecompute> &vertices
		, const std::vector<uint> &indices
		, const uint numTransforms
		, OmegaRefVector &outOmegaRefs
		, Matrix4Vector &outOmegas
		, std::vector<uint> &outTransformIndices
	);

	void DDMSkinCPU(
		  const std::vector<BaseVertex> &vertices
		, const Matrix4Vector &transforms
		, const OmegaRefVector &omegaRefs
		, const Matrix4Vector &omegas
		, const std::vector<uint> &transformIndices
		, std::vector<SkinnedVertex> &outSkinnedVertices
		, std::vector<DebugOutput> &outDebug
	);

	void DDMSkinCPUV1(
		  const std::vector<BaseVertex> &vertices
		, const Matrix4Vector &transforms
		, const OmegaRefVector &omegaRefs
		, const Matrix4Vector &omegas
		, const std::vector<uint> &transformIndices
		, std::vector<SkinnedVertex> &outSkinnedVertices
		, std::vector<DebugOutput> &outDebug
	);

}

#endif // DIRECTDELTAMUSHSKINNINGPRECOMPUTE_H