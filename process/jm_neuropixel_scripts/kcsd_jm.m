function[CSD_depth_time,y_steps_mm,src_grid] = kcsd_jm(V_data)

% --- 2D kCSD Implementation ---
% used https://github.com/Arsakes/kCSD.git as roadmap

% V_data = chans x t LFP matrix in microvolts

% Parameters
R_kernel = 25;% Spatial kernel filter radius (in µm)
lambdas_to_test = 10.^(linspace(-8, 2, 1000));
snippet_sz_for_lambda = ceil(size(V_data,2)*0.05); % use e.g., 5% of the data from the start 

% Define conductivity of brain
sigma = 0.3; 

% Neuropixels 2.0 geometry specs
%col_spacing = 32; % Horizontal distance between columns (µm)
%row_pitch   = 15; % Vertical distance between rows (µm)

col_spacing = 50; % Horizontal distance between columns (µm)
row_pitch   = 50; % Vertical distance between rows (µm)


num_channels = size(V_data,1); 

%% make the electrode layout

% Assign positions based on even (Col 1) and odd (Col 2) mapping
x_coords = zeros(num_channels, 1);
y_coords = zeros(num_channels, 1);

for ch = 1:num_channels
    chan_idx = ch - 1; % 0-indexed match
    if mod(chan_idx, 2) == 0
        x_coords(ch) = 0;                     % Left Column (Even)
    else
        x_coords(ch) = col_spacing;           % Right Column (Odd)
    end
    y_coords(ch) = floor(chan_idx / 2) * row_pitch; % Vertical Depth
end

% Electrode Positions [X, Y]
src_grid = [x_coords, y_coords];
src_mm = src_grid / 1000;       % Convert electrode positions to mm

% 2. Re-map grid to millimeters
x_steps_mm = (min(src_grid(:,1)) : 2 : max(src_grid(:,1))) / 1000;
y_steps_mm = (min(src_grid(:,2)) : 5 : max(src_grid(:,2))) / 1000;
[X_mesh, Y_mesh] = meshgrid(x_steps_mm, y_steps_mm);
out_mm = [X_mesh(:), Y_mesh(:)]; % [N_points x 2]

% 3. Calculate Cross-Correlation Potential Matrix (K_pot)
% In true kCSD, K_pot relies on an analytical integral. For standard 
% Gaussian basis sources, the potential between electrodes is:
X_src = src_mm(:,1); Y_src = src_mm(:,2);
dist_src = sqrt((X_src - X_src').^2 + (Y_src - Y_src').^2);

% The physical forward model equation mapping current to voltage:
% Note: convert R_kernel to mm as well
R_mm = R_kernel / 1000;

K_pot = exp(-(dist_src.^2) / (2 * R_mm^2)) / (4 * pi * sigma);


% % 4. Calculate Estimation Matrix (K_interp)
% % This maps the true underlying source densities directly to your pixels
X_out = out_mm(:,1); Y_out = out_mm(:,2);
dist_interp = sqrt((X_out - X_src').^2 + (Y_out - Y_src').^2);
K_interp = exp(-(dist_interp.^2) / (2 * R_mm^2));

%% ---Cross-Validation (LOOCV) for optimal Lambda ---

LOOCV_errors = zeros(length(lambdas_to_test), 1);

% Select a representative timeframe snippet to optimize (e.g., first 500 frames)
V_cv = V_data(:, 1:min(snippet_sz_for_lambda, size(V_data,2))); 

% Precompute the inverse helper matrix to optimize the loop speed
[U, S, ~] = svd(K_pot); 
s_diag = diag(S);

for l = 1:length(lambdas_to_test)

    curr_lambda = lambdas_to_test(l);

    % Compute the complete reconstruction matrix for this lambda
    % K_inverse_regularized = inv(K_pot + lambda*I)
    K_inv = U * diag(1 ./ (s_diag + curr_lambda)) * U';

    % Step-by-step Leave-One-Out validation trick:
    % Rather than a nested loop for every single channel, a linear projection 
    % trick yields the exact cross-validation error array directly:
    Influence_diag = diag(K_pot * K_inv); 
    V_predicted = K_pot * K_inv * V_cv;

    % Normalized prediction error at missing sites
    errors = (V_cv - V_predicted) ./ (1 - Influence_diag);
    LOOCV_errors(l) = mean(errors(:).^2); % Total Mean Squared Error

end

% Extract the mathematically optimal parameter
[~, best_idx] = min(LOOCV_errors);
lambda = lambdas_to_test(best_idx);
fprintf('Optimal Lambda found via Cross-Validation: %e\n', lambda);

% --- Plotting the kCSD Cross-Validation Curve ---
figure, hold on
% Plot the prediction error across all tested lambdas
loglog(lambdas_to_test, LOOCV_errors, 'b-', 'LineWidth', 2);
loglog(lambda, LOOCV_errors(best_idx), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
set(gca, 'XScale', 'log', 'YScale', 'log'); % Ensure log-log visibility
xlabel('Regularization Parameter (\lambda)');
ylabel('Leave-One-Out Prediction Error (MSE)');
title('kCSD Cross-Validation Optimization Curve');
text(lambda * 1.5, LOOCV_errors(best_idx) * 1.2, ...
    ['\leftarrow Optimal \lambda = ' num2str(lambda, '%e')], ...
    'Color', 'r', 'FontWeight', 'bold');

%% 5. Compute the final CSD over time via a single matrix division
% Input is μV, spatial elements are mm, conductivity is S/m.
% This combination forces the output directly into nA/mm³!
CSD_final_flat = K_interp * ((K_pot + lambda * eye(size(K_pot))) \ V_data);

% 6. Reshape into 3D Spatiotemporal Matrix
num_y_steps = length(y_steps_mm);
num_x_steps = length(x_steps_mm);
num_timepoints = size(V_data, 2);
CSD_3D_final = reshape(CSD_final_flat, [num_y_steps, num_x_steps, num_timepoints]);

% 7. Collapse probe width to yield your classic Depth vs Time CSD plot
CSD_depth_time = squeeze(mean(CSD_3D_final, 2));

