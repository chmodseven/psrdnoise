//
// psrdnoise3_min.hlsl
//
// psrdnoise (c) Stefan Gustavson and Ian McEwan,
// Shannon Rowe (chmodseven@gmail.com) for HLSL port and added seed
// ver. 2021-12-02, published under the MIT license:
// https://github.com/stegu/psrdnoise/

// ReSharper disable CppParameterMayBeConst
// ReSharper disable CppLocalVariableMayBeConst
// ReSharper disable CppInconsistentNaming

#ifndef _INCLUDE_PSRDNOISE3_MIN_HLSL_
#define _INCLUDE_PSRDNOISE3_MIN_HLSL_

#include "./psrdnoise_common.hlsl"

float psrdnoise3_min (float3 pos, float3 period, float alpha, bool useSeed, float4 seed, out float3 gradient)
{
    const float3x3 M = float3x3 (float3 (0.0, 1.0, 1.0), float3 (1.0, 0.0, 1.0), float3 (1.0, 1.0, 0.0));
    const float3x3 Mi = float3x3 (float3 (-0.5, 0.5, 0.5), float3 (0.5, -0.5, 0.5), float3 (0.5, 0.5, -0.5));
    float3 uvw = mul (pos, M);
    float3 i0 = floor (uvw);
    float3 f0 = frac (uvw);
    float3 g_ = step (f0.xyx, f0.yzz);
    float3 l_ = 1.0 - g_;
    float3 g = float3 (l_.z, g_.xy);
    float3 l = float3 (l_.xy, g_.z);
    float3 o1 = min (g, l);
    float3 o2 = max (g, l);
    float3 i1 = i0 + o1;
    float3 i2 = i0 + o2;
    float3 i3 = i0 + float3 (1.0, 1.0, 1.0);
    float3 v0 = mul (i0, Mi);
    float3 v1 = mul (i1, Mi);
    float3 v2 = mul (i2, Mi);
    float3 v3 = mul (i3, Mi);
    float3 x0 = pos - v0;
    float3 x1 = pos - v1;
    float3 x2 = pos - v2;
    float3 x3 = pos - v3;
    if (period.x > 0.0 || period.y > 0.0 || period.z > 0.0)
    {
        float4 vx = float4 (v0.x, v1.x, v2.x, v3.x);
        float4 vy = float4 (v0.y, v1.y, v2.y, v3.y);
        float4 vz = float4 (v0.z, v1.z, v2.z, v3.z);
        if (period.x > 0.0)
        {
            vx = mod (vx, period.x);
        }
        if (period.y > 0.0)
        {
            vy = mod (vy, period.y);
        }
        if (period.z > 0.0)
        {
            vz = mod (vz, period.z);
        }
        i0 = floor (mul (float3 (vx.x, vy.x, vz.x), M) + 0.5);
        i1 = floor (mul (float3 (vx.y, vy.y, vz.y), M) + 0.5);
        i2 = floor (mul (float3 (vx.z, vy.z, vz.z), M) + 0.5);
        i3 = floor (mul (float3 (vx.w, vy.w, vz.w), M) + 0.5);
    }
    float4 hash;
    if (useSeed)
    {
        float4 param = permute (float4 (i0.z, i1.z, i2.z, i3.z), seed.x);
        float4 param_1 = permute (param, seed.y) + float4 (i0.y, i1.y, i2.y, i3.y);
        float4 param_2 = permute (param_1, seed.z) + float4 (i0.x, i1.x, i2.x, i3.x);
        hash = permute (param_2, seed.w);
    }
    else
    {
        float4 param = float4 (i0.z, i1.z, i2.z, i3.z);
        float4 param_1 = permute (param) + float4 (i0.y, i1.y, i2.y, i3.y);
        float4 param_2 = permute (param_1) + float4 (i0.x, i1.x, i2.x, i3.x);
        hash = permute (param_2);
    }
    float4 theta = hash * 3.883222077;
    float4 sz = hash * -0.006920415 + 0.996539792;
    float4 psi = hash * 0.108705628;
    float4 Ct = cos (theta);
    float4 St = sin (theta);
    float4 sz_prime = sqrt (1.0 - sz * sz);
    float4 gx;
    float4 gy;
    float4 gz;
    if (alpha != 0.0)
    {
        float4 Sp = sin (psi);
        float4 Cp = cos (psi);
        float4 px = Ct * sz_prime;
        float4 py = St * sz_prime;
        float4 pz = sz;
        float4 Ctp = St * Sp - Ct * Cp;
        float4 qx = lerp (Ctp * St, Sp, sz);
        float4 qy = lerp (-Ctp * Ct, Cp, sz);
        float4 qz = - (py * Cp + px * Sp);
        float4 Sa = sin (alpha).xxxx;
        float4 Ca = cos (alpha).xxxx;
        gx = Ca * px + Sa * qx;
        gy = Ca * py + Sa * qy;
        gz = Ca * pz + Sa * qz;
    }
    else
    {
        gx = Ct * sz_prime;
        gy = St * sz_prime;
        gz = sz;
    }
    float3 g0 = float3 (gx.x, gy.x, gz.x);
    float3 g1 = float3 (gx.y, gy.y, gz.y);
    float3 g2 = float3 (gx.z, gy.z, gz.z);
    float3 g3 = float3 (gx.w, gy.w, gz.w);
    float4 w = 0.5 - float4 (dot (x0, x0), dot (x1, x1), dot (x2, x2), dot (x3, x3));
    w = max (w, 0.0);
    float4 w2 = w * w;
    float4 w3 = w2 * w;
    float4 gdotx = float4 (dot (g0, x0), dot (g1, x1), dot (g2, x2), dot (g3, x3));
    float n = dot (w3, gdotx);
    float4 dw = w2 * -6.0 * gdotx;
    float3 dn0 = g0 * w3.x + x0 * dw.x;
    float3 dn1 = g1 * w3.y + x1 * dw.y;
    float3 dn2 = g2 * w3.z + x2 * dw.z;
    float3 dn3 = g3 * w3.w + x3 * dw.w;
    gradient = (dn0 + dn1 + dn2 + dn3) * 39.5;
    return 39.5 * n;
}

// Used by ShaderGraph
void psrdnoise3_min_float (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out float value, out float3 gradient)
{
    value = psrdnoise3_min (pos, period, alpha, useSeed, seed, gradient);
}

// Used by ShaderGraph
void psrdnoise3_min_half (float3 pos, float3 period, float alpha, bool useSeed, float4 seed,
    out half value, out half3 gradient)
{
    value = psrdnoise3_min (pos, period, alpha, useSeed, seed, gradient);
}

#endif