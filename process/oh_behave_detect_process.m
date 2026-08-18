function [] = oh_behave_detect_process()

%%
do_subj = 1;

top_pth = '/Users/jeremy/Documents/data/Cue_S2_POm/behavior/';

fs = 2e3;

switch do_subj

    case 1
        
        id = '162';
        pth = [top_pth 'gpr26_162/'];      
        strt = '2026-04-08';
        fin = '2026-04-18'; ...datetime('today');

    case 2
        id = '158';
        pth = [top_pth 'gpr26_158/'];
        strt = '2026-05-08';
        fin = '2026-05-20'; ...datetime('today');
   
end

%

[runs,exp_day,dates] = get_data_pths(pth,id,strt,fin);

run_days = [];
read_in_data = 0;
only_compute_new = true;
for i = unique(exp_day)'
    rns = runs(exp_day==i,:); 
    dts = dates(exp_day==i);
    run_day = dts(1);
    run_days = [run_days; run_day];
    fprintf(['\nDoing ' char(run_day) ', Using files:\n'])  
    for j = 1:size(rns,1)
        fprintf([rns(j,:) ', '])
    end
    if read_in_data
        if only_compute_new
            if ~exist([pth 'behavior_' char(run_day) '.mat'])
                data = read_teensy_data(pth,rns,dts);
                [S] = get_teensy_behavior(data,fs);
                save([pth 'behavior_' char(run_day) '.mat'],'S')
            end
        else
            data = read_teensy_data(pth,rns,dts);
            [S] = get_teensy_behavior(data,fs);
            save([pth 'behavior_' char(run_day) '.mat'],'S')
        end
    end
end

%%

compile_days = unique(exp_day)';
get_teensy_behavior_compile(pth,compile_days,run_days,id)
    





