
Fs = 7.44;
win_s = 120;

x = D.new_F;

win_len = ceil(Fs*win_s);

idx = hankel(1:win_len, win_len:size(x,2));

z = [];
for i = 1:size(x,1)

    xx = x(i,:);
    y=xx(idx);
    ps = prctile(y,25);
    xx = xx(1:end-(win_len-1));
    xx = (xx-ps)./ps;

    z = [z;xx];
end

z(isoutlier(max(z,[],2)),:) = [];

imagesc(z)
clim([0 5])