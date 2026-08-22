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
// Composed variants of the 2-D psrdnoise function: fBM, fractal, warped
// fractal, flow noise, billowing smoke, tendrils, and a fake bump lighting
// term. Each is a short accumulation loop over psrdnoise2().
//
// ---------------------------------------------------------------------------
// THREE THINGS CHANGED FROM THE ORIGINAL DEMO VERSIONS
//
// 1. THE GRADIENT OUTPUT IS NOW CORRECT.
//    Every variant previously returned the LAST octave's gradient, which is
//    not the gradient of the value it returns. Each now accumulates the
//    gradient by the chain rule: an octave sampled at frequency f contributes
//    its gradient scaled by its amplitude AND by f.
//
//    Where a variant WARPS its sample position by an accumulated gradient
//    (warped_fractal, flow_noise, billowing_smoke, tendrils, not_bump), the
//    exact derivative would need the Jacobian of the warp, which in turn needs
//    the Hessian of the noise. psrdnoise does not return one. Those variants
//    therefore return an APPROXIMATE gradient that ignores the warp Jacobian.
//    This is the usual practice for domain-warped noise and is accurate enough
//    for normals and slopes, but it is an approximation and is marked as such
//    on each function.
//
// 2. PERIOD NOW SCALES WITH FREQUENCY IN EVERY OCTAVE.
//    An octave that samples at f times the position must also be given f times
//    the period, or it does not wrap where the caller asked. fBM, fractal and
//    warped_fractal all passed the period through unscaled and so only tiled
//    on their first octave.
//
//    Note this affects PERIODIC WRAP only. Field continuity across adjacent
//    chunks never depended on it, so splitting a pattern across tiles by
//    shifting the sample position was, and remains, correct.
//
// 3. THE HARDCODED UV-SPACE TRANSFORM IS GONE.
//    Every variant began with "v = nscale * (pos - 0.5)", with nscale fixed at
//    4, 6, or 8. That is right for a demo quad with UVs in [0,1] and wrong for
//    world-space or tier-local coordinates, and it also broke the period,
//    because the position was scaled while the period was not.
//
//    The variants are now pure functions of the position handed to them.
//    TO REPRODUCE THE PREVIOUS APPEARANCE from a material, fold the transform
//    into the material's own Scale and Offset:
//        Scale  := Scale * nscale
//        Offset := Offset * nscale - nscale * 0.5
//    where nscale was 4 for most variants, 6 for fractal, 8 for not_bump.
//
//    Two position-dependent warp ramps have also gone, for the same reason:
//    warped_fractal and flow_noise faded their warp with "1.1 - pos.y * 1.2",
//    which put an unexplained top-to-bottom gradient on any surface.
// ---------------------------------------------------------------------------

// ReSharper disable CppParameterMayBeConst
// ReSharper disable CppLocalVariableMayBeConst
// ReSharper disable CppAssignedValueIsNeverUsed
// ReSharper disable CppInconsistentNaming

#ifndef _INCLUDE_PSRDNOISE2_VARIANTS_HLSL_
#define _INCLUDE_PSRDNOISE2_VARIANTS_HLSL_

#include "./psrdnoise2.hlsl"

