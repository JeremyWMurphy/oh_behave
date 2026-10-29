function[sesh] = find_piezo_onsets_np(sesh,piezo_chan,iti_min,method,piezo_ixs_to_peak)

% find piezo stims in ni data and align to ephys

Fs = sesh.Fs;

piezo_data = sesh.ni_data_map.Data.aio(piezo_chan,:);
piezo_data = double(piezo_data).* sesh.ni_bit_volts;

piezo_data = detrend(piezo_data);
piezo_data = piezo_data-min(piezo_data);

switch method
    case 'sharp'
%% this works for square type waves, but will likely not get the leading edge of a slower ramp
% binarize, this thresholding seems to work, but double check, may not work
% for some stimulus types
piezo_crop = piezo_data;
thresh = prctile(piezo_crop,75)+3*iqr(piezo_crop); 
piezo_crop(piezo_crop<=thresh) = 0;
piezo_crop(piezo_crop>thresh) = 1;


[~,stim_onsets] = findpeaks(diff(piezo_crop),'minpeakdistance',Fs*iti_min);
clear piezo_crop

    case 'smooth'

        piezo_crop = piezo_data;
        % has to be at least min ITI apart and have an amplitude >10% of
        % the max amplitude
        [~,stim_peaks] = findpeaks(piezo_crop,'minpeakdistance',Fs*iti_min,'minpeakheight',max(piezo_crop)*0.1);
        stim_onsets = stim_peaks - piezo_ixs_to_peak;

end
% the ni and np timestamps are synced but the data itself is not
% one-to-one, so we have to find the nearest np timestamp 
%  to the ni piezo timestamp
ni_stim_times = sesh.ni_time(stim_onsets);
np_piezo_ixs = nan(numel(ni_stim_times),1);
np_piezo_df = nan(numel(ni_stim_times),1);
for i = 1:numel(ni_stim_times)
    [v,mn] = min(abs(ni_stim_times(i)-sesh.np_time));
    np_piezo_ixs(i) = mn;
    np_piezo_df(i) = v; % actual difference, should be really small
end

t = 1/Fs:1/Fs:size(piezo_data,2)/Fs;
figure,
subplot(2,2,[1 2]), hold on
plot(t,piezo_data)
plot(t(stim_onsets),piezo_data(stim_onsets),'og')
xlabel('Time(Sec)')
ylabel('V')
title('Piezo stim alignment outcome')
legend('piezo data','stim onsets')

subplot(2,2,3), hold on
win = -Fs:Fs;
p_epochs = nan(numel(win),numel(stim_onsets));
for i = 1:numel(stim_onsets)
    p_epochs(:,i) = piezo_data(stim_onsets(i)+win);
end

imagesc(win/Fs,1:numel(stim_onsets),p_epochs')
colormap(turbo)
xlim([-0.1 0.1])
title('All stim windows')
xlabel('Time(Sec)')
ylabel('Trial')

subplot(2,2,4), hold on
plot(win/Fs,p_epochs)
xlim([-0.1 0.1])

sesh.piezo_ixs = np_piezo_ixs;
sesh.ni_piezo_ixs = stim_onsets;

