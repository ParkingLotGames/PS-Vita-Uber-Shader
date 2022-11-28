#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

#define TAU 6.28318530718

struct MeshData {
    fixed4 vertex : POSITION;
    fixed3 normal : NORMAL;
    fixed4 tangent : TANGENT; // xyz = tangent direction, w = tangent sign
    fixed2 uv : TEXCOORD0;
};

struct Interpolators {
    fixed4 vertex : SV_POSITION;
    fixed2 uv : TEXCOORD0;
    fixed3 normal : TEXCOORD1;
    
	#ifdef PIXEL_NORMAL_MAPPING
	fixed3 tangent : TEXCOORD2;
    fixed3 bitangent : TEXCOORD3;
	#endif
	
	#ifdef VERTEX_NORMAL_MAPPING
	fixed3 tangent : TEXCOORD2;
    fixed3 bitangent : TEXCOORD3;
	#endif

	#ifdef VERTEX_DIFF_LIGHTING
	fixed3 diff : COLOR;
	fixed3 ambient : COLOR1;
	#endif

    fixed3 wPos : TEXCOORD4;
	LIGHTING_COORDS(5,6)
    fixed3 localPos : TEXCOORD7;
	#ifdef VERTEX_IBL_LIGHTING
	fixed4 ibl : TEXCOORD8;
	fixed4 fogColor : TEXCOORD9;
	#endif
	#ifdef VERTEX_NORMAL_MAPPING
	//fixed3 tspace0 : TEXCOORD10; // tangent.x, bitangent.x, normal.x
	//fixed3 tspace1 : TEXCOORD11; // tangent.y, bitangent.y, normal.y
	//fixed3 tspace2 : TEXCOORD12; // tangent.z, bitangent.z, normal.z
	#endif
};

sampler2D _MainTex;
fixed4 _MainTex_ST;
sampler2D _NormalMap;
sampler2D _HeightMap;
#ifdef CUBEMAP_IBL
samplerCUBE _DiffuseIBL;
#endif
#ifdef EQUIRECTANGULAR_IBL
sampler2D _DiffuseIBL;
#endif
sampler2D _SpecularIBL;
float4 _HDR_Tex;
fixed _Gloss;
fixed4 _Color;
fixed4 _ColorGrading;
fixed _AmbientIntensity;
fixed _NormalIntensity;
fixed _DispStrength;
fixed _DiffuseIBLIntensity;
fixed _SpecIBLIntensity;
fixed _DissolveAmount;

fixed2 Rotate( fixed2 v, fixed angRad ) {
    fixed ca = cos( angRad );
    fixed sa = sin( angRad );
    return fixed2( ca * v.x - sa * v.y, sa * v.x + ca * v.y );
}

fixed2 DirToRectilinear( fixed3 dir ) {
    fixed x = atan2( dir.z, dir.x ) / TAU + 0.5; // 0-1
    fixed y = dir.y * 0.5 + 0.5; // 0-1
    return fixed2(x,y);
}

Interpolators vert (MeshData v) {
    
	Interpolators o;
    
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    
	fixed3 worldNormal = UnityObjectToWorldNormal( v.normal );
	o.normal = worldNormal;

#ifdef VERTEX_DISPLACEMENT
    fixed height = tex2Dlod( _HeightMap, fixed4(o.uv, 0, 0 ) ).x * 2 - 1;
    v.vertex.xyz += v.normal * (height * _DispStrength);
    o.localPos = v.vertex.xyz;
#endif
	o.vertex = UnityObjectToClipPos(v.vertex);

#ifdef PIXEL_NORMAL_MAPPING
    o.tangent = UnityObjectToWorldDir( v.tangent.xyz );
    o.bitangent = cross( o.normal, o.tangent );
    o.bitangent *= v.tangent.w * unity_WorldTransformParams.w; // correctly handle flipping/mirroring
#endif
	
	o.wPos = mul( unity_ObjectToWorld, v.vertex );
#ifdef USE_LIGHTING

#ifdef VERTEX_DIFF_LIGHTING
	
	#ifdef HALF_LAMBERT
	fixed nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz))*.5 +.5;
	o.ambient = ShadeSH9(fixed4(worldNormal,1))*.5 + .5;
	#else
	fixed nl = max(0, dot(worldNormal, _WorldSpaceLightPos0.xyz));
	o.ambient = ShadeSH9(fixed4(worldNormal,1));
	#endif

	o.diff = nl * _LightColor0;
	
	#ifdef COLOR_GRADING
	o.diff.rgb *= _ColorGrading;
	#endif

	#ifdef VERTEX_IBL_LIGHTING
	
	#ifdef EQUIRECTANGULAR_IBL
	fixed3 vertexDiffuseIBL = tex2Dlod( _DiffuseIBL, fixed4(DirToRectilinear( normalize(worldNormal) ),0,0) ).xyz * _DiffuseIBLIntensity;
	
	o.ibl = fixed4(vertexDiffuseIBL,1);
	#endif
	
	#ifdef CUBEMAP_IBL
	float4 vertexDiffuseIBL = texCUBE(_DiffuseIBL, o.vertex.xyz) * _DiffuseIBLIntensity;
	//float4 c = DecodeHDR(vertexDiffuseIBL, _HDR_Tex);	
	o.ibl = vertexDiffuseIBL;
	#endif

	#endif

	#ifdef VERTEX_NORMAL_MAPPING
    o.tangent = UnityObjectToWorldDir( v.tangent.xyz );
    o.bitangent = cross( o.normal, o.tangent );
    o.bitangent *= v.tangent.w * unity_WorldTransformParams.w; // correctly handle flipping/mirroring
	
	o.tspace0 = fixed3(o.tangent.x, o.bitangent.x, o.normal.x);
	o.tspace1 = fixed3(o.tangent.y, o.bitangent.y, o.normal.y);
	o.tspace2 = fixed3(o.tangent.z, o.bitangent.z, o.normal.z);
	#endif

