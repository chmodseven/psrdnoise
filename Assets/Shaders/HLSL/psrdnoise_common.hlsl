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

float4 permute_half (float4 x)
{
    float4 xm = mod (x, 49.0);
    return mod ((xm * 14.0 + 4.0) * xm, 49.0);
}

// ---------------------------------------------------------------------------
// Seeding
//
// The original psrdnoise has no seed. This is an addition by the Unity port.
//
// Four properties are required of it, and none is optional:
//
//  1. A zero seed must reproduce the original function EXACTLY. Every seed term
//     is written so that substituting zero collapses it back to the published
//     constant. There is no separate "unseeded" code path.
//
//  2. Every intermediate must stay a whole number below 2^24, where a 32-bit
//     float is exact. That is what makes mod() safe: an exact integer never
//     lands closer than 1/289 to a mod boundary, so no rounding difference on
//     any GPU can flip the floor() inside mod(). A FRACTIONAL seed destroys
//     this -- it can put a product exactly on a multiple of 289, where one ulp
//     of difference swings the hash across its whole range.
//
//  3. The permutation must stay a bijection. permute() is bijective because its
//     quadratic coefficient is a multiple of 17 and its linear coefficient is
//     coprime to 17 (289 = 17*17). One seed value in 17 would break that and
//     collapse the hash from 289 outputs to 9, so the multipliers below are
//     CONSTRUCTED to skip those values rather than repaired afterwards. A repair
//     would map two adjacent seeds onto the same pattern.
//
//  4. Adjacent seeds must look unrelated. A seed is therefore run through a
//     bijective 16-bit integer mix before anything is derived from it, so that
//     incrementing by one restructures the field instead of nudging it.
//     Integer arithmetic is bit-exact on every GPU, so the mix costs no
//     determinism -- only the noise itself has to stay in exact-integer floats.
//
// The seed is four whole numbers in [0, 65535] -- four 16-bit slices of a
// 64-bit integer seed -- carried in a Vector4 property, never a Color.
// ---------------------------------------------------------------------------

// A bijective mix on 16 bits. Bijective means no two seeds collide; mix(0) == 0
// means a zero seed still gives the published function.
uint psrdnoise_mix16 (uint x)
{
    x &= 0xFFFFu;
    x ^= x >> 8;
    x = (x * 0x2545u) & 0xFFFFu;
    x ^= x >> 8;
    x = (x * 0x8AD5u) & 0xFFFFu;
    x ^= x >> 8;
    return x;
}

// Splits one 16-bit seed slice into three independent fields:
//   q : 0 .. p-1        coarse part of a multiplier
//   t : 0 .. p-2        fine part -- p-1 residues, so one can always be skipped
//   c : 0 .. p*p-1      a free additive
// For p = 17 the split is injective, because 17 * 16 * 241 >= 65536: no two
// 16-bit seeds give the same triple. All three are zero when the seed is zero.
// floor() and clamp() are the guard against a fractional or out-of-range seed.
void psrdnoise_slice (float seedComponent, float p, out float q, out float t, out float c)
{
    uint h = psrdnoise_mix16 ((uint) clamp (floor (abs (seedComponent)), 0.0, 65535.0));
    uint pi = (uint) p;
    q = (float) (h % pi);
    t = (float) ((h / pi) % (pi - 1u));
    c = (float) ((h / (pi * (pi - 1u))) % (uint) (p * p));
}

// Builds an offset in [0, p*p) whose residue mod p is never 'forbidden', so the
// round it feeds stays a bijection. Returns 0 at q = t = 0, which is what keeps
// a zero seed on the published constant. Every call site passes a non-zero
// 'forbidden', so zero is always reachable.
float psrdnoise_pick (float q, float t, float p, float forbidden)
{
    return p * q + t + step (forbidden, t);
}

// permute() with a seed. permute_seeded(x, 0, 0) == permute(x), exactly.
float3 permute_seeded (float3 x, float k, float c)
{
    float3 xm = mod (x, 289.0);
    return mod ((xm * 34.0 + (10.0 + k)) * xm + c, 289.0);
}

float4 permute_seeded (float4 x, float k, float c)
{
    float4 xm = mod (x, 289.0);
    return mod ((xm * 34.0 + (10.0 + k)) * xm + c, 289.0);
}

#endif
