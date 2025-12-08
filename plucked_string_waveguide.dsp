declare author "Tarun Nalluri";

import("stdfaust.lib");

gate = button("gate");

// Change in trigger signal from 0 to 1 starts countdown from n to 0,
// where the countdown lasts for 1/freq seconds.
countdownOnTrigger(freq, trigger) = select2((trigger-trigger') < 1, 
                                            ma.SR/freq, max(0, _-1)) ~ _;

// Rectangular window initiated when trigger signal changes from 0 to 1,
// and lasts for 1/freq seconds.
windowOnTrigger(freq, trigger) = countdownOnTrigger(freq, trigger) > 0;

// Ramping signal generator that resets to zero whenever trigger signal 
// changes from 0 to 1. 
rampOnTrigger(freq, trigger) = _*((trigger-trigger') < 1) + (ma.T*freq) ~ _;

process = gate : windowOnTrigger(1);