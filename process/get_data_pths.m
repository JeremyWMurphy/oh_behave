function [good_fldrs,runs,good_dates] = get_data_pths(pth,id,strt,fin)

strt = datetime(strt,'InputFormat','yyyy-MM-dd');
fin = datetime(fin,'InputFormat','yyyy-MM-dd');

nfo = dir(fullfile(pth,[id '*']));
fldrs = vertcat(nfo.name);
dates = datetime(fldrs(:,5:end),'InputFormat','yyyy-MM-dd_''T''HH-mm-ss');
dates = dateshift(dates, 'start', 'day');

good_dates_tf = dates >= strt & dates <= fin;
good_fldrs = fldrs(good_dates_tf,:);
[~,~,runs] = unique(dates(good_dates_tf));

good_dates = dates(good_dates_tf);









