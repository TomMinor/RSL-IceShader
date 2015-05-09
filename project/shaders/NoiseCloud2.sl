/* NoiseCloud
 * Raymarched noise cloud shader (with self shadowing)
 * by Wobbe F. Koning 
 *
 * NOTE: only works correctly on a sphere located at 
 *       the origin object space!   
 *
 * Lighting parameters:
 *   Kd, Ks, Ka and roughness - the usual
 *   shadows - amount of self shadowing. 0 = no shadows.
 *   backLight - Creates glowing edge from lights behind object
 *
 * Noise shape controls:
 *   noiseFreq, noiseIter - Controls fBm loop.
 *   density - How dense a cloud do you want ?
 *   softness - controls the fluffy-ness. Smaller is more solid.
 *   edgeFade - The noise pattern will be faded in between
 *              the sphere's normalized radius and 1 - edgeFade
 * RayMarch controls:
 *   stepsize - the size of the steps to take through the spere
 *              (in object space units)
 *   stepJitter - How much the jitter the start point of the path 
 *                through the sphere
 */

#define udn(x,lo,hi) (smoothstep(.25, .75, float noise(x)) * ((hi) - (lo)) + (lo))

float
MakeNoiz ( point Pnoiz; 
	   uniform float Freq, Iter; 
	   float softness;
	   uniform float stepsize; 
	   float radius;
	   float density2; )
{ 
  float n; 
  float noizy = 0;
  point PnoizObj = transform ("object", Pnoiz);

  /* calculate iterative noise, taking softness parameter into account */
  for (n = 0 ; n < Iter ; n += 1){
    noizy += pow (udn (PnoizObj*Freq*((n+1)*(n+1)), 0.0, 1.0)/pow(n+1,2), (1/softness));
  }

  /* Scale noiz to make density independent of stepsize */
  noizy = noizy * (stepsize/radius) * density2;

  return noizy;
}

/* Normal calculation approximation, adapted from AR page 424 */
normal
makeNormal ( float Ospoint;
	     point Pnew; 
	     float radius;
	     uniform float Freq, Iter, stepsize;
	     float softness, density; )
{
  float offset = 1.5*stepsize;

  point Ptemp = Pnew - vector (offset,0,0);
  float densX = MakeNoiz(Ptemp,Freq,Iter,softness,stepsize,radius,density) - Ospoint;

  Ptemp = Pnew - vector (0,offset,0);
  float densY = MakeNoiz(Ptemp,Freq,Iter,softness,stepsize,radius,density) - Ospoint;

  Ptemp = Pnew - vector (0,0,offset);
  float densZ = MakeNoiz(Ptemp,Freq,Iter,softness,stepsize,radius,density) - Ospoint;

  return normalize ( normal(densX,densY,densZ) );
}

float
RayMarch4Light ( point PP;
		 normal directionIn;
		 float radius;
		 uniform float edgeFade;
		 uniform float stepsize;
		 uniform float Freq;
		 uniform float Iter;
		 float softness; 
		 float density; 
		 uniform float jitter; )
{
  point Pnew = transform ("object", PP);
  normal direction = ntransform ("object", directionIn);

  /* jitter startpoint and take first step */
  Pnew += direction * stepsize * (1 + jitter * udn ((Pnew/stepsize), -.5, .5));

  float fromOrigin =  length(Pnew);
  float innerRadius = radius * (1 - edgeFade);
  float edgeCorrect;

  float Oslight = 0;
  float Ostemp;

  /* end loop when outside sphere  OR full opacity is reached  */
  while ( (fromOrigin <= radius) && (Oslight <= 1.0) ) {

    edgeCorrect = 1 - smoothstep ( innerRadius, radius, fromOrigin);

    Ostemp = MakeNoiz(Pnew,Freq,Iter,softness,stepsize,radius,density);

    Oslight += edgeCorrect *  Ostemp;

    /* next step along ray */
    Pnew += stepsize * direction;
    fromOrigin = length(Pnew);
  }

  return min (Oslight, 1);
}

