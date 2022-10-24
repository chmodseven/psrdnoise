Shader "psrdnoise/psrdnoise3_Builtin"
{
    Properties
    {
        [ShowAsVector3] _Period ("Period", Vector) = (10.0, 10.0, 10.0, 10.0)
        _Alpha ("Alpha", Range (0.0, 1.0)) = 0.0
        [Toggle (_UseSeed)] _UseSeed ("Use Seed", Float) = 1.0
        _Seed ("Seed", Color) = (1.0, 1.0, 1.0, 1.0)
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

        #include "../HLSL/psrdnoise3.hlsl"
        
        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Alpha;
        fixed4 _Period;
        float _UseSeed;
        fixed4 _Seed;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float result = 0.0;
            float3 adjustedUV = float3 (IN.uv_MainTex.x, IN.uv_MainTex.y, 0.0);
            float3 gradient;
            bool useSeed = _UseSeed == 1.0;
            result = psrdnoise3 (adjustedUV, _Period, _Alpha, useSeed, _Seed, gradient);
            o.Albedo = result.rrr;
            o.Alpha = 1.0;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
