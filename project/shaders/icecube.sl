#include "noises.h"

// ----------------------- Useful Noise Functions -----------------------

/* Reference : Jon Macey http://nccastaff.bournemouth.ac.uk/jmacey/Renderman/slides/RendermanShaders2.pdf */
float turbulence(
		float layers;
		float gain;
		float startFreq;
		float lacunarity;
	)
{
	uniform float i;
	varying float mag = 0;
	varying float freq = 1;
	point PP = transform("shader", P);
	PP *= startFreq;

	for(i = 0; i < layers; i += 1)
	{
		mag += abs(float noise(PP*freq) - 0.5) * 2/pow(freq, gain);
		freq *= lacunarity;
	}

	return mag;
}

/* Reference : Jon Macey http://nccastaff.bournemouth.ac.uk/jmacey/Renderman/slides/RendermanShaders2.pdf */
float layerNoise(
		float layers;
		float gain;
	)
{
	uniform float i;
	float mag = 0;
	point Pt = transform("shader", P);

	uniform float freq = 1;
	// Layer noise
	for(i = 0; i < layers; i += 1)
	{
		mag += (float noise(Pt * freq) - 0.5) * 2/gain;
		freq *= 2;
	}

	return mag + 0.5;
}

// ----------------------- Oren Nayer BRDF -----------------------

/* http://nccastaff.bournemouth.ac.uk/jmacey/Renderman/slides/RendermanShaders1.pdf */
color LocIllumOrenNayar (
	normal N; 
	vector V; 
	float roughness;
	)
{
	// Surface roughness coefficients for Oren/Nayar's formula
	float sigma2 = roughness * roughness;
	float A = 1 - 0.5 * sigma2 / (sigma2 + 0.33);
	float B = 0.45 * sigma2 / (sigma2 + 0.09);
	// Useful precomputed quantities
	float theta_r = acos (V . N); // Angle between V and N
	vector V_perp_N = normalize(V-N*(V.N)); // Part of V perpendicular to N

	// Accumulate incoming radiance from lights in C
	color C = 0;
	extern point P;
	illuminance (P, N, PI/2)
	{
		vector LN = normalize(L);
		float cos_theta_i = LN . N;
		float cos_phi_diff = V_perp_N . normalize(LN - N*cos_theta_i);
		float theta_i = acos (cos_theta_i);
		float alpha = max (theta_i, theta_r);
		float beta = min (theta_i, theta_r);
		C += 1 * Cl * cos_theta_i * (A + B * max(0,cos_phi_diff) * sin(alpha) * tan(beta));
	}
	return C;
}

// ----------------------- Superquad Primitive -----------------------

/* Source : (Ian Stephenson) Page 9 @ http://www.dctsystems.co.uk/RenderMan/angel.pdf */
point superquad (
	float east;
	float north;
	)
{
 	float uu,vv;
	float cv,cu;
	float sv,su;

	uu=(u-0.5)*2*PI;
	vv=(v-0.5)*PI;
	cu=cos(uu);
	cu=(cu<0)? -pow(-cu,east) : pow(cu,east);
	
	cv=cos(vv);
	cv=(cv<0)? -pow(-cv,north) : pow(cv,north);
	
	su=sin(uu);
	su=(su<0)? -pow(-su,east) : pow(su,east);
	
	sv=sin(vv);
	sv=(sv<0)? -pow(-sv,north) : pow(sv,north);
	
	point result = point (cu*cv,su*cv,sv);

	// Convert to object space
	result = transform("object", "current", result);

	return result;
}

//----------------------- Ice Cube Shader Object -----------------------