void
RayMarch ( output float Osnew;
	   output color Csnew;
	   point PP;
	   normal directionIn;
	   float radius;
	   uniform float edgeFade;
	   uniform float stepsize;
	   uniform float Freq;
	   uniform float Iter;
	   float density;
	   float softness;
	   uniform float Kd;
	   uniform float Ks;
	   uniform float roughness;
	   uniform float backLight;
	   uniform float shadows; 
	   uniform float jitter;)
{
  point Pnew = PP;
  normal direction = normalize(ntransform ("object", directionIn));

  point Origin = point (0,0,0);
  float fromOrigin = length(Pnew);
  float innerRadius = radius * (1 - edgeFade);
  float edgeCorrect;
  float nearEdge;
  float OstempRaw;
  float Ostemp;
  float OsOld;

  /* variables 4 lighting */
  extern vector I;
  point Pworld;
  normal Nlight = normalize ( normal (vtransform ("world", -I) ) );
  normal Npoint;
  normal Ln;
  float attenuation;
  float attnTemp;
  float Osxtra;
  float Oslight;
  color Clight = 0;
  float density4light = density * shadows;

  /* end loop if outside sphere, or full opacity is reached */
  while (( fromOrigin <= radius ) && (Osnew <= 1) ){

    edgeCorrect = 1 - smoothstep ( innerRadius, radius, fromOrigin);
    OsOld = Osnew; /* remember old density to attenuate light! */
    OstempRaw = MakeNoiz(Pnew,Freq,Iter,softness,stepsize,radius,density4light);
    Ostemp = edgeCorrect * OstempRaw;
    Osnew += Ostemp;

    /* calculate lighting, only if OstempRaw >0 */
    if ( OstempRaw > 0 ) {
      Pworld = transform ("object", "world", Pnew);

      color C = 0;

      /* calculate normal approximation */
      Npoint = makeNormal ( OstempRaw, Pnew, radius, Freq, Iter, stepsize, softness, density);
      Npoint = normalize (ntransform ("object","world", Npoint));
      nearEdge = smoothstep ( 1-(stepsize*2), 1-stepsize, fromOrigin/radius);
      Npoint = mix ( Npoint, normal normalize(N) , nearEdge);

      illuminance ( Pworld )  /*consider all lights*/
	{
	  Ln = normalize(normal(L));
	  vector H = normalize ( Ln + Nlight );

	  /* diffuse & backlight contribution, making sure it's positive */
	  attnTemp = (Ln.Npoint);
	  attenuation = max ( 0, Kd * attnTemp);
	  float attenBack = backLight * smoothstep(.5, .8, - (Ln.Nlight) );
	  attenuation += attenBack;
	  /* specular contribution, also has to be positive  */
	  attenuation += max (0, Ks * pow(max(0,(Npoint.H)), 1/roughness));

	  /*if light behind point, it's opacity blocks light, unless backlit  */
	  Osxtra = Ostemp * (max (0, -attnTemp )) * (1 - attenBack);

	  if (attenuation > 0 ) {
	    /* calculate density between Point and Lightsource */
	    normal toLight = normalize(normal(vtransform("object",L)));
	    
	    /* Step along ray to find density towards light */
	    Oslight = RayMarch4Light ( Pnew, toLight, radius, edgeFade, stepsize, Freq, Iter, softness, density4light, jitter );
	    Oslight += Osxtra;  /* add Ostemp for lights behind point */

	    /* Make lightcontribution independant of stepsize */
	    /*attenuation /= stepsize;*/

	    /* Calculate light, attenuating for light position 
	     * and the density towards light */
	    C += Cl * attenuation *  ( 1 - clamp( Oslight, 0, 1) );
	  }
	}

      /* Calculate light, attenuating for density towards camera 
       * (OsOld, jitter that density a bit)
       * and adjust for the density of the current point  */
      OsOld += softness * Ostemp * jitter * noise(9*Pnew/stepsize);
      Clight += C * Ostemp * max(0,1-OsOld);
    }

    /* next step along ray */
    Pnew += stepsize * direction;
    fromOrigin = length (Pnew);
  }
 
  Osnew = min (Osnew,1);
  Csnew = Csnew * Clight;
  /*Csnew = color (1,0,0);*/
}

surface
NoiseCloud ( uniform float Kd = 1;
	     uniform float Ks = 1;
	     uniform float roughness = .5;
	     uniform float Ka = 0.1;
	     uniform float shadows = 1;
	     uniform float backLight = 1;
	     uniform float noiseFreq = 2;
 	     uniform float noiseIter = 2;
	     uniform float density = 1;
	     uniform float softness = .5;
	     uniform float edgeFade = .1;
	     uniform float stepsize = .1; 
	     uniform float stepJitter = 1; )
{
  color Csnew = Cs;
  float Osnew = 0;

  /* do not calculate for backfaces */
  if ((N.I)<0){
    /* transform P to object space*/
    point PP = transform("object", P);
 
    /* transform I to object space and normalize it */
    normal Ni = normal (normalize ( vtransform ("object", I)));

    /* calculate size of sphere */
    float radius = length (PP);

    /* jitter startpoint */
    PP += Ni * stepJitter * udn ( (PP/stepsize), 0, stepsize);

    /* correct density for softness, and make sure softness >0 */
    float softcorr = max (softness, 1e-6);
    float denscorr = density/softness;

    /* Step along ray */
    RayMarch ( Osnew, Csnew, PP, Ni, radius, edgeFade, stepsize, noiseFreq, noiseIter, denscorr, softcorr, Kd, Ks, roughness, backLight, shadows, stepJitter );
  }

  Oi = clamp( Osnew, 0.0, 1.0);
  Ci = Oi * ( Csnew + Cs*Ka*ambient() );
}






































