
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