function[csd] = csd_simple_jm(dat,spc)

num_rows = size(dat, 2);
csd = nan(size(dat, 1), num_rows - 2);
for i = 2:(num_rows - 1)
    % Compute the true vertical second derivative (Ohm's law requires multiplying by -sigma)
    % sigma = 0.3 S/m
    x = -0.3 * (dat(:, i-1) - 2.*dat(:, i) + dat(:, i+1)) ./ spc^2;
    csd(:, i-1) = x;
end


