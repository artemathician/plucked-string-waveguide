declare author "Tarun Nalluri";

import("stdfaust.lib");

gate = button("gate");

countdownOnTrigger(freq, trigger) = select2((trigger-trigger') < 1, 
                                            ma.SR/freq, max(0, _-1)) ~ _;

process = gate : countdownOnTrigger(1);