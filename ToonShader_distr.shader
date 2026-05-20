Shader"Custom/ToonShader"
{
    Properties
    {        
        [MainTexture][NoScaleOffset] _BaseMap("Base Color Map", 2D) = "white" {}

        [Header(1st Shadow Setting)][Space]
        [NoScaleOffset] _FirstShadowMap("   1st Shadow Color", 2D) = "gray" {}
        _FirstShadowThreshold("   Threshold", Range(0.0,1.0)) = 0.5
        [PowerSlider(3.0)] _FirstShadowFadeRange("   Fade Range",Range(0.0,0.1)) = 0.01
        [NoScaleOffset] _ShadowControlMap("   Shadow Control Map", 2D) = "gray" {}


        [NoScaleOffset] _OpacityMap("Opacity Map", 2D) = "white"{}

        [HDR][NoScaleOffset] _EmissiveMap("Emissive Map", 2D) = "black" {}
        _EmissiveIntensity("Emissive Intensity",Float) = 1.0

        _LightDirectionMaskIntensity("Light Direction Mask Intensity",Float) = 1

        // RImlight Parameter
        [Header(Rimlight)][Space]
        [HDR] _RimlightColor("   Color",Color) = (1,1,1,1)
        _RimlightThickness("   Thickness",float) = 1.0
        _RimlightSharpness("   Sharpness",int) = 1
        [NoScaleOffset] _RimlightMaskMap("   Mask Map", 2D) = "white" {}
        
        // Highlight Parameter
        [Header(Highlight)][Space]
        [HDR] _HighlightColor("   Color", Color) = (1,1,1,1)
        _HighlightSharpness("   Sharpness",int) = 1
        _HighlightSize("   Size", float) = 1
        [NoScaleOffset] _HighlightMaskMap("   Mask Map",2D) = "white"{}

        // Facail Detail Mask
        [Space]
        [NoScaleOffset] _FacialDetailShadowCtrMap("Facial Detail Shadow Control Map", 2D) = "gray"{}

        // Atmosphere
        [Header(Atmosphere)][Space]
        _AtmosphereCol("   Color", Color) = (1,1,1,1)
        _AtmosphereIntens("   Intensity", Float) = 1.0
        _AtmosphereFadeStartDistance("   Fade Start Distance", Float) = 7
        _AtmosphereFadeEndDistance("   Fade End Distance", Float) = 15

        // Outline Properties
        [Header(Outline)][Space]
        _OutlineColor("   Color", Color) = (0,0,0,1)
        _OutlineThickness("   Thickness", Float) = 1.0
        _FadeStartDistance("   Correction Fade Start Distance", Float) = 7
        _FadeEndDistance("   Correction Fade End Distance", Float) = 15
    }

    SubShader
    {

        Tags
        { 
            "RenderType" = "TransparentCutout"
            "Queue" = "AlphaTest"
            "RenderPipeline" = "UniversalPipeline"
        }

        // Outline Path
        Pass
        {
            Name "Outline"
            Tags{"LightMode" = "SRPDefaultUnlit"}

            Cull Front
            ZWrite On

            Blend Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_OutlineThicknessControllMap);
            SAMPLER(sampler_OutlineThicknessControllMap);
            

            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;
                float _OutlineThickness;
                float _FadeEndDistance;
                float _FadeStartDistance;
                float _LightDirectionMaskIntensity;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 meshNormal : NORMAL;
                half4 vertexColor : COLOR;
                float2 uv0 : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;

                VertexPositionInputs posInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.meshNormal);

                float4 positionCS = posInput.positionCS;

                // 押し出し方向をビュー空間へ変換する
                float3 normalVS = TransformWorldToViewDir(normalInput.normalWS, true);
                float2 offsetDir = normalize(normalVS.xy);

                //ライトマスクの実装。
                float3 mainLightDirWS = GetMainLight().direction;
                float3 mainLightDirCS = TransformWorldToViewDir(mainLightDirWS, true);
                float lightMask = saturate(dot(normalVS,mainLightDirCS)* _LightDirectionMaskIntensity);

                // UNITY_MATRIX_P[0][0], [1][1] を使って clip space に寄せる
                float2 projScale = float2(UNITY_MATRIX_P[0][0], UNITY_MATRIX_P[1][1]);

                float2 offset = offsetDir * normalize(projScale);

                //補正係数の計算
                float3 objectPosWS = TransformObjectToWorld(float3(0,0,0));
                float3 cameraPosWS = GetCameraPositionWS();
                float cameraDistance = distance(objectPosWS,cameraPosWS);
                float correction = lerp(positionCS.w,1,smoothstep(_FadeStartDistance,_FadeEndDistance,cameraDistance));
                //ライン描画
                positionCS.xy += offset * _OutlineThickness * correction * IN.vertexColor.r*lightMask;

                OUT.positionCS = positionCS;
                return OUT;

            }

            half4 frag(Varyings IN) : SV_Target
            {
                return half4(_OutlineColor);
            }

            ENDHLSL
        }

        // Outline Shading Path
        Pass
        {
            Name "Shading"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite On
            ZTest LEqual

            Blend Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv0 : TEXCOORD0;
                float4 customNormal : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                float3 meshNormalOS : NORMAL;
                float3 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float3 customNormalWS : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                float lightMask : TEXCOORD5;
                float3 meshNormalWS : NORMAL;
                float3 tangentWS : TANGENT;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_FirstShadowMap);
            SAMPLER(sampler_FirstShadowMap);
            TEXTURE2D(_ShadowControlMap);
            SAMPLER(sampler_ShadowControlMap);
            TEXTURE2D(_OpacityMap);
            SAMPLER(sampler_OpacityMap);
            TEXTURE2D(_EmissiveMap);
            SAMPLER(sampler_EmissiveMap);
            TEXTURE2D(_FacialDetailShadowCtrMap);
            SAMPLER(sampler_FacialDetailShadowCtrMap);
            TEXTURE2D(_RimlightMaskMap);
            SAMPLER(sampler_RimlightMaskMap);
            TEXTURE2D(_HighlightMaskMap);
            SAMPLER(sampler_HighlightMaskMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float _FirstShadowThreshold;
                float _FirstShadowFadeRange;
                half _EmissiveIntensity;
                float4 _RimlightColor;
                int _RimlightSharpness;
                float _RimlightThickness;
                float4 _HighlightColor;
                int _HighlightSharpness;
                float _HighlightSize;
                int _LightMaskSharpness;
                float _LightDirectionMaskIntensity;
                half4  _AtmosphereCol;
                float _AtmosphereIntens;
                float _AtmosphereFadeStartDistance;
                float _AtmosphereFadeEndDistance;

            CBUFFER_END


                float Cross2D(float2 a, float2 b)
                {
                    return a.x * b.y - a.y * b.x;
                }

            Varyings vert(Attributes IN)
            {
                Varyings OUT = (Varyings)0;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz); 
                OUT.uv0 = TRANSFORM_TEX(IN.uv0, _BaseMap);

                float3 customNormalOS = normalize(IN.customNormal.xyz * 2.0 - 1.0);
                OUT.customNormalWS = normalize(TransformObjectToWorldNormal(customNormalOS));
                OUT.meshNormalWS = normalize(TransformObjectToWorldNormal(IN.meshNormalOS));
                OUT.tangentWS = normalize(TransformObjectToWorldDir(IN.tangentOS));

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // get Positions
                //カメラのワールド空間の座標は_WorldSpaceCameraPosで取得できる

                // get directions
                float3 mainLightDirWS = normalize(GetMainLight().direction);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - IN.positionWS);
                float3 characterRight = TransformObjectToWorldDir(float3(1,0 ,0));
                float3 characterForward = normalize(TransformObjectToWorldDir(float3(0,0,1)));

                // get dot
                float mNdotV = dot(IN.meshNormalWS,viewDirWS);
                float cNdotV = dot(IN.customNormalWS, viewDirWS);
                float mNdotL = dot(IN.meshNormalWS, mainLightDirWS);
                float cNdotL = dot(IN.customNormalWS, mainLightDirWS);
                float TdotL = dot(IN.tangentWS, mainLightDirWS);

                float isCharacterRight = sign(dot(mainLightDirWS, characterRight));

                // get Distance
                float3 cameraDistanceWS = distance(_WorldSpaceCameraPos, IN.positionWS);


                // sample textures
                half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv0);
                half4 shadowCol = SAMPLE_TEXTURE2D(_FirstShadowMap, sampler_BaseMap, IN.uv0);
                float alpha = SAMPLE_TEXTURE2D(_OpacityMap,sampler_OpacityMap,IN.uv0).r;
                float emissiveMap = SAMPLE_TEXTURE2D(_EmissiveMap, sampler_EmissiveMap,IN.uv0).r;
                float rimlightMask = SAMPLE_TEXTURE2D(_RimlightMaskMap,sampler_RimlightMaskMap,IN.uv0).r;
                float highlightMask = SAMPLE_TEXTURE2D(_HighlightMaskMap,sampler_HighlightMaskMap,IN.uv0).r;
               
                // cal halfLambert
                float halfLamFac = cNdotL * 0.5 + 0.5;

                // cal LightMask
                float lightMask = saturate(mNdotL * _LightDirectionMaskIntensity);

                // cal Rimlight
                float rimlightFac = pow(saturate((1 - mNdotV) * _RimlightThickness),_RimlightSharpness) * (1 - lightMask) * rimlightMask;

                // cal Highlight
                float3 halfVector = normalize(viewDirWS + mainLightDirWS);
                float highlightFac = saturate(pow(saturate(dot(halfVector,IN.meshNormalWS))*_HighlightSize, _HighlightSharpness)) * halfLamFac * highlightMask;

                // cal Atmoshere
                float atmosphereFac = smoothstep(_AtmosphereFadeStartDistance,_AtmosphereFadeEndDistance,cameraDistanceWS) * _AtmosphereIntens;

                // Facial Detail Shadow Control
                half detailMask = SAMPLE_TEXTURE2D(_FacialDetailShadowCtrMap, sampler_FacialDetailShadowCtrMap, IN.uv0).r;
                float detailMask_nose  = saturate((0.5 - detailMask) * 2.0);
                float detailMask_cheek = saturate((detailMask - 0.5) * 2.0);
                float sideMask = step(IN.uv0.x,0.5)*2 -1;

                float firstShadowThreshold_cheek = step(0,mNdotL)*step(0,Cross2D(IN.customNormalWS.xz,mainLightDirWS.xz)*-sideMask)*detailMask_cheek;

                // Facial Detail Shadow 鼻
                // 前後判定
                float noseSign = sign(-mNdotL);
                // 左右判定 現在ライトが左右のどちらに存在するか。meshNormalなのは鼻は左右でベクトルが大きく異なるためCrossで、パカら無くなる点もうれしい
                float noseCross = Cross2D(IN.meshNormalWS.xz, mainLightDirWS.xz);

                float firstShadowThreshold_nose = noseSign * step(0.0, noseCross * -sideMask * mNdotL) * detailMask_nose;


                // cel threshold
                half4 shadowControlOffset = SAMPLE_TEXTURE2D(_ShadowControlMap, sampler_ShadowControlMap, IN.uv0).r;
                float firstShadowThreshold = _FirstShadowThreshold - (shadowControlOffset - 0.5);
                halfLamFac = saturate(halfLamFac + firstShadowThreshold_cheek + firstShadowThreshold_nose);

                // Colorize
                half4 finalCol = half4(lerp(shadowCol,texColor,smoothstep(firstShadowThreshold, saturate(firstShadowThreshold+_FirstShadowFadeRange), halfLamFac)).rgb,alpha);

                finalCol += emissiveMap *_EmissiveIntensity;
                finalCol += rimlightFac * _RimlightColor;
                finalCol += highlightFac * _HighlightColor;
                finalCol = lerp(finalCol,_AtmosphereCol,atmosphereFac);
                clip(finalCol.a - 0.5);
                return finalCol;
            }

            ENDHLSL
        }
    }
}