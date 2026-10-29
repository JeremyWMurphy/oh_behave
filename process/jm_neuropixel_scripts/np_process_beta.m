
pth = '/Users/jeremy/Desktop/gpr26_161_ephys/20260914/';
run = 1;
sesh = read_in_np2_jm(pth,run);

%% l4 sink channels

l4_sink_run = 3;

sink_run = glob(fullfile(pth, ['run' num2str(l4_sink_run) '*'],'*_data_processed.mat'));
s = load(sink_run{1})
beta_channels = [s.sesh.l4_elecs-2 s.sesh.l4_elecs s.sesh.l4_elecs+2];
clear s

%% unit data

sort_fl = glob(fullfile(pth,['*' num2str(run) '*'],'*spik*'));
sorting = load(sort_fl{1});
sesh.sorting = sorting;

%%

% get data
sesh = read_in_np2_jm(pth,run);

% make l4 lfp to find events
d = mean(sesh.np_data_map.Data.ephys(beta_channels,:),1);

r = 60;
d = decimate(d,r);
Fs = sesh.Fs/r;
t = 1/Fs:1/Fs:numel(d)/Fs;

d = zscore(d);
sesh.beta_channels = beta_channels;


%% wavelet tfr

d = d';

n_cycles = 8;

f = 1:60;

[w] = wavelet_bank_jm(size(d,1),Fs,f,n_cycles*ones(size(f)));
verbose = true;
[pow_spec] = wavelet_conv_jm(d,w,Fs,verbose);
pow_spec = pow_spec';

d = d';

%%
figure,subplot(2,2,[1 2])
imagesc(t,f,pow_spec./median(pow_spec,2))
axis xy
colormap(turbo)

subplot(2,2,3)
plot(f,10*log10(sum(pow_spec,2)))

subplot(2,2,4)
plot(f,10*log10(sum(pow_spec./median(pow_spec,2),2)))

sesh.pow_spec = pow_spec;
sesh.f = f;

%% find events

method = 2;
f_band = [14 29];
thresh = 8;
spec_events = spectralevents_find(method,f_band,thresh,t,f,pow_spec,1);

sesh.spec_events = spec_events;

event_times = spec_events.Events.Events.maximatiming;

event_fmax = spec_events.Events.Events.maximafreq;
event_pmax = spec_events.Events.Events.maximapower;
event_pmax_norm = spec_events.Events.Events.maximapowerFOM;
event_fspan = spec_events.Events.Events.Fspan;

%%

figure

subplot(2,3,1)
[n,g] = groupcounts(round(event_times));
bar(g,n,'EdgeColor','None','FaceColor','c')
title('Events/Sec')

subplot(2,3,2)
[n,g] = groupcounts(event_fmax);
bar(g,n,'EdgeColor','None','FaceColor','c')
title('Peak F')

subplot(2,3,3)
[n,g] = groupcounts(event_fspan);
bar(g,n,'EdgeColor','None','FaceColor','c')
title('F Span')

subplot(2,3,4)
scatter(event_fmax,event_pmax,'Marker','o','MarkerEdgeColor','None','MarkerFaceColor','m','MarkerFaceAlpha',0.5)
title('Frequency x Power')

subplot(2,3,5)
scatter(event_times,event_fmax,'Marker','o','MarkerEdgeColor','None','MarkerFaceColor','m','MarkerFaceAlpha',0.5)
title('Time x Frequency')

subplot(2,3,6)
scatter(event_fmax,event_fspan,'Marker','o','MarkerEdgeColor','None','MarkerFaceColor','m','MarkerFaceAlpha',0.5)
xlabel('Frequency')
ylabel('F Span')
title('Frequency x F Span')


%% epoch events 

event_times_sub = event_times(event_fmax>=14&event_fmax<=29); 

sesh.event_times = event_times_sub;

sesh.ep_win = [-0.2 0.2];
sesh.align_by = 'max'; % min,max,absmax
[sesh] = epoch_beta(sesh,sesh.ep_win,r);

%%

good_trials = 1:size(sesh.wave_eps,2);
good_trials(sesh.bad_trials) = [];

w = sesh.wave_eps(:,good_trials);

w = w';
[L] = cluster_beta(w,Fs);

%% show lfp and mua

grps = [1 2 3];

t = sesh.ep_win(1):1/Fs:sesh.ep_win(2);

trl_ixs = ismember(L,grps);

lfp_waves = sesh.lfp_eps(:,:,good_trials);
lfp_waves = lfp_waves(:,:,trl_ixs);


lfp_waves = lfp_waves - mean(lfp_waves,1);
lfp_wave = mean(lfp_waves,3);
lfp_wave(:,sesh.bad_channels) = NaN;
lfp_wave = fillmissing(lfp_wave','spline');

figure, subplot(1,2,1), hold on
imagesc(t,1:size(lfp_waves,2),lfp_wave)
colormap turbo

% plot mua

% estimate noise floor so division by near zero value doesn't cause
% problems when I normalize psths
spks = sesh.spk_eps(:,:,trl_ixs);
fuzzfactor = 0.01 * median(std(spks,0,1,'omitnan'));
spk_bs = mean(spks,1)+fuzzfactor;
spk_eps_bs = (spks-spk_bs)./spk_bs;
spk_mu = mean(spk_eps_bs,3,'omitnan');
subplot(1,2,2), hold on
imagesc(t,1:size(spk_mu,2),spk_mu')
%line([0 0],ylim,'Color','w','LineWidth',2)
axis xy
colormap turbo
xlabel('Time (Sec)')
ylabel('Channels organized by ascending depth')
title('Mean MUA')
clim([0 0.05])


%% traditional csd with smoothing

chan_spacing = 15e-6; % channel spacing in meters

% Average the columns together
lfp_1d = (lfp_wave(1:2:end,:)+lfp_wave(2:2:end,:))/2;

[csd] = csd_simple_jm(lfp_1d',15e-6);

gauss_spatial_length = 12; % width of gaussian for smoothing 

csd_smooth = smoothdata(csd,2,'gauss',gauss_spatial_length);

figure
imagesc(t,1:size(csd_smooth,2),csd_smooth')
axis xy
clim([-8e8 8e8])
colormap jet

xlabel('Time (Sec)')
ylabel('Channels organized by ascending depth')
title('Mean Traditional CSD with smoothing')

%%
dz = 15e-6;
R = 500e-6;
sigma = 0.3;

[csd, z_coords] = compute_icsd_delta_np2(lfp_1d, dz, R, sigma,1);

figure
imagesc(t,z_coords.*1e6,csd)
%imagesc(t,1:size(csd,1),csd)
axis xy
colormap jet
xlabel('Time (Sec)')
ylabel('Channels organized by ascending depth')
title('delta icsd')

%%

tmp = squeeze(mean(sesh.unit_eps,3));