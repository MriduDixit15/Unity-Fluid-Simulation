Shader "Unlit/NavierStokesVisual"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Albedo ("_Albedo", 2D) = "white" {}
        _Clip("Thresshold", float) = 1
        _ClipSource("Clip Source", Color) = (0,0,0,1)
        _PureTint("Pure Tint", Range(0,1)) = 0
        [HDR] _Tint("Tint", Color) = (1,1,1)

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
               
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                //  o.vertex += tex2Dlod(_MainTex, float4(o.uv, 0 ,0 )) * 0.01;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            half4 _ClipSource;
            half3 _Tint;
            half _Clip, _PureTint;
            half max3(half3 v) { return max(v.x, max(v.y, v.z));}
            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);
                half3 normal3 = normalize(float3(col.xy, 1));

                //return dot(_WorldSpaceLightPos0,normal3);
                clip(abs(dot(col, _ClipSource)) - _Clip);
                col.rgb = lerp(col.rgb, 1, _PureTint);
                col.rgb *= _Tint;
                return col;
            }
            ENDCG
        }
    }
}
