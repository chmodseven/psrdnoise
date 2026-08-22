//
// psrdnoise3_variants.hlsl
//
// Authors: Stefan Gustavson (stefan.gustavson@gmail.com)
// and Ian McEwan (ijm567@gmail.com)
// Shannon Rowe (chmodseven@gmail.com) for HLSL port
// Published under the MIT license (see below)
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
// ---------------------------------------------------------------------------
// 3-D counterparts of the variants in psrdnoise2_variants.hlsl.
//
// The composition -- octave ladders, weights, warp strengths, ridge and valley
// folds -- is identical to the 2-D file, term for term. Only the dimension
// changes: float3 positions, float3 periods, float3 gradients, and psrdnoise3
// in place of psrdnoise2. Matching a 2-D and a 3-D variant with the same
// parameters therefore gives the same character of pattern.
//
// USAGE
//
// These are pure functions of the position handed to them. No UV-space scale
// or centre offset is applied, so feed them whatever coordinate frame the
// caller works in.
//
// To scrub through a volume, vary pos.z. Because the field is a pure function
// of position, a z sweep is a continuous cross-section through one static
// volume -- useful for inspecting the field, and for baking a 3-D texture
// slice by slice.
//
// To ANIMATE, vary alpha instead. alpha rotates the generating gradients in
// place, so the field churns without translating. That is a different motion
// from a z sweep and usually the one wanted for smoke, cloud and fog.
//
// PERIODICITY
//
// psrdnoise3 supports periods up to 289 in each axis. Asking for more does not
// work: the hash is modulo 289, so the field repeats at 289 lattice units
// whatever is requested. Every octave here scales the period with its
// frequency, so the OUTERMOST octave is the binding constraint -- a variant
// with a 16x top octave needs its base period at or below 289 / 16.
//
// GRADIENTS
//
// fbm and fractal return an exact analytic gradient. The domain-warped
// variants return an approximation that ignores the warp Jacobian, which would
// need the Hessian of the noise. Each is marked below.
// ---------------------------------------------------------------------------

// ReSharper disable CppParameterMayBeConst
// ReSharper disable CppLocalVariableMayBeConst
// ReSharper disable CppAssignedValueIsNeverUsed
// ReSharper disable CppInconsistentNaming

#ifndef _INCLUDE_PSRDNOISE3_VARIANTS_HLSL_
#define _INCLUDE_PSRDNOISE3_VARIANTS_HLSL_

#include "./psrdnoise3.hlsl"

