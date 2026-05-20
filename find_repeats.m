function[n_rep_ixs] = find_repeats(trls,n)

% Find indices where the values change
d = [true, diff(trls)' ~= 0, true];
indices = find(d);
% Calculate the lengths of the consecutive runs
lengths = diff(indices);

% Find which runs have a length of at least n
n_rep_ixs = indices(lengths>=n);