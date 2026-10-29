function[pow_spec,spec_events,t] = find_beta_events_np(d,Fs,f,n_cycles)

d = d';
[w] = wavelet_bank_jm(size(d,1),Fs,f,n_cycles*ones(size(f)));
verbose = true;
[pow_spec] = wavelet_conv_jm(d,w,Fs,verbose);
pow_spec = pow_spec';

t = 1/Fs:1/Fs:size(pow_spec,2)/Fs;

method = 3;
f_band = [14 29];

thresh = 10;

spec_events = spectralevents_find(method,f_band,thresh,t,1:60, ...
    pow_spec,1);



