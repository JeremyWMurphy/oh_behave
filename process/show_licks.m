fs = 2e3;

licks = S.licks;

bin_sz_sec = 1;
bin_sz = fs * bin_sz_sec;
sz = size(licks,1);
bin_rem = mod(sz,bin_sz);
lck = licks(1:end-bin_rem);
lck = reshape(lck,bin_sz,[]);
lck = sum(lck,1)./bin_sz_sec;

t = bin_sz_sec:bin_sz_sec:length(lck)*bin_sz_sec;

figure, hold on
plot(t,lck,'r');

xlabel('Seconds')

%

bin_sz_sec = 60;
bin_sz = fs * bin_sz_sec;
sz = size(hit_vec,1);
bin_rem = mod(sz,bin_sz);
hit = hit_vec(1:end-bin_rem);
hit = reshape(hit,bin_sz,[]);
miss = miss_vec(1:end-bin_rem);
miss = reshape(miss,bin_sz,[]);

bin_hit_rate = sum(hit,1)./(sum(hit,1)+sum(miss,1));
bar(bin_hit_rate,'facecolor','r')