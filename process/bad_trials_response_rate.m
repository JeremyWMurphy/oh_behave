function [bad_trials] = bad_trials_response_rate(f,c,h,m)

gos = m+h; % these mark all go trials
resps = h+f; % these mark all trials where the animal responded to a go or no-go

gos = smoothdata(gos,1,'movmean',2e3*60);
resps = smoothdata(resps,1,'movmean',2e3*60);

r = resps./gos; % smoothed response rate

thresh = mean(r)-1.5*std(r);

thresh_vec = zeros(size(r));
thresh_vec(r<thresh) = 1;
thresh_vec(r>=thresh) = -1;

trl_num = [(1:numel(find(f+c+h+m)))' find(f+c+h+m)];

trls = thresh_vec.*(f+c+h+m);
bts = find(trls==1);

[~,~,bad_trials]=intersect(bts,trl_num(:,2));



