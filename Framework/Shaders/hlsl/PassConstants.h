#ifndef PASS_CONSTANTS_H
#define PASS_CONSTANTS_H

#include "HlslFrameworkInterop.h"

#define CB_PASS_CONSTANTS_REGISTER		0
#define CB_OBJECT_CONSTANTS_REGISTER	1

// follows vector math convention, matrices are column major
// multiplication must be done: vecResult = mat * vec

CBUFFER CbPassConstants REGISTER_B( CB_PASS_CONSTANTS_REGISTER )
{
	float4x4 View; // world to view/camera
	float4x4 Projection; // view/camera to clip space
	float4x4 ViewProjection; // proj * view, world to clip space
};

CBUFFER CbObjectConstants REGISTER_B( CB_OBJECT_CONSTANTS_REGISTER )
{
	float4x4 World; // object to world
	float4x4 WorldIT; // object to world, transpose(inverse(World)), for transforming normals
};


#endif // PASS_CONSTANTS_H
