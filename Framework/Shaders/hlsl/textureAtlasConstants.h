#ifndef TEXTUREATLAS_CONSTANTS_H
#define TEXTUREATLAS_CONSTANTS_H

#include "HlslFrameworkInterop.h"

// follows vector math convention, matrices are column major
// multiplication must be done: vecResult = mat * vec

CBUFFER CbTextureAtlasConstants REGISTER_B(2)
{
	float4x4 WorldToDecal; // world to decal transform
	int outputMode;
	int derivativesMode;
	int textureMode;
	int samplerMode;
};


#endif // TEXTUREATLAS_CONSTANTS_H
