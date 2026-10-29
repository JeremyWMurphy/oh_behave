function [] = read_in_spike_interface()

pyenv('Version', '/Users/jeremy/Documents/python_environments/spikeInterface/bin/python')

pth = '/Users/jeremy/Desktop/spikeinterface-results/run1/';
pth_out = '/Users/jeremy/Desktop/gpr26_161_ephys/20260914/run1_spike_sorting.mat';

k4_files = glob(fullfile(pth,'kilosort4','sorter_output','**','*.npy'));
sort_analyzer_files = glob(fullfile(pth,'sorting_analyzer','**','*npy'));
bomb_cell = glob(fullfile(pth,'**','bombcell*'));
bombcell_labels = read_npy_jm(bomb_cell{1});

template_info = glob(fullfile(pth,'**','/template_metrics/','metrics.csv'));
template_metrics = readtable(template_info{1});

quality_info = glob(fullfile(pth,'**','/quality_metrics/','metrics.csv'));
quality_metrics = readtable(quality_info{1});


k4_data = struct();
for i = 1:numel(k4_files)
   
   [mat_data] = read_npy_jm(k4_files{i});
    nm = split(k4_files{i},'/');
    nm = nm{end}(1:end-4);
    k4_data.(nm) = mat_data;

end

si_data = struct();
for i = 1:numel(sort_analyzer_files)

    [mat_data] = read_npy_jm(sort_analyzer_files{i});
    nm = split(sort_analyzer_files{i},'/');
    nm = nm{end}(1:end-4);
    si_data.(nm) = mat_data;

end

%%

good_ids = [];
good_chans = [];
good_waves = [];
good_wave_idxs = {};
pk_tr_dur = [];
for i = 1:numel(si_data.KSLabel)

    if strcmp(si_data.KSLabel{i},'good')
        good_ids = [good_ids;i];
        chan = split(string(si_data.main_channel_id{i}),'CH');
        chan = str2num(chan(2,:));
        good_chans = [good_chans; chan];
        good_waves = cat(1,good_waves,squeeze(si_data.average(i,:,chan)));
        good_wave_idxs = cat(2,good_wave_idxs,double(k4_data.spike_times(k4_data.spike_clusters==i-1))); % the kilosort output is 0 indexed
        pk_tr_dur = [pk_tr_dur;template_metrics.peak_to_trough_duration(i)];
    end

end

good_waves = good_waves-mean(good_waves,2);

save(pth_out,'good_ids','good_waves','good_chans','good_wave_idxs','pk_tr_dur')





