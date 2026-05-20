A = load('D:\data\Cue_S2_POm\behavior\gpr26_162\all_behavior.mat');
B = load('D:\data\Cue_S2_POm\behavior\gpr26_157\all_behavior.mat');
C = load('D:\data\Cue_S2_POm\behavior\gpr26_160\all_behavior.mat');

%%
ft = fittype('logistic');

include_amps = [0 0.2 0.3 0.4 0.6 1.0];
include_opto_ts = [25 50 75 200];

figure, hold on
amp_ixs = logical(sum(A.p_amps==include_amps,2));
mdl_fit{1} = fit(A.beh_summ{1}(amp_ixs,1),A.beh_summ{1}(amp_ixs,2),ft);
eval_x = 0:0.01:1;
fit_points = mdl_fit{1}(eval_x);
plot(eval_x,fit_points,'w')
plot(A.beh_summ{1}(amp_ixs,1),A.beh_summ{1}(amp_ixs,2),'ow')

%%
amp_ixs = logical(sum(B.p_amps==include_amps,2));
mdl_fit{1} = fit(B.beh_summ{1}(amp_ixs,1),B.beh_summ{1}(amp_ixs,2),ft);
eval_x = 0:0.01:2;
fit_points = mdl_fit{1}(eval_x);
plot(eval_x,fit_points,'r')
plot(B.beh_summ{1}(amp_ixs,1),B.beh_summ{1}(amp_ixs,2),'or')

amp_ixs = logical(sum(C.p_amps==include_amps,2));
mdl_fit{1} = fit(C.beh_summ{1}(amp_ixs,1),C.beh_summ{1}(amp_ixs,2),ft);
eval_x = 0:0.01:2;
fit_points = mdl_fit{1}(eval_x);
plot(eval_x,fit_points,'b')
plot(C.beh_summ{1}(amp_ixs,1),C.beh_summ{1}(amp_ixs,2),'ob')

xlabel('Stimulus Intensity')
ylabel('P(Hit)')
legend('mouse 1 (Opto)','','mouse 2 (Control)','','mouse 3 (Control)')

ylim([0 1])

%%

W = {A};
ids = {'162'};

clrs = {'r','b'};

include_opto_ts = [0 25 50 75 200];

for i = 1:numel(W)

    tmp = W{i};
    unstruct(tmp);

    amp_ixs = logical(sum(p_amps==include_amps,2));
    opto_ixs = find(sum(opto_ts==include_opto_ts,2))';

    lgd = {};
    lgd{1} = 'No Opto';

    figure, hold on
    annotation('textbox', [0.5, 0.9, 0.1, 0.1], 'String', ids{i}, ...
        'EdgeColor', 'none', 'BackgroundColor', 'none','Fontsize',14);

    % no opto curve
    plot(beh_summ{1}(amp_ixs,1),beh_summ{1}(amp_ixs,2),'-ok');

    % opto curves
    for j = 1:numel(opto_ixs)
        plot(beh_summ{1}(amp_ixs,1),beh_summ{opto_ixs(j)+1}(amp_ixs,2),['-' clrs{j} 'o']);
        lgd{j+1} = num2str(-1*opto_ts(opto_ixs(j)));
    end

    %
    % mdl_fit = {};
    %
    % ft = fittype('Gompertz');
    % mdl_fit{1} = fit(beh_summ{1}(amp_ixs,1),beh_summ{1}(amp_ixs,2),ft);
    % eval_x = 0:0.01:2;
    % fit_points = mdl_fit{1}(eval_x);
    % plot(eval_x,fit_points,'k')
    %
    % cntr = 1;
    % for j = opto_ixs
    %     mdl_fit{j+1} = fit(beh_summ{j+1}(amp_ixs,1),beh_summ{j+1}(amp_ixs,2),ft);
    %     fit_points = mdl_fit{j+1}(eval_x);
    %     plot(eval_x,fit_points,clrs{cntr})
    %     cntr = cntr + 1;
    % end

    xlabel('Piezo Voltage')
    ylabel('P(hit)')
    legend(lgd);
    ax=gca;
    ax.Legend.EdgeColor = 'None';
    ax.Legend.Location = 'SouthEast';
    ylim([0 1])

end

%%
W = {A,B,C};
ids = {'162','157','160'};

for i = 1:numel(W)

    unstruct(W{i})
    % go_licks(go_licks==0) = NaN;
    % pre_post = [-0.5 2];
    % lick_t = pre_post(1):1/fs:pre_post(2);
    % 
    % figure, hold
    % scatter(lick_t,go_licks+linspace(1,size(go_licks,2),size(go_licks,2)),'Marker','o','SizeData',4,'MarkerFaceColor','k','MarkerEdgeColor','none','MarkerFaceAlpha', 0.01)
    % xlim(pre_post)
    % ylim([0 size(go_licks,2)])
    % xlabel('Time (S)')
    % ylabel('Trial Number')
    % line([0 0],ylim,'Color','r','LineWidth',2)

    figure, hold
    bar([beh_summ{1}(1,2) mean(beh_summ{2}(1,2),2)],'FaceColor',[0.25 0.1 0.5],'EdgeColor','None')
    ylim([0 1])
    ylabel('P(FA)')
    xlabel('Condition')
    ax=gca;
    ax.XTick = [1 2];
    ax.XTickLabel = {'No Opto','Opto'};
    title(ids{i})

end

%%

figure, hold on
plot(beh_summ{1}(amp_ixs,1),D{1}(amp_ixs),'w')
for i = 1:numel(opto_ixs)
    plot(beh_summ{1}(amp_ixs,1),D{opto_ixs(i)+1}(amp_ixs))
end