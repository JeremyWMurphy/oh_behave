function [bad_trials] = mov_d_thresh(fas,cws,hits,misses)

d_thresh = 0;

fas(fas==1) = 4;
cws(cws==1) = 3;
misses(misses==1) = 2;

beh_vec = fas+cws+misses+hits;

win_sz_hlf = 25;
ixs=find(beh_vec);

d_mov_win = zeros(numel(ixs),1);
for i = win_sz_hlf+1:numel(ixs)-(win_sz_hlf+1)

    win = ixs(i-win_sz_hlf:i+win_sz_hlf);

    f = sum(beh_vec(win)==4);
    m = sum(beh_vec(win)==2);
    h = sum(beh_vec(win)==1);
    c = sum(beh_vec(win)==3);

    if f == 0
        f = 0.5;
    end
    
    if m == 0
        m = 0.5;
    end

    if h == 0
        h = 0.5;
    end
    
    if c == 0
        c = 0.5;
    end

    pHit = h/(h+m); % pHit = P(YES|SIGNAL)
    pFA  = f/(f+c); % pFA = P(YES|NOISE)
    %-- Convert to Z scores, no error checking

    zHit = norminv(pHit);
    zFA  = norminv(pFA);

    %-- Calculate d-prime
    d = zHit - zFA;
    d_mov_win(i) = d;

end

win = ixs(1:win_sz_hlf*2+1);
f = sum(beh_vec(win)==4);
m = sum(beh_vec(win)==2);
h = sum(beh_vec(win)==1);
c = sum(beh_vec(win)==3);
if f == 0
    f = 0.5;
end

if m == 0
    m = 0.5;
end

if h == 0
    h = 0.5;
end
if c == 0
    c = 0.5;
end
pHit = h/(h+m); % pHit = P(YES|SIGNAL)
pFA  = f/(f+c); % pFA = P(YES|NOISE)
%-- Convert to Z scores, no error checking
zHit = norminv(pHit);
zFA  = norminv(pFA);
%-- Calculate d-prime
d_first = zHit - zFA;

win = ixs(end-win_sz_hlf*2+1:end);
f = sum(beh_vec(win)==4);
m = sum(beh_vec(win)==2);
h = sum(beh_vec(win)==1);
c = sum(beh_vec(win)==3);
if f == 0
    f = 0.5;
end
if m == 0
    m = 0.5;
end
if h == 0
    h = 0.5;
end
if c == 0
    c = 0.5;
end
pHit = h/(h+m); % pHit = P(YES|SIGNAL)
pFA  = f/(f+c); % pFA = P(YES|NOISE)
%-- Convert to Z scores, no error checking
zHit = norminv(pHit);
zFA  = norminv(pFA);
%-- Calculate d-prime
d_last = zHit - zFA;

bad_trials = find(d_mov_win<=d_thresh);
bad_trials(bad_trials<=win_sz_hlf*2+1) = [];
bad_trials(bad_trials>=size(d_mov_win,1)-(win_sz_hlf*2+1)) = [];

if d_first <= d_thresh
    bad_trials = [(1:win_sz_hlf*2+1)'; bad_trials];
end

if d_last <= d_thresh
    bad_trials = [bad_trials; (size(d_mov_win,1)-(win_sz_hlf*2+1):size(d_mov_win,1))'];
end
