#include "extranoise.h"
#include "noises.h"

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

point surfaceNoise()
{
	point result = layerNoise(3, 8);

	return result;
}

displacement icecubeDisp(
	float cornerRoundness = 0.5;
	)
{
	P = superquad(cornerRoundness, cornerRoundness);
	N = calculatenormal(P);

	float dispScale = 0.1;
	float RepeatS = 4;
	float RepeatT = 4;

	// ----------------------- Large Noise ----------------------------
	point PP;
	normal NN = normalize(N);
	
	// now calculate the new disp value for P
	float ss=mod(s * RepeatS,1);
	float tt=mod(t * RepeatT,1);
	float disp=sin(ss * 2 * PI) * sin(tt * 2 * PI);
	
	PP = P + (NN * disp * dispScale);

	P = PP;
	N = calculatenormal(P);

	// ---------------------- Scra tches ----------------------

	float scratchMask = 0;
	scratchMask = turbulence(4, 0.25, 2, 8);
	scratchMask = abs(scratchMask - 0.5); // Replace highlights with dark patches
	scratchMask = pow(scratchMask, 3);
	scratchMask *= 8;
	scratchMask = smoothstep(0.25 * s, 0.3 * t, scratchMask);

	float tmp=spline(scratchMask,
		0,
		0.1,
		0.3,
		0.35,
		0.4,
		0.5
	);

	P = P - (tmp * NN * 0.1);
	N = calculatenormal(P);
}