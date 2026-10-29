function[sesh] = find_piezo_onsets(sesh,piezo_chan,iti_min,method,piezo_len)

% find piezo stims in ni data and align to ephys

Fs = sesh.Fs;


piezo_data = sesh.ni_data_map.Data.aio(piezo_chan,:);
piezo_data = double(piezo_data).*sesh.ni_bit_volts;

piezo_data = detrend(piezo_data);
piezo_data = piezo_data-min(piezo_data);

switch method
    case 'sharp'
        %% this works for square type waves, but will likely not get the leading edge of a slower ramp
        % binarize, this thresholding seems to work, but double check, may not work
        % for some stimulus types

        piezo_crop = smoothdata(piezo_data,2,'movmedian',Fs*0.001);
        thresh = prctile(piezo_crop,75)+3*iqr(piezo_crop);
        piezo_crop(piezo_crop>thresh) = 1;
        piezo_crop(piezo_crop<=thresh) = 0;

        [~,stim_onsets] = findpeaks(diff(piezo_crop),'minpeakdistance',Fs*iti_min);
        [~,stim_offsets] = findpeaks(-1*diff(piezo_crop),'minpeakdistance',Fs*iti_min);
        stim_lens = stim_offsets-stim_onsets;

        stim_diff = Fs*piezo_len-median(stim_lens);
        missing_edge = round(stim_diff/2);

        stim_onsets = stim_onsets - missing_edge;
  

    case 'smooth'

        piezo_crop = piezo_data;
        % has to be at least min ITI apart and have an amplitude >10% of
        % the max amplitude
        [~,stim_peaks] = findpeaks(piezo_crop,'minpeakdistance',Fs*iti_min,'minpeakheight',max(piezo_crop)*0.05);
        stim_onsets = stim_peaks - round(sesh.Fs*piezo_len/2); %! this only works if the stim is symmetric

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

sesh.np_piezo_ixs = stim_onsets;

