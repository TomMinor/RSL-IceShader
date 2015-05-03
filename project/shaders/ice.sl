surface
ice ( float Ka = 1,    // Ambient scalar
			Kd = 0.5,  // Diffuse scalar
			Ks = 1,    // Specular scalar
			Kr = 0.5,  // Ideal Reflection scalar
			Kt = 0.5,  // Ideal Refraction scalar
			roughness = 0.05, 	// Specular roughness
			shinyness = 50, 	// Specular shinyness
			ior = 1.5; // Index of refraction
			color specularColor = 1;
	)
{
	// Nn = faceforward(normalize(N), I, N); // Construct normal facing the camera
    normal Nn = normalize(N); 				// Don't construct a front facing normal to avoid artifacts
    vector incidentRay = normalize (I);     /* normalized incident vector */
    vector viewDir = -incidentRay;  		/* view direction */

	float eta = (incidentRay.Nn < 0) ? 1/ior : ior; /* relative index of refraction */
    
	Ci = 0;
	vector reflectedDir = normalize(reflect (incidentRay, Nn)); // Get perfect reflection along normal TODO This may not need to be initialised
    //--------------------------------- Calculate Refraction -------------------------------------
    // http://renderman.pixar.com/view/ray-traced-shading-2
    float kr, kt; 
    vector refreflectedDir;
    color refractionTerm = 0;		/* Color of the refractions */

    // Compute kr, kt, reflectedDir, and refreflectedDir.  If there is total internal
    // reflection, kt is set to 0 and refreflectedDir is set to (0,0,0). 
    fresnel(incidentRay, Nn, eta, kr, kt, reflectedDir, refreflectedDir);
    kt = 1 - kr;

    /* Mirror reflection */
    if (Kr * kr > 0)
    	refractionTerm = Kr * kr * trace(P, reflectedDir);
    
    /* Ideal refraction */
    if (Kt * kt > 0)
		refractionTerm = Kt * kt * trace(P, refreflectedDir) * Cs;	

	//--------------------------------- Calculate Reflection  -------------------------------------
    color reflectionTerm = 0;		/* Color of the reflections */
    /* Calculate the reflection color */
	// if (Kr > 0.001) 
	// {
	// 	reflectionTerm = Kr * trace (P, reflectedDir) * pow(shinyness, -1); // Get the colour traced in the reflected direction
	// }
  	
  	//--------------------------------- Calculate Result  -------------------------------------
	color ambientTerm = Ka * ambient();
	color diffuseTerm = Kd * diffuse(Nn);
	//color specTerm = specularColor * (refractionTerm + reflectionTerm + Ks * specular(Nn, -incidentRay, roughness));
	color refractReflectTerm = refractionTerm + reflectionTerm;

    // Ci = Os * ((ambientTerm + diffuseTerm)) + refractReflectTerm;
    Ci = Os * (ambientTerm + (0.5 * diffuseTerm));// + refractReflectTerm;
    Oi = Os; 

    // Custom illuminance loop : Phong brdf
	// illuminance(P, Nn, PI/2) 
	// {
	//         vector Ln = normalize(L);   /* normalized direction to light source */
	//         vector H = normalize(Ln + viewDir);   /* half-way vector */
	//         Ci += Ks * pow(H . Nn, shinyness) * Cl;
	// }
}