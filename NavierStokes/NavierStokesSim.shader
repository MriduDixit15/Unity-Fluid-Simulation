Shader "Hidden/NavierStokesSim"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always
        CGINCLUDE        
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uUv : TEXCOORD0;
                float2 vL: TEXCOORD1;
                float2 vR: TEXCOORD2;
                float2 vT: TEXCOORD3;
                float2 vB: TEXCOORD4;
                float4 vertex : SV_POSITION;
            };
            float2 texelSize;
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uUv = v.uv;
                o.vL = o.uUv - float2(texelSize.x, 0.0);
                o.vR = o.uUv + float2(texelSize.x, 0.0);
                o.vT = o.uUv + float2(0.0, texelSize.y);
                o.vB = o.uUv - float2(0.0, texelSize.y);
               
                return o;
            }

            sampler2D uTexture, uPressure, uDivergence, uVelocity, uCurl, uTarget, uSource;

        ENDCG
        Pass {
            NAME "CLEAR"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            float value;
            fixed4 frag (v2f i) : SV_Target
            {
                return value * tex2D(uTexture, i.uUv);
            }
            ENDCG
        }
        Pass {
            NAME "DISPLAY"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            fixed4 frag (v2f i) : SV_Target
            {
                half3 C = tex2D(uTexture, i.uUv).rgb;
                float a = max(C.r, max(C.g, C.b));
                return half4(C, a);
            }
            ENDCG
        }
        Pass  {
            NAME "BACKGROUND"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            uniform float aspectRatio;
            #define SCALE 25.0

            fixed4 frag (v2f i) : SV_Target
            {
                half2 uv = floor(i.uUv * SCALE * half2(aspectRatio, 1.0));
                float v = fmod(uv.x + uv.y, 2.0);
                v = v * 0.1 + 0.8;
                return half4(v.xxx, 1.0);

            }
            ENDCG
        }
        Pass {
            NAME "DISPLAY_SHADING"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            fixed4 frag (v2f i) : SV_Target
            {
                half3 L = tex2D(uTexture, i.vL).rgb;
                half3 R = tex2D(uTexture, i.vR).rgb;
                half3 T = tex2D(uTexture, i.vT).rgb;
                half3 B = tex2D(uTexture, i.vB).rgb;
                half3 C = tex2D(uTexture, i.uUv).rgb;
                float dx = length(R) - length(L);
                float dy = length(T) - length(B);
                half3 n = normalize(half3(dx, dy, length(texelSize)));
                half3 l = half3(0.0, 0.0, 1.0);
                float diffuse = clamp(dot(n, l) + 0.7, 0.7, 1.0);
                C.rgb *= diffuse;
                float a = max(C.r, max(C.g, C.b));
               return half4(C, a);
            }
            ENDCG
        }
        Pass {
            NAME "SPLAT"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            float sdBox( in half2 p, in half2 b )
            {
                half2 d = abs(p)-b;
                return length(max(d,0)) + min(max(d.x,d.y),0.0);
            }

            uniform float aspectRatio;
            uniform half3 color;
            uniform half2 targetPoint;
            uniform float radius;

            fixed4 frag (v2f i) : SV_Target
            {
                half2 p = i.uUv - targetPoint.xy;
                p.x *= aspectRatio;
                half3 splat = exp(-dot(p, p) / radius) * color;
                // float mask = sdBox(p, 0.02) < 0.0;
                // splat *= mask;
                half3 base = tex2D(uTarget, i.uUv).xyz;
                half3 final = base + splat;
                half alpha = max(final.x, max(final.y, final.z));
               return half4(final, alpha);
            }
            ENDCG
        }
        Pass {
            NAME "ADVECTION"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            uniform float dt;
            uniform float dissipation;

            fixed4 frag (v2f i) : SV_Target
            {
                half2 coord = i.uUv - dt * tex2D(uVelocity, i.uUv).xy * texelSize;
                half4 source = tex2D(uSource, coord);
                return float4(dissipation * source.rgb, source.a);
            }
            ENDCG
        }
        Pass {
            NAME "DIVERGENCE"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            fixed4 frag (v2f i) : SV_Target
            {
                float L = tex2D(uVelocity, i.vL).x;
                float R = tex2D(uVelocity, i.vR).x;
                float T = tex2D(uVelocity, i.vT).y;
                float B = tex2D(uVelocity, i.vB).y;
                half2 C = tex2D(uVelocity, i.uUv).xy;
                if (i.vL.x < 0.0) { L = -C.x; }
                if (i.vR.x > 1.0) { R = -C.x; }
                if (i.vT.y > 1.0) { T = -C.y; }
                if (i.vB.y < 0.0) { B = -C.y; }
                float div = 0.5 * (R - L + T - B);
               return half4(div, 0.0, 0.0, 1.0);
            }
            ENDCG
        }
        Pass {
            NAME "CURL"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            uniform float dt;
            uniform float dissipation;

            fixed4 frag (v2f i) : SV_Target
            {
                float L = tex2D(uVelocity, i.vL).y;
                float R = tex2D(uVelocity, i.vR).y;
                float T = tex2D(uVelocity, i.vT).x;
                float B = tex2D(uVelocity, i.vB).x;
                float vorticity = R - L - T + B;
               return half4(0.5 * vorticity, 0.0, 0.0, 1.0);
            }
            ENDCG
        }
        Pass {
            NAME "VORTICITY"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            uniform float curl;
            uniform float dt;

            fixed4 frag (v2f i) : SV_Target
            {
                float L = tex2D(uCurl, i.vL).x;
                float R = tex2D(uCurl, i.vR).x;
                float T = tex2D(uCurl, i.vT).x;
                float B = tex2D(uCurl, i.vB).x;
                float C = tex2D(uCurl, i.uUv).x;
                half2 force = 0.5 * half2(abs(T) - abs(B), abs(R) - abs(L));
                force /= length(force) + 0.0001;
                force *= curl * C;
                force.y *= -1.0;
                half2 vel = tex2D(uVelocity, i.uUv).xy;
               return half4(vel + force * dt, 0.0, 1.0);
            }
            ENDCG
        }
        Pass {
            NAME "PRESSURE"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            fixed4 frag (v2f i) : SV_Target
            {
                float L = tex2D(uPressure, (i.vL)).x;
                float R = tex2D(uPressure, (i.vR)).x;
                float T = tex2D(uPressure, (i.vT)).x;
                float B = tex2D(uPressure, (i.vB)).x;
                float C = tex2D(uPressure, i.uUv).x;
                float divergence = tex2D(uDivergence, i.uUv).x;
                float pressure = (L + R + B + T - divergence) * 0.25;
               return half4(pressure, 0.0, 0.0, 1.0);
            }
            ENDCG
        }   

        Pass {
            NAME "GRADIENT_SUBTRACT"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            fixed4 frag (v2f i) : SV_Target
            {
                float L = tex2D(uPressure, (i.vL)).x;
                float R = tex2D(uPressure, (i.vR)).x;
                float T = tex2D(uPressure, (i.vT)).x;
                float B = tex2D(uPressure, (i.vB)).x;
                half2 velocity = tex2D(uVelocity, i.uUv).xy;
                velocity.xy -= half2(R - L, T - B);
                 return  half4(velocity, 0.0, 1.0);
            }
            ENDCG
        }
    }
}
