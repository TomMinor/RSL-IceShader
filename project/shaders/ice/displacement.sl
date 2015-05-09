#include "extranoise.h"
#include "noises.h"


displacement scratchedSurface(
	)
{
 	vector NN = normalize(N);
 	point Pt = transform("shader", P);

	P = P;

	color cv;
	float f1;
	point pos1;
	voronoi_f1_3d(Pt, 0, f1, pos1);

	//P += f1 * NN;

	N = calculatenormal(P);
}