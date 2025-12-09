declare author "Tarun Nalluri";

import("stdfaust.lib");

gate = button("gate");
gain = hslider("gain", 0.5, 0, 1, 0.01);
freq = environment {
    delta = -0.2;
    vert = hslider("freq", 247, 15, 8000, 0.01);
    horiz = vert+delta;
};

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

pluck = gate : ba.impulsify : nCycleSine(1/2,freq.vert) *(g + (1 - g)*gain)
with {
    g = hslider("[hidden:1]Minimum Gain",0.5,0,1,0.01);
};

process = gate : countdownOnTrigger(1);