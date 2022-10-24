Shader "psrdnoise/psrdnoise_switchable_Builtin"
{
    Properties
    {
        [Header (Primary Variant)]
        [Space (5)]
        [KeywordEnum (Base, Fractal, Warped Fractal, Flow Noise, Billowing Smoke, Tendrils, Not Bump)] _Primary ("Type", Float) = 0
        _PrimaryAlpha ("Alpha", Range (0.0, 1.0)) = 0.0
        [Toggle (_PrimaryInvert)] _PrimaryInvert ("Invert", Float) = 0.0
        [Space (12)]
        [Header (Secondary Variant)]
        [Space (5)]
        [KeywordEnum (None, Base, Fractal, Warped Fractal, Flow Noise, Billowing Smoke, Tendrils, Not Bump)] _Secondary ("Type", Float) = 0
        _SecondaryAlpha ("Alpha", Range (0.0, 1.0)) = 0.0
        [Toggle (_SecondaryInvert)] _SecondaryInvert ("Invert", Float) = 0.0
        [Space (12)]
        [Header (Misc)]
        [Space (5)]
        [ShowAsVector2] _Period ("Period", Vector) = (10.0, 10.0, 10.0, 10.0)
        _BlendAmount ("Blend Amount", Range (0.0, 1.0)) = 0.5
        _MainTex ("Tiling and Offset", 2D) = "white" {}
        [Toggle (_UseSeed)] _UseSeed ("Use Seed", Float) = 1.0
        _Seed ("Seed", Color) = (1.0, 1.0, 1.0, 1.0)
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

        #pragma multi_compile _PRIMARY_BASE _PRIMARY_FRACTAL _PRIMARY_WARPED_FRACTAL _PRIMARY_FLOW_NOISE _PRIMARY_BILLOWING_SMOKE _PRIMARY_TENDRILS _PRIMARY_NOT_BUMP     
        #pragma multi_compile _SECONDARY_NONE _SECONDARY_BASE _SECONDARY_FRACTAL _SECONDARY_WARPED_FRACTAL _SECONDARY_FLOW_NOISE _SECONDARY_BILLOWING_SMOKE _SECONDARY_TENDRILS _SECONDARY_NOT_BUMP     
        
        #include "../HLSL/psrdnoise2_variants.hlsl"
        
        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _PrimaryAlpha;
        float _PrimaryInvert;
        half _SecondaryAlpha;
        float _SecondaryInvert;
        fixed4 _Period;
        half _BlendAmount;
        float _UseSeed;
        fixed4 _Seed;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        float getPrimaryVariantNoise (float2 pos)
        {
            float result = 0.0;
            float2 gradient;
            bool useSeed = _UseSeed == 1.0;
            #ifdef _PRIMARY_BASE
                result = psrdnoise2 (pos, _Period, _PrimaryAlpha, useSeed, _Seed, gradient);
            #elif _PRIMARY_FRACTAL
                result = psrdnoise2_fractal (pos, _Period, _PrimaryAlpha, useSeed, _Seed, gradient);
            #elif _PRIMARY_WARPED_FRACTAL
                result = psrdnoise2_warped_fractal (pos, _Period, _PrimaryAlpha, useSeed, _Seed, gradient);
            #elif _PRIMARY_FLOW_NOISE
                result = psrdnoise2_flow_noise (pos, _Period, _PrimaryAlpha, useSeed, _Seed, gradient);
            #elif _PRIMARY_BILLOWING_SMOKE
                result = psrdnoise2_billowing_smoke (pos, _Period, _PrimaryAlpha, useSeed, _Seed, gradient);
            #elif _PRIMARY_TENDRILS
                result = psrdnoise2_tendrils (pos, _Period, _PrimaryAlpha, useSeed, _Seed, gradient);
            #elif _PRIMARY_NOT_BUMP
                result = psrdnoise2_not_bump (pos, _Period, _PrimaryAlpha, useSeed, _Seed, gradient);
            #endif
            if (_PrimaryInvert == 1.0)
            {
                return 1.0 - result;
            }
            return result;
        }

        float getSecondaryVariantNoise (float2 pos)
        {
            float result = 0.0;
            float2 gradient;
            bool useSeed = _UseSeed == 1.0;
            #ifdef _SECONDARY_NONE
                return 0.0;
            #elif _SECONDARY_BASE
                result = psrdnoise2 (pos, _Period, _SecondaryAlpha, useSeed, _Seed, gradient);
            #elif _SECONDARY_FRACTAL
                result = psrdnoise2_fractal (pos, _Period, _SecondaryAlpha, useSeed, _Seed, gradient);
            #elif _SECONDARY_WARPED_FRACTAL
                result = psrdnoise2_warped_fractal (pos, _Period, _SecondaryAlpha, useSeed, _Seed, gradient);
            #elif _SECONDARY_FLOW_NOISE
                result = psrdnoise2_flow_noise (pos, _Period, _SecondaryAlpha, useSeed, _Seed, gradient);
            #elif _SECONDARY_BILLOWING_SMOKE
                result = psrdnoise2_billowing_smoke (pos, _Period, _SecondaryAlpha, useSeed, _Seed, gradient);
            #elif _SECONDARY_TENDRILS
                result = psrdnoise2_tendrils (pos, _Period, _SecondaryAlpha, useSeed, _Seed, gradient);
            #elif _SECONDARY_NOT_BUMP
                result = psrdnoise2_not_bump (pos, _Period, _SecondaryAlpha, useSeed, _Seed, gradient);
            #endif
            if (_SecondaryInvert == 1.0)
            {
                return 1.0 - result;
            }
            return result;
        }
                
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float primary = getPrimaryVariantNoise (IN.uv_MainTex);
            #ifdef _SECONDARY_NONE
                o.Albedo = primary.rrr;
            #else
                float secondary = getSecondaryVariantNoise (IN.uv_MainTex);            
                float blendPrimary = primary * _BlendAmount;
                float blendAmountInverse = 1.0 - _BlendAmount;
                float blendSecondary = secondary * blendAmountInverse;
                float blended = blendPrimary + blendSecondary;
                o.Albedo = blended.rrr;
            #endif
            o.Alpha = 1.0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
