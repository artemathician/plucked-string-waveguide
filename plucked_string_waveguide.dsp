declare author "Tarun Nalluri";

import("stdfaust.lib");

gate = button("gate");

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

process = gate : countdownOnTrigger(1);