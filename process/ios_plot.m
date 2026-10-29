function [] = ios_plot()

pth = '/Users/jeremy/Desktop/gpr26_175_ios/20261022/stacks/data.mat';
load(pth)

%%

tlim = [0 3];

for i = [2 5 8]

    t = time_vecs{i};
    bnds = t>tlim(1) & t<tlim(2);
    vMask = vMasks{i};

    windowMask = windowMasks{i};

    ep = rn_eps{i};
    h2 = fspecial('gaussian',50,10);
    for j = 1:size(ep,3)
        for k = 1:size(ep,4)
            ep(:,:,j,k) = imfilter(ep(:,:,j,k),h2);
        end
    end

    ep = ep .* windowMask;

    ep = ep .* vMask;

    bs_ix = t<0;
    bs = mean(ep(:,:,bs_ix,:),3);
    ep_bs = ep-bs;

    v = var(reshape(ep_bs,size(ep_bs,1)*size(ep_bs,2)*size(ep_bs,3),[]));
    bts = v > median(v) + 1.5 * std(v);

    ep_bs(:,:,:,bts) = [];

    p = [1 25];

    trls_win = squeeze(mean(mean(mean(ep_bs(:,:,bnds,:)))));
  
    [~,min_trls]=sort(trls_win,'ascend');
    min_trls_ix = round(prctile(1:numel(min_trls),p));

    image_ep = mean(mean(ep_bs(:,:,bnds,min_trls(min_trls_ix(1):min_trls_ix(2))),3),4);
    figure
    imagesc(image_ep)


    ios_imgs{i} = image_ep;

end

%save([data_pth{1} 'ios_images.mat'],'ios_imgs','run_names');

grn_im = grn_ims{2};
grn_im = imfilter(grn_im,h2);
sz = size(grn_im);
grn_im = reshape(grn_im,8,sz(1)/8,8,sz(2)/8);
grn_im = squeeze(mean(mean(grn_im,1),3));

clip = -2;

figure
ax1 = axes;
ax2 = axes;

x1 = ios_imgs{2};
x1 = zscore(x1(:));
x1 = reshape(x1,[256 256]);
x1(x1>clip) = NaN;

x2 = ios_imgs{5};
x2 = zscore(x2(:));
x2 = reshape(x2,[256 256]);
x2(x2>clip) = NaN;

x3 = ios_imgs{8};
x3 = zscore(x3(:)); 
x3 = reshape(x3,[256 256]);
x3(x3>clip) = NaN;

msk1 = x1;
msk1(isnan(msk1))=0;
msk1(msk1<0)=1;

msk2 = x2;
msk2(isnan(msk2))=0;
msk2(msk2<0)=2;

msk3 = x3;
msk3(isnan(msk3))=0;
msk3(msk3<0)=3;

%
imagesc(ax1,grn_im)
axis image
axis off

colormap(ax1,'gray');

ios_msk = msk1+msk2+msk3;
ios_msk(ios_msk>3) = 0;
imagesc(ax2,ios_msk);
colormap(ax2);

ax2.Visible = 'off';
axis image
axis off

ad = ios_msk>0;
ad = ad.*0.3;
set(ax2.Children(1), 'Alphadata', ad); 
clr_mp = jet(numel(unique(ios_msk)));
clr_mp(1,:) = [0 0 0];
ax2.Colormap = clr_mp;
colorbar

f = gcf;
c = f.Children(1);
c.Ticks = [1.2 2 3];
c.TickLabels = {'C1','C2','B2'};

linkprop([ax1 ax2],'Position'); 


