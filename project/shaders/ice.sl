#include "noises.h"
#include "ice/extranoise.h"

color colorPow(color colour; float p)
{
	point c = point colour;

	float x = xcomp(c);
	float y = ycomp(c);
	float z = zcomp(c);

	return color (pow(x, p), pow(y, p), pow(z, p));	
}


// http://rendermanx.blogspot.co.uk/2013/08/remap.html
float remap(float x; float a1; float b1; float a2; float b2) 
{ 
   return (x*(b2-a2) - a1*b2 + b1*a2) / (b1-a1); 
} 

// Produce a fresnel effect modified to allow a thick 'edge' in addition to the smooth fresnel effect
float vignette(
	normal Nn;
	float falloff;
	float edgeScale;
	)
{
	float kr, kt;
	fresnel(normalize(I), Nn, 1/falloff, kr, kt);

	return smoothstep(edgeScale, 1, kt);
}

// color phong()
// {
// 		color result = 0;
// 	    /* Specular highlights */
//         illuminance (P, Nf, PI/2) {
//                 vector Ln = normalize(L);   /* normalized direction to light source  */
//                 vector H = normalize(Ln + V);   /* half-way vector */
//                 result += Ks * pow(H . Nf, shinyness) * Cl;
//         }
//         return result;
// }

#define inverseVignette(Nn, falloff, edgeScale) (1 - vignette(Nn, falloff, edgeScale))

color 
glassrefr (
	normal Nn;
	float Kr;         	/* ideal (mirror) reflection multiplier */
	float Kt;         	/* ideal refraction multiplier */
	float ior;      	/* index of refraction */
	float Ks;         	/* specular reflection coeff. */
	float shinyness) 	/* Phong exponent */
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
        
        return result;
}

/* http://nccastaff.bournemouth.ac.uk/jmacey/Renderman/slides/RendermanShaders1.pdf */
color
LocIllumOrenNayar (normal N; vector V; float roughness;)
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

/*
TODO:
 - Surface scratches
 	+ Surface shader + Displacement
 - Frost
 	+ Layer up a bunch of noise
 - Refraction w/ noise
 - Reflection
 - Interior Bubbles
 	+ Scary stuff, probably don't have time now
*/

