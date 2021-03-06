% The code is written by Jie Wen
% If you have any questions to the code, please send email to
% jiewen_pr@126.com
% Please cite the following papers if you use the code:
% Jie Wen, Zheng Zhang, Zhao Zhang, Lei Zhu, Lunke Fei, Bob Zhang, Yong Xu, 
% Unified Tensor Framework for Incomplete Multi-view Clustering and Missing-view Inferring, 
% AAAI Conference on Artificial Intelligence, 2021.

clear memory
clear all
clc

addpath('./twist');
Dataname = 'Caltech101-7';
percentDel = 0.3;
% Please select the best parameter for the other datasets!
lambda1 = 0.00001;
lambda2 = 0.01;
lambda3 = 0.01;

f = 1;
load(Dataname);
Datafold = [Dataname,'_percentDel_',num2str(percentDel),'.mat'];
load(Dataname);
load(Datafold);
                
ind_folds = folds{f}; 
clear folds
truthF = Y;
clear Y
numClust = length(unique(truthF));
                
for iv = 1:length(X)
    X1 = X{iv}';
    X1 = NormalizeFea(X1,0);
    ind_0 = find(ind_folds(:,iv) == 0);
    ind_1 = find(ind_folds(:,iv) == 1);
    X1(:,ind_0) = 0;    % 缺失视角补0
    Y{iv} = X1;         % 一列一个样本
    % ------------- 构造缺失视角的索引矩阵 ----------- %
    linshi_W = eye(size(X1,2));
    linshi_W(:,ind_1) = [];
    W{iv} = linshi_W;
    Ne(iv) = length(ind_0); 
    % ---------- 初始KNN图构建 ----------- %
    X1(:,ind_0) = [];
    options = [];
    options.NeighborMode = 'KNN';
    options.k = 11;
    options.WeightMode = 'Binary';      % Binary  HeatKernel
    Z1 = full(constructW(X1',options));

    linshi_W = diag(ind_folds(:,iv));
    linshi_W(:,ind_0) = [];
    Z_ini{iv} = linshi_W*max(Z1,Z1')*linshi_W';

    clear Z1 linshi_W
end
clear X X1 ind_0
X = Y;
clear Y


max_iter = 120;
miu = 1e-2;
rho = 1.2;

[Z,~,~,obj] = IMVTSC(Z_ini,X,Ne,W,lambda1,lambda2,lambda3,miu,rho,max_iter);

Sum_Z = 0;
nv = length(X);
for iv = 1:nv
    Sum_Z = Sum_Z+Z{iv};
end
Sum_Z = (1/nv)*Sum_Z;
Sum_Z = (Sum_Z+Sum_Z')*0.5;

Dd = diag(sqrt(1./(sum(Sum_Z,1)+eps)));
An = Dd*Sum_Z*Dd;
An(isnan(An)) = 0;
An(isinf(An)) = 0;
try
    [Fng, ~] = eigs(An,numClust);
catch ME
    if (strcmpi(ME.identifier,'MATLAB:eigs:ARPACKroutineErrorMinus14'))
        opts.tol = 1e-3;
        [Fng, ~] = eigs(An,numClust,opts.tol);
    else
        rethrow(ME);
    end
end
Fng(isnan(Fng))=0;
Fng = Fng./repmat(sqrt(sum(Fng.^2,2))+eps,1,numClust);  %optional

pre_labels = kmeans(real(Fng),numClust,'maxiter',1000,'replicates',20,'EmptyAction','singleton');
result_cluster = ClusteringMeasure(truthF, pre_labels)*100

