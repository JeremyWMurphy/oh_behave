function [S] = get_teensy_behavior(d,fs,valid_response_win)

if nargin < 3
    valid_response_win = 1.5;
end

state = d.State;
outcome = d.TrialOutcome;
piezo = 5*(d.Ao0/4095);
opto = 5*(d.Ao1/4095);
licks = d.Licks;

brk_ixs = find(diff(state) == 7);
brk_ixs = [brk_ixs;size(state,1)];

cntr = 0;
trial_dat = {};
trial_ixs = [];
trial_ix_abs = [];
if isscalar(brk_ixs)

    new_state = state;
    new_out = outcome;
    new_pz = piezo;
    new_opto = opto;
    new_licks = licks;

    new_state(new_state~=2&new_state~=3&new_state~=12) = 0;

    trl_ends = find(diff(new_state)==-12)+1;
    trl_starts = find(diff(new_state)==2|diff(new_state)==3)-1;

    for j = 1:numel(trl_starts)
        strt_ix = trl_starts(j);
        end_ix = find(strt_ix-trl_ends<0,1,'first');
        if isempty(end_ix)
            continue
        else
            trial_ix = [strt_ix trl_ends(end_ix)];
            cntr = cntr+1;
            trial_dat{cntr} = [new_state(trial_ix(1):trial_ix(2)) ...
                new_out(trial_ix(1):trial_ix(2)) ...
                new_pz(trial_ix(1):trial_ix(2)) ...
                new_opto(trial_ix(1):trial_ix(2)) ...
                new_licks(trial_ix(1):trial_ix(2))];
            trial_ixs = cat(1,trial_ixs,trial_ix);
        end
    end

else

    for i = 1:numel(brk_ixs)-1

        new_state = state(brk_ixs(i):(brk_ixs(i+1)-1));
        new_out = outcome(brk_ixs(i):(brk_ixs(i+1)-1));
        new_pz = piezo(brk_ixs(i):(brk_ixs(i+1)-1));
        new_opto = opto(brk_ixs(i):(brk_ixs(i+1)-1));
        new_licks = licks(brk_ixs(i):(brk_ixs(i+1)-1));

        new_state(new_state~=2&new_state~=3&new_state~=12) = 0;

        trl_ends = find(diff(new_state)==-12)+1;
        trl_starts = find(diff(new_state)==2|diff(new_state)==3)-1;


        for j = 1:numel(trl_starts)
            strt_ix = trl_starts(j);
            end_ix = find(strt_ix-trl_ends<0,1,'first');
            if isempty(end_ix)
                continue
            else
                trial_ix = [strt_ix trl_ends(end_ix)];
                trial_ix_abs = cat(1,trial_ix_abs,[strt_ix+brk_ixs(i) trl_ends(end_ix)+brk_ixs(i)]);
                cntr = cntr+1;
                trial_dat{cntr} = [new_state(trial_ix(1):trial_ix(2)) ...
                    new_out(trial_ix(1):trial_ix(2)) ...
                    new_pz(trial_ix(1):trial_ix(2)) ...
                    new_opto(trial_ix(1):trial_ix(2)) ...
                    new_licks(trial_ix(1):trial_ix(2))];
                trial_ixs = cat(1,trial_ixs,trial_ix);
            end
        end
    end

end

%%
beh = [];
% beh will be [piezo_amp opto_trl opto_t outcome rt trial_ixs ix];
% for each trial, get outcome
all_go_licks = [];
all_opto_nogo_licks = [];
for i = 1:numel(trial_dat)

    dat = trial_dat{i};
    trial_ix = trial_ix_abs(i,:) + brk_ixs(1);

    ttype = dat(find(dat(:,1)>0,1,'first'),1);
    rslt =  dat(find(dat(:,2)>0,1,'first'),2);

    if rslt == 5
        abrt = true;
    else
        abrt = false;
    end

    b = [];
    if ~abrt
        if ttype == 2 % go trial
            pz = dat(:,3);
            pz_amp = round(max(pz),2);
            pz_onset = find(diff(pz)>0,1,'first');       
            opto_win = dat(:,4);
            if max(opto_win) > 0
                opto_onset = find(diff(opto_win)>0,1,'first');
                opto_t = floor(1000*(pz_onset-opto_onset)/fs);
                opto_trl = 1;
            else
                opto_t = NaN;
                opto_trl = 0;
            end
            if isempty(pz_onset)                
                continue % this rarely happens but seems to happen at the first trial of a run, haven't tracked down the issue yet
            elseif pz_onset - 0.5*fs < 1 || pz_onset + 2*fs > size(pz,1)                
            else
                all_go_licks = cat(2,all_go_licks,dat(pz_onset-0.5*fs:(pz_onset+2*fs),5));
            end
            if rslt == 2 % it was a miss
                b = [pz_amp opto_trl opto_t 0 0 trial_ix i];         
            elseif rslt == 1 % it was a hit       
                lk_win = dat(:,5);
                lk_ixs = find(diff(lk_win)>0);
                lk_ix = lk_ixs(find(lk_ixs>pz_onset & lk_ixs<= pz_onset+valid_response_win*fs,1,'first'));
                b = [pz_amp opto_trl opto_t 1 (lk_ix-pz_onset)./fs trial_ix i];
            else
                % this rarely happens but seems to happen at the first trial (or maybe last) of a run, haven't tracked down the issue yet
                fprintf('\nThere is a mismatch between the trial type and the outcome');
                continue
            end
        elseif ttype == 3 % no go
            opto_win = dat(:,4);
            if max(opto_win) > 0
                opto_t = 0;
                opto_trl = 1;
                opto_onset = find(diff(opto_win)>0,1,'first');
            else
                opto_t = NaN;
                opto_trl = 0;
            end

            if rslt == 3 % it was a correct withold
                b = [0 opto_trl opto_t 2 0 trial_ix i];
      
            elseif rslt == 4 % it was a fa
                b = [0 opto_trl opto_t 3 0 trial_ix i];
                if opto_trl && opto_onset-0.5*fs > 0 && opto_onset+2*fs <= size(dat,1)                
                    all_opto_nogo_licks = cat(2,all_opto_nogo_licks,dat(opto_onset-0.50*fs:(opto_onset+2*fs),5));
                end
          
            else
                % this rarely happens but seems to happen at the first trial (or maybe last) of a run, haven't tracked down the issue yet
                fprintf('\nThere is a mismatch between the trial type and the outcome');
                continue
            end
        end
        beh = cat(1,beh,b);
    end

end

S.beh = beh;
S.licks = licks;
S.piezo = piezo;
S.outcome = outcome;
S.state = state;
S.opto = opto;
S.fs = fs;
S.all_go_licks = all_go_licks;
S.all_opto_nogo_licks = all_opto_nogo_licks;
S.file_break_ixs = brk_ixs;
