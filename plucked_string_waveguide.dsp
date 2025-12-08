declare author "Tarun Nalluri";

import("stdfaust.lib");

gate = button("gate");

// Change in trigger signal from 0 to 1 starts countdown from n to 0,
// where the countdown lasts for 1/freq seconds.
countdownOnTrigger(freq, trigger) = select2((trigger-trigger') < 1, 
                                            ma.SR/freq, max(0, _-1)) ~ _;

process = gate : countdownOnTrigger(1);