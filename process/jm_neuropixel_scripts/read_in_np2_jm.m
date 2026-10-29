function[sesh] = read_in_np2_jm(pth,run)

% path two recording folders, e.g., top_path = '/Users/jeremy/Desktop/gpr26_158_ephys/20260916/';
% which run to do, assumes the recording folders start with 'runN',e.g., 'run1', run = 3;

% this is the full path to the recording folder
ephys_folder = cell2mat(glob(fullfile(pth,['run' num2str(run) '*'])));

% this is the full path to get the metadata
info_fl = glob(fullfile(ephys_folder,'/Rec*/exp*/rec*/structure.oebin'));
sesh.info = jsondecode(fileread(info_fl{1}));

sesh.Fs = sesh.info.continuous(2).sample_rate;

% this is the full path to actually pull the raw binary data
ephys_path = glob(fullfile(ephys_folder,'Rec*','exp*', 'rec*'));
ephys_path = cell2mat(ephys_path);

np_path = cell2mat(glob(fullfile(ephys_path,'\con*\Neuro*'))); % for neuropixel data
ni_path = cell2mat(glob(fullfile(ephys_path,'\con*\NI*'))); % for national instruments analog data

% NP data and info
sesh.np_data_map = memmapfile(fullfile(np_path, 'continuous.dat'),'Format','int16');
sesh.np_num_chans = sesh.info.continuous(2).num_channels;
data_len = length(sesh.np_data_map.Data);
sesh.np_data_map = memmapfile(fullfile(np_path, 'continuous.dat'),'Format',{'int16',[sesh.np_num_chans data_len/sesh.np_num_chans],'ephys'});
sesh.np_time = readNPY([np_path 'timestamps.npy']);

% NI data and info
sesh.ni_data_map = memmapfile(fullfile(ni_path, 'continuous.dat'),'Format','int16');
sesh.ni_num_chans = sesh.info.continuous(1).num_channels;
data_len = length(sesh.ni_data_map.Data);
sesh.ni_data_map = memmapfile(fullfile(ni_path, 'continuous.dat'),'Format',{'int16',[sesh.ni_num_chans data_len/sesh.ni_num_chans],'aio'});
sesh.ni_time = readNPY([ni_path 'timestamps.npy']);

% these are mapping the ephys to microvolts and the ni analog inputs to volts
sesh.np_bit_volts = sesh.info.continuous(2).channels.bit_volts;
sesh.ni_bit_volts = sesh.info.continuous(1).channels.bit_volts;
