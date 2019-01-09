#ifndef PASS_CONSTANTS_H
#define PASS_CONSTANTS_H

#include "HlslFrameworkInterop.h"

#define REGISTER_CBUFFER_PASS_CONSTANTS		MAKE_REGISTER_CBUFFER( 0 )
#define REGISTER_CBUFFER_OBJECT_CONSTANTS	MAKE_REGISTER_CBUFFER( 1 )

// follows vector math convention, matrices are column major
// multiplication must be done: vecResult = mat * vec

MAKE_FLAT_CBUFFER( CbPassConstants, REGISTER_CBUFFER_PASS_CONSTANTS )
{
	float4x4 View; // world to view/camera
	float4x4 Projection; // view/camera to clip space
	float4x4 ViewProjection; // proj * view, world to clip space
};

MAKE_FLAT_CBUFFER( CbObjectConstants, REGISTER_CBUFFER_OBJECT_CONSTANTS )
{
	float4x4 World; // object to world
	float4x4 WorldIT; // object to world, transpose(inverse(World)), for transforming normals
};


#endif // PASS_CONSTANTS_H
