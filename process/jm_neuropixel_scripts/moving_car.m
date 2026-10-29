function [y] = moving_car(x,window_size)

y = zeros(size(x));
num_channels = size(x, 2);

for ch = 1:num_channels
    % Define local channel boundaries
    start_ch = max(1, ch - window_size/2);
    end_ch = min(num_channels, ch + window_size/2);

    % Subtract local median
    local_median = median(x(:,start_ch:end_ch),2,'omitnan');
    y(:,ch) = x(:,ch) - local_median;
end