#endif

    TRANSFER_VERTEX_TO_FRAGMENT(o); // Send attenuation to Fragment Shader
	TRANSFER_SHADOW(o);
#endif
	#ifdef VERTEX_IBL_LIGHTING
		#ifndef USE_LIGHTING
	fixed3 vertexDiffuseIBL = tex2Dlod( _DiffuseIBL, fixed4(DirToRectilinear( normalize(worldNormal) ),0,0) ).xyz * _DiffuseIBLIntensity;
	o.ibl = fixed4(vertexDiffuseIBL,1);
		#endif
	#endif
    return o;
}

fixed4 frag (Interpolators i) : SV_Target {
 
    fixed3 albedo = tex2D( _MainTex, i.uv );
	
    fixed3 surfaceColor = albedo * _Color.rgb;
    
	fixed attenuation = LIGHT_ATTENUATION(i);
	fixed shadows = SHADOW_ATTENUATION(i);
	
	#ifdef PIXEL_SPECULAR_IBL_LIGHTING
    fixed3 V = normalize( _WorldSpaceCameraPos - i.wPos );
	#endif    

	#ifdef PIXEL_NORMAL_MAPPING
    
	fixed3 tangentSpaceNormal = UnpackNormal( tex2D( _NormalMap, i.uv ) );
    tangentSpaceNormal = normalize( lerp( fixed3(0,0,1), tangentSpaceNormal, _NormalIntensity ) );
		fixed3x3 mtxTangToWorld = 
		  { i.tangent.x, i.bitangent.x, i.normal.x,
		    i.tangent.y, i.bitangent.y, i.normal.y,
		    i.tangent.z, i.bitangent.z, i.normal.z };

	#endif

#ifdef PIXEL_DIFF_LIGHTING
		#ifdef PIXEL_NORMAL_MAPPING
		fixed3 N = mul( mtxTangToWorld, tangentSpaceNormal );
		#else	
        fixed3 N = normalize(i.normal);
		#endif

        fixed3 L = normalize( UnityWorldSpaceLightDir( i.wPos ) );
		fixed3 ambient = ShadeSH9(fixed4(i.normal,1));
		#ifdef HALF_LAMBERT
        //fixed3 lambert = saturate( dot( N, L ) );
        fixed3 lambert = saturate( dot( N, L ) *.5 + .5 );
		#else
        fixed3 lambert = saturate( dot( N, L ) );
		#endif
        fixed3 diffuseLight = (lambert * attenuation * shadows ) * _LightColor0.xyz + (ambient * _AmbientIntensity);

        #ifdef BASE_PASS
            #ifdef PIXEL_IBL_LIGHTING
			fixed3 diffuseIBL = tex2Dlod( _DiffuseIBL, fixed4(DirToRectilinear( N ),0,0) ).xyz * _DiffuseIBLIntensity;
				#ifdef LINEAR_TO_GAMMA
            diffuseLight = sqrt(diffuseLight * diffuseIBL); // adds the indirect diffuse lighting
				#else
            diffuseLight *= diffuseIBL; // adds the indirect diffuse lighting
				#endif
			#endif
        #endif

	#ifdef PIXEL_SPECULAR_IBL_LIGHTING
        // specular lighting
        
        fixed3 H = normalize(L + V);
        //fixed3 R = reflect( -L, N ); // uses for Phong
        fixed3 specularIBLLight = saturate(dot(H, N)) * (lambert > 0); // Blinn-Phong

        fixed specularExponent = exp2( _Gloss * 11 ) + 2;
        specularIBLLight = pow( specularIBLLight, specularExponent ) * _Gloss * attenuation * shadows; // specular exponent
        specularIBLLight *= _LightColor0.xyz;
    
        #ifdef BASE_PASS
				#ifdef PIXEL_SPEC_IBL_USE_FRESNEL
			fixed fresnel = pow(1-saturate(dot(V,N)),5);
				#endif
            fixed3 viewRefl = reflect( -V, N );
            fixed mip = (1-_Gloss)*6;
            fixed3 specularIBL = tex2Dlod( _SpecularIBL, fixed4(DirToRectilinear( viewRefl ),mip,mip) ).xyz;

				#ifdef PIXEL_SPEC_IBL_USE_FRESNEL
            specularIBLLight += specularIBL * _SpecIBLIntensity * fresnel;
				#else
            specularIBLLight += specularIBL * _SpecIBLIntensity;
				#endif
	
		#endif
    
	#endif
    
		#ifdef PIXEL_SPECULAR_IBL_LIGHTING
        return fixed4( diffuseLight * surfaceColor + specularIBLLight, 1 );
		#else
        return fixed4( diffuseLight * surfaceColor, 1 );
		#endif

#else
	#ifdef VERTEX_DIFF_LIGHTING
	
	#ifdef VERTEX_NORMAL_MAPPING
	fixed3 tangentSpaceNormal = UnpackNormal( tex2D( _NormalMap, i.uv ) );
    tangentSpaceNormal = normalize( lerp( fixed3(0,0,1), tangentSpaceNormal, _NormalIntensity ) );

		half3 worldNormal;
		worldNormal.x = dot(i.tspace0, tangentSpaceNormal);
		worldNormal.y = dot(i.tspace1, tangentSpaceNormal);
		worldNormal.z = dot(i.tspace2, tangentSpaceNormal);

		half3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.wPos));

        fixed3 L = UnityWorldSpaceLightDir( i.wPos );
