//
// mpsrdnoise2.hlsl
//
// This variant of the 2D "psrdnoise" function is compatible with the
// 16-bit half-precision float type. Useful on platforms where
// half-floats are faster, or where 32-bit floats are unavailable.
//
// mpsrdnoise (c) Stefan Gustavson and Ian McEwan,
// Shannon Rowe (chmodseven@gmail.com) for HLSL port and added seed
// ver. 2022-03-29, published under the MIT license:
// https://github.com/stegu/psrdnoise/

// ReSharper disable CppParameterMayBeConst
// ReSharper disable CppLocalVariableMayBeConst
// ReSharper disable CppInconsistentNaming

#ifndef _INCLUDE_PSRDNOISE2_MIN_HLSL_
#define _INCLUDE_PSRDNOISE2_MIN_HLSL_

#include "./psrdnoise_common.hlsl"

float mpsrdnoise2 (float2 pos, float2 period, float alpha, bool useSeed, float4 seed, out float2 gradient)
{
    float2 uv = float2 (pos.x + pos.y * 0.5, pos.y);
    float2 i0 = floor (uv);
    float2 f0 = frac (uv);
    float cmp = step (f0.y, f0.x);
    float2 o1 = float2 (cmp, 1.0 - cmp);
    float2 i1 = i0 + o1;
    float2 i2 = i0 + float2 (1.0, 1.0);
    float2 v0 = float2 (i0.x - i0.y * 0.5, i0.y);
    float2 v1 = float2 (v0.x + o1.x - o1.y * 0.5, v0.y + o1.y);
    float2 v2 = float2 (v0.x + 0.5, v0.y + 1.0);
    float2 x0 = pos - v0;
    float2 x1 = pos - v1;
    float2 x2 = pos - v2;
    float3 iu;
    float3 iv;
    if (period.x > 0.0 || period.y > 0.0)
    {
        float3 xw = float3 (v0.x, v1.x, v2.x);
        float3 yw = float3 (v0.y, v1.y, v2.y);
        if (period.x > 0.0)
        {
            xw = mod (float3 (v0.x, v1.x, v2.x), period.x);
        }
        if (period.y > 0.0)
        {
            yw = mod (float3 (v0.y, v1.y, v2.y), period.y);
        }
        iu = floor (xw + yw * 0.5 + 0.5);
        iv = floor (yw + 0.5);
    }
    else
    {
        iu = float3 (i0.x, i1.x, i2.x);
        iv = float3 (i0.y, i1.y, i2.y);
    }

    // Expand the seed against the mediump modulus of 49 = 7*7.
    // Every term vanishes at seed 0, so a zero seed and useSeed = false both
    // give the published function exactly.
    float4 sd = useSeed ? seed : float4 (0.0, 0.0, 0.0, 0.0);
    float q0, t0, c0, q1, t1, c1, q2, t2, c2, q3, t3, c3;
    psrdnoise_slice (sd.x, 7.0, q0, t0, c0);
    psrdnoise_slice (sd.y, 7.0, q1, t1, c1);
    psrdnoise_slice (sd.z, 7.0, q2, t2, c2);
    psrdnoise_slice (sd.w, 7.0, q3, t3, c3);

    // Remap the two lattice indices by multipliers coprime to 7. The chain
    // itself takes additive seed terms only -- a multiplier there would raise
    // the largest product from 2352 to over 32000, far outside the
    // exact-integer range of a 16-bit float, which would defeat the entire
    // point of this variant. As written the largest product stays 2352:
    // exactly the original's, so the mediump envelope is unchanged.
    float mu = 1.0 + psrdnoise_pick (q0, t0, 7.0, 6.0);
    float mv = 1.0 + psrdnoise_pick (q3, t3, 7.0, 6.0);

    // Pairs of steps below COMPOSE into a permutation polynomial:
    //   steps 1 and 2 give 14*u^2 + (2 + k1)*u + v   (mod 49)
    //   steps 3 and 4 give 14*h^2 + (4 + k2)*h       (mod 49)
    // 14 is a multiple of 7, so each is a bijection only while its linear
    // coefficient stays coprime to 7. A free additive there would break that
    // for one seed in seven and collapse the hash to as few as 4 of 49
    // values, so both are constructed to skip the bad residues.
    float k1 = psrdnoise_pick (q1, t1, 7.0, 5.0);   // keeps 2 + k1 coprime to 7
    float k2 = psrdnoise_pick (q2, t2, 7.0, 3.0);   // keeps 4 + k2 coprime to 7

    // Hash permutation carefully tuned to stay within the range
    // of exact representation of integers in a half-float.
    // Tons of mod() operations here, sadly.
    float3 iu_m49 = mod (mu * mod (iu, 49.0) + c0, 49.0);
    float3 iv_m49 = mod (mv * mod (iv, 49.0) + c3, 49.0);
    float3 hashtemp = mod (14.0 * iu_m49 + (2.0 + k1), 49.0);
    hashtemp = mod (hashtemp * iu_m49 + iv_m49, 49.0);
    float3 hash = mod (14.0 * hashtemp + (4.0 + k2), 49.0);
    hash = mod (hash * hashtemp, 49.0);
	
    float3 psi = hash * 0.1282283 + alpha; // 0.1282283 is 2*pi/49
    float3 gx = cos (psi);
    float3 gy = sin (psi);
    float2 g0 = float2 (gx.x, gy.x);
    float2 g1 = float2 (gx.y, gy.y);
    float2 g2 = float2 (gx.z, gy.z);
    float3 w = 0.8 - float3 (dot (x0, x0), dot (x1, x1), dot (x2, x2));
    w = max (w, 0.0);
    float3 w2 = w * w;
    float3 w4 = w2 * w2;
    float3 gdotx = float3 (dot (g0, x0), dot (g1, x1), dot (g2, x2));
    float n = dot (w4, gdotx);
    float3 w3 = w2 * w;
    float3 dw = w3 * -8.0 * gdotx;
    float2 dn0 = g0 * w4.x + x0 * dw.x;
    float2 dn1 = g1 * w4.y + x1 * dw.y;
    float2 dn2 = g2 * w4.z + x2 * dw.z;
    gradient = (dn0 + dn1 + dn2) * 10.9;
    return 10.9 * n;
}

// Used by ShaderGraph
void mpsrdnoise2_float (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out float value, out float2 gradient)
{
    value = mpsrdnoise2 (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void mpsrdnoise2_half (float2 pos, float2 period, float alpha, bool useSeed, float4 seed,
    out half value, out half2 gradient)
{
    value = mpsrdnoise2 (pos, period, alpha, useSeed, seed, gradient);
}

#endif