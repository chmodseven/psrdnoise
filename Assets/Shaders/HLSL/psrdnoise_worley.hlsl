//
// psrdnoise_worley.hlsl
//
// Shannon Rowe (chmodseven@gmail.com)
// Published under the MIT license, matching the rest of this repository.
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
// PROTOTYPE -- cellular (Worley) noise built on the psrdnoise hash.
//
// This is not psrdnoise. It is a different algorithm -- one feature point per
// grid cell, and a distance search over the neighbouring cells -- that borrows
// psrdnoise's permutation to place its points. Doing so gives it three
// properties that off-the-shelf Worley implementations do not have together:
//
//   PERIODIC.  The cell index is reduced to the period before it is hashed,
//              so the field tiles exactly. The point POSITION is not reduced,
//              so cells still form correctly across the seam.
//   SEEDED.    The same four-component whole-number seed as psrdnoise, through
//              the same psrdnoise_slice and psrdnoise_pick helpers. A zero seed
//              is simply the unseeded field.
//   EXACT.     Worley has no trigonometry -- only hashes, subtractions and min.
//              Every operation is exactly representable, so unlike psrdnoise
//              this needs no gradient lookup table to match bit-for-bit
//              between a compute shader and a Burst job.
//
// WHY IT IS WORTH HAVING
//
// Voronoi geometry is the standard description of large-scale cosmic
// structure: voids are the cells, filaments are the edges between them, and
// clusters sit at the vertices where edges meet. A Voronoi construction is
// therefore not an imitation of that structure's appearance -- it is the same
// geometry. Also good for crater fields, crystalline rock, ice fracture, and
// anything with a cell wall.
//
// OUTPUTS
//
//   f1      distance to the nearest feature point
//   f2      distance to the second nearest
//   cellId  a per-cell value in [0,1) for the winning cell, for colouring
//
// f2 - f1 approaches zero on the boundary between two cells, which is what
// draws the edges. 1 - f1 gives rounded blobs. f1 alone gives crater basins.
//
// COST
//
// Nine cell hashes in 2-D, twenty-seven in 3-D, against three or four for
// psrdnoise. Cheap on a GPU, and there is no trigonometry to pay for.
// ---------------------------------------------------------------------------

// ReSharper disable CppParameterMayBeConst
// ReSharper disable CppLocalVariableMayBeConst
// ReSharper disable CppInconsistentNaming

#ifndef _INCLUDE_PSRDNOISE_WORLEY_HLSL_
#define _INCLUDE_PSRDNOISE_WORLEY_HLSL_

#include "./psrdnoise_common.hlsl"

// The expanded seed, shared by the 2-D and 3-D entry points.
struct PsrdnoiseWorleySeed
{
    float mu;   // multiplier on the first cell axis
    float mv;   // multiplier on the second cell axis
    float mw;   // multiplier on the third cell axis, 3-D only
    float k1;   // coefficient offset, keeps 2 + k1 coprime to 17
    float k2;   // coefficient offset, keeps 10 + k2 coprime to 17
    float c0;   // additive on the first round
    float c1;   // additive on the second round
    float c2;   // additive on the third round
};

// Expands a four-component whole-number seed. A zero seed leaves every term at
// its published constant, exactly as in psrdnoise itself.
PsrdnoiseWorleySeed psrdnoise_worley_expand (float4 seed, bool useSeed)
{
    float4 sd = useSeed ? seed : float4 (0.0, 0.0, 0.0, 0.0);
    float q0, t0, c0, q1, t1, c1, q2, t2, c2, q3, t3, c3;
    psrdnoise_slice (sd.x, 17.0, q0, t0, c0);
    psrdnoise_slice (sd.y, 17.0, q1, t1, c1);
    psrdnoise_slice (sd.z, 17.0, q2, t2, c2);
    psrdnoise_slice (sd.w, 17.0, q3, t3, c3);

    PsrdnoiseWorleySeed s;
    s.mu = 1.0 + psrdnoise_pick (q0, t0, 17.0, 16.0);
    s.mv = 1.0 + psrdnoise_pick (q3, t3, 17.0, 16.0);
    s.mw = 1.0 + psrdnoise_pick (q1, t1, 17.0, 16.0);
    s.k1 = psrdnoise_pick (q1, t1, 17.0, 15.0);
    s.k2 = psrdnoise_pick (q2, t2, 17.0, 7.0);
    s.c0 = mod (c0 + c3, 289.0);
    s.c1 = c1;
    s.c2 = c2;
    return s;
}

// Hashes a 2-D cell index to two values in [0, 289). Same chain shape as the
// psrdnoise2 hash, so it inherits the same bijection guarantees.
float2 psrdnoise_worley_hash2 (float2 cell, PsrdnoiseWorleySeed s)
{
    float h = mod (s.mu * mod (cell.x, 289.0) + s.c0, 289.0);
    h = mod ((h * 51.0 + (2.0 + s.k1)) * h + s.mv * mod (cell.y, 289.0) + s.c1, 289.0);
    float hx = mod ((h * 34.0 + (10.0 + s.k2)) * h + s.c2, 289.0);
    float hy = mod ((hx * 34.0 + (10.0 + s.k2)) * hx + s.c2 + 1.0, 289.0);
    return float2 (hx, hy);
}