// Fractal Brownian motion in 3-D. Exact analytic gradient.
// variant: 0 = standard, 1 = valleys, 2 = ridges.
float psrdnoise3_fbm (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    int variant, int octaves, float frequency, float amplitude, float lacunarity, float gain, out float3 gradient)
{
    int numberVariants = 3;
    gradient = float3 (0.0, 0.0, 0.0);
    if (octaves <= 0 || variant < 0 || variant >= numberVariants)
    {
        return 0.0;
    }

    float value = 0.0;
    float3 octaveGradient;

    if (variant == 0)
    {
        // Standard
        for (int i = 0; i < octaves; ++i)
        {
            float noise = psrdnoise3 (pos * frequency, period * frequency, alpha,
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
            float noise = psrdnoise3 (pos * frequency, period * frequency, alpha,
                useSeed, seed, octaveGradient);
            value += abs (noise) * amplitude;
            gradient += sign (noise) * octaveGradient * amplitude * frequency;
            frequency *= lacunarity;
            amplitude *= gain;
        }
    }
    else if (variant == 2)
    {
        // Ridges
        float previousNoise = 0.0;
        float3 previousGradient = float3 (0.0, 0.0, 0.0);
        for (int i = 0; i < octaves; ++i)
        {
            float offset = 0.9;
            float noise = psrdnoise3 (pos * frequency, period * frequency, alpha,
                useSeed, seed, octaveGradient);

            float3 dAbs = sign (noise) * octaveGradient * frequency;
            float ridge = offset - abs (noise);
            float3 dRidge = -dAbs;
            float squared = ridge * ridge;
            float3 dSquared = 2.0 * ridge * dRidge;

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
void psrdnoise3_fbm_float (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    int variant, int octaves, float frequency, float amplitude, float lacunarity, float gain,
    out float value, out float3 gradient)
{
    value = psrdnoise3_fbm (pos, period, alpha, useSeed, seed,
        variant, octaves, frequency, amplitude, lacunarity, gain, gradient);
}

// Used by ShaderGraph
void psrdnoise3_fbm_half (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    int variant, int octaves, float frequency, float amplitude, float lacunarity, float gain,
    out half value, out half3 gradient)
{
    float3 g;
    value = psrdnoise3_fbm (pos, period, alpha, useSeed, seed,
        variant, octaves, frequency, amplitude, lacunarity, gain, g);
    gradient = g;
}

// Five-octave fractal on a 1, 2, 3, 8, 16 frequency ladder.
// alpha is used as a time value here. Exact analytic gradient.
float psrdnoise3_fractal (float3 pos, float3 period, float alpha, bool useSeed, float4 seed, out float3 gradient)
{
    float a = 0.5 * alpha;
    float3 g;
    float n = 0.5;

    n += 0.4 * psrdnoise3 (pos, period, a, useSeed, seed, g);
    gradient = 0.4 * g;
    n += 0.2 * psrdnoise3 (2.0 * pos + 0.1, period * 2.0, 2.0 * a, useSeed, seed, g);
    gradient += 0.2 * 2.0 * g;
    n += 0.1 * psrdnoise3 (3.0 * pos + 0.2, period * 3.0, 4.0 * a, useSeed, seed, g);
    gradient += 0.1 * 3.0 * g;
    n += 0.05 * psrdnoise3 (8.0 * pos + 0.3, period * 8.0, 8.0 * a, useSeed, seed, g);
    gradient += 0.05 * 8.0 * g;
    n += 0.025 * psrdnoise3 (16.0 * pos, period * 16.0, 16.0 * a, useSeed, seed, g);
    gradient += 0.025 * 16.0 * g;

    return n;
}

// Used by ShaderGraph
void psrdnoise3_fractal_float (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out float value, out float3 gradient)
{
    value = psrdnoise3_fractal (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise3_fractal_half (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out half value, out half3 gradient)
{
    float3 g;
    value = psrdnoise3_fractal (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// Four octaves, later ones warped by the accumulated gradient.
// Gradient is APPROXIMATE: the warp Jacobian is ignored.
float psrdnoise3_warped_fractal (float3 pos, float3 period, float alpha, bool useSeed, float4 seed, out float3 gradient)
{
    const float warp = 0.13;
    float3 g;
    float n = 0.5;

    n += 0.4 * psrdnoise3 (pos, period, alpha, useSeed, seed, g);
    gradient = 0.4 * g;
    float3 gsum = g;

    float3 warped = pos * 2.0 + warp * gsum;
    n += 0.2 * psrdnoise3 (warped, period * 2.0, alpha * 2.0, useSeed, seed, g);
    gradient += 0.2 * 2.0 * g;
    gsum += 0.5 * g;

    warped = pos * 4.0 + warp * gsum;
    n += 0.1 * psrdnoise3 (warped, period * 4.0, alpha * 4.0, useSeed, seed, g);
    gradient += 0.1 * 4.0 * g;
    gsum += 0.25 * g;

    warped = pos * 8.0 + warp * gsum;
    n += 0.05 * psrdnoise3 (warped, period * 8.0, alpha * 8.0, useSeed, seed, g);
    gradient += 0.05 * 8.0 * g;

    return n;
}

// Used by ShaderGraph
void psrdnoise3_warped_fractal_float (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out float value, out float3 gradient)
{
    value = psrdnoise3_warped_fractal (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise3_warped_fractal_half (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out half value, out half3 gradient)
{
    float3 g;
    value = psrdnoise3_warped_fractal (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// Two octaves, the second warped by the first's gradient.
// Gradient is APPROXIMATE: the warp Jacobian is ignored.
float psrdnoise3_flow_noise (float3 pos, float3 period, float alpha, bool useSeed, float4 seed, out float3 gradient)
{
    const float warp = 0.15;
    float3 g;
    float n = 0.5;

    n += 0.4 * psrdnoise3 (pos, period, alpha, useSeed, seed, g);
    gradient = 0.4 * g;
    float3 gsum = g;

    float3 warped = pos * 2.0 + warp * gsum;
    n += 0.2 * psrdnoise3 (warped, period * 2.0, alpha * 2.0, useSeed, seed, g);
    gradient += 0.2 * 2.0 * g;

    return n;
}

// Used by ShaderGraph
void psrdnoise3_flow_noise_float (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out float value, out float3 gradient)
{
    value = psrdnoise3_flow_noise (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise3_flow_noise_half (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out half value, out half3 gradient)
{
    float3 g;
    value = psrdnoise3_flow_noise (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// Five octaves warped by the running gradient sum, biased bright.
// The natural base for volumetric smoke, cloud and fog: sample it in a
// raymarch or into a froxel grid, and animate it with alpha.
// Gradient is APPROXIMATE: the warp Jacobian is ignored. It is still the
// cheapest density gradient available, and it removes the six extra samples a
// central-difference normal would cost per raymarch step.
float psrdnoise3_billowing_smoke (float3 pos, float3 period, float alpha, bool useSeed, float4 seed, out float3 gradient)
{
    const float warp = 0.13;
    float n = 0.0;
    float w = 1.0;
    float s = 1.0;
    float3 g;
    float3 gsum = float3 (0.0, 0.0, 0.0);
    float3 gradAcc = float3 (0.0, 0.0, 0.0);

    for (float i = 0.0; i < 5.0; i++)
    {
        n += w * psrdnoise3 (s * pos + warp * gsum, s * period, s * alpha, useSeed, seed, g);
        gsum += w * g;              // drives the warp; deliberately unscaled by s
        gradAcc += w * s * g;       // the actual derivative of n
        w *= 0.5;
        s *= 2.0;
    }

    gradient = 0.4 * gradAcc;
    return 0.5 + 0.4 * n;
}

// Used by ShaderGraph
void psrdnoise3_billowing_smoke_float (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out float value, out float3 gradient)
{
    value = psrdnoise3_billowing_smoke (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise3_billowing_smoke_half (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out half value, out half3 gradient)
{
    float3 g;
    value = psrdnoise3_billowing_smoke (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// The same accumulation biased dark, which inverts the structure into bright
// filaments around darker cells.
// Gradient is APPROXIMATE: the warp Jacobian is ignored.
float psrdnoise3_tendrils (float3 pos, float3 period, float alpha, bool useSeed, float4 seed, out float3 gradient)
{
    const float warp = 0.13;
    float n = 0.0;
    float w = 1.0;
    float s = 1.0;
    float3 g;
    float3 gsum = float3 (0.0, 0.0, 0.0);
    float3 gradAcc = float3 (0.0, 0.0, 0.0);

    for (float i = 0.0; i < 5.0; i++)
    {
        n += w * psrdnoise3 (s * pos + warp * gsum, s * period, s * alpha, useSeed, seed, g);
        gsum += w * g;              // drives the warp; deliberately unscaled by s
        gradAcc += w * s * g;       // the actual derivative of n
        w *= 0.5;
        s *= 2.0;
    }

    gradient = -0.4 * gradAcc;
    return 0.5 - 0.4 * n;
}

// Used by ShaderGraph
void psrdnoise3_tendrils_float (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out float value, out float3 gradient)
{
    value = psrdnoise3_tendrils (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise3_tendrils_half (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out half value, out half3 gradient)
{
    float3 g;
    value = psrdnoise3_tendrils (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

// A lighting term that resembles a bump map without one.
// The 2-D version treats the field as a heightfield and builds a normal from
// float3(-gradient, 1). A 3-D scalar field has no such up axis, so the normal
// here is the isosurface normal: the normalised negative gradient.
// NOTE: as in 2-D, the returned value is a shaded luminance, and the gradient
// output is the accumulated FIELD gradient rather than the derivative of it.
float psrdnoise3_not_bump (float3 pos, float3 period, float alpha, bool useSeed, float4 seed, out float3 gradient)
{
    const float warp = 0.11;
    float3 g;
    float n = 0.5;

    n += 0.4 * psrdnoise3 (pos, period, alpha, useSeed, seed, g);
    float3 gsum = 0.4 * g;

    n += 0.2 * psrdnoise3 (pos * 2.0 + warp * gsum, period * 2.0, alpha * 2.0, useSeed, seed, g);
    gsum += 0.2 * 2.0 * g;

    gradient = gsum;

    // Isosurface normal, guarded against a vanishing gradient in a flat region
    float3 negated = -gsum;
    float len = max (length (negated), 1e-6);
    float3 N = negated / len;
    float3 L = normalize (float3 (1.0, 1.0, 1.0));
    return pow (max (dot (N, L), 0.0), 10.0);
}

// Used by ShaderGraph
void psrdnoise3_not_bump_float (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out float value, out float3 gradient)
{
    value = psrdnoise3_not_bump (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise3_not_bump_half (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out half value, out half3 gradient)
{
    float3 g;
    value = psrdnoise3_not_bump (pos, period, alpha, useSeed, seed, g);
    gradient = g;
}

#endif
