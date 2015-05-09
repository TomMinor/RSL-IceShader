/* $Revision: #5 $ $Date: 2012/10/03 $
# ------------------------------------------------------------------------------
#
# FROSTED GLASS SHADER
# 
# kristeneggleston42.com
# Kristen Eggleston
# Feb 2013
#
#
# Shader that has all the normal glass attributes but also a noise based
# frost that can be controlled by a locator ( if the user wants it ). 
#
#
# Based of of Pixar's plausile glass shader. Used with permission.
#
# ------------------------------------------------------------------------------
*/
#include <stdrsl/ShadingContext.h>
#include <stdrsl/RadianceSample.h>
#include <stdrsl/Lambert.h>
#include <stdrsl/SpecularAS.h>
#include <stdrsl/Math.h>
#include <stdrsl/Colors.h>

//  plausibleGlass:
//
//  A plausible glass material. Implements a basic 
//  functionality needed to shade plausible glass materials.
//  Uses a stdrsl specular component (stdrsl_SpecularAS).

class frostedGlass(
    uniform color glassColor = color(1); // color of glass, combines with Cs
	varying color frostedColor = color(0.4);
	uniform float transparency = 0;
	uniform float frostyAmount = 0;
    uniform float roughness = 0.03;
	uniform float specRoughscale = 1;
	uniform float refractRoughscale = 0.75;
    uniform float specularGain = 0.2;
    uniform float reflectiveGain = 0.5;
    uniform float diffuseGain = 1;
    uniform color specularColor = color(0.6);
    uniform float internalReflectionLimit = 4; 
        // max number of internal reflections
    uniform float rouletteThreshold = .3; 
        // above this threshold we integrate both refl and v 
        // below this threshold we select a refl or refr path
    uniform float internalReflectionAttenuation = .9;
    uniform float ior = 1.5; // glass
    uniform float mediaIor = 1; // air

    uniform string surfaceMap  = ""; // optional texture combines with glassColor
    uniform string roughnessMap = "";

    uniform float displacementAmount = 0;
    uniform string displacementMap  = "";

    uniform float directLightSamples = 1; 
    uniform float indirectSamples = 16;

    uniform float indirectSpecularMaxDistance = 1e10;
    uniform string indirectSpecularSubset = "";
    uniform float applySRGB = 1;

    uniform string lightCategory = "";
    uniform float __computesOpacity = 0; // set to 1 for fake shadows and colored shadows
	string 	frost_spaceA = "shader",
			frost_spaceB = "shader";
			
	float	radOfInfluence = 1.0;
	string	influenceSpace = "";
	float   maxInside = 0;
	float   rampSize = 0;
	float	frost_rimFreq = 0, frost_rimAmp = 0;
	
	float Kf = 10,
		  filterWidth = 0.01,
		  octaves = 5,
		  amplitude = 0.174,
		  offset = 0;
    )
{
    // Member variables
    stdrsl_ShadingContext 	m_shadingCtx;
    stdrsl_Lambert			m_diffuse;
    stdrsl_Fresnel 			m_fres;
    stdrsl_SpecularAS 		m_specular;
    stdrsl_SpecularAS 		m_specularIndirect;
    varying color 			m_glassColor;
    uniform float 			m_mode;
    varying float 			m_roughness;
	varying float			m_transparency;
	varying float 			influence;


    public void begin() 
    {
        m_shadingCtx->init();
    }

    public void displacement(output point P; output normal N) 
    {

        if(displacementMap != "" && displacementAmount != 0) 
        {
            float v = displacementAmount * texture(displacementMap[0]);
            m_shadingCtx->displace(vector(normalize(N)), v, "displace");
            m_shadingCtx->init();
        }


		// measure the distance to the origin of "influenceSpace"
		point fs = point "object" (0,0,0);
		fs = transform(influenceSpace, fs);
		float d = distance(fs,transform("shader", P));
		
		float lumpy = noise(transform("shader", P), frost_rimFreq) * frost_rimAmp;
		influence = smoothstep(0 + rampSize, radOfInfluence, d + lumpy);
		
		if(maxInside > 0)
			influence = 1 - influence;
		
		//initialize m_shadingCtx variable just in case it had been used before
    	m_shadingCtx->init();
		
		//assign m_hump variable based on wavelet noise
   		m_transparency = wnoise(transform(frost_spaceA, P) * Kf, filterWidth, "octaves", octaves,"amplitude", amplitude);
    	varying float transparencyVariate;

		transparencyVariate = wnoise(transform(frost_spaceB, P) * (Kf / 5), 0.5, "octaves", 2,"amplitude", 2);
		
		m_transparency = (m_transparency * transparencyVariate) * influence;
		
		//displace based on m_transparency
		m_shadingCtx->displace(vector(normalize(N)), m_transparency * displacementAmount,
                                    "displace");
		//reinitialize m_shadingCtx
		m_shadingCtx->init();//take out to make a toon shader!!!!
    }

    public void opacity(output color Oi)
    {

        m_glassColor = glassColor * Cs;
        if(__computesOpacity == 1)
        {
            // Signals that we want to be transparent to transmission rays.
            // Since we want to be opaque to camera rays we set Oi to 1
            // in specularlighting. 
            Oi = color(1) - (glassColor * transparency);
        }
        // We could implement a fake view dependent shadow but that's left
        // as an exercise to the reader. (see the Revealing Opacity app note)
    }


    public void specularlighting(output color Ci,Oi) 
    {
        color CdirectSpec = 0;
        color CindirectSpec = 0;
        color specColor = specularColor; 

        m_fres->init(m_shadingCtx, mediaIor, ior);

        if(surfaceMap!= "")
        {
            color c = color texture(surfaceMap);
            if(applySRGB != 0) c = srgbToLinear(c);
            m_glassColor *= c;
        }

        m_roughness = roughness * refractRoughscale;

        m_specular->init(m_shadingCtx, specColor * m_fres->m_Kr,
                         roughness, 0, specRoughscale,
                         1, directLightSamples); 

        // We aportion the indirectSamples between reflection and refraction
        // according to Fresnel. Since this value varies over the grid and
        // we need a uniform value, we employ gridmax.
        uniform float reflSamps =  gridmax(max(1, indirectSamples * m_fres->m_Kr));
        m_specularIndirect->init(m_shadingCtx, specColor * m_fres->m_Kr,
                                 m_roughness, 0, 1,
                                 reflSamps, reflSamps);

        // Internal reflection attenuation, first internal reflection isn't
        // attenuated
        if(m_shadingCtx->m_RayDepth > 1)
            m_fres->m_Kr *= pow(internalReflectionAttenuation,
                                m_shadingCtx->m_RayDepth);

        uniform float sampleBase = (m_shadingCtx->m_RayDepth > 0) ? 0 : 1;
            // On Ray hits, we want no sample-base jittering.

        // We don't share material samples between indirectspecular and
        // directlighting because our sample-counts differ due to the
        // refraction light paths.
		float distances[16];
		float i;
		for(i = 0; i < 16; i += 1)
			distances[i] = noise( transform("object", P) * 8.2);
	
        CindirectSpec += indirectspecular(surface, 
                                "samplebase", sampleBase,
                                "subset", indirectSpecularSubset,
                                "maxdist", indirectSpecularMaxDistance,
                                "integrationdomain", "sphere",
								"samplesend:surface:Os", distances);

        CdirectSpec = directlighting(this, getlights("category", lightCategory),
                                    "mis", 1,
                                    "integrationdomain", "sphere");

		CindirectSpec = CindirectSpec * reflectiveGain;
		CdirectSpec = CdirectSpec * specularGain;

        Ci +=  (CindirectSpec + CdirectSpec);
        Oi = 1; // always opaque to camera, specular rays

    }

    



    public void diffuselighting(output color Ci, Oi) 
    {
		color diffColor = glassColor * diffuseGain * Cs;
		
		m_transparency += offset * influence;

		float tvalue = 0;
		if(attribute("user:test", tvalue) == 1) {
			 //user the tvalue in some way
			diffColor[0] = tvalue;
			}


        if(surfaceMap!= "")
        {
            color c = color texture(surfaceMap);
            if(applySRGB != 0) c = srgbToLinear(c);
            diffColor *= c;
        }
        m_diffuse->init(diffColor);


		//diffuse lighting multiplied by the noise so that the frost only shows in the light then lighten up shadows
		//because frosted glass is more flatly lit than other objects
		color frostColor = influence;
		color surfColor = directlighting(this, getlights("category",lightCategory)) * influence * transparency + (m_transparency * frostyAmount) + (influence * frostedColor);
        

		if(surfColor[0] <= 1 && surfColor[1] <= 1 && surfColor[2] <=1)
		{
			Ci = surfColor;
		}
		else{
			Ci = 1;
		}

    }

    public void evaluateSamples(string distribution;
                                output __radiancesample samples[] ) 
    {

        if (distribution == "diffuse")
		{
            m_diffuse->evalDiffuseSamps(m_shadingCtx, m_fres, samples); 
		}

        if(distribution == "specular") 
        {
            m_specular->evalSpecularSamps(m_shadingCtx, m_fres, samples);
        }
    }

    private void genRefractionSamples(float refractionSamples;
                                    output __radiancesample samples[]) 
    {
        if(gridmax(m_fres->m_Kt) != 0 &&  m_glassColor != color(0)) 
        {
            uniform float begin = arraylength(samples); 
                                 // reflection samples may preceed ours in samples
            uniform float maxSamplesCount = gridmax(refractionSamples);
            uniform float totalSamples = begin + maxSamplesCount;
            resize(samples, totalSamples);

            // Translate roughness to solid angle approximations
            float cosTheta= pow(.0001,m_roughness*m_roughness);
            float angularVis = acos(cosTheta);
            float spread = tan(angularVis);
            float invSpread = 1 /(2 * PI * (1-cosTheta));

            varying float eta = (m_shadingCtx->m_EnteringRegion == 1) ?
                                    (mediaIor/ior) : ior/mediaIor;
            
            // Generate stratified samples for refraction
            varying vector randomSamples[];
            randomstrat(0, maxSamplesCount, randomSamples);

            uniform float i,j = 0;
            for(i=begin;i<totalSamples;i+=1) 
            {
                // Distribute refraction samples uniformly across a
                // elliptical cone. To-do: non-uniform specular distribution.
                vector tn = m_shadingCtx->m_Ns;
                tn += (randomSamples[j][0] * 2 - 1) * 
                         m_shadingCtx->m_Tangent * spread + 
                      (randomSamples[j][1] * 2 - 1) * 
                         m_shadingCtx->m_Bitangent * spread;
                tn = normalize(tn);
                j+=1;

                samples[i]->direction = refract(m_shadingCtx->m_In, tn, eta);
                samples[i]->distance = 1e6;
                samples[i]->materialPdf = invSpread;
                samples[i]->materialResponse = m_fres->m_Kt * invSpread 
                                               * m_glassColor;
            }
        }
    }

    public void generateSamples(string type; output __radiancesample samples[];)
    {
        uniform float invSpread = 1e6; 
            // nominal pdf response for the "sharpest" single ray 
        if(type == "specular") 
        {
            reserve(samples, directLightSamples); // generateSamplesAS will resize 
            uniform float ifever = 0;
            varying float nDotI = m_shadingCtx->m_Nn.m_shadingCtx->m_In;
            if(nDotI < 0)
                ifever = 1; // we're at least partly front-facing

            if(nDotI < 0) 
            {
                // I vector is outside of the surface, 
                // generate regular BRDF samples
                m_specular->genSpecularSamps(m_shadingCtx, m_fres, type, 
                                            samples);
            } 
            else 
            {
                // The sample is coming from the inside of the surface
                // we need to sample the light along the refracted direction.

                // If the above code didn't ever run the array 
                // hasn't been resized.
                if(ifever == 0) 
                    resize(samples, directLightSamples);

                uniform float i, n = arraylength(samples);
                for (i=0; i<n;  i+=1)
                {
                    if(m_shadingCtx->m_RayDepth >= internalReflectionLimit &&
                            m_fres->m_Tv == vector(0))
                    {
                        // If we are in a situation of total internal reflection 
                        // and the max internal reflections have been reached,
                        // we need to sample the light sources for direct lighting 
                        // along the same vector as used by reflections. This is
                        // not correct but yields results preferable to "black".
                        samples[i]->direction = normalize(I);
                        samples[i]->distance = M_MAXDIST;
                        samples[i]->materialResponse = 
                                                max(m_fres->m_Kt, m_fres->m_Kr) *
                                                invSpread * m_glassColor;
                        samples[i]->materialPdf = invSpread;
                    }
                    else 
                    {
                        samples[i]->direction = m_fres->m_Tv;
                        samples[i]->distance = M_MAXDIST;
                        samples[i]->materialResponse = m_fres->m_Kt*invSpread 
                                                       * m_glassColor;
                        samples[i]->materialPdf = invSpread;
                    }
                }
            }
        }
        else 
        if(type == "indirectspecular") 
        {
            if(m_shadingCtx->m_RayDepth == 0) 
            {
                // We're on camera rays, sample both reflection and refraction.

                uniform float sampsPerLobe[2];
                reserve(samples, indirectSamples+1);

                m_specularIndirect->genSpecularSamps(m_shadingCtx, m_fres, type, 
                                                     samples);
                sampsPerLobe[0] = arraylength(samples);

                float count = floor(max(1, indirectSamples * m_fres->m_Kt));

				genRefractionSamples(count, samples);
                sampsPerLobe[1] = arraylength(samples) - sampsPerLobe[0];

                normalizeMaterialResponse(samples, sampsPerLobe);
            } 
            else 
            {
                // Path tracing: subsequent samples
                resize(samples, 2);

                // Russian roulette probability, above this value we'll
                // sample both directions, below, we'll pick one.
                float probability = m_fres->m_Kt/rouletteThreshold;
                float randValue = random(); 
                
                // Generate transmission (refraction) ray
                if(m_fres->m_Kt > rouletteThreshold)
                {
                    samples[0]->direction = m_fres->m_Tv;
                    samples[0]->distance = M_MAXDIST;
                    samples[0]->materialResponse = m_fres->m_Kt *
                                                    invSpread * m_glassColor;
                    samples[0]->materialPdf = invSpread;
                }
                else 
                if(probability > randValue)
                {
                    samples[0]->direction = m_fres->m_Tv;
                    samples[0]->distance = M_MAXDIST;
                    samples[0]->materialResponse = rouletteThreshold *  
                        invSpread * m_glassColor;
                    samples[0]->materialPdf = invSpread;
                }
                else
                {
                    samples[0]->direction = vector(0);
                    samples[0]->materialResponse = 0;
                    samples[0]->materialPdf = 0;
                }

                // Generate reflection ray
                if(m_shadingCtx->m_RayDepth < internalReflectionLimit)
                {
                    probability = m_fres->m_Kr/rouletteThreshold;
                    if(m_fres->m_Kr > rouletteThreshold)
                    {
                        uniform float begin = arraylength(samples);
                        samples[1]->direction = m_fres->m_Rv;
                        samples[1]->distance = M_MAXDIST;
                        samples[1]->materialResponse = m_fres->m_Kr *
                                                  invSpread * m_glassColor;
                        samples[1]->materialPdf = invSpread;
                    }
                    else 
                    if(probability > randValue)
                    {
                        uniform float begin = arraylength(samples);
                        samples[1]->direction = m_fres->m_Rv;
                        samples[1]->distance = M_MAXDIST;
                        samples[1]->materialResponse = rouletteThreshold *  
                                                  invSpread * m_glassColor;
                        samples[1]->materialPdf = invSpread;
                    }
                    else
                    {
                        // turn off the sample as it hasn't been
                        // chosen by roulette. Transmisison ray will be
                        // chosen instead
                        samples[1]->direction = vector(0);
                        samples[1]->materialResponse = 0;
                        samples[1]->materialPdf = 0;
                    }
                } 
                else 
                {
                    // Due to internal reflection suppression, we didn't 
                    // generate a reflection ray. To prevent unsampled results
                    // which would be black, we create a substitute ray that
                    // continues on the direction of the ray that sampled this
                    // point. This isn't correct but yields more acceptable 
                    // results.
                    samples[1]->direction = m_shadingCtx->m_In;
                    samples[1]->distance = M_MAXDIST;
                    samples[1]->materialResponse = m_fres->m_Kr * invSpread * 
                                                   m_glassColor;
                    samples[1]->materialPdf = invSpread;
                }
                uniform float sampsPerLobe[2]= {1,1};
                normalizeMaterialResponse(samples, sampsPerLobe);
            }
        }
    }
}
