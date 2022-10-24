Shader "psrdnoise/psrdnoise2_fBM_Builtin"
{
    Properties
    {
        [ShowAsVector2] _Period ("Period", Vector) = (10.0, 10.0, 10.0, 10.0)
        _Alpha ("Alpha", Range (0.0, 1.0)) = 0.0
        [Toggle (_UseSeed)] _UseSeed ("Use Seed", Float) = 1.0
        _Seed ("Seed", Color) = (1.0, 1.0, 1.0, 1.0)
        [KeywordEnum (Standard, Valleys, Ridges)] _Variant ("Type", Float) = 0
        _Octaves ("Octaves", Float) = 4.0
        _Frequency ("Frequency", Float) = 1.0
        _Amplitude ("Amplitude", Float) = 1.0
        _Lacunarity ("Lacunarity", Float) = 2.0
        _Gain ("Gain", Float) = 0.5
        _MainTex ("Tiling and Offset", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        #pragma multi_compile _VARIANT_STANDARD _VARIANT_VALLEYS _VARIANT_RIDGES     
        
        #include "../HLSL/psrdnoise2_variants.hlsl"
        
        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Alpha;
        fixed4 _Period;
        float _UseSeed;
        fixed4 _Seed;
        float _Octaves;
        float _Frequency;
        float _Amplitude;
        float _Lacunarity;
        float _Gain;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float result = 0.0;
            float2 gradient;
            bool useSeed = _UseSeed == 1.0;
            #ifdef _VARIANT_STANDARD
                result = psrdnoise2_fbm (IN.uv_MainTex, _Period, _Alpha, useSeed, _Seed,
                    0, _Octaves, _Frequency, _Amplitude, _Lacunarity, _Gain, gradient);
            #elif _VARIANT_VALLEYS
                result = psrdnoise2_fbm (IN.uv_MainTex, _Period, _Alpha, useSeed, _Seed,
                    1, _Octaves, _Frequency, _Amplitude, _Lacunarity, _Gain, gradient);
            #elif _VARIANT_RIDGES
                result = psrdnoise2_fbm (IN.uv_MainTex, _Period, _Alpha, useSeed, _Seed,
                    2, _Octaves, _Frequency, _Amplitude, _Lacunarity, _Gain, gradient);
            #endif
            o.Albedo = result.rrr;
            o.Alpha = 1.0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
