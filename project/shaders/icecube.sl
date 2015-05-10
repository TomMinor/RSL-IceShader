#include "noises.h"
#include "extranoise.h"

class icecube(
	uniform float texfreq = 1, 
	DMult = 0.0;
	float cornerRoundness = 0.5;
	float frostAmount = 1.0;
	// 1 = low reflection, low refraction
	// 0 = medium reflection, high refraction

	float ior = 1.3;

	color colourTint = color "rgb" (1, 1, 1);
	color frostTint = color "rgb" (0.784, 0.9098, 0.8941);
	)
{
	varying normal Nn = 0;


        /* Source : (Ian Stephenson) Page 9 @ http://www.dctsystems.co.uk/RenderMan/angel.pdf */
		private point superquad (
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

		private color colorPow(color colour; float p)
		{
			point c = point colour;

			float x = xcomp(c);
			float y = ycomp(c);
			float z = zcomp(c);

			return color (pow(x, p), pow(y, p), pow(z, p));	
		}

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

		private void calculateReflectRefract (
			float Kr;         	/* ideal (mirror) reflection multiplier */
			float Kt;         	/* ideal refraction multiplier */
			float ior;      	/* index of refraction */
			output color refraction; // Refracted value around point
			output color reflection; // Reflected value about point
			)
		{
		        vector In = normalize(I);
		        normal Nf = faceforward(Nn, In, Nn);
		        vector V = -In;   /* view direction */
		        vector reflDir, refrDir;

		        float eta = (In.Nn < 0) ? 1/ior : ior; /* relative index of refraction */
		        float kr, kt;
		        
		        color result = 0;
		        
		        /* Compute kr, kt, reflDir, and refrDir.  If there is total internal
		        reflection, kt is set to 0 and refrDir is set to (0,0,0). */
		        fresnel(In, Nf, eta, kr, kt, reflDir, refrDir);
		        kt = 1 - kr;
		        
		        /* Mirror reflection */
		        if (Kr * kr > 0)
		        	result += Kr * kr * trace(P, reflDir);
		        
		        /* Ideal refraction */
		        if (Kt * kt > 0)
		        	result += Kt * kt * trace(P, refrDir) * Cs;	
		        
		        refraction = result;

			    /* Calculate the reflection color */
				if (Kr > 0.001) 
				{
					reflection = Kr * trace (P, reflDir); // Get the colour traced in the reflected direction
				}
		}

		/* http://nccastaff.bournemouth.ac.uk/jmacey/Renderman/slides/RendermanShaders1.pdf */
		private color LocIllumOrenNayar (
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

		public void displacement(output point P; output normal N) 
        {
            P = superquad(cornerRoundness, cornerRoundness);
			N = calculatenormal(P);

			float dispScale = 0.1;
			float RepeatS = 4;
			float RepeatT = 4;

			// ----------------------- Large Noise ----------------------------
			float ss=mod(s * RepeatS,1);
			float tt=mod(t * RepeatT,1);
			float disp=sin(ss * 2 * PI) * sin(tt * 2 * PI);

			P = P + (normalize(N) * disp * dispScale);
			N = calculatenormal(P);

			// ---------------------- Scratches ----------------------
			float scratchDensityMin = 0.25;
			float scratchDensityMax = 0.5;

			float scratchMask = 0;
			scratchMask = turbulence(4, 0.25, 2, 8);
			scratchMask = abs(scratchMask - 0.5); 		// Replace highlights with dark patches
			scratchMask = pow(scratchMask, 3) * 8; 		// 
			scratchMask = smoothstep(scratchDensityMin, scratchDensityMax, scratchMask);
			// Remap the values
			scratchMask=spline(scratchMask,
								0,
								0.1,
								0.3,
								0.35,
								0.4,
								0.5
								);

			// ---------------------- Small Bumpyness ----------------------
			float smallBumps = layerNoise(6, 4); 
			smallBumps = pow(1 - smallBumps, 4);

			// Remove scratches from bumpy areas
			float result = smallBumps + ((1 - smallBumps) * scratchMask);

			P = P - (result * normalize(N) * 0.1); // TODO parameterise this
			N = calculatenormal(P);

			Nn = normalize(N);
        }
        
        public void surface(
        	output color Ci, Oi) 
        {
			// reflection should be masked by a fresnel effect
			normal Nn = normalize(N);
			vector incidentRay = normalize(I);      /* normalized incident vector */
			vector V = normalize(faceforward(Nn, -I));

			color ka = ambient();
			color kd = (diffuse(Nn) * 0.5) + 0.5; // Half Lambert, since we never really want 100% black in our diffuse
			
			color Ct;
			point Pt = transform("shader", P);

			//Ct = layerNoise(6); 						// LayerNoise - Looks very rough and mountain like 
			//Ct = filteredsnoise(Pt, 0.25); 			// snoise - Very smooth, harsh edges, looks like camo
			//Ct = 	; 	// brownian - Like snoise, but more cloudy. Can be pushed to be very noisy  
			//Ct = VLNoise(Pt, 2); 						// VLNoise - Ocean like, very smooth. Still resembles snoise
			//Ct = noise(Pt);							// Trivial colourful noise, smooth
			//Ct = cellnoise(Pt);						// Checkerboard style noise, not smooth, faster than other noises
			
			/* http://dl.acm.org/citation.cfm?id=1531326.1531360 */
			/* Camo style */
			// filterregion fr;
			// fr->calculate2d(s * 16,t * 16);
			// fr->scale(0.25);
			// Ct = knoise(fr, 0.25);

			//Ct = pnoise(Pt, point (1,1,1)); 			// Tartan style noise
			//Ct = random(); 							// Random colour noise
			//Ct = turbulence(6, 4, 0.5, 1.9132);	 		// Cool looking mountains or cell outlines

			//Ci = Os * (ka + kd);
			// Ci = Os * mix(reflectionTerm * 0.25, reflectionTerm, fresnalMask);

			float scratchFreq = 1;
			float scratchNoiseScale = 20;
			float scratchRatio = 0.3;

			point PP = P;
			PP += noise(PP * scratchFreq * 0.01) * scratchNoiseScale;

			float scratch = noise(xcomp(PP * 0.2), ycomp(PP * 0.005));
			scratch = smoothstep(1 - scratchRatio, 1, scratch);

			color cv;
			float f1;
			point pos1;
			voronoi_f1_3d(Pt, 1, f1, pos1);

			float a = mix(1,  0, f1);
			float b = exp(smoothstep(0.2, 0.8, a));

			float Ks=.4, Kd=.6, Ka=.1, roughness=.1;
			float veining = 8;
			color specularcolor=1;

			varying float cmi;
			varying normal Nf;
			float pixelsize, twice, pixscale, weight, turbulence;

			Nf = normalize(N);
			V = -normalize(I);

			PP = transform("shader",P) * veining;
			PP = PP/2;	/* frequency adjustment (S-shaped curve) */
			pixelsize = sqrt(area(PP)); 
			twice = 2 * pixelsize;

			/* compute turbulence */
			turbulence = 0;
			for (pixscale = 1; pixscale > twice; pixscale /= 2) {
				/**** This function is different - abs() and -0.5 ****/
				turbulence += pixscale * abs(noise(PP/pixscale)-0.5);
			}

			/* gradual fade out of highest freq component near visibility limit */
			if (pixscale > pixelsize) {
				weight = (pixscale / pixelsize) - 1;
				weight = clamp(weight, 0, 1);
				/**** This function is different - abs() and -0.5 ****/
				turbulence += weight * pixscale * abs(noise(PP/pixscale)-0.5);
			}
			/*
			 * turbulence now has a range of 0:2, but its values actually
			 * tend strongly to lie around 0.75 to 1.
			 */

			 //todo How do splines work
			/**** This is different - no multiply by 4 and subtract 3 ****/
			cmi = fBm(Pt, filterwidthp(Pt), 3, 4, 2)	;
			cmi = clamp(cmi, 0, 1);
			float diffusecolor =
				float spline(cmi,
					float (0.2),
					float (0.05),
					float (0.5),
					float (0.6),
					float (0.3),
					float (0.05),
					float (0.8)
				);

			/* ------------------------- Specular Terms ------------------------- */
			// Tie roughness to the melting?
			color orenNayer = LocIllumOrenNayar(Nn, V, 1.0);
			
			float phongStrength = 24; // Strong highlight
			float phongNoiseStrength = 1;
			color phongTerm = 0;
			{
				// Temp normals/incident vectors, TODO : Clean up at the end
				vector V = normalize(faceforward(Nn, I));
				phongTerm = phong(Nn, V, phongStrength);
			}

			/* ------------------------- Frost Term ------------------------- */
			//color frostTerm = exp(fBm(Pt, filterwidthp(Pt), 3, 4, 2));
			float frostDensity = 0;
			float frostMask = inverseVignette(5, 0.25);
			frostMask = pow(frostMask, 4); // Make the mask more pronounced
			frostMask = clamp(frostMask, 0.1, 0.95);
			frostMask = mix(0, frostMask, frostDensity);

			/* ------------------------- Refraction/Reflection Terms ------------------------- */
			float refractionFrostSoftness = 0.4;
			float refractionTermFrost = layerNoise(3, frostAmount * 8);
			refractionTermFrost = mix(turbulence(8, 1, 2, 1.937), layerNoise(5, 16), 1 - refractionFrostSoftness);

			color refractionTerm = 0;
			color reflectionTerm = 0;
			calculateReflectRefract(1, 1, ior, refractionTerm, reflectionTerm);
			reflectionTerm *= phongTerm;
			
			// Make the refraction rougher ( param : refractionRoughness )
			float i;
			float jitterCount = 1;
			float randomScale = 0.5;
			color refractionBlur = 0;
			float blurAmount = 0.3; // Parametarise the surface's roughness instead

			normal tmp = Nn;

			// Not actually necessary, the displacement shader does this for us
			// color tmpReflection = 0;
			// for(i = 0; i < jitterCount; i+=1)
			// {
			// 	Nn = Nn + normal refractionTermFrost + (randomScale * random());
			// 	color blurRefraction = 0;
			// 	calculateReflectRefract(1, 1, ior, blurRefraction, tmpReflection);
			// 	refractionBlur += blurRefraction;
			// }
			// refractionBlur /= jitterCount;
			// refractionTerm = mix(refractionTerm, refractionBlur, blurAmount);

			Nn = tmp;

			//reflectionTermFrost = (reflectionTermFrost * 0.5) + 0.5; // Make the noise difference subtle using a half lambert effect


			/* ------------------------- Surface Scratches ------------------------- */

			float scratchMask = 0;
			scratchMask = turbulence(4, 0.25, 2, 8);
			scratchMask = abs(scratchMask - 0.5); // Replace highlights with dark patches
			scratchMask = pow(scratchMask, 3);
			scratchMask *= 8;
			scratchMask = smoothstep(0.25 * s, 0.3 * t, scratchMask);

			scratchMask = float spline(scratchMask,
				0,
				0.1,
				0.3,
				0.35,
				0.4,
				0.5
			);

			scratchMask *= 0.1;

			 
			/* ------------------------- Final Result ------------------------- */
			//Ci = diffusecolor * (Ka*ambient() + Kd*diffuse(Nf));
			/* add in specular component */	
			// Ci = Os * (Ci + specularcolor * Ks * specular(Nf,V,roughness));

			//Ci = Os * diffuse(Nn);
			//Ci = Os * mix(diffuse(Nn), refractionTerm, cmi);
			//Ci = Os * refractionTerm;

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
			Ci = Oi * refractionTerm;
			// Ci = ka + orenNayer;

		 /*
			Frost - refraction mixed with white, rough oren nayer shading, low phong
			No frost - clear refraction mixed with reflections, smooth oren nayer, high phong
			Both - Ambient + Diffuse * Slightly darkened backplate

		 */
			
			//Ci = ka + (kd * colourTint * silhouetteMask * (phongTerm + mix(frostTint * color refractionTermFrost, refractionTerm, frostMask)));

        }

}