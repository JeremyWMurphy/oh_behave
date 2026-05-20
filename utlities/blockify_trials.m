function[trl_blcks] = blockify_trials(trls)

trl_blcks = [];
ttypes = unique(trls);
n = zeros(numel(ttypes),1);
for i = 1:numel(ttypes)
    n(i) = sum(trls==ttypes(i));
end

while ~isempty(trls)


end


