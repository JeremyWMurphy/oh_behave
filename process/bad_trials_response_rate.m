function [bad_trials] = bad_trials_response_rate(f,c,h,m)

r = smoothdata(f+h,1,'gauss',180*2e3);

thresh = mean(r)-std(r);

thresh_vec = zeros(size(r));
thresh_vec(r<thresh) = 1;
thresh_vec(r>=thresh) = -1;

trl_num = [(1:numel(find(f+c+h+m)))' find(f+c+h+m)];

trls = thresh_vec.*(f+c+h+m);
bts = find(trls==1);

[~,~,bad_trials]=intersect(bts,trl_num(:,2));