surface icecube(
		float frostAmount = 1.0;
		// 1 = low reflection, low refraction
		// 0 = medium reflection, high refraction

		float ior = 1.3;

		color colourTint = color "rgb" (1, 1, 1);
		color frostTint = color "rgb" (0.784, 0.9098, 0.8941);
	)
{
	// reflection should be masked by a fresnel effect
	normal Nn = normalize(N);
	vector incidentRay = normalize(I);      /* normalized incident vector */
	vector V = normalize(faceforward(-I, Nn));

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


	Oi = Os;
	//Ci = Os * (ka + kd);
	// Ci = Os * mix(reflectionTerm * 0.25, reflectionTerm, fresnalMask);

	// float scratchFreq = 1;
	// float scratchNoiseScale = 20;
	// float scratchRatio = 0.3;

	// point PP = P;
	// PP += noise(PP * scratchFreq * 0.01) * scratchNoiseScale;

	// float scratch = noise(xcomp(PP * 0.2), ycomp(PP * 0.005));
	// scratch = smoothstep(1 - scratchRatio, 1, scratch);

	//color cv;
	// float f1;
	// point pos1;
	// voronoi_f1_3d(Pt, 1, f1, pos1);

	// float a = mix(1,  0, f1);
	// float b = exp(smoothstep(0.2, 0.8, a));

	// float Ks=.4, Kd=.6, Ka=.1, roughness=.1;
	// float veining = 8;
	// color specularcolor=1;

	// varying float cmi;
	// varying normal Nf;
	// float pixelsize, twice, pixscale, weight, turbulence;

	// Nf = normalize(N);
	// V = -normalize(I);

	//PP = transform("shader",P) * veining;
	//PP = PP/2;	/* frequency adjustment (S-shaped curve) */
	// pixelsize = sqrt(area(PP)); 
	// twice = 2 * pixelsize;

	// /* compute turbulence */
	// turbulence = 0;
	// for (pixscale = 1; pixscale > twice; pixscale /= 2) {
	// 	/**** This function is different - abs() and -0.5 ****/
	// 	turbulence += pixscale * abs(noise(PP/pixscale)-0.5);
	// }

	// /* gradual fade out of highest freq component near visibility limit */
	// if (pixscale > pixelsize) {
	// 	weight = (pixscale / pixelsize) - 1;
	// 	weight = clamp(weight, 0, 1);
	// 	/**** This function is different - abs() and -0.5 ****/
	// 	turbulence += weight * pixscale * abs(noise(PP/pixscale)-0.5);
	// }
	// /*
	//  * turbulence now has a range of 0:2, but its values actually
	//  * tend strongly to lie around 0.75 to 1.
	//  */

	//  //todo How do splines work
	// /**** This is different - no multiply by 4 and subtract 3 ****/
	// cmi = fBm(Pt, filterwidthp(Pt), 3, 4, 2)	;
	// cmi = clamp(cmi, 0, 1);
	// float diffusecolor =
	// 	float spline(cmi,
	// 		float (0.2),
	// 		float (0.05),
	// 		float (0.5),
	// 		float (0.6),
	// 		float (0.3),
	// 		float (0.05),
	// 		float (0.8)
	// 	);

	/* use color spline to compute basic color */

	// Tie roughness to the melting?
	color orenNayer = LocIllumOrenNayar(Nn, V, 0.0);

	/* ------------------------- Specular Term ------------------------- */
	float phongStrength = 1;
	float phongNoiseStrength = 1;
	float phongNoise = layerNoise(6, 8);
	color phongTerm = colorPow(phong(Nn, V, phongNoise), 16) * phongStrength;

	/* ------------------------- Frost Term ------------------------- */
	//color frostTerm = exp(fBm(Pt, filterwidthp(Pt), 3, 4, 2));
	float frostDensity = 1;
	float frostMask = inverseVignette(Nn, 5, 0.25);
	frostMask = pow(frostMask, 4); // Make the mask more pronounced
	frostMask = clamp(frostMask, 0.1, 0.95);
	frostMask = mix(0, frostMask, frostDensity);

	/* ------------------------- Refraction Term ------------------------- */
	float reflectionFrostSoftness = 0.4;
	float reflectionTermFrost = layerNoise(3, frostAmount * 8);
	reflectionTermFrost = mix(turbulence(8, 1, 2, 1.937), layerNoise(5, 16), 1 - reflectionFrostSoftness);

	color reflectionTerm = glassrefr(Nn, 1, 1, ior, 1, 50);
	
	// Make the refraction rougher ( param : refractionRoughness )
	float i;
	float jitterCount = 1;
	float randomScale = 0.5;
	color reflectionBlur = 0;
	float blurAmount = 0.3;
	for(i = 0; i < jitterCount; i+=1)
	{
		normal refractionJitter = Nn + normal reflectionTermFrost + (randomScale * random());
		reflectionBlur += glassrefr(refractionJitter, 1, 1, ior, 1, 50);
	}
	reflectionBlur /= jitterCount;
	reflectionTerm = mix(reflectionTerm, reflectionBlur, blurAmount);

	//reflectionTermFrost = (reflectionTermFrost * 0.5) + 0.5; // Make the noise difference subtle using a half lambert effect

	/* ------------------------- Reflection Term ------------------------- */
	// TODO



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

	scratchMask *= 0.01;

	 
	/* ------------------------- Final Result ------------------------- */
	Oi = Os;
	//Ci = diffusecolor * (Ka*ambient() + Kd*diffuse(Nf));
	/* add in specular component */	
	// Ci = Os * (Ci + specularcolor * Ks * specular(Nf,V,roughness));

	//Ci = Os * diffuse(Nn);
	//Ci = Os * mix(diffuse(Nn), reflectionTerm, cmi);
	//Ci = Os * reflectionTerm;
	
	float distance = length(E - P);
	distance = distance * (1/200);

	float mindistance = 0, maxdistance = 0.0025;
	float silhouetteMaskAmbient = 1;
	float silhouetteMask = depth(transform("world", P));
	silhouetteMask = clamp(silhouetteMaskAmbient + (silhouetteMask - mindistance) / (maxdistance - mindistance), 0.0, 1.0);
	silhouetteMask = silhouetteMask * 0.5; // Increase the contrast a little

	//Ci = test;
	Ci = ka + (kd * colourTint * silhouetteMask * (phongTerm + mix(frostTint * color reflectionTermFrost, reflectionTerm, frostMask)));

	//Ci = reflectionTermFrost;

	//Ci = refractionJitter;
}

