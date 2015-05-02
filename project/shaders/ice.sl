/*
* A simple glass shader where the result color is the sum of 
* reflection, refraction, and Phong specular.
*/

surface 
ice (
float Kr = 1;         /* ideal (mirror) reflection multiplier */
float Kt = 1;         /* ideal refraction multiplier */
float ior = 1.5;      /* index of refraction */
float Ks = 1;         /* specular reflection coeff. */
float shinyness = 50) /* Phong exponent */
{
        normal Nn = normalize(N);
        vector In = normalize(I);
        normal Nf = faceforward(Nn, In, Nn);
        vector V = -In;   /* view direction */
        vector reflDir, refrDir;
        float eta = (In.Nn < 0) ? 1/ior : ior; /* relative index of refraction */
        float kr, kt;
        
        Ci = 0;
        
        /* Compute kr, kt, reflDir, and refrDir.  If there is total internal
        reflection, kt is set to 0 and refrDir is set to (0,0,0). */
        fresnel(In, Nf, eta, kr, kt, reflDir, refrDir);
        kt = 1 - kr;
        
        /* Mirror reflection */
        if (Kr * kr > 0)
        	Ci += Kr * kr * trace(P, reflDir);
        
        /* Ideal refraction */
        if (Kt * kt > 0)
    		Ci += Kt * kt * trace(P, refrDir) * Cs;	
        
        /* Specular highlights */
        illuminance (P, Nf, PI/2) {
                vector Ln = normalize(L);   /* normalized direction to light source */
                vector H = normalize(Ln + V);   /* half-way vector */
                Ci += Ks * pow(H . Nf, shinyness) * Cl;
        }
}