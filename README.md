## ABOUT THIS REPO

This is a port to HLSL-based Unity shaders of the brilliant GLSL-based "psrdnoise" repo provided at https://github.com/stegu/psrdnoise by Stefan Gustavson, from the 2021 research paper by Stefan Gustavson and Ian McEwan. Please see the original repo's README comments and MIT license details below this section. I myself am far from being any sort of competent mathematician and so the implementation details are way beyond my understanding, but I have included the technical articles from the original repo for anybody interested in the mathematical explanations, as well as the original GLSL code. This repo exists mostly to provide a convenient Unity port of their functionality.

The repo is provided as a full Unity 2021.3 project, with materials and shaders for:
- Builtin render pipeline
- URP (Universal Render Pipeline)
- HDRP (High Definition Render Pipeline)

Simply import the relevant folders for the render pipeline your project uses, or import everything and delete whatever you don't need. You may be prompted to update the Shader Graphs if using a newer version of Unity or of your SRP package of choice.

For the two SRP versions, the ported HLSL is fed into Shader Graph through the use of custom nodes. Some simple Shader Graphs and materials are provided which give examples of how to use these nodes in your own more complex shaders, or you can just use the materials provided. The builtin shaders simply reference the HLSL into appropriate surface shader format.

There are a number of noise variants provided as individual shaders and materials, based on the various documentation web examples provided in the original repo, which have been converted to HLSL as well. These variants are:
- *mprsdnoise2* -- Medium precision (halfs instead of floats) for leaner use cases
- *psrdnoise2* -- The baseline noise variant
- *psrdnoise2_billowing_smoke* -- A variant that looks similar to puffy smoke clouds
- *psrdnoise2_fBM* -- A fractal brownian motion variant, complete with the usual octaves, frequency, amplitude and gain parameters; furthermore, a dropdown on the material allows a type choice between Standard, Valleys, or Ridges, each of which looks different and cool
- *psrdnoise2_fBM_colored* -- An experimental version of fBM, but with a colored gradient used to resemble a world with water and land; NOTE: this variant is only available in the SRP versions
- *psrdnoise2_flow_noise* -- A variant that attempts to mimic a flow noise pattern
- *psrdnoise2_fractal* -- A fractal algorithm variant
- *psrdnoise2_not_bump* -- This unusual variant resembles the lighting on a bump/roughness map 
- *psrdnoise2_tendrils* -- A variant that snakes out into tendril-like patterns
- *psrdnoise2_warped_fractal* -- A variation of the fractal one, but with additional warped stretching applied to it, similar to the flow noise one
- *psrdnoise3* -- A version of 3D noise; NOTE: the example material only uses the 2D UV properties, but the provided HLSL and custom node do have 3D position parameters and could therefore be used in your own more complex shaders that involve 3D topology

Each of these variants has its own material, one for each render pipeline, identifiable by the suffixes _Builtin, _URP, or _HDRP. An example, similarly-named scene is also provided for each of these, with the quad on the left showing the full noise pattern for a given (usually seamless) scale, and then the four smaller quads on the right showing how that same pattern can be recreated by tiling smaller sections together, using a halving of the scale and a shift on the tiling offset values. This proof of concept demonstrates how to break up a given noise pattern into smaller chunks, for example when trying to create an infinite world where seamless edges between tiles are important.

One of the best things about psrdnoise is that it can be made seamless, infinite, or periodic. All of the materials have some common shader parameters:
- *Scale* (called *Tiling* in the Builtin version)
- *Offset* -- shifts the noise in the X or Y direction
- *Period* -- if set to 0,0 then the noise will be infinite; if set to the same as Scale then the noise will be seamless; otherwise it will indicate how far before the noise wraps
- *Alpha* -- this value acts as a sort of rotation in-place for the noise, and if lerped over time can make some cool animated effects
- *Use Seed* and *Seed* -- checking the Use Seed checkbox will force the shader to use the RGB color value in the Seed parameter (the color being a more convenient way in my opinion to adjust a seed value in the Unity inspector than three inexplicable floats, but it wouldn't be hard to change the parameter back to a vector value if that's what you prefer) to pseudorandomly create a different noise pattern. NOTE: the original GLSL implementation did not have a seed feature; this is something I have added, and while it seems to work just fine from what I can tell, please note once again that I am not mathematically skilled enough to grasp all the nuances of the psrdnoise implementation, and so I can't guarantee that the permutes being done to apply the seed values aren't adversely affecting the result in some way. Use with caution!

Right, that's enough from me. I do hope you find some value in this port, and if you wish to express your gratitude, please do so to the original authors of the psrdnoise algorithm rather than to me. The README contents from the source repo https://github.com/stegu/psrdnoise will now follow below.

The above usage notes copyright 2022 Shannon Rowe (chmodseven)

# psrdnoise
Tiling simplex flow noise in 2-D and 3-D compatible with GLSL 1.20 (WebGL 1.0) and above.

A WGSL port is in the "src" directory with the GLSL versions, and it seems
to be working (yields the same results as the corresponding GLSL functions),
but I have only done a minimal amount of testing. If you find bugs, please
report them in the "Issues" section.

A variant of 2-D noise which is compatible with "mediump" 16-bit float precision
has been added to the repository. (A 3-D version is more tricky. No promises yet.)
As with the WGSL port, bug reports and general feedback on the code is appreciated.

A scientific article on this is published in Journal of Computer Graphics
Techniques, [JCGT](http://jcgt.org/published/0011/01/02/).
Code is in the src/ folder, and there are some live WebGL examples and
a tutorial on how to use these functions on
[the accompanying Github Pages site](https://stegu.github.io/psrdnoise).

The infamous troll-owned patent on Simplex Noise finally expired in January 2022,
but none of these functions implement any of the patented methods. That patent
was arguably never valid in the first place, because I would argue that its
primary claim is demonstrably false. In any case, it's a moot point now.

## LICENSE

The entire content of the docs/ folder is in the public domain, with the
exception of GLSL shader code that comes with an MIT license as specified
in the code comments.

All GLSL code in this repository is published under the permissive
[MIT license](https://opensource.org/licenses/MIT):

Copyright 2021 Stefan Gustavson and Ian McEwan

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## UNITY PORT LICENSE

All HLSL ported code and Shader Graph nodes/graphs and materials in this repository are published under the permissive
[MIT license](https://opensource.org/licenses/MIT):

Copyright 2022 Shannon Rowe (chmodseven)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
