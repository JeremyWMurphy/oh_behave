function [] = print_parameters(fid,S)

% need to ignore teensy substruct for now
fns = fieldnames(S);
fns(ismember(fns,'tp')) = [];
for i = 1:numel(fns)
    fprintf(fid,['\n' fns{i} ': ' num2str(S.(fns{i}))]);
end

% also print nested teensy parameters
fns = fieldnames(S.tp);
for i = 1:numel(fns)
    fprintf(fid,['\n' fns{i} ': ' num2str(S.tp.(fns{i}))]);
end




