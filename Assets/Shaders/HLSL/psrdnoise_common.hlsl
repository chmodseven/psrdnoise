// ReSharper disable CppInconsistentNaming
// ReSharper disable CppParameterMayBeConst
// ReSharper disable CppLocalVariableMayBeConst

// This prevents includes shared across multiple subgraphs from giving redefinition error  
#ifndef _INCLUDE_PSRDNOISE_COMMON_HLSL_
#define _INCLUDE_PSRDNOISE_COMMON_HLSL_

float mod (float x, float y)
{
    return x - y * floor (x / y);
}

float2 mod (float2 x, float2 y)
{
    return x - y * floor (x / y);
}

float3 mod (float3 x, float3 y)
{
    return x - y * floor (x / y);
}

float4 mod (float4 x, float4 y)
{
    return x - y * floor (x / y);
}

float4 permute (float4 x)
{
    float4 xm = mod (x, 289.0);
    return mod ((xm * 34.0 + 10.0) * xm, 289.0);
}

float permute (float x, float seedPart)
{
    float xm = mod (x, 289.0);
    return mod ((xm * 34.0 + 10.0 + seedPart) * xm, 289.0);
}

float2 permute (float2 x, float seedPart)
{
    float2 xm = mod (x, 289.0);
    return mod ((xm * 34.0 + 10.0 + seedPart) * xm, 289.0);
}

float3 permute (float3 x, float seedPart)
{
    float3 xm = mod (x, 289.0);
    return mod ((xm * 34.0 + 10.0 + seedPart) * xm, 289.0);
}

float4 permute (float4 x, float seedPart)
{
    float4 xm = mod (x, 289.0);
    return mod ((xm * 34.0 + 10.0 + seedPart) * xm, 289.0);
}

float4 permute_half (float4 x)
{
    float4 xm = mod (x, 49.0);
    return mod ((xm * 14.0 + 4.0) * xm, 49.0);
}

float permute_half (float x, float seedPart)
{
    float xm = mod (x, 49.0);
    return mod ((xm * 14.0 + 4.0 + seedPart) * xm, 49.0);
}

float2 permute_half (float2 x, float seedPart)
{
    float2 xm = mod (x, 49.0);
    return mod ((xm * 14.0 + 4.0 + seedPart) * xm, 49.0);
}

float3 permute_half (float3 x, float seedPart)
{
    float3 xm = mod (x, 49.0);
    return mod ((xm * 14.0 + 4.0 + seedPart) * xm, 49.0);
}

float4 permute_half (float4 x, float seedPart)
{
    float4 xm = mod (x, 49.0);
    return mod ((xm * 14.0 + 4.0 + seedPart) * xm, 49.0);
}

#endif