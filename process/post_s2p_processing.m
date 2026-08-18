function[] = post_s2p_processing()

id = '161';

dates = {'20260502','20260504','20260505','20260507','20260508','20260512'};

pth0 = '/Users/jeremy/Desktop/gpr26_161/';

fs = 7.44;
img_n_avg = 4; % we have n of these per image due to the way prairie view sends triggers

for r = 1:size(dates,2)

    run_dirs = dir([pth0 dates{r}  '/run*']);
    run_ts_dirs = dir([pth0 dates{r}  '/run*/T*']);
    run1_dir = dir([pth0 dates{r}  '/run1*/T*']);
    runs = {run_dirs.name};

    pth_2p = [run1_dir.folder '/' run1_dir.name '/suite2p/plane0/'];


    S = load(fullfile(pth_2p,'Fall.mat'));
    iscell = logical(S.iscell);
    stat = S.stat;
    stat(~iscell(:,1)) = [];
    F = S.F(iscell(:,1),:);
    Fneu = S.Fneu(iscell(:,1),:);
    spks = S.spks;

    F = F-Fneu*0.7;

    m = cellfun(@(n) [n.med],stat,'UniformOutput',false);
    m = reshape(cell2mat(m),2,[])';

    run_frames = zeros(numel(runs,1));

    for i = 1:numel(runs)

        tiff_fldr =  fullfile(run_ts_dirs(i).folder,run_ts_dirs(i).name);
        tiffs = dir(fullfile(tiff_fldr,'*.tif'));

        nframes = 0;
        for j = 1:size(tiffs,1)

            t = imfinfo(fullfile(tiff_fldr,tiffs(j).name));
            nframes = nframes + size(t,1);

        end

        run_frames(i) = nframes;
    end

    %% original rois

    full_mask = zeros(512,512);
    cntr = 1;
    for i = 1:size(stat,2)
        ypix = double(stat{i}.ypix) + 1; % Add 1 for 1-based indexing after exporting from python
        xpix = double(stat{i}.xpix) + 1;

        indices = sub2ind([512, 512], ypix, xpix);
        indices(stat{i}.overlap) = [];

        full_mask(indices) = cntr;
        cntr = cntr + 1;
    end

    colormap turbo
    imagesc(full_mask)

    %% merge rois based on correlation and distance

    c_thresh = 0.6;
    d_thresh = 1e4;

    cc = corrcoef(F');
    dd = squareform(pdist(double(m),'euclidean'));

    % Create a graph from the thresholded correlation matrix
    adj_mat = (cc > c_thresh) & (dd < d_thresh) & ~eye(size(cc)); % Adjacency matrix
    G = graph(adj_mat);
    % Find fully connected subgraphs (clusters/merged groups)
    grp_ids = conncomp(G);

    new_mask = zeros(512,512);
    new_F = nan(numel(unique(grp_ids)),size(F,2));
    new_spks = nan(numel(unique(grp_ids)),size(F,2));

    xpix_merge = {};
    ypix_merge = {};
    overlap_merge = {};
    grp_size = [];
    for i = 1:numel(unique(grp_ids))

        ixs = find(grp_ids==i);
        new_F(i,:) = mean(F(ixs,:),1);
        new_spks(i,:) = mean(spks(ixs,:),1);

        xpix_tmp = [];
        ypix_tmp = [];
        overlap_tmp = [];

        for j = 1:numel(ixs)
            xpix_tmp = cat(2,xpix_tmp,stat{ixs(j)}.xpix);
            ypix_tmp = cat(2,ypix_tmp,stat{ixs(j)}.ypix);
            overlap_tmp = cat(2,overlap_tmp,stat{ixs(j)}.overlap);
        end

        xpix_merge{i} = xpix_tmp;
        ypix_merge{i} = ypix_tmp;
        overlap_merge{i} = overlap_tmp;

        idxs = sub2ind([512, 512], ypix_tmp, xpix_tmp);
        n_pix = numel(idxs);
        grp_size(i) = n_pix;
        idxs(logical(overlap_tmp)) = [];
        new_mask(idxs) = i;

    end

    figure,
    imagesc(new_mask)
    colormap turbo

    dat = {};
    spikes= {};
    cntr = 0;
    for i = 1:numel(runs)
        dat{i} = new_F(:,cntr+1:cntr+run_frames(i));
        spikes{i} = new_spks(:,cntr+1:cntr+run_frames(i));
        cntr = cntr + run_frames(i);
    end

    dat_dff = {};
    for h = 1:numel(dat)
        win = -ceil(3*Fs):ceil(Fs*4);
        x = dat{h};
        w = nan(size(x));
        bad_locs = [];
        for i = 1:size(x,1)

            y = smoothdata(x(i,:),2,'gaussian',ceil(Fs));
            thresh = prctile(y,75) + 1.5*iqr(y);
            y = [nan(1,numel(win)) y nan(1,numel(win))];
            [~,pk_ixs]=findpeaks(y,'minpeakdistance',ceil(Fs*0.5),'minpeakheight',thresh,'minpeakwidth',Fs*0.5);

            if isempty(pk_ixs)
                bad_locs = [bad_locs i];
            end

            y(pk_ixs'+win) = NaN;
            y = fillmissing(y,'movmedian',Fs*10);
            y = smoothdata(y,'movmedian',ceil(Fs*30));
            y = y(numel(win)+1:end-numel(win));
            w(i,:) = (x(i,:)-y)./y;

        end

        w(bad_locs,:) = NaN;
        w = smoothdata(w,'gaussian',5);
        dat_dff{h} = w;

    end

    %% teensy data

    teensy_frames = {};
    beh = {};
    beh_all = [];

    for i = 1:size(run_dirs,1)

        fldr_name = dir(fullfile(run_dirs(i).folder, run_dirs(i).name, [ id '*']));
        dt = datetime(fldr_name.name(5:end),'InputFormat','yyyy-MM-dd_''T''HH-mm-ss');
        [D] = read_teensy_data([fldr_name.folder '/'],fldr_name.name,dt);

        frame_idx = find(diff(D.FrameNum)>0.5);
        frame_idx = frame_idx(1:img_n_avg:end);
        if size(frame_idx,1) > run_frames(i)
            frame_idx = frame_idx(1:run_frames(i));
        end
        teensy_frames{i} = frame_idx;

        teensy_fs = 2e3;
        valid_response_win = 0.7;
        [S] = get_teensy_behavior_imaging(D,teensy_fs,valid_response_win);
        beh{i} = S;
        beh_all = [beh_all;S.beh];

    end

    beh_all = array2table(beh_all,VariableNames={'piezo_amp','outcome','rt','trial_ix_strt','trial_ix_end','idx'});

    %%

    ep_win = ceil(-3*fs):ceil(5*fs);
    wheel_win = ceil(-3*beh{1}.fs):ceil(5*beh{1}.fs);
    t = ep_win./fs;

    eps = {};
    eps_dff = {};    
    eps_spks = {};
    outcomes = {};
    for i = 1:size(runs,2)

        d = dat{i};
        e = dat_dff{i};
        s = spikes{i};

        frms = teensy_frames{i};
        td = beh{i};
        whl = td.wheel;

        run_amps =  unique(td.beh(:,1));
        run_amps(run_amps==0) = [];

        for j = 1:numel(run_amps)
            amp = run_amps(j);
            ixs = find(td.beh(:,1)==amp);

            ep = [];
            w_ep = [];
            ep_s = [];
            ep_e = [];
            outcome = [];
            for k = 1:numel(ixs)
                
                trl_dat = td.trial_dat{ixs(k)};
                otcm = td.beh(ixs(k),2);
                p_dat = trl_dat(:,3);
                pix = find(diff(p_dat)>0,1,'first');
                strt = td.beh(ixs(k),4);
                pix = pix+strt;
                [~,p_frame]=min(abs(pix-frms));

                if all(p_frame+ep_win>0) && all(p_frame+ep_win<size(d,2))
                    ep =  cat(3,ep,d(:,p_frame+ep_win));
                    ep_e =  cat(3,ep_e,e(:,p_frame+ep_win));
                    w_ep = cat(2,w_ep,whl(pix+wheel_win));
                    ep_s =  cat(3,ep_s,s(:,p_frame+ep_win));
                    outcome = cat(1,outcome,otcm);
                end

            end

            eps{i,j} = ep;
            whl_eps{i,j} = w_ep;
            eps_evts{i,j} = ep_e;
            eps_spks{i,j} = ep_s;

            outcomes{i,j} = outcome;

        end

    end

    %%

    bs_ix = t<0;
    eps_all = {};
    whl_eps_all = {};
    eps_e_all = {};
    eps_s_all = {};

    for i = 1:size(eps,2)
        tmp = [];
        tmp2 = [];
        tmp_e = [];
        tmp_s = [];
        tmp_w = [];
        for j = 1:size(eps,1)
            tmp = cat(3,tmp,eps{j,i});
            tmp_e = cat(3,tmp_e,eps_evts{j,i});
            tmp_s = cat(3,tmp_s,eps_spks{j,i});
            tmp_w = cat(2,tmp_w,whl_eps{j,i});
            tmp2 = cat(1,tmp2,outcomes{j,i});

        end

        bs = mean(tmp(:,bs_ix,:),2);
        tmp = (tmp-bs)./bs;
        eps_all{i} = tmp;

        eps_e_all{i} = tmp_e;
        whl_eps_all{i} = tmp_w;

        eps_s_all{i} = tmp_s;
        outcomes_all{i} = tmp2;

    end

    %%

    save([pth0 '/data_proc_' dates{r} '.mat'],'new_F','t','eps_all','eps_e_all','eps_s_all','outcomes_all','beh','beh_all','new_mask')

end

    %%

    eps_all_hits = [];
    eps_all_misses = [];
    eps_all_all = [];
    eps_s_all_hits = [];
    eps_s_all_misses = [];
    eps_s_all_all = [];
    for i = 1:size(eps_all,2)

        eps_all_hits = cat(3,eps_all_hits,eps_all{i}(:,:,outcomes_all{i}==1));
        eps_all_misses = cat(3,eps_all_misses,eps_all{i}(:,:,outcomes_all{i}==0));
        eps_all_all = cat(3,eps_all_all,eps_all{i});

        eps_s_all_hits = cat(3,eps_s_all_hits,eps_s_all{i}(:,:,outcomes_all{i}==1));
        eps_s_all_misses = cat(3,eps_s_all_misses,eps_s_all{i}(:,:,outcomes_all{i}==0));
        eps_s_all_all = cat(3,eps_s_all_all,eps_s_all{i});

    end


    %
    
    %X = squeeze(mean(eps_all{4}(:,:,outcomes_all{4}==1),3));
    X = squeeze(mean(eps_all{5},3));
    
    L = linkage(X,'complete');
    figure
    dendrogram(L)

    %eva = evalclusters(X,'linkage','silhouette','KList',1:10);

    T = cluster(L,MaxClust=2);
    grp_ids = unique(T);

    clusters = {};

    for i = 1:size(eps_all,2)

        eps_c_hit = [];
        eps_c_miss = [];
        for j = 1:numel(grp_ids)

            eps_c_hit = mean(mean(eps_all{i}(T==grp_ids(j),:,outcomes_all{i}==1),3),1);
            eps_c_miss = mean(mean(eps_all{i}(T==grp_ids(j),:,outcomes_all{i}==0),3),1);

            clusters{i,j,1} = eps_c_hit;
            clusters{i,j,2} = eps_c_miss;

        end

    end

    %

    for i = 1:size(clusters,2)
        figure, hold on
        title(['Cluster ' num2str(i)])
        clrs = colororder;
        for j = 1:size(clusters,1)
            plot(t,smoothdata(clusters{j,i,1},2,'movmean',5),'Color',clrs(1,:))
            clrs(1,1) = clrs(1,1) + .1;

        end
        for j = 1:size(clusters,1)

            plot(t,smoothdata(clusters{j,i,2},2,'movmean',5),'Color',clrs(2,:))

            clrs(2,2) = clrs(2,2) + .1;
        end

        legend({'Hit Amp 1','Hit Amp 2','Hit Amp 3','Hit Amp 4','Hit Amp 5',...
            'Miss Amp 1','Miss Amp 2','Miss Amp 3','Miss Amp 4','Miss Amp 5'})

    end

 