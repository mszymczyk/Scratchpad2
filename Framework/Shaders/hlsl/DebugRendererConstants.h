#ifndef DEBUG_RENDERER_CONSTANTS_H
#define DEBUG_RENDERER_CONSTANTS_H

#include "HlslFrameworkInterop.h"

// follows vector math convention, matrices are column major
// multiplication must be done: vecResult = mat * vec

#define REGISTER_CBUFFER_DEBUG_RENDERER_CONSTANTS		MAKE_REGISTER_CBUFFER( 1 )

MAKE_FLAT_CBUFFER( CbDebugRendererConstants, REGISTER_CBUFFER_DEBUG_RENDERER_CONSTANTS )
{
	float4x4 WorldViewProjection; // proj * view * world, object to clip space
	float4 Color;
};


#endif // DEBUG_RENDERER_CONSTANTS_H