// surface
// ice ( float Ka = 1,    // Ambient scalar
// 			Kd = 0.5,  // Diffuse scalar
// 			Ks = 1,    // Specular scalar
// 			Kr = 0.5,  // Ideal Reflection scalar
// 			Kt = 0.5,  // Ideal Refraction scalar
// 			roughness = 0.05, 	// Specular roughness
// 			shinyness = 50, 	// Specular shinyness
// 			ior = 1.5; // Index of refraction
// 			color specularColor = 1;
// 			color opacity = 1;
// 	)
// {
// 	// Nn = faceforward(normalize(N), I, N); // Construct normal facing the camera
//     normal Nn = normalize(N); 				// Don't construct a front facing normal to avoid artifacts
//     vector incidentRay = normalize(I);      /* normalized incident vector */
//     vector viewDir = -incidentRay;  		/* view direction */


    
	
//     //--------------------------------- Calculate Refraction -------------------------------------
//     // http://renderman.pixar.com/view/ray-traced-shading-2
//     float kr, kt; 
//     vector refreflectedDir;
//     color refractionTerm = 0;		/* Color of the refractions */

//     // Compute kr, kt, reflectedDir, and refreflectedDir.  If there is total internal
//     // reflection, kt is set to 0 and refreflectedDir is set to (0,0,0). 
//     fresnel(incidentRay, Nn, eta, kr, kt, reflectedDir, refreflectedDir);
//     kt = 1 - kr;

//     /* Mirror reflection */
//     if (Kr * kr > 0)
//     	refractionTerm = Kr * kr * trace(P, reflectedDir);
    
//     /* Ideal refraction */
//     if (Kt * kt > 0)
// 		refractionTerm = Kt * kt * trace(P, refreflectedDir) * Cs;	

// 	//--------------------------------- Calculate Reflection  -------------------------------------
//     color reflectionTerm = 0;		/* Color of the reflections */
//     /* Calculate the reflection color */
// 	// if (Kr > 0.001) 
// 	// {
// 	// 	reflectionTerm = Kr * trace (P, reflectedDir) * pow(shinyness, -1); // Get the colour traced in the reflected direction
// 	// }
  	
//   	//--------------------------------- Calculate Result  -------------------------------------
// 	color ambientTerm = Ka * ambient();
// 	color diffuseTerm = Kd * diffuse(Nn);

// 	//color specTerm = specularColor * (refractionTerm + reflectionTerm + Ks * specular(Nn, -incidentRay, roughness));
// 	color refractReflectTerm = refractionTerm + reflectionTerm;

//     Ci = opacity * ((ambientTerm + diffuseTerm)) + refractReflectTerm;
//     //Ci = Os * noise(s * 16, t * 16);
//     Oi = opacity; 

//     // Custom illuminance loop : Phong brdf
// 	// illuminance(P, Nn, PI/2) 
// 	// {
// 	//         vector Ln = normalize(L);   /* normalized direction to light source */
// 	//         vector H = normalize(Ln + viewDir);   /* half-way vector */
// 	//         Ci += Ks * pow(H . Nn, shinyness) * Cl;
// 	// }
// }