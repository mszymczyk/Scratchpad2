#ifndef HLSLFRAMEWORKINTEROP_H
#define HLSLFRAMEWORKINTEROP_H

#ifdef __cplusplus

#include <Util\Vectormath.h>
#include <Gfx\Math\DirectXMathWrap.h>

typedef Matrix4 float4x4;
typedef Vector4 float4;
typedef spad::dxmath::Float3 float3;

#define CBUFFER struct
#define REGISTER_B(exp)
#define REGISTER_T(exp)
#define REGISTER_U(exp)
#define REGISTER_S(exp)

#define MAKE_FLAT_CBUFFER( _name, _register ) struct _name

#define CBUFFER_FLOAT4X4( name )								Matrix4 name
#define CBUFFER_UINT4( name )									uint name[4]
#define CBUFFER_FLOAT4( name )									Vector4 name

#else

#define REGISTER_B(exp) : register(b##exp) // constant buffer
#define REGISTER_T(exp) : register(t##exp) // texture or buffer
#define REGISTER_U(exp) : register(u##exp) // unordered access
#define REGISTER_S(exp) : register(s##exp) // sampler

#define CBUFFER cbuffer

#define MAKE_FLAT_CBUFFER( _name, _register ) cbuffer _name : register( b##_register )

#define CBUFFER_FLOAT4X4( name )								float4x4 name
#define CBUFFER_UINT4( name )									uint4 name
#define CBUFFER_FLOAT4( name )									float4 name

#endif //

#endif // HLSLFRAMEWORKINTEROP_H
