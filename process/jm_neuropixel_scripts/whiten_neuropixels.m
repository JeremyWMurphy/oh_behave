function [whitenedData, W_ZCA] = whiten_neuropixels(rawData, epsilon)
% WHITEN_NEUROPIXELS Applies spatial ZCA whitening to a data matrix.
%
% Inputs:
%   rawData - An [N x T] matrix where N is the number of channels 
%             and T is the number of time samples.
%   epsilon - (Optional) Regularization parameter to stabilize the matrix
%             inversion for dead/quiet channels. Defaults to 1e-5.
%
% Outputs:
%   whitenedData - The spatially decorrelated data [N x T].
%   W_ZCA        - The calculated [N x N] whitening matrix.

if nargin < 2
    epsilon = 1e-5; 
end

% 1. Double precision ensures stability during matrix operations
rawData = double(rawData);

% 2. Center the data (subtract mean of each channel)
meanChannels = mean(rawData, 2);
centeredData = rawData - meanChannels;

% 3. Compute the spatial covariance matrix (N x N)
T = size(centeredData, 2);
covarianceMatrix = (centeredData * centeredData') / (T - 1);

% 4. Eigen-decomposition of the covariance matrix
% V: Eigenvectors matrix, D: Diagonal matrix of eigenvalues
[V, D] = eig(covarianceMatrix);

% 5. Add regularization to the diagonal eigenvalues
% This prevents division-by-zero errors on dead channels
D_diag = diag(D);
D_inv_sqrt = diag(1 ./ sqrt(D_diag + epsilon));

% 6. Compute the ZCA Whitening Matrix (V * D^(-1/2) * V')
% This rotates the data back to the original physical channel space
W_ZCA = V * D_inv_sqrt * V';

% 7. Apply the transformation to the centered data
whitenedData = W_ZCA * centeredData;
end