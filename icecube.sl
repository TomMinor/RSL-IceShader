// surface icecube(
// 	color baseColour = (0.0, 1.0, 0.8);
// 	color specularColour = 1;
// 	color opacity = 0.5;
// 	float roughness = 0.1;
// 	float Ka = 0.0; 	// Ambient scale
// 	float Kd = .8;	// Diffuse scale
// 	float Ks = 1	// Specular scale
// 	)
// {
// 	normal Nn = normalize(N);
// 	vector V = normalize(-I); // I is a point on the surface

// 	color halfLambert = (diffuse(Nn) * 0.5) + 0.5;
// 	color specular = specular(Nn, V, roughness);

//     Ci = (Ka*ambient() + (baseColour * opacity * (Kd*halfLambert))) + (Ks*specularColour*specular);
//     Oi = opacity;
// }

// surface icecube()
// {
// 	float samples = 16;      /* often from a shader parameter */
// float blur = radians(5); /* often from a shader parameter */
// Ci = 0;
// if (N.I < 0) { /* only trace from points facing the eye */
//    vector R = reflect(normalize(I),normalize(N));
//    color hitcolor = 0;
   
//    gather("illuminance", P, R, blur, samples, "volume:Ci", hitcolor) 
//    {
//       Ci += hitcolor;
//    } else {
//       Ci += environment("skymap.env", R);
//    }
//    Ci = Ci / samples;
// }
// Ci *= Os;
// Oi = Os;
// }

surface icecube(
	color color1 = 1, 
	color2 = 0,
	opacity = 1,
	specularColor = 1;
	float Kd = 0.8,
	Ka = 0,
	Ks = 1,
	roughness = 0.3,
	freqS = 16,
	freqT = 16,
	bendScaleS = 1,
	bendScaleT = 1,
	modAmount = 2
	)
{
	// Diffuse
	normal Nn = normalize(N);

	// Specular
	vector V = normalize(-I); // Negative incident ray

	float ss = s + inversesqrt(t * 2 * PI) * bendScaleS;// + sin(t * 2 * PI) * bendScaleS;
	float st = t + inversesqrt(s * 2 * PI) * bendScaleT;// + sin(s * 2 * PI) * bendScaleT;

	float stripeS = floor(ss * freqS);
	float stripeT = floor(st * freqT);

	color stripeColour = mix(color1, color2, mod(stripeS + stripeT, modAmount));

	Ci = stripeColour * opacity * (Kd*diffuse(Nn) + Ka*ambient()) + (specularColor * specular(Nn, V, roughness));
	Oi = opacity;
}