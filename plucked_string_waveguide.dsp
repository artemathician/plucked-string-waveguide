declare author "Tarun Nalluri";

import("stdfaust.lib");

gate = button("gate");
gain = hslider("gain", 0.5, 0, 1, 0.01);

// Frequencies of vertical and horizontal polarization of string vibration.
freq = environment {
    vert = hslider("freq", 247, 15, 8000, 0.01);
    horiz = vert + delta;
    delta = -0.2;
};

omega = environment {
    vert = 2 *ma.PI *freq.vert;
    horiz = 2 *ma.PI *freq.horiz;
};

// Maps a linear [0,1] signal to an exponential [0,1] signal
exponential(a,zeroToOne) = (a^(zeroToOne)-1)/(a-1);



// ===========================================================================
//
// Pluck Functions
//
// ===========================================================================

// 0->1 trigger starts countdown from n to 0, lasting for 1/freq seconds.
countdownOnTrigger(freq, trigger) = max(0, decrementer) ~ _
with {
    decrementer = _ + ma.SR/freq*((trigger-trigger') > 0) 
                  - 1*((trigger-trigger') < 1);
};

// 0->1 trigger starts rectangular window, lasting for 1/freq seconds.
windowOnTrigger(freq, trigger) = countdownOnTrigger(freq, trigger) > 0;

// Ramping signal that resets to 0 upon 0->1 trigger. 
rampOnTrigger(freq, trigger) = _*((trigger-trigger') < 1) + (ma.T*freq) ~ _;

// 0->1 trigger starts 0 to 1 ramp that lasts 1/freq seconds. 
// Otherwise outputs 0. 
oneCyclePhasor(freq, trigger) = rampOnTrigger(freq, trigger)
                                *windowOnTrigger(freq, trigger);

// 0->1 trigger generates n (float) periods of a sine wave. Otherwise outputs 0.
nCycleSine(n, freq, trigger) = 2*n*ma.PI*oneCyclePhasor(freq, trigger) : sin;

// Half period sine wave pluck with a minimum gain of 0.5 and maximum gain of 1.
pluckSmooth = gate : ba.impulsify : nCycleSine(1/2, freq.vert) :
              *(g + (1 - g)*gain)
with {
    g = hslider("[hidden:1]Minimum Gain", 0.5, 0, 1, 0.01);
};

// Makes input noisy, correlated directly with gain (i.e. key/pluck velocity)
noisify = _ <: _*(1 - g*ph), _*noise*g*ph : +
with {
    g = gain;
    ph = hslider("[1]Pluck Dynamics", 0.75, 0, 1, 0.01);
    noise = (no.noise : fi.highpass(1, freq.vert) 
        : fi.lowpass(1, freq.vert*100*ph : min(20000) 
        : max(freq.vert)))*0.5 + 1 : _/1.5;
};

// Pluck whose 'noisiness' correlates directly with gain (i.e. key velocity) 
pluckNoisy = pluckSmooth : noisify *(1/60);

pluckPosition = hslider("[2]Pluck Position", 0.21, 0, 1, 0.01);



// ===========================================================================
//
// String Parameters and Variables
//
// ===========================================================================
// For all parameters: sm = 'small', lg = 'large', def = 'default'. Default
// values are provided by Trautmann et al. for a nylon B guitar string.

area = environment {// Cross sectional area, units = mm^2
    sm = 0.1;
    lg = 2;
    def = 0.5188;
};

density = environment {// Mass density, units = kg/(mm^3)
    def = 1140*(10^(-9));
};

moment = environment {// Units = mm^4
    def = 0.171;
};

modulus = environment {// Units = kg/(mm s^2)
    def = 5.4*(10^6);
};

tension = environment {// Units = (kg mm)/(s^2)
    sm = 15*(10^3);
    lg = 10000*(10^3);
    def = 60.97*(10^3);
    range = lg-sm;
    slider = hslider("[4]String Tension",0.5,0,1,0.0001) : exponential(125);
    var = slider*range + sm;
};

d1 = environment {// Frequency INdependent damping, units = kg/(m s)
    sm = 4*(10^(-7));
    lg = 32*(10^(-6));
    def = 8*(10^(-10));
    range = lg-sm;
    slider = hslider("[3]String Damping",0.15,0,1,0.0001) : exponential(125);
    // Use (target-s)/r to calculate def slider value to target
    var = slider*range + sm;
    };

d3 = environment {// Frequency DEpendent damping, units = (kg mm)/s
    def = -6.4*(10^(-3));
};

length = environment {// Units = mm
    sm = 10;
    lg = 10*1000; // 10m
    def = 650;
    var = environment {
        vert = sqrt(tension.var / (density.def * area.def))
               /(2*freq.vert);

        horiz = sqrt(tension.var / (density.def * area.def))
                /(2*freq.horiz);
        };
};



// ===========================================================================
//
// Delay Functions for Digital Waveguides
//
// ===========================================================================

delayVert = environment {
    length = ma.SR/freq.vert;

    // Length of string is split into two parts, where split location
    // corresponds to pluckPosition
    one = delayFilter(length * (1-position));
    two = delayFilter(length * position - 1);
};

delayHoriz = environment {
    length = ma.SR/freq.horiz;

    // Length of string is split into two parts, where split location
    // corresponds to pluckPosition
    one = delayFilter(length * (1-position));
    two = delayFilter(length * position - 1);
};



// ===========================================================================
//
// String Loss Filters
//
// ===========================================================================

// Filters away losses from vertical string polarization
lossFilterV = _ <: _*a, _ :> _*g : + ~(_*(-a))
with {
    c = (density.def * area.def)
        *length.var.vert^2
        *omega.vert^3
        *ma.T^2
        /(4*(ma.PI^3) * d3.def);

    a = -1 + c + sqrt(c^2 - 2*c);

    g = 1 - 
        (ma.PI * d1.var
        /(density.def * area.def)
        /omega.vert);
};

// Filters away losses from horizontal string polarization
lossFilterH = _ <: _*a, _ :> _*g : + ~(_*(-a))
with {
    c = (density.def * area.def)
        *length.var.horiz^2
        *omega.horiz^3
        *ma.T^2
        /(4*(ma.PI^3) * d3.def);

    a = -1 + c + sqrt(c^2 - 2*c);

    g = 1 - 
        (ma.PI * d1.var
        /(density.def * area.def)
        /omega.horiz);
};



// ===========================================================================
//
// Digital Waveguides for Two Planes of Vibration
//
// ===========================================================================

waveguideVert(in) = ((in/2, (_*(-fb) : lossFilterV) : + : 
                    delayVert.one), _)
                    ~ ((in/2,(_*(-fb)) : + : delayVert.two) <: _,_) : +
with {
    fb = 1;
};

waveguideHoriz(in) = ((in/2, (_*(-fb) : lossFilterH) : + : 
                    delayHoriz.one), _)
                    ~ ((in/2,(_*(-fb)) : + : delayHoriz.two) <: _,_) : +
with {
    fb = 1;
};



finalGain = hslider("Output Gain", 0.5, 0, 1, 0.01) *60;

process = pluckNoisy : _*finalGain <: _,_;