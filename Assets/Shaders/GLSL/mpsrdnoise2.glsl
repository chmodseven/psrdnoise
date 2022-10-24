// This variant of the 2D "psrdnoise" function is compatible with the
// 16-bit half-precision float type. Useful on platforms where
// half-floats are faster, or where 32-bit floats are unavailable.

#ifdef GL_ES
precision mediump float;
#endif

// mpsrdnoise (c) Stefan Gustavson and Ian McEwan,
// ver. 2022-03-29, published under the MIT license:
// https://github.com/stegu/psrdnoise/

float mpsrdnoise(vec2 x, vec2 period, float alpha, out vec2 gradient)
{
	vec2 uv = vec2(x.x + x.y*0.5, x.y);
	vec2 i0 = floor(uv), f0 = fract(uv);
	float cmp = step(f0.y, f0.x);
	vec2 o1 = vec2(cmp, 1.0-cmp);
	vec2 i1 = i0 + o1, i2 = i0 + 1.0;
	vec2 v0 = vec2(i0.x - i0.y*0.5, i0.y);
	vec2 v1 = vec2(v0.x + o1.x - o1.y*0.5, v0.y + o1.y);
	vec2 v2 = vec2(v0.x + 0.5, v0.y + 1.0);
	vec2 x0 = x - v0, x1 = x - v1, x2 = x - v2;
	vec3 iu, iv, xw, yw;
	if(any(greaterThan(period, vec2(0.0)))) {
		xw = vec3(v0.x, v1.x, v2.x);
		yw = vec3(v0.y, v1.y, v2.y);
		if(period.x > 0.0)
			xw = mod(vec3(v0.x, v1.x, v2.x), period.x);
		if(period.y > 0.0)
			yw = mod(vec3(v0.y, v1.y, v2.y), period.y);
		iu = floor(xw + 0.5*yw + 0.5); iv = floor(yw + 0.5);
	} else {
		iu = vec3(i0.x, i1.x, i2.x); iv = vec3(i0.y, i1.y, i2.y);
	}
	// Hash permutation carefully tuned to stay within the range
	// of exact representation of integers in a half-float.
	// Tons of mod() operations here, sadly.
	vec3 iu_m49 = mod(iu, 49.0);
	vec3 iv_m49 = mod(iv, 49.0);
	vec3 hashtemp = mod(14.0*iu_m49 + 2.0, 49.0);
	hashtemp = mod(hashtemp*iu_m49 + iv_m49, 49.0);
	vec3 hash = mod(14.0*hashtemp + 4.0, 49.0);
	hash = mod(hash*hashtemp, 49.0);
	
	vec3 psi = hash*0.1282283 + alpha; // 0.1282283 is 2*pi/49
	vec3 gx = cos(psi); vec3 gy = sin(psi);
	vec2 g0 = vec2(gx.x, gy.x);
	vec2 g1 = vec2(gx.y, gy.y);
	vec2 g2 = vec2(gx.z, gy.z);
	vec3 w = 0.8 - vec3(dot(x0, x0), dot(x1, x1), dot(x2, x2));
	w = max(w, 0.0); vec3 w2 = w*w; vec3 w4 = w2*w2;
	vec3 gdotx = vec3(dot(g0, x0), dot(g1, x1), dot(g2, x2));
	float n = dot(w4, gdotx);
	vec3 w3 = w2*w; vec3 dw = -8.0*w3*gdotx;
	vec2 dn0 = w4.x*g0 + dw.x*x0;
	vec2 dn1 = w4.y*g1 + dw.y*x1;
	vec2 dn2 = w4.z*g2 + dw.z*x2;
	gradient = 10.9*(dn0 + dn1 + dn2);
	return 10.9*n;
}
