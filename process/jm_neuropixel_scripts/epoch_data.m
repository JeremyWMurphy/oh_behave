function[sesh] = epoch_data(sesh,ep_win,decimate_by)

Fs = sesh.Fs;
np_data_len = size(sesh.np_data_map.Data.ephys,2);
stim_onsets = sesh.piezo_ixs;
ni_stim_onsets = sesh.ni_piezo_ixs';

% for rms estimates to find bad channels
n_samples = 25; % N snippets
sample_len = 1; % length of snippets in seconds

gauss_win_len = 0.02; % length in seconds of gaussian for smoothing the PSTHs

epsilon = 1e-5;%   epsilon - (Optional) Regularization parameter to stabilize the matrix inversion for dead/quiet channels

%% bad channel detection - in the NP data these are largely flat channels, I haven't really seen crazy noisy channels yet
% don't want to read in all the data, so we'll take a series of random
% snippets 

rmss = nan(sesh.np_num_chans,n_samples);
idxs = randi(floor(np_data_len/Fs),n_samples,1);
for i = 1:sesh.np_num_chans
    fprintf(['\nEstimating RMS of channel ' num2str(i)])
    for j = 1:n_samples
        tmp = sesh.np_data_map.Data.ephys(i,idxs(j):(idxs(j)+Fs*sample_len));
        rmss(i,j) = rms(detrend(double(tmp)));
    end
end

rms_median = median(rmss,2);
bcs = find(isoutlier(rms_median));

fprintf('\nThe following channels were marked as bad:\n\n')
disp(bcs)

sesh.bad_channels = bcs;

%% epoch the data

win = ep_win(1)*Fs:ep_win(2)*Fs;
t_long = win./Fs;
t = downsample(t_long,decimate_by);

L = round(Fs*gauss_win_len);
if mod(L,2) == 0
    L = L + 1;
end
w = gausswin(L);
w = w./sum(w);
grp_delay = median(grpdelay(w,1));

sesh.spk_eps = nan(numel(t),sesh.np_num_chans,numel(stim_onsets));
sesh.lfp_eps = nan(numel(t),sesh.np_num_chans,numel(stim_onsets));
sesh.piezo_eps = nan(numel(t_long),numel(stim_onsets));

for i = 1:numel(stim_onsets)

    fprintf(['\n -> Epoching trial ' num2str(i) ' of ' num2str(numel(stim_onsets))])
    
    if any(stim_onsets(i)+win<0) || any(stim_onsets(i)+win>np_data_len)
        bts = cat(1,bts,i);
        continue
    else

        sesh.piezo_eps(:,i) = double(sesh.ni_data_map.Data.aio(sesh.piezo_chan,ni_stim_onsets(i)+win).*sesh.ni_bit_volts);
                 
        dat = double(sesh.np_data_map.Data.ephys(:,stim_onsets(i)+win))'.*sesh.np_bit_volts;                    

        % --- MUA ----
        fprintf('\nGetting MUA for trial')
        dat(:,bcs) = NaN;
        % interpolate bad channels for spiking data
        dat = fillmissing(dat','spline')';
        dat2 = dat; % save copy for lfp

        % highpass
        [B,A] = butter(3,500/(Fs/2),'High');
        dat = filtfilt(B,A,dat);
      
        % moving common median reference, e.g., 20 - use a windows
        % of 20 nearest channels to do CAR
        dat = moving_car(dat,20);
               
        % whiten the data
        dat = dat-mean(dat,1); % zero mean        
        % spatial covariance matrix (N x N)                        
        cv = (dat' * dat) / (size(dat,2) - 1);
        [v, d] = eig(cv);      
        d_diag = diag(d);
        d_inv_sqrt = diag(1 ./ sqrt(d_diag + epsilon));
        % compute whitening Matrix (V * D^(-1/2) * V')        
        wm = v * d_inv_sqrt * v';
        % apply the transformation to data
        dat = dat * wm;

        % estimate PSTH using hilbert and then smoothing       
        spk = abs(hilbert(dat));
        spk = [spk; zeros(grp_delay,size(spk,2))];  
        spk = filter(w,1,spk);
        spk = spk(grp_delay+1:end,:);
        % downsample
        for j = 1:size(spk,2)
            sesh.spk_eps(:,j,i) = decimate(spk(:,j),decimate_by);
        end

        % --- LFP ---
        %fprintf('\nGetting LFP for trial')
        %[B,A] = butter(3,0.1/(Fs/2),'High');
        %dat2 = filtfilt(B,A,dat2);
        %[B,A] = butter(3,100/(Fs/2),'Low');
        %dat2 = filtfilt(B,A,dat2);

        dat2 = dat2-dat2(:,end); % reref to top channel, which is just sitting in saline above the brain
        
        % downsample
        for j = 1:size(dat2,2)
            sesh.lfp_eps(:,j,i) = decimate(dat2(:,j),decimate_by);
        end

    end
end

sesh.t = t;
sesh.t_piezo = t_long;
