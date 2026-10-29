function[sesh] = epoch_beta(sesh,ep_win,decimate_by)

Fs = sesh.Fs;
np_data_len = size(sesh.np_data_map.Data.ephys,2);

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
        rmss(i,j) = std(detrend(double(tmp)));
    end
end

rms_median = log10(median(rmss,2));

hi = prctile(rms_median,75)+1.5*iqr(rms_median);
lo = prctile(rms_median,25)-1.5*iqr(rms_median);

bcs = find(rms_median<lo|rms_median>hi);

fprintf('\nThe following channels were marked as bad:\n\n')
disp(bcs)

sesh.bad_channels = bcs;
sesh.rmss = median(rmss,2); 

%% epoch the data

win = ep_win(1)*Fs:ep_win(2)*Fs;
win_shorter = -0.075*Fs:0.075*Fs; % for finding beta peak
win_shorter_center = find((win_shorter==0));
t_long = 1/Fs:1/Fs:np_data_len/Fs;
t = downsample(win./Fs,decimate_by);

L = round(Fs*gauss_win_len);
if mod(L,2) == 0
    L = L + 1;
end
w = gausswin(L);
w = w./sum(w);
grp_delay = median(grpdelay(w,1));

sesh.spk_eps = nan(numel(t),sesh.np_num_chans,size(sesh.event_times,1));
sesh.lfp_eps = nan(numel(t),sesh.np_num_chans,size(sesh.event_times,1));
sesh.wave_eps = nan(numel(t),size(sesh.event_times,1));
sesh.unit_eps = nan(numel(t),size(sesh.sorting.good_ids,1),size(sesh.event_times,1));

sesh.bad_trials = [];

figure,
subplot(1,2,1), hold on
subplot(1,2,2), hold on
offset = 8;

beta_dat = mean(double(sesh.np_data_map.Data.ephys(sesh.beta_channels,:))'.*sesh.np_bit_volts,2);
beta_dat = zscore(beta_dat);
beta_dat = smoothdata(beta_dat,1,'movmean',[Fs*0.002 Fs*0.002]);

new_event_ixs = nan(size(sesh.event_times));

for i = 1:size(sesh.event_times,1)

    fprintf(['\n -> Epoching event ' num2str(i) ' of ' num2str(size(sesh.event_times,1))])
    
    [~,event_ix] = min(abs(t_long-sesh.event_times(i)));

    if any(event_ix+win<0) || any(event_ix+win>np_data_len)
        sesh.bad_trials = cat(1,sesh.bad_trials,i);
        continue
    else
                  
        beta_tmp = detrend(beta_dat(event_ix+win_shorter),0);
        subplot(1,2,1)

        
        switch sesh.align_by
            case 'max'
                [~,pk_ix] = max(beta_tmp);
            case 'min'
                [~,pk_ix] = min(beta_tmp);
            case 'absmax'
                [~,pk_ix] = max(abs(beta_tmp));
        end

        new_event_ix =  event_ix - (win_shorter_center - pk_ix);  
        new_event_ixs(i) = new_event_ix; 
        
        beta_tmp = beta_dat(new_event_ix+win);      
        sesh.wave_eps(:,i) = decimate(beta_tmp,decimate_by);
        plot(t,sesh.wave_eps(:,i)+offset,'m');

        dat = double(sesh.np_data_map.Data.ephys(:,new_event_ix+win))'.*sesh.np_bit_volts;
        for j = 1:size(dat,2)
            sesh.lfp_eps(:,j,i) = decimate(dat(:,j),decimate_by)';
        end

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
        dat = [dat;zeros(grp_delay,sesh.np_num_chans)];
        spk = abs(hilbert(dat));
        spk = filter(w,1,spk);
        spk = spk(grp_delay+1:end,:);
        % downsample
        for j = 1:size(spk,2)
            sesh.spk_eps(:,j,i) = decimate(spk(:,j),decimate_by);
        end

        % for all units
        for j = 1:size(sesh.sorting.good_ids,1)
            tmp_ixs = sesh.sorting.good_wave_idxs{j};
            dat = ismember(new_event_ix+win,tmp_ixs)';
            dat = [dat;zeros(grp_delay,1)];
            spk = abs(hilbert(dat));
            spk = filter(w,1,spk);
            spk = spk(grp_delay+1:end,:);
            spk = decimate(spk,decimate_by);
            sesh.unit_eps(:,j,i) = spk;
        end
            

    end
end

    

    


 