//    		fixed3 N = mul( mtxTangToWorld, tangentSpaceNormal );
			surfaceColor *= saturate( dot(L,worldNormal)+1.123);
	#endif

	#ifdef PIXEL_NORMAL_MAPPING
		fixed3 N = mul( mtxTangToWorld, tangentSpaceNormal );
        fixed3 L = normalize( UnityWorldSpaceLightDir( i.wPos ) );
		
		surfaceColor *=dot(N,L) + 1.123;
    #endif    
		#ifdef VERTEX_IBL_LIGHTING
			surfaceColor *= _LightColor0.xyz * attenuation  * shadows * i.diff + (i.ambient * _AmbientIntensity);
			
			#ifdef GAMMA_TO_LINEAR
			surfaceColor *= surfaceColor * i.ibl + i.ibl; // adds the indirect diffuse lighting
			#else
				
				#ifdef LINEAR_TO_GAMMA
			surfaceColor = sqrt(surfaceColor * i.ibl); // adds the indirect diffuse lighting
				#else
			surfaceColor *= i.ibl; // adds the indirect diffuse lighting
				#endif
			#endif

		#else
			surfaceColor *= _LightColor0.xyz * attenuation * shadows * i.diff + (i.ambient * _AmbientIntensity);

			#ifdef GAMMA_TO_LINEAR
			surfaceColor *= surfaceColor; // adds the indirect diffuse lighting
			#else
				
				#ifdef LINEAR_TO_GAMMA
			surfaceColor = sqrt(surfaceColor); // adds the indirect diffuse lighting
				#else
			surfaceColor = surfaceColor; // adds the indirect diffuse lighting
				#endif
			#endif

		#endif
			
			return fixed4 (surfaceColor,1);

	#endif
	#ifdef BASE_PASS
		#ifdef VERTEX_IBL_LIGHTING
			#ifdef GAMMA_TO_LINEAR
			fixed4 col = (surfaceColor.rgb * i.ibl, 1);
			return fixed4(col * col);
			#else
			return fixed4 (surfaceColor.rgb * i.ibl, 1);
			#endif
		#else
			#ifdef GAMMA_TO_LINEAR
			fixed4 col = (surfaceColor.rgb , 1);
			return fixed4 (col * col);
			#else
			return fixed4 (surfaceColor.rgb , 1);
			#endif
		#endif
	#else
            return 0;
	#endif
#endif

    
}