// Hashes a 3-D cell index to three values in [0, 289).
float3 psrdnoise_worley_hash3 (float3 cell, PsrdnoiseWorleySeed s)
{
    float h = mod (s.mu * mod (cell.x, 289.0) + s.c0, 289.0);
    h = mod ((h * 51.0 + (2.0 + s.k1)) * h + s.mv * mod (cell.y, 289.0) + s.c1, 289.0);
    h = mod ((h * 51.0 + (2.0 + s.k1)) * h + s.mw * mod (cell.z, 289.0) + s.c1, 289.0);
    float hx = mod ((h * 34.0 + (10.0 + s.k2)) * h + s.c2, 289.0);
    float hy = mod ((hx * 34.0 + (10.0 + s.k2)) * hx + s.c2 + 1.0, 289.0);
    float hz = mod ((hy * 34.0 + (10.0 + s.k2)) * hy + s.c2 + 2.0, 289.0);
    return float3 (hx, hy, hz);
}

// 2-D cellular noise.
// "period" wraps the cell grid; zero or negative on an axis skips the wrap.
// "jitter" in [0,1] moves the feature point from the cell centre to anywhere
// in the cell. Values near 1 give classic Worley; near 0 give a regular grid.
void psrdnoise_worley2 (float2 pos, float2 period, float jitter, bool useSeed, float4 seed,
    out float f1, out float f2, out float cellId)
{
    PsrdnoiseWorleySeed s = psrdnoise_worley_expand (seed, useSeed);
    const float inv289 = 1.0 / 289.0;

    float2 baseCell = floor (pos);
    f1 = 1e20;
    f2 = 1e20;
    cellId = 0.0;

    for (int dy = -1; dy <= 1; dy++)
    {
        for (int dx = -1; dx <= 1; dx++)
        {
            float2 cell = baseCell + float2 (dx, dy);

            // Wrap the cell index for HASHING only. The point position below
            // uses the unwrapped cell, so cells still meet across the seam.
            float2 hashCell = cell;
            if (period.x > 0.0)
            {
                hashCell.x = mod (cell.x, period.x);
            }
            if (period.y > 0.0)
            {
                hashCell.y = mod (cell.y, period.y);
            }

            float2 h = psrdnoise_worley_hash2 (hashCell, s);
            float2 point = cell + 0.5 + (h * inv289 - 0.5) * jitter;
            float2 delta = point - pos;
            float distanceSquared = dot (delta, delta);

            if (distanceSquared < f1)
            {
                f2 = f1;
                f1 = distanceSquared;
                cellId = h.x * inv289;
            }
            else if (distanceSquared < f2)
            {
                f2 = distanceSquared;
            }
        }
    }

    f1 = sqrt (f1);
    f2 = sqrt (f2);
}

// 3-D cellular noise. Twenty-seven cells searched.
void psrdnoise_worley3 (float3 pos, float3 period, float jitter, bool useSeed, float4 seed,
    out float f1, out float f2, out float cellId)
{
    PsrdnoiseWorleySeed s = psrdnoise_worley_expand (seed, useSeed);
    const float inv289 = 1.0 / 289.0;

    float3 baseCell = floor (pos);
    f1 = 1e20;
    f2 = 1e20;
    cellId = 0.0;

    for (int dz = -1; dz <= 1; dz++)
    {
        for (int dy = -1; dy <= 1; dy++)
        {
            for (int dx = -1; dx <= 1; dx++)
            {
                float3 cell = baseCell + float3 (dx, dy, dz);

                float3 hashCell = cell;
                if (period.x > 0.0)
                {
                    hashCell.x = mod (cell.x, period.x);
                }
                if (period.y > 0.0)
                {
                    hashCell.y = mod (cell.y, period.y);
                }
                if (period.z > 0.0)
                {
                    hashCell.z = mod (cell.z, period.z);
                }

                float3 h = psrdnoise_worley_hash3 (hashCell, s);
                float3 point = cell + 0.5 + (h * inv289 - 0.5) * jitter;
                float3 delta = point - pos;
                float distanceSquared = dot (delta, delta);

                if (distanceSquared < f1)
                {
                    f2 = f1;
                    f1 = distanceSquared;
                    cellId = h.x * inv289;
                }
                else if (distanceSquared < f2)
                {
                    f2 = distanceSquared;
                }
            }
        }
    }

    f1 = sqrt (f1);
    f2 = sqrt (f2);
}

// Used by ShaderGraph
void psrdnoise_worley2_float (float2 pos, float2 period, float jitter, bool useSeed, float4 seed,
    out float f1, out float f2, out float cellId)
{
    psrdnoise_worley2 (pos, period, jitter, useSeed, seed, f1, f2, cellId);
}

// Used by ShaderGraph
void psrdnoise_worley2_half (float2 pos, float2 period, float jitter, bool useSeed, float4 seed,
    out half f1, out half f2, out half cellId)
{
    float a, b, c;
    psrdnoise_worley2 (pos, period, jitter, useSeed, seed, a, b, c);
    f1 = a;
    f2 = b;
    cellId = c;
}

// Used by ShaderGraph
void psrdnoise_worley3_float (float3 pos, float3 period, float jitter, bool useSeed, float4 seed,
    out float f1, out float f2, out float cellId)
{
    psrdnoise_worley3 (pos, period, jitter, useSeed, seed, f1, f2, cellId);
}

// Used by ShaderGraph
void psrdnoise_worley3_half (float3 pos, float3 period, float jitter, bool useSeed, float4 seed,
    out half f1, out half f2, out half cellId)
{
    float a, b, c;
    psrdnoise_worley3 (pos, period, jitter, useSeed, seed, a, b, c);
    f1 = a;
    f2 = b;
    cellId = c;
}

#endif
