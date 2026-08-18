function [] = get_teensy_behavior_compile(pth,compile_days,runs,id,fname)

fs = 2e3;
rt_cutoff = 100;

opto_fa_thresh = Inf;

d_thresh = 0;

% beh will be [piezo_amp opto_trl opto_t outcome rt trial_ix i];
% hit = 1, miss = 0, cw = 2, fa = 3
beh = [];
beh_day = {};
go_licks = [];
nogo_opto_licks = [];
for i = 1:numel(compile_days)

    fprintf(['\nDoing ' pth 'behavior_' char(runs(compile_days(i))) '.mat'])
    load([pth 'behavior_' char(runs(compile_days(i))) '.mat'],'S');
    b = S.beh;

    opto_trls = b(b(:,2)==1,:);
    
    opto_fa_ixs = opto_trls(opto_trls(:,4)==3,6);
    opto_cw_ixs = opto_trls(opto_trls(:,4)==2,6);
    p_opto_fa = numel(opto_fa_ixs)./(numel(opto_fa_ixs) + numel(opto_cw_ixs));
    
    if p_opto_fa > opto_fa_thresh
         continue
    end

    hit_vec = zeros(b(end,7),1);
    hit_ixs = b(b(:,4)==1,6);
    hit_vec(hit_ixs) = 1;

    miss_vec = zeros(b(end,7),1);
    miss_ixs = b(b(:,4)==0,6);
    miss_vec(miss_ixs) = 1;

    cw_vec = zeros(b(end,7),1);
    cw_ixs = b(b(:,4)==2,6);
    cw_vec(cw_ixs) = 1;

    fa_vec = zeros(b(end,7),1);
    fa_ixs = b(b(:,4)==3,6);
    fa_vec(fa_ixs) = 1;

    %[bad_trials_r] = bad_trials_response_rate(fa_vec,cw_vec,hit_vec,miss_vec);
    [bad_trials_d] = mov_d_thresh(fa_vec,cw_vec,hit_vec,miss_vec,d_thresh);
    
    bad_trials = [bad_trials_d]; ....; bad_trials_d];
    b(bad_trials,:) = [];

    beh = cat(1,beh,b);
    % beh will be [piezo_amp opto_trl opto_t outcome rt trial_ix i];
    % hit = 1, miss = 0, cw = 2, fa = 3
    b = array2table(b,VariableNames={'piezo_amp','opto_trial','opto_time','outcome','rt','trial_ix_strt','trial_ix_end','idx'});
    beh_day{i} = b;

    nogo_opto_licks = cat(2,nogo_opto_licks,S.all_opto_nogo_licks);

end

% remove hits where the rt was faster than the cutoff
beh(beh(beh(:,4)==1,5)<=rt_cutoff,:) = [];

%% n_conditions = p amps x opo tf x opto time

% cell 1 will be no opto
beh_summ{1} = zeros(numel(unique(beh(:,1))),3);
% remaining cells will be for each opto time
opto_ts = unique(beh(~isnan(beh(:,3)),3));
for i = 1:numel(opto_ts)
    beh_summ{i+1} = zeros(numel(unique(beh(:,1))),3);
end

p_amps = unique(beh(:,1));
cnts = {};
for i = 1:numel(p_amps)

    all_pts = beh(beh(:,1)==p_amps(i),:);
    opto_pts = all_pts(logical(all_pts(:,2)),:);
    non_opto_pts = all_pts(~logical(all_pts(:,2)),:);

    if p_amps(i)==0
        fa_rate = nnz(non_opto_pts(:,4)==3)./(nnz(non_opto_pts(:,4)==3)+nnz(non_opto_pts(:,4)==2));
        cnts{1}.n_cws(i) = nnz(non_opto_pts(:,4)==2);
        cnts{1}.n_fas(i) = nnz(non_opto_pts(:,4)==3);
        beh_summ{1}(i,:) = [p_amps(i) fa_rate 0];
        % deal with opto nogos here because they have no timing relative to
        % piezo, so it's going to be the same value across all opto times
        opto_cw_cnts = nnz(opto_pts(:,4)==2);
        opto_fa_cnts = nnz(opto_pts(:,4)==3);
        opto_fa_rate = opto_fa_cnts./(opto_cw_cnts+opto_fa_cnts);
    else
        hit_rate = nnz(non_opto_pts(:,4)==1)./(nnz(non_opto_pts(:,4)==1)+nnz(non_opto_pts(:,4)==0));
        cnts{1}.n_hits(i) = nnz(non_opto_pts(:,4)==1);
        cnts{1}.n_misses(i) = nnz(non_opto_pts(:,4)==0);
        rt = mean(non_opto_pts(:,5),'omitnan');
        beh_summ{1}(i,:) = [p_amps(i) hit_rate rt];
    end

    for j = 1:numel(opto_ts)

        this_t_opto_pts = opto_pts(opto_pts(:,3)==opto_ts(j),:,:,:,:);

        if p_amps(i)==0
            cnts{j+1}.n_cws(i) = opto_cw_cnts;
            cnts{j+1}.n_fas(i) = opto_fa_cnts;
            beh_summ{j+1}(i,:) = [p_amps(i) opto_fa_rate 0];
        else
            hit_rate = nnz(this_t_opto_pts(:,4)==1)./(nnz(this_t_opto_pts(:,4)==1)+nnz(this_t_opto_pts(:,4)==0));
            cnts{j+1}.n_hits(i) = nnz(this_t_opto_pts(:,4)==1);
            cnts{j+1}.n_misses(i) = nnz(this_t_opto_pts(:,4)==0);
            rt = mean(this_t_opto_pts(:,5),'omitnan');
            beh_summ{j+1}(i,:) = [p_amps(i) hit_rate rt];
        end
    end
end

D = {};
for i = 1:numel(cnts)
    hit_cnt = cnts{i}.n_hits;
    hit_cnt(hit_cnt==0) = 0.5;
    miss_cnt = cnts{i}.n_misses;
    cw_cnt = cnts{i}.n_cws;
    fa_cnt = cnts{i}.n_fas;
    fa_cnt(fa_cnt==0) = 0.5;
    for j = 1:numel(hit_cnt)

        pHit = hit_cnt(j)./(hit_cnt(j) + miss_cnt(j));
        pFA = fa_cnt./(fa_cnt + cw_cnt);

        if pHit == 1
            pHit = 0.999;
        elseif pHit == 0
            pHit = 0.001;
        elseif pFA == 1
            pFA = 0.999;
        elseif pFA == 0
            pFA = 0.001;
        end
     
        zHit = norminv(pHit);
        zFA  = norminv(pFA);
        d = zHit - zFA;
        D{i}(j) = d;

    end
end

save([pth 'all_behavior'],'D','beh_summ','cnts','p_amps','opto_ts','go_licks','beh','beh_day')




