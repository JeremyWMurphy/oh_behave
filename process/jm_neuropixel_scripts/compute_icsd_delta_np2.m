function [csd, z_coords] = compute_icsd_delta_np2(lfp, dz, R, sigma,lambda_scaler)

% COMPUTE_ICSD_DELTA_NP2 Regularized 1D delta-iCSD for Neuropixels 2.0 dual columns

% Adapted from:
% Klas H. Pettersen, Anna Devor, Istvan Ulbert, Anders M. Dale, Gaute T. Einevoll,
% Current-source density estimation based on inversion of electrostatic forward
% solution: Effects of finite extent of neuronal activity and conductivity
% discontinuities, Journal of Neuroscience Methods, Volume 154, Issues 1-2,
% 30 June 2006, Pages 116-133, ISSN 0165-0270,
% http://dx.doi.org/10.1016/j.jneumeth.2005.12.005.
% (http://www.sciencedirect.com/science/article/pii/S0165027005004541)

% Inputs:
%   lfp - Raw LFP data matrix [384 Channels x Timepoints] sorted by depth
%   dz      - Vertical distance between rows in meters (15e-6 for NP 2.0)
%   R       - Radius of the source disc in meters (e.g., 500e-6)
%   sigma   - Extracellular conductivity in S/m (0.3)
%   lambda  - Regularization parameter to stabilize noise (try 0.01 to
%   0.1), i actually do a parameter search below

num_channels = size(lfp, 1);
z_coords = (0:num_channels-1)' * dz;

% Initialize and populate the forward matrix F
F = zeros(num_channels, num_channels);
for i = 1:num_channels
    for j = 1:num_channels
        h = abs(z_coords(i) - z_coords(j)); 
        % Analytical solution for potential on-axis from a delta-disc source
        F(i,j) = (1 / (2 * sigma)) * (sqrt(h^2 + R^2) - h);
    end
end

%%

% Define the logarithmic scan range for lambdas
lambdas_test = 10.^(linspace(-8, 2, 200)); % 
num_lambdas = length(lambdas_test);

res_norm = zeros(num_lambdas, 1);
sol_norm = zeros(num_lambdas, 1);

% Run the L-curve diagnostic scan
for l = 1:num_lambdas
    curr_lambda = lambdas_test(l);

    % Invert matrix with current lambda constraint
    F_inv = (F' * F + curr_lambda * eye(num_channels)) \ F';
    curr_csd = F_inv * lfp;

    % Forward project back to voltage to check predictive error (Residual)
    V_predicted = F * curr_csd;

    % Compute norms across space and time
    res_norm(l) = norm(lfp - V_predicted, 'fro'); % Data Mismatch
    sol_norm(l) = norm(curr_csd, 'fro');             % Complexity/Noise Inflation
end

% 5. Transform to log scale to find the physical curve elbow
log_res = log(res_norm);
log_sol = log(sol_norm);

% Programmatically find the point of maximum curvature (The Corner)
% We calculate the second spatial derivative of the curve vector
d1_res = diff(log_res);   
d1_sol = diff(log_sol);
d2_res = diff(d1_res);    
d2_sol = diff(d1_sol);

% Truncate vectors to align lengths safely
d1_res = d1_res(1:end-1); 
d1_sol = d1_sol(1:end-1);

% Curvature formula for a parametric 2D curve
curvature = abs(d1_res .* d2_sol - d1_sol .* d2_res) ./ ...
    (d1_res.^2 + d1_sol.^2).^(1.5);

% Locate the index of the absolute sharpest turning corner
[~, corner_idx] = max(curvature);
% Adjust index to offset the two diff operations
corner_idx = corner_idx + 1; 

lambda_opt = lambdas_test(corner_idx);
lambda_opt = lambda_opt.*lambda_scaler;
%% Regularized Inversion (Ridge Regression)
F_inv = (F' * F + lambda_opt * eye(num_channels)) \ F';
csd = F_inv * lfp;


