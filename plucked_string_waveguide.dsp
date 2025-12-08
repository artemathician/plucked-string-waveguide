declare author "Tarun Nalluri";

import("stdfaust.lib");

gate = button("gate");

// 0->1 trigger starts countdown from n to 0, lasting for 1/freq seconds.
countdownOnTrigger(freq, trigger) = select2((trigger-trigger') < 1, 
                                            ma.SR/freq, max(0, _-1)) ~ _;

// Rectangular window initiated upon 0->1 trigger, lasting for 1/freq seconds.
windowOnTrigger(freq, trigger) = countdownOnTrigger(freq, trigger) > 0;

// Ramping signal that resets to 0 upon 0->1 trigger. 
rampOnTrigger(freq, trigger) = _*((trigger-trigger') < 1) + (ma.T*freq) ~ _;

// Upon 0->1 trigger, outputs 0 to 1 ramp that lasts 1/freq seconds. 
// Otherwise outputs 0. 
oneCyclePhasor(freq, trigger) = rampOnTrigger(freq, trigger)
                                * windowOnTrigger(freq, trigger);

// Generates n (float) periods of a sine wave upon 0->1 trigger.
nCycleSine(n, freq, trigger) = 2*n*ma.PI*oneCyclePhasor(freq, trigger) : sin;

process = gate : oneCyclePhasor(1);