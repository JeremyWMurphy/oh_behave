function[sink_chan,peak_sink_depth] = find_early_sink(CSD,time,depth_mm,src_grid)

% --- Automated Earliest Evoked Sink Extraction ---
% Inputs: 
%   - CSD_publication_units: your [Num_Depths x Timepoints] matrix
%   - time in sec
%   - depth_mm: the probe depth vector (µm)

% 1. Define your post-stimulus search window (adjust based on your paradigm)
search_window = [0 0.030]; % Search for the initial input between 0 and 50 ms

% Find the matrix column indices that fall within this time window
search_time_idx = find(time >= search_window(1) & time <= search_window(2));

% 2. Isolate the data within the search window
CSD_search_zone = CSD(:, search_time_idx);

% 3. Locate the absolute peak negative value (the strongest sink)
[min_val, flat_idx] = min(CSD_search_zone(:));

% Convert the flat 1D index back to 2D [Row, Column] matrix indices
[row_sink, col_sink_relative] = ind2sub(size(CSD_search_zone), flat_idx);

% Map the relative search column back to the original full matrix column index
col_sink_full = search_time_idx(col_sink_relative);

% 4. Extract the physical depth and exact latency values
peak_sink_depth = depth_mm(row_sink)*1e3; % in microns now

peak_sink_latency = time(col_sink_full);

% 5. Print the findings clearly to the Command Window
fprintf('\n================ SINK EXTRACTION REPORT ================\n');
fprintf('Earliest Evoked Sink Detected at:\n');
fprintf('  -> Probe Depth:   %.2f µm\n', peak_sink_depth);
fprintf('  -> Peak Latency:  %.2f sec post-stimulus\n', peak_sink_latency);
fprintf('  -> Amplitude:     %.2f nA/mm^3\n', min_val);
fprintf('========================================================\n');

% 6. Optional: Add a visual target marker onto your active figure plot
hold on;
plot(peak_sink_latency, peak_sink_depth, 'wx', 'MarkerSize', 12, 'LineWidth', 2);
plot(peak_sink_latency, peak_sink_depth, 'wo', 'MarkerSize', 14, 'LineWidth', 1.5);
text(peak_sink_latency + 2, peak_sink_depth, ' Primary Input (Sink Peak)', ...
    'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');

% Get the baseline value at t=0 and the peak value at the trough
stim_idx = find(time==0);
v_start = CSD(row_sink, stim_idx);
v_trough = min_val; % This is the peak amplitude found earlier

sink_rise_profile = CSD(row_sink, stim_idx:col_sink_full);

% Find 30% and 70% amplitude thresholds
thresh_30 = v_start + 0.30 * (v_trough - v_start);
thresh_70 = v_start + 0.70 * (v_trough - v_start);

% Find the frames corresponding to this linear window
idx_30 = find(sink_rise_profile <= thresh_30, 1, 'first');
idx_70 = find(sink_rise_profile <= thresh_70, 1, 'first');

% Fit a line (y = mx + b) to this segment
time_segment = time(stim_idx + (idx_30:idx_70) - 1)';
csd_segment = sink_rise_profile(idx_30:idx_70)';
p = polyfit(time_segment, csd_segment, 1); % p(1) is slope, p(2) is intercept

% Find where the line intersects the baseline (y = v_start)
sink_onset_latency = (v_start - p(2)) / p(1);

fprintf('  -> Onset Latency (Linear Extrapolation): %.4f ms\n', sink_onset_latency);

plot(sink_onset_latency, peak_sink_depth, 'wx', 'MarkerSize', 12, 'LineWidth', 2);
plot(sink_onset_latency, peak_sink_depth, 'wo', 'MarkerSize', 14, 'LineWidth', 1.5);
text(sink_onset_latency - 2, peak_sink_depth, ' Primary Input (Sink Peak)', ...
    'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');

% --- Map Sink Coordinates back to True Channel Index ---
% Inputs:
%   src_grid: Your [384 x 2] physical coordinate matrix in micrometers
%   peak_sink_depth: The depth (y) of the sink in micrometers (found earlier)

% 1. Define the exact (X, Y) coordinate of the sink peak.
% Since we averaged across the probe width to get the depth profile, 
% we look at the center-line or check both columns. Let's assume X is centered (16 µm).
sink_x = find(time==peak_sink_latency); 
sink_y = peak_sink_depth;

% 2. Calculate the distance from every single electrode to this sink point
distances = sqrt((src_grid(:,1) - sink_x).^2 + (src_grid(:,2) - sink_y).^2);

% 3. Find the closest physical channel
[~, sink_chan] = min(distances);

% 4. Convert to your preferred index format
channel_index_0based = sink_chan - 1;

fprintf('\n================ CHANNEL INDEX REPORT ================\n');
fprintf('The physical channel closest to the first sink is:\n');
fprintf('  -> %d\n', sink_chan);

fprintf('  -> Exact contact location:   (X = %.1f µm, Y = %.1f µm)\n', ...
    src_grid(sink_chan, 1), src_grid(sink_chan, 2));
fprintf('======================================================\n');
