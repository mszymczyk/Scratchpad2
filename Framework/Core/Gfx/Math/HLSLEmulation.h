#pragma once

#define GLM_FORCE_SWIZZLE			GLM_ENABLE
#define GLM_ENABLE_EXPERIMENTAL		GLM_ENABLE
//#define GLM_SILENT_WARNINGS			GLM_ENABLE
#define GLM_FORCE_CXX11				GLM_ENABLE

#pragma warning(push)
#pragma warning(disable:4201)   // suppress even more warnings about nameless structs

// Include GLM vector extensions:
#include <3rdParty\glm\glm/vec2.hpp>               // vec2, bvec2, dvec2, ivec2 and uvec2
#include <3rdParty\glm\glm/vec3.hpp>               // vec3, bvec3, dvec3, ivec3 and uvec3
#include <3rdParty\glm\glm/vec4.hpp>               // vec4, bvec4, dvec4, ivec4 and uvec4
#include <3rdParty\glm\glm/mat2x2.hpp>             // mat2, dmat2
#include <3rdParty\glm\glm/mat2x3.hpp>             // mat2x3, dmat2x3
#include <3rdParty\glm\glm/mat2x4.hpp>             // mat2x4, dmat2x4
#include <3rdParty\glm\glm/mat3x2.hpp>             // mat3x2, dmat3x2
#include <3rdParty\glm\glm/mat3x3.hpp>             // mat3, dmat3
#include <3rdParty\glm\glm/mat3x4.hpp>             // mat3x4, dmat2
#include <3rdParty\glm\glm/mat4x2.hpp>             // mat4x2, dmat4x2
#include <3rdParty\glm\glm/mat4x3.hpp>             // mat4x3, dmat4x3
#include <3rdParty\glm\glm/mat4x4.hpp>             // mat4, dmat4
#include <3rdParty\glm\glm/common.hpp>             // all the GLSL common functions: abs, min, mix, isnan, fma, etc.
#include <3rdParty\glm\glm/exponential.hpp>        // all the GLSL exponential functions: pow, log, exp2, sqrt, etc.
#include <3rdParty\glm\glm/geometric.hpp>           // all the GLSL geometry functions: dot, cross, reflect, etc.
#include <3rdParty\glm\glm/integer.hpp>            // all the GLSL integer functions: findMSB, bitfieldExtract, etc.
#include <3rdParty\glm\glm/matrix.hpp>             // all the GLSL matrix functions: transpose, inverse, etc.
//#include <3rdParty\glm\glm/packing.hpp>            // all the GLSL packing functions: packUnorm4x8, unpackHalf2x16, etc.
#include <3rdParty\glm\glm/trigonometric.hpp>      // all the GLSL trigonometric functions: radians, cos, asin, etc.
#include <3rdParty\glm\glm/vector_relational.hpp>  // all the GLSL vector relational functions: equal, less, etc.
#include <3rdParty\glm\glm\gtx\compatibility.hpp>

#pragma warning(pop)

using namespace glm;

#define HLSL_LOOP
#define HLSL_UNROLL
#define HLSL_in
#define HLSL_out
#define HLSL_inout
#define HLSL_CPP_inout &
#define HLSL_CPP_out &

inline float4x4 ToFloat4x4( const Matrix4 &m )
{
	return *reinterpret_cast<const float4x4*>( &m );
}

inline float3 ToFloat3( const Vector3 &v )
{
	return float3( v.getX().getAsFloat(), v.getY().getAsFloat(), v.getZ().getAsFloat() );
}

inline float3 ToFloat3( const Vector4 &v )
{
	return float3( v.getX().getAsFloat(), v.getY().getAsFloat(), v.getZ().getAsFloat() );
}

inline float4 ToFloat4( const Vector4 &v )
{
	return float4( v.getX().getAsFloat(), v.getY().getAsFloat(), v.getZ().getAsFloat(), v.getW().getAsFloat() );
}