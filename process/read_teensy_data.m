function [D] = read_teensy_data(pth,runs)

D = [];

dt = datetime(runs{1}(5:end),'InputFormat','yyyy-MM-dd_''T''HH-mm-ss');

% after 4/29/2026 I added yet another column to the teensy output
if dt > datetime('2026_04_29_17-33-30','InputFormat','yyyy_MM_dd_HH-mm-ss')

    if nargin > 1

        last_ix = 0;

        for i = 1:numel(runs)

            fid = fopen([pth runs{i} '/data_stream.csv']);
            data = fscanf(fid,'<%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d>\n');
            fclose(fid);

            r = mod(numel(data),11); % find an incomplete line at the end
            data = data(1:end-r);
            data = reshape(data,11,[])';
            strt = find(data(:,1)==0,1,'first'); % find teensy restart (this is always done at the start of the experiment)
            data = data(strt:end,:);
            data(:,1) = data(:,1) + last_ix;
            D = cat(1,D,data);
            last_ix = data(end,1);

        end

    else

        fid = fopen([pth '/data_stream.csv']);
        data = fscanf(fid,'<%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d>\n');
        fclose(fid);

        r = mod(numel(data),11); % find an incomplete line at the end
        data = data(1:end-r);
        data = reshape(data,11,[])';
        strt = find(data(:,1)==0,1,'first'); % find teensy restart (this is always done at the start of the experiment)
        data = data(strt:end,:);
        data(:,1) = data(:,1);
        D = data;

    end


    D = array2table(D,'VariableNames',{'LoopNum','FrameNum','State','TrialOutcome','Ao0','Ao1','Licks','Wheel','Reward','Vac','Barcode'});
    summary(D)


else

    if nargin > 1
        last_ix = 0;

        for i = 1:numel(runs)

            fid = fopen([pth runs{i} '/data_stream.csv']);
            data = fscanf(fid,'<%d,%d,%d,%d,%d,%d,%d,%d,%d,%d>\n');
            fclose(fid);

            r = mod(numel(data),10); % find an incomplete line at the end
            data = data(1:end-r);
            data = reshape(data,10,[])';
            strt = find(data(:,1)==0,1,'first'); % find teensy restart (this is always done at the start of the experiment)
            data = data(strt:end,:);
            data(:,1) = data(:,1) + last_ix;
            D = cat(1,D,data);
            last_ix = data(end,1);

        end

    else

        fid = fopen([pth '/data_stream.csv']);
        data = fscanf(fid,'<%d,%d,%d,%d,%d,%d,%d,%d,%d,%d>\n');
        fclose(fid);

        r = mod(numel(data),10); % find an incomplete line at the end
        data = data(1:end-r);
        data = reshape(data,10,[])';
        strt = find(data(:,1)==0,1,'first'); % find teensy restart (this is always done at the start of the experiment)
        data = data(strt:end,:);
        data(:,1) = data(:,1);
        D = data;

    end

    D = array2table(D,'VariableNames',{'LoopNum','FrameNum','State','TrialOutcome','Ao0','Ao1','Licks','Wheel','Reward','Vac'});
    summary(D)

end


