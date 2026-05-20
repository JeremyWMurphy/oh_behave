function justStream(src,~,ax,up_every)

% OUTPUT from Teensy is,
% <loopNum, FrameNum, State, TrialOutcome, Ao0, Ao1, Licks, Wheel>

% read data
data = read(src,up_every,'char');

% if we have some data
if ~isempty(data)

    % parse for graphing and tracking teensy state -- this need to be as
    % efficient as possible
    strt = find(data=='<',1,'first');
    fin = find(data=='>',1,'last');
    data = data(strt:fin);
    data = sscanf(data,'<%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d>\n');    
    data = reshape(data,11,[])';

    data(data(:,7)==0,7) = NaN;

    % set data graphs
    ax.Children(8).set('Ydata',[ax.Children(8).YData(size(data,1)+1:end) data(:,11)']); % barcode
    ax.Children(7).set('Ydata',[ax.Children(7).YData(size(data,1)+1:end) 3 + [diff(data(:,2)') 0]]); % frames
    ax.Children(6).set('Ydata',[ax.Children(6).YData(size(data,1)+1:end) 5 + data(:,9)']); % reward valve
    ax.Children(5).set('Ydata',[ax.Children(5).YData(size(data,1)+1:end) 7 + data(:,10)']); % remove valve
    ax.Children(4).set('Ydata',[ax.Children(4).YData(size(data,1)+1:end) 9 + data(:,8)'./1024]); % wheel
    ax.Children(3).set('Ydata',[ax.Children(3).YData(size(data,1)+1:end) 11 + data(:,6)'./4095]); % opto
    ax.Children(2).set('Ydata',[ax.Children(2).YData(size(data,1)+1:end) 13 + 5*(data(:,5)'./4095)]); % ao0
    ax.Children(1).set('Ydata',[ax.Children(1).YData(size(data,1)+1:end) 14 + data(:,7)']); % licks
   
end


end
