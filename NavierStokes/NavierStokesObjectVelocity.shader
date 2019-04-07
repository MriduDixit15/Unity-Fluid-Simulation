Shader "Unlit/NavierStokesObjectVelocity"
{
    Properties
    {
        _Velocity("Velocity", Vector) = (0,0,0)
        [HDR]_DensityColor("Color", Color) = (1,1,1)


    }
    SubShader
    {
        Tags { "NavierStokes"="True" }
        LOD 100
        Cull Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma enable_d3d11_debug_symbols
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv2: TEXCOORD1;
            };

            struct v2f
            {
                float2 uv2 : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };


            float _EmmitDensity, _Density;
            float3 _DensityColor, _Velocity;
            float4x4 custom_ObjectToClip;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = mul(custom_ObjectToClip, v.vertex); //UnityObjectToClipPos(v.vertex);
                float2 velocity = -v.uv2 ;

                o.uv2 = lerp(velocity * 1500, _Density * length(velocity), _EmmitDensity);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                half3 value = lerp(_Velocity, _DensityColor, _EmmitDensity);
                return half4(value, 0.0);
            }
            ENDCG
        }
    }
}
