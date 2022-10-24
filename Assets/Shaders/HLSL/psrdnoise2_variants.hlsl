//
// psrdnoise2_variants.hlsl
//
// Authors: Stefan Gustavson (stefan.gustavson@gmail.com)
// and Ian McEwan (ijm567@gmail.com)
// Shannon Rowe (chmodseven@gmail.com) for HLSL port
// Version 2021-12-02, published under the MIT license (see below)
//
// Copyright (c) 2021 Stefan Gustavson and Ian McEwan.
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.
//
// Periodic (tiling) 2-D simplex noise (hexagonal lattice gradient noise)
// with rotating gradients and analytic derivatives.
//
// This is (yet) another variation on simplex noise. Unlike previous
// implementations, the grid is axis-aligned and slightly stretched in
// the y direction to permit rectangular tiling.
// The noise pattern can be made to tile seamlessly to any integer period
// in x and any even integer period in y. Odd periods may be specified
// for y, but then the actual tiling period will be twice that number.
//
// The rotating gradients give the appearance of a swirling motion, and
// can serve a similar purpose for animation as motion along z in 3-D
// noise. The rotating gradients in conjunction with the analytic
// derivatives allow for "flow noise" effects as presented by Ken
// Perlin and Fabrice Neyret.
//
// 2-D tiling simplex noise with rotating gradients and analytical derivative.
// "float2 x" is the point (x,y) to evaluate,
// "float2 period" is the desired periods along x and y, and
// "float alpha" is the rotation (in radians) for the swirling gradients.
// The "float" return value is the noise value, and
// the "out float2 gradient" argument returns the x,y partial derivatives.
//
// Setting either period to 0.0 or a negative value will skip the wrapping
// along that dimension. Setting both periods to 0.0 makes the function
// execute about 15% faster.
//
// Not using the return value for the gradient will make the compiler
// eliminate the code for computing it. This speeds up the function
// by 10-15%.
//
// The rotation by alpha uses one single addition. Unlike the 3-D version
// of psrdnoise(), setting alpha == 0.0 gives no speedup.
//

// ReSharper disable CppParameterMayBeConst
// ReSharper disable CppLocalVariableMayBeConst
// ReSharper disable CppAssignedValueIsNeverUsed
// ReSharper disable CppInconsistentNaming

#ifndef _INCLUDE_PSRDNOISE2_VARIANTS_HLSL_
#define _INCLUDE_PSRDNOISE2_VARIANTS_HLSL_

#include "./psrdnoise2.hlsl"

float psrdnoise2_fbm (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    int variant, int octaves, float frequency, float amplitude, float lacunarity, float gain, out float2 gradient)
{
    int numberVariants = 3;
    if (octaves <= 0.0 || variant < 0 || variant >= numberVariants)
    {
        gradient = float2 (0.0, 0.0);
        return 0.0;
    }

    float value = 0.0;
    
    if (variant == 0)
    {
        // Standard
        for (int i = 0; i < octaves; ++i)
        {
            float2 adjustedPos = float2 (pos.x * frequency, pos.y * frequency);
            float noise = psrdnoise2 (adjustedPos, period, alpha, useSeed, seed, gradient) * amplitude;
            value += noise;
            frequency *= lacunarity;
            amplitude *= gain;
        }
    }
    else if (variant == 1)
    {
        // Valleys
        for (int i = 0; i < octaves; ++i)
        {
            float2 adjustedPos = float2 (pos.x * frequency, pos.y * frequency);
            float noise = psrdnoise2 (adjustedPos, period, alpha, useSeed, seed, gradient) * amplitude;
            value += abs (noise);
            frequency *= lacunarity;
            amplitude *= gain;
        }
    }
    else if (variant == 2)
    {
        // Ridges
        float previousNoise = 0.0;
        for (int i = 0; i < octaves; ++i)
        {
            float offset = 0.9;
            float2 adjustedPos = float2 (pos.x * frequency, pos.y * frequency);
            float noise = psrdnoise2 (adjustedPos, period, alpha, useSeed, seed, gradient);
            noise = abs (noise);
            noise = offset - noise;
            noise = noise * noise;
            value += noise * amplitude;
            value += noise * amplitude * previousNoise;
            previousNoise = noise;
            frequency *= lacunarity;
            amplitude *= gain;
        }
    }
    
    return value;
}

// Used by ShaderGraph
void psrdnoise2_fbm_float (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    int variant, int octaves, float frequency, float amplitude, float lacunarity, float gain,
    out float value, out float2 gradient)
{
    value = psrdnoise2_fbm (pos, period, alpha, useSeed, seed,
        variant, octaves, frequency, amplitude, lacunarity, gain, gradient);
}

// Used by ShaderGraph
void psrdnoise2_fbm_half (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    int variant, int octaves, float frequency, float amplitude, float lacunarity, float gain,
    out half value, out half2 gradient)
{
    value = psrdnoise2_fbm (pos, period, alpha, useSeed, seed,
        variant, octaves, frequency, amplitude, lacunarity, gain, gradient);
}

float psrdnoise2_fractal (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    float time = alpha;
    const float scale = 6.0;
    float2 v = scale * (pos - 0.5);
    float2 p = period;
    float a = 0.5 * time;
    float n = 0.5;
    n += 0.4 * psrdnoise2 (v, p, a, useSeed, seed, gradient);
    n += 0.2 * psrdnoise2 (2.0 * v + 0.1, p * 2.0, 2.0 * a, useSeed, seed, gradient);
    n += 0.1 * psrdnoise2 (3.0 * v + 0.2, p * 4.0, 4.0 * a, useSeed, seed, gradient);
    n += 0.05 * psrdnoise2 (8.0 *v + 0.3, p * 8.0, 8.0 * a, useSeed, seed, gradient);
    n += 0.025 * psrdnoise2 (16.0 * v, p * 16.0, 16.0 * a, useSeed, seed, gradient);
    return n;
}

// Used by ShaderGraph
void psrdnoise2_fractal_float (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out float value, out float2 gradient)
{
    value = psrdnoise2_fractal (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise2_fractal_half (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out half value, out half2 gradient)
{
    value = psrdnoise2_fractal (pos, period, alpha, useSeed, seed, gradient);
}

float psrdnoise2_warped_fractal (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{ 
    const float nscale = 4.0;
    float2 v = nscale * (pos - 0.5);
    float warp = 0.13 * clamp (1.1 - pos.y * 1.2, 0.0, 1.0);
    float n = 0.5;
    n += 0.4 * psrdnoise2 (v, period, alpha, useSeed, seed, gradient);
    float2 gsum = gradient;
    float2 warped_v = v * 2.0 + warp * gsum;
    n += 0.2 * psrdnoise2 (warped_v, period, alpha * 2.0, useSeed, seed, gradient);
    gsum += 0.5 * gradient;
    warped_v = v * 4.0 + warp*gsum;
    n += 0.1 * psrdnoise2 (warped_v, period, alpha * 4.0, useSeed, seed, gradient);
    gsum += 0.25 * gradient;
    warped_v = v * 8.0 + warp*gsum;
    n += 0.05 * psrdnoise2 (warped_v, period, alpha * 8.0, useSeed, seed, gradient);
    return n;
}

// Used by ShaderGraph
void psrdnoise2_warped_fractal_float (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out float value, out float2 gradient)
{
    value = psrdnoise2_warped_fractal (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise2_warped_fractal_half (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out half value, out half2 gradient)
{
    value = psrdnoise2_warped_fractal (pos, period, alpha, useSeed, seed, gradient);
}

float psrdnoise2_flow_noise (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    const float nscale = 4.0;
    float2 v = nscale * (pos - 0.5);
    float n = 0.5;
    float warpamount = clamp (1.1 - pos.y * 1.2, 0.0, 1.0);
    n += 0.4 * psrdnoise2 (v, period, alpha, useSeed, seed, gradient);
    float2 gsum = gradient;
    float2 warped_v = v * 2.0 + 0.15 * warpamount * gsum;
    n += 0.2 * psrdnoise2 (warped_v, period * 2.0, alpha * 2.0, useSeed, seed, gradient);
    return n;
}

// Used by ShaderGraph
void psrdnoise2_flow_noise_float (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out float value, out float2 gradient)
{
    value = psrdnoise2_flow_noise (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise2_flow_noise_half (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out half value, out half2 gradient)
{
    value = psrdnoise2_flow_noise (pos, period, alpha, useSeed, seed, gradient);
}

float psrdnoise2_billowing_smoke (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    const float nscale = 4.0;
    float2 v = nscale * (pos - 0.5);
    float n = 0.0;
    float w = 1.0;
    float s = 1.0;
    float2 gsum = float2 (0.0, 0.0);
    for (float i = 0.0; i < 5.0; i++)
    {
        float warp = 0.13;
        n += w * psrdnoise2 (s * v + warp * gsum, s * period, s * alpha, useSeed, seed, gradient);
        gsum += w * gradient;
        w *= 0.5;
        s *= 2.0;
    }
    return 0.5 + 0.4 * n;
}

// Used by ShaderGraph
void psrdnoise2_billowing_smoke_float (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out float value, out float2 gradient)
{
    value = psrdnoise2_billowing_smoke (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise2_billowing_smoke_half (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out half value, out half2 gradient)
{
    value = psrdnoise2_billowing_smoke (pos, period, alpha, useSeed, seed, gradient);
}

float psrdnoise2_tendrils (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{ 
    const float nscale = 4.0;
    float2 v = nscale * (pos - 0.5);
    float n = 0.0;
    float w = 1.0;
    float s = 1.0;
    float2 gsum = float2 (0.0, 0.0);
    for (float i = 0.0; i < 5.0; i++)
    {
        float warp = 0.13;
        n += w * psrdnoise2 (s * v + warp * gsum, s * period, s * alpha, useSeed, seed, gradient);
        gsum += w * gradient;
        w *= 0.5;
        s *= 2.0;
    }
    return 0.5 - 0.4 * n;
}

// Used by ShaderGraph
void psrdnoise2_tendrils_float (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out float value, out float2 gradient)
{
    value = psrdnoise2_tendrils (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise2_tendrils_half (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out half value, out half2 gradient)
{
    value = psrdnoise2_tendrils (pos, period, alpha, useSeed, seed, gradient);
}

float psrdnoise2_not_bump (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    const float nscale = 8.0;
    float2 v = nscale * (pos - 0.5);
    float n = 0.5;
    n += 0.4 * psrdnoise2 (v, period, alpha, useSeed, seed, gradient);
    float2 gsum = gradient;
    n += 0.2 * psrdnoise2 (v * 2.0 + 0.11 * gsum, period * 2.0, alpha * 2.0, useSeed, seed, gradient);
    gsum += gradient;
    float3 N = normalize (float3 (-gsum, 1.0));
    float3 L = normalize (float3 (1.0, 1.0, 1.0));
    return pow (max (dot (N,L), 0.0), 10.0);
}

// Used by ShaderGraph
void psrdnoise2_not_bump_float (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out float value, out float2 gradient)
{
    value = psrdnoise2_not_bump (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise2_not_bump_half (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out half value, out half2 gradient)
{
    value = psrdnoise2_not_bump (pos, period, alpha, useSeed, seed, gradient);
}

#endif