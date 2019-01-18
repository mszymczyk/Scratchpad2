#ifndef HLSLFRAMEWORKINTEROP_H
#define HLSLFRAMEWORKINTEROP_H

#ifdef __cplusplus

#define COMPILING_SHADER_CODE 0

#include <Util\Vectormath.h>
#include <Gfx\Math\DirectXMathWrap.h>

typedef Matrix4 float4x4;
typedef Vector4 float4;
typedef spad::dxmath::Float3 float3;

#define cfloat3 float3

#define CBUFFER struct
#define MAKE_REGISTER_SAMPLER( index )		index
#define MAKE_REGISTER_CBUFFER( index )		index
#define MAKE_REGISTER_SRV( index )			index
#define MAKE_REGISTER_UAV( index )			index


#define MAKE_FLAT_CBUFFER( _name, _register ) struct _name

#define CBUFFER_FLOAT4X4( name )								Matrix4 name
#define CBUFFER_UINT4( name )									uint name[4]
#define CBUFFER_FLOAT4( name )									Vector4 name

#else

#define COMPILING_SHADER_CODE 1

#define cfloat3 float3

//#define REGISTER_B(exp) : register(b##exp) // constant buffer
//#define REGISTER_T(exp) : register(t##exp) // texture or buffer
//#define REGISTER_U(exp) : register(u##exp) // unordered access
//#define REGISTER_S(exp) : register(s##exp) // sampler

#define MAKE_REGISTER( prefix, index ) : register( prefix ## index )
#define MAKE_REGISTER_SAMPLER( index )		MAKE_REGISTER( s, index )
#define MAKE_REGISTER_CBUFFER( index )		MAKE_REGISTER( b, index )
#define MAKE_REGISTER_SRV( index )			MAKE_REGISTER( t, index )
#define MAKE_REGISTER_UAV( index )			MAKE_REGISTER( u, index )


#define CBUFFER cbuffer

#define MAKE_FLAT_CBUFFER( _name, _register ) cbuffer _name _register

#define CBUFFER_FLOAT4X4( name )								float4x4 name
#define CBUFFER_UINT4( name )									uint4 name
#define CBUFFER_FLOAT4( name )									float4 name

//#define safe_mul24( x, y ) ( x * y )
//#define safe_mad24( x, y, a ) ( x * y + a )

//#define safe_mul24( x, y ) mul( x, y )
//#define safe_mad24( x, y, a ) mad( x, y, a )

uint safe_mul24( uint x, uint y )         { return mul( x, y ); }
uint safe_mad24( uint x, uint y, uint a ) { return mad( x, y, a ); }

#define min3( x, y, z ) min( x, min( y, z ) )
#define max3( x, y, z ) max( x, max( y, z ) )

#endif //

#endif // HLSLFRAMEWORKINTEROP_H