class icecube(
	float frostAmount = 1.0;
	// 1 = low reflection, low refraction
	// 0 = medium reflection, high refraction

	float cornerRoundness = 0.5;
	float displacementAmount = 1.0;
	float scratchDeepness = 0.5;

	float ior = 1.3;

	color colourTint = color "rgb" (1, 1, 1);
	color frostTint = color "rgb" (0.784, 0.9098, 0.8941);
	)
{
	varying normal Nn = 0;
	varying float scratchDetail = 0;

        

		// Produce a fresnel effect modified to allow a thick 'edge' in addition to the smooth fresnel effect
		private float vignette(
			float falloff;
			float edgeScale;
			)
		{
			float kr, kt;
			fresnel(normalize(I), Nn, 1/falloff, kr, kt);

			return smoothstep(edgeScale, 1, kt);
		}

		#define inverseVignette(falloff, edgeScale) (1 - vignette(falloff, edgeScale))

		public void displacement(output point P; output normal N) 
        {
        	// Set the shape to the superquad primitive
            P = superquad(cornerRoundness, cornerRoundness);
			N = calculatenormal(P);

			// ----------------------- Large Bumps ----------------------------
			float surfaceBump = layerNoise(3, 1);
			surfaceBump *= 0.1;

			// ----------------------- Rough Bumps ----------------------------
			float surfaceNoise = layerNoise(6, 4);
			surfaceNoise = pow(1 - surfaceNoise, 4);
			// surfaceNoise = abs(surfaceNoise);
			surfaceNoise = surfaceNoise * 0.1;

			// ---------------------- Scratches - Also used by surface ----------------------
			float scratchDensityMin = 0.25;
			float scratchDensityMax = 0.5;

			scratchDetail = turbulence(4, 0.25, 2, 8);
			scratchDetail = abs(scratchDetail - 0.5); 		// Replace highlights with dark patches
			scratchDetail = pow(scratchDetail, 3) * 8; 		
			scratchDetail = smoothstep(scratchDensityMin, scratchDensityMax, scratchDetail);
			
			// Remap the values
			scratchDetail=spline(scratchDetail,
								0,
								0.1,
								0.3,
								0.35,
								0.4,
								1.0
								);

			scratchDetail *= 0.1; // Make it subtle

			point displace = 0;
			displace = displacementAmount * (surfaceNoise + surfaceBump + (scratchDetail * scratchDeepness));
			// displace = surfaceNoise;

			P = P - (displace * normalize(N) * displacementAmount); // TODO parameterise this
			N = calculatenormal(P);

			Nn = normalize(N);
        }
        
        public void surface(
        	output color Ci, Oi) 
        {
			// reflection should be masked by a fresnel effect
			normal Nn = normalize(N);
			vector incidentRay = normalize(I);      /* normalized incident vector */
			vector V = normalize(faceforward(Nn, I));

			color ka = ambient();
			// REPORT : Talk about how I planned to use a half lambert diffuse because i wanted soft shading, but decided on oren instead
			//color kd = (diffuse(Nn) * 0.5) + 0.5; 
			
			//point Pt = transform("shader", P);

			//Ct = layerNoise(6); 						// LayerNoise - Looks very rough and mountain like 
			//Ct = filteredsnoise(Pt, 0.25); 			// snoise - Very smooth, harsh edges, looks like camo
			//Ct = 	; 									// brownian - Like snoise, but more cloudy. Can be pushed to be very noisy  
			//Ct = VLNoise(Pt, 2); 						// VLNoise - Ocean like, very smooth. Still resembles snoise
			//Ct = noise(Pt);							// Trivial colourful noise, smooth
			//Ct = cellnoise(Pt);						// Checkerboard style noise, not smooth, faster than other noises
			
			/* http://dl.acm.org/citation.cfm?id=1531326.1531360 */
			/* Camo style */
			// filterregion fr;
			// fr->calculate2d(s * 16,t * 16);
			// fr->scale(0.25);
			// Ct = knoise(fr, 0.25);

			//Ct = pnoise(Pt, point (1,1,1)); 				// Tartan style noise
			//Ct = random(); 								// Random colour noise
			//Ct = turbulence(6, 4, 0.5, 1.9132);	 		// Cool looking mountains or cell outlines

			/* ------------------------- Specular Terms ------------------------- */
			// Tie roughness to the melting?
			color orenNayer = LocIllumOrenNayar(Nn, V, 1.0);
			
			float phongStrength = 24; // Strong highlight
			float phongNoiseStrength = 1;
			color phongTerm = phong(Nn, V, phongStrength);
		
			/* ------------------------- Frost Term ------------------------- */
			//color frostTerm = exp(fBm(Pt, filterwidthp(Pt), 3, 4, 2));
			float frostDensity = 1.0;
			float frostMask = inverseVignette(1.05, 0.5); // @param
			// frostMask = pow(frostMask, 4); // Make the mask more pronounced
			// frostMask = clamp(frostMask, 0, 1.0);
			frostMask = mix(0, frostMask, frostDensity);

			/* ------------------------- Refraction/Reflection Terms ------------------------- */
			float refractionFrostSoftness = 0.4;
			float refractionTermFrost = layerNoise(3, frostAmount * 8);
			refractionTermFrost = mix(turbulence(8, 1, 2, 1.937), layerNoise(5, 16), 1 - refractionFrostSoftness);

			float reflectionScale = 1; /* ideal (mirror) reflection multiplier */
			float refractionScale = 1; /* ideal refraction multiplier */

			color refractionTerm = 0;
			color reflectionTerm = 0;

			vector In = normalize(I);
	        normal Nf = faceforward(Nn, In, Nn);
	        vector reflDir, refrDir;

	        float eta = (In.Nn < 0) ? 1/ior : ior; /* relative index of refraction */
	        float kr, kt;
	        
	        /* Compute kr, kt, reflDir, and refrDir.  If there is total internal 
	           reflection, kt is set to 0 and refrDir is set to (0,0,0). */
	        fresnel(In, Nf, eta, kr, kt, reflDir, refrDir);
	        kt = 1 - kr;
	        
	        /* Mirror reflection */
	        if (reflectionScale * kr > 0)
	        {
	        	reflectionTerm += reflectionScale * kr * trace(P, reflDir);
	        }
	        
	        /* Ideal refraction */
	        if (refractionScale * kt > 0)
	        {
	        	refractionTerm += refractionScale * kt * trace(P, refrDir) * Cs;	
	        }

		    /* Calculate the reflection color */
			if (reflectionScale > 0.001) 
			{
				reflectionTerm += reflectionScale * trace (P, reflDir); // Get the colour traced in the reflected direction
			}

			reflectionTerm = (reflectionTerm * 0.025) + (reflectionTerm * phongTerm); // Add highlights to the reflection
			
			// Make the refraction rougher ( param : refractionRoughness )
			float blurAmount = 0.3; // Parametarise the surface's roughness instead


			//reflectionTermFrost = (reflectionTermFrost * 0.5) + 0.5; // Make the noise difference subtle using a half lambert effect


			/* ------------------------- Surface Scratches ------------------------- */
			

			 
			/* ------------------------- Final Result ------------------------- */
			float mindistance = 0, maxdistance = 0.0025;
			float silhouetteMaskAmbient = 1;
			float silhouetteMask = depth(transform("world", P));
			silhouetteMask = clamp(silhouetteMaskAmbient + (silhouetteMask - mindistance) / (maxdistance - mindistance), 0.0, 1.0);
			silhouetteMask = silhouetteMask * 0.5; // Increase the contrast a little


			color ambientLayer = ka;
			color frostLayer = frostTint * color refractionTermFrost * orenNayer;
			color refractionLayer = mix(frostLayer, refractionTerm, frostMask);
			color reflectionLayer = mix(frostLayer, reflectionTerm, frostMask);
			color phongSpecularLayer = phongTerm;

			Oi = Os;
			Ci = Oi * reflectionTerm;

		 /*
			Frost - refraction mixed with white, rough oren nayer shading, low phong
			No frost - clear refraction mixed with reflections, smooth oren nayer, high phong
			Both - Ambient + Diffuse * Slightly darkened backplate

		 */
			
			//Ci = ka + (kd * colourTint * silhouetteMask * (phongTerm + mix(frostTint * color refractionTermFrost, refractionTerm, frostMask)));

        }

}