Shader "PS Vita/Dark Paradigm/Lit/Vertex/Diffuse/Pixel Normal Mapped + Color Correction + Shadows + Pixel Lights" {
    Properties {
		_ColorGrading ("Color Grading", Color) = (1,1,1,1)
        _Color ("Tint", Color) = (1,1,1,1)
        [NoScaleOffset]_MainTex ("Diffuse/Albedo", 2D) = "white" {}
		_AmbientIntensity ("Ambient Light Intensity", Range (0,8)) = 2
        [NoScaleOffset]_NormalMap ("Normal Map", 2D) = "bump" {}
		_NormalIntensity ("Normal Intensity",Range (0,10)) = 1 
	}
    SubShader {
        Tags { "RenderType"="Opaque" "Queue"="Geometry" }
		LOD 400

        // Base pass
        Pass {
            Tags { "LightMode" = "ForwardBase" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma multi_compile_fwdbase
			//#define SHADOW_CASTER
            #define BASE_PASS
			#define USE_LIGHTING
			//#define HALF_LAMBERT
			//#define CUSTOM_LIGHTING
			
			//#define EQUIRECTANGULAR_IBL
			//#define CUBEMAP_IBL
			//#define VERTEX_IBL_LIGHTING
			//#define PIXEL_IBL_LIGHTING
			//#define PIXEL_SPECULAR_IBL_LIGHTING
			//#define PIXEL_SPEC_IBL_USE_FRESNEL


			#define VERTEX_DIFF_LIGHTING
			//#define PIXEL_DIFF_LIGHTING
			#define PIXEL_NORMAL_MAPPING
			//#define VERTEX_NORMAL_MAPPING
			//#define USE_DISSOLVE
			//#define VERTEX_DISPLACEMENT
			#define COLOR_GRADING
			//#define GAMMA_TO_LINEAR
			//define LINEAR_TO_GAMMA
		  #include "DarkParadigmUber.cginc"
            ENDCG
        }
        
        // Add pass
        Pass {
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One // src*1 + dst*1
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd
			#define USE_LIGHTING
			#define PIXEL_DIFF_LIGHTING
			#define COLOR_GRADING
			//#define PIXEL_NORMAL_MAPPING
			#define VERTEX_NORMAL_MAPPING
            #include "DarkParadigmUber.cginc"
            ENDCG
        }
		Pass {
            Tags { "LightMode" = "ShadowCaster" }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			//#define SHADOW_CASTER
#ifdef SHADOW_CASTER
//			#pragma multi_compile_shadowcaster
#endif
            #include "DarkParadigmUber.cginc"
			

			ENDCG
        }
		//UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
