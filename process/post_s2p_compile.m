pth0 = '/Users/jeremy/Desktop/gpr26_161/';
fls = glob(fullfile([pth0 'data_proc*']));

hts = [0 0 0 0 0 0];
mss = [0 0 0 0 0 0];

amps = [0 0.2 0.3 0.4 0.6 1.0];


D = load(fls{1});
t = D.t;
E = {nan(1,numel(D.t)),nan(1,numel(D.t)),nan(1,numel(D.t)),nan(1,numel(D.t)),nan(1,numel(D.t))};
outcomes = {nan,nan,nan,nan,nan};

for i = 1:size(fls,1)

    D = load(fls{i});
    t = D.t;
    

    for j = 1:numel(amps)
        bt = D.beh_all(D.beh_all.piezo_amp==amps(j),:);
        if amps(j) == 0
            hts(j) = hts(j) + sum(bt.outcome==3);
            mss(j) = mss(j) + sum(bt.outcome==2);
        else
            hts(j) = hts(j) + sum(bt.outcome==1);
            mss(j) = mss(j) + sum(bt.outcome==0);
        end
    end

    for j = 1:numel(amps)-1
        tmp = D.eps_all{j};
        %bs_ix = t<0;
        %bs = mean(tmp(:,bs_ix,:),2);
        %tmp = (tmp-bs)./bs;
        E{j} = cat(1,E{j},mean(tmp,3));
        outcomes{j} = cat(1,outcomes{j},D.outcomes_all{j});
    end

     
end

p_hit = hts./(hts+mss);

ft = fittype('logistic');
mdl_fit = fit(amps',p_hit',ft);
eval_x = 0:0.01:1;
fit_points = mdl_fit(eval_x);

figure, hold

plot(eval_x,fit_points,'r')
plot(amps,p_hit,'-ow')
title(['ID: 161; N trials = ' num2str((hts+mss))])
ylabel('P(Hit)')
xlabel('Stimulus Amplitude')

%%

%%

eps_all_hits = [];
eps_all_misses = [];
eps_all_all = [];
for i = 1:size(E,2)

    eps_all_hits = cat(3,eps_all_hits,E{i}(:,:,outcomes{i}==1));
    eps_all_misses = cat(3,eps_all_misses,E{i}(:,:,outcomes{i}==0));
    eps_all_all = cat(3,eps_all_all,E{i});

end


%%

%X = squeeze(mean(eps_all{4}(:,:,outcomes_all{4}==1),3));
X = squeeze(mean(eps_all_all(:,:,outcomes_all{4}==0),3));

L = linkage(X,'complete');
figure
dendrogram(L)

eva = evalclusters(X,'linkage','silhouette','KList',1:10);

T = cluster(L,MaxClust=3);
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

        clrs(2,2) = clrs(2,2) + .05;
    end

    legend({'Hit Amp 1','Hit Amp 2','Hit Amp 3','Hit Amp 4','Hit Amp 5',...
        'Miss Amp 1','Miss Amp 2','Miss Amp 3','Miss Amp 4','Miss Amp 5'})

end