// Fractal Brownian motion. Exact analytic gradient.
// variant: 0 = standard, 1 = valleys, 2 = ridges.
float psrdnoise2_fbm (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    int variant, int octaves, float frequency, float amplitude, float lacunarity, float gain, out float2 gradient)
{
    int numberVariants = 3;
    gradient = float2 (0.0, 0.0);
    if (octaves <= 0 || variant < 0 || variant >= numberVariants)
    {
        return 0.0;
    }

    float value = 0.0;
    float2 octaveGradient;

    if (variant == 0)
    {
        // Standard
        for (int i = 0; i < octaves; ++i)
        {
            float noise = psrdnoise2 (pos * frequency, period * frequency, alpha,
                useSeed, seed, octaveGradient);
            value += noise * amplitude;
            gradient += octaveGradient * amplitude * frequency;
            frequency *= lacunarity;
            amplitude *= gain;
        }
    }
    else if (variant == 1)
    {
        // Valleys. d|n| = sign(n) * dn
        for (int i = 0; i < octaves; ++i)
        {
            float noise = psrdnoise2 (pos * frequency, period * frequency, alpha,
                useSeed, seed, octaveGradient);
            value += abs (noise) * amplitude;
            gradient += sign (noise) * octaveGradient * amplitude * frequency;
            frequency *= lacunarity;
            amplitude *= gain;
        }
    }
    else if (variant == 2)
    {
        // Ridges. Each octave forms q = (offset - |n|)^2 and contributes
        // q * amplitude * (1 + previous q), so the derivative needs both the
        // derivative of q and that of the previous octave's q.
        float previousNoise = 0.0;
        float2 previousGradient = float2 (0.0, 0.0);
        for (int i = 0; i < octaves; ++i)
        {
            float offset = 0.9;
            float noise = psrdnoise2 (pos * frequency, period * frequency, alpha,
                useSeed, seed, octaveGradient);

            float2 dAbs = sign (noise) * octaveGradient * frequency;
            float ridge = offset - abs (noise);
            float2 dRidge = -dAbs;
            float squared = ridge * ridge;
            float2 dSquared = 2.0 * ridge * dRidge;

            value += squared * amplitude;
            value += squared * amplitude * previousNoise;
            gradient += amplitude * ((1.0 + previousNoise) * dSquared + squared * previousGradient);

            previousNoise = squared;
            previousGradient = dSquared;
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
    float2 g;
    value = psrdnoise2_fbm (pos, period, alpha, useSeed, seed,
        variant, octaves, frequency, amplitude, lacunarity, gain, g);
    gradient = g;
}

// Five-octave fractal on a 1, 2, 3, 8, 16 frequency ladder.
// alpha is used as a time value here; the rotation advances with frequency.
// Exact analytic gradient.
float psrdnoise2_fractal (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    float a = 0.5 * alpha;
    float2 g;
    float n = 0.5;

    n += 0.4 * psrdnoise2 (pos, period, a, useSeed, seed, g);
    gradient = 0.4 * g;
    n += 0.2 * psrdnoise2 (2.0 * pos + 0.1, period * 2.0, 2.0 * a, useSeed, seed, g);
    gradient += 0.2 * 2.0 * g;
    n += 0.1 * psrdnoise2 (3.0 * pos + 0.2, period * 3.0, 4.0 * a, useSeed, seed, g);
    gradient += 0.1 * 3.0 * g;
    n += 0.05 * psrdnoise2 (8.0 * pos + 0.3, period * 8.0, 8.0 * a, useSeed, seed, g);
    gradient += 0.05 * 8.0 * g;
    n += 0.025 * psrdnoise2 (16.0 * pos, period * 16.0, 16.0 * a, useSeed, seed, g);
    gradient += 0.025 * 16.0 * g;

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
    float2 g;
    value = psrdnoise2_fractal (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// Four-octave fractal whose later octaves are warped by the accumulated
// gradient of the earlier ones. Gradient is APPROXIMATE: the warp Jacobian is
// ignored.
float psrdnoise2_warped_fractal (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    const float warp = 0.13;
    float2 g;
    float n = 0.5;

    n += 0.4 * psrdnoise2 (pos, period, alpha, useSeed, seed, g);
    gradient = 0.4 * g;
    float2 gsum = g;

    float2 warped = pos * 2.0 + warp * gsum;
    n += 0.2 * psrdnoise2 (warped, period * 2.0, alpha * 2.0, useSeed, seed, g);
    gradient += 0.2 * 2.0 * g;
    gsum += 0.5 * g;

    warped = pos * 4.0 + warp * gsum;
    n += 0.1 * psrdnoise2 (warped, period * 4.0, alpha * 4.0, useSeed, seed, g);
    gradient += 0.1 * 4.0 * g;
    gsum += 0.25 * g;

    warped = pos * 8.0 + warp * gsum;
    n += 0.05 * psrdnoise2 (warped, period * 8.0, alpha * 8.0, useSeed, seed, g);
    gradient += 0.05 * 8.0 * g;

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
    float2 g;
    value = psrdnoise2_warped_fractal (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// Two octaves, the second warped by the first's gradient.
// Gradient is APPROXIMATE: the warp Jacobian is ignored.
float psrdnoise2_flow_noise (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    const float warp = 0.15;
    float2 g;
    float n = 0.5;

    n += 0.4 * psrdnoise2 (pos, period, alpha, useSeed, seed, g);
    gradient = 0.4 * g;
    float2 gsum = g;

    float2 warped = pos * 2.0 + warp * gsum;
    n += 0.2 * psrdnoise2 (warped, period * 2.0, alpha * 2.0, useSeed, seed, g);
    gradient += 0.2 * 2.0 * g;

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
    float2 g;
    value = psrdnoise2_flow_noise (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// Five octaves warped by the running gradient sum, biased bright.
// Gradient is APPROXIMATE: the warp Jacobian is ignored.
float psrdnoise2_billowing_smoke (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    const float warp = 0.13;
    float n = 0.0;
    float w = 1.0;
    float s = 1.0;
    float2 g;
    float2 gsum = float2 (0.0, 0.0);
    float2 gradAcc = float2 (0.0, 0.0);

    for (float i = 0.0; i < 5.0; i++)
    {
        n += w * psrdnoise2 (s * pos + warp * gsum, s * period, s * alpha, useSeed, seed, g);
        gsum += w * g;              // drives the warp; deliberately unscaled by s
        gradAcc += w * s * g;       // the actual derivative of n
        w *= 0.5;
        s *= 2.0;
    }

    gradient = 0.4 * gradAcc;
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
    float2 g;
    value = psrdnoise2_billowing_smoke (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// The same accumulation as billowing_smoke, biased dark, which inverts the
// structure into bright filaments around darker cells.
// Gradient is APPROXIMATE: the warp Jacobian is ignored.
float psrdnoise2_tendrils (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    const float warp = 0.13;
    float n = 0.0;
    float w = 1.0;
    float s = 1.0;
    float2 g;
    float2 gsum = float2 (0.0, 0.0);
    float2 gradAcc = float2 (0.0, 0.0);

    for (float i = 0.0; i < 5.0; i++)
    {
        n += w * psrdnoise2 (s * pos + warp * gsum, s * period, s * alpha, useSeed, seed, g);
        gsum += w * g;              // drives the warp; deliberately unscaled by s
        gradAcc += w * s * g;       // the actual derivative of n
        w *= 0.5;
        s *= 2.0;
    }

    gradient = -0.4 * gradAcc;
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
    float2 g;
    value = psrdnoise2_tendrils (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// A lighting term that resembles a bump map without one.
// NOTE: unlike the other variants, the returned value is a shaded luminance,
// not a scalar field. The gradient output is therefore the accumulated FIELD
// gradient used to build the surface normal, not the derivative of the
// returned luminance -- which is what a caller actually wants from it.
float psrdnoise2_not_bump (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    const float warp = 0.11;
    float2 g;
    float n = 0.5;

    n += 0.4 * psrdnoise2 (pos, period, alpha, useSeed, seed, g);
    float2 gsum = 0.4 * g;

    n += 0.2 * psrdnoise2 (pos * 2.0 + warp * gsum, period * 2.0, alpha * 2.0, useSeed, seed, g);
    gsum += 0.2 * 2.0 * g;

    gradient = gsum;

    float3 N = normalize (float3 (-gsum, 1.0));
    float3 L = normalize (float3 (1.0, 1.0, 1.0));
    return pow (max (dot (N, L), 0.0), 10.0);
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
    float2 g;
    value = psrdnoise2_not_bump (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

#endif
