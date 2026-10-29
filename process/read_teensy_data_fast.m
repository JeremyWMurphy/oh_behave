function[D] = read_teensy_data_fast(file_path)

fid = fopen(file_path);
ln_one = fgetl(fid);
% if we just caught the teensy mid data report, fseek wont find the pattern, and returns none 
if ln_one(1) ~= '<' || ln_one(end) ~= '>'
    data = fscanf(fid,'<%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d>\n');
else
    frewind(fid)
    data = fscanf(fid,'<%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d>\n');
end
fclose(fid);
r = mod(numel(data),11); % find an incomplete line at the end
data = data(1:end-r);
data = reshape(data,11,[])';
strt = find(data(:,1)==0,1,'first'); % find teensy restart (this is always done at the start of the experiment)
data = data(strt:end,:);

D = data;

D = array2table(D,'VariableNames',{'LoopNum','FrameNum','State','TrialOutcome','Ao0','Ao1','Licks','Wheel','Reward','Vac','Barcode'});
summary(D)