% 1. Initialization Parameters
Fs = 44100;                 % Sampling frequency (Hz)
Duration = 5.0;             % Total signal duration (seconds)
t = 0:1/Fs:Duration-1/Fs;   % Time vector
fc = 1500;                  % Target coherent tone frequency (Hz)
A = 1;                    % Strict constant amplitude wrapper
% 2. Define the Coherence Window (Momentary Event)
% The signal will become coherent between 2.0 and 3.0 seconds
coherence_start = 2.0; 
coherence_end = 2.5;
transition_width = 0.01;    % Smoothness of the transition window (seconds)
% Create smooth transition gates using hyperbolic tangents
gate_on = 0.5 * (1 + tanh((t - coherence_start) / transition_width));
gate_off = 0.5 * (1 + tanh((coherence_end - t) / transition_width));
coherence_gate = gate_on .* gate_off; % 0 = Noise, 1 = Coherent Tone
% 3. Generate Instantaneous Frequency Vector
% When gate is 0, frequency jitters randomly. When 1, jitter is crushed to 0.
noise_bandwidth = 5000;      % Width of the noise state in Hz
frequency_jitter = (rand(size(t)) - 0.5) * noise_bandwidth; 
inst_freq = fc + (frequency_jitter .* (1 - coherence_gate));
% 4. Phase Accumulation (Crucial step to prevent phase steps/clicks)
% We integrate the instantaneous frequency to compute continuous phase
inst_phase = 2 * pi * cumsum(inst_freq) / Fs;
% 5. Synthesize Constant-Amplitude Signal
signal = A * sin(inst_phase);
sound(signal,Fs)