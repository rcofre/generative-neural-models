function [J, VK] = fit_Kpairwise(data, J0, VK0, options)
%fit_Kpairwise Fits K-pairwise model to data. 
%This function uses gradient descent on negative log-likelihood with
%gradient estimated by averaging over samples from the model. Samples at
%T+1th iteration are generated by applying the MCMC transition matrix to
%samples at Tth iteration.
%
% Syntax: [J, VK] = fit_Kpairwise(data, J0, VK0, options)
%
% Inputs:
%   data: Binary array of size number of samples x number of neurons.
%   J0: Initial guess for J.
%   VK0: Initial guess for VK.
%   options: Struct with fields corresponding to hyperparameters.
%     .learning_rate: Learning rate for gradient descent.
%     .iter: Number of gradient descent iterations.
%     .M_samples: Number of samples used for estimating gradient.
%     .gibbs_steps: Number of single neuron flips that take you from 
%                   samples at Tth iteration to samples at T+1th iteration.
%
% Outputs:
%   J: Learned J.
%   VK: Learned VK.
%
% Required m-files: sample_Kpairwise.m, grad_descent.m

% Initialize
[M,n] = size(data);
J0_lin = J0(:);
if isrow(VK0)
    VK0 = VK0';
end
pars0 = [J0_lin; VK0];
% Estimate empirical covariance which is to be reproduced by model.
emp_cov = (data'*data)/M;
% Estimate empirical p(K) which is to be reproduced by model.
K_data = sum(data, 2);
p_K_emp = zeros(n+1,1);
for i = 1:(n+1)
    p_K_emp(i) = nnz(K_data == (i-1))/M;
end
% Initialize gibbs chain at data distribution.
samples = data(randi(length(data), options.M_samples, 1),:);
% Start a parallel pool.
pool = gcp;
n_pools = pool.NumWorkers;
% Divide samples into batches to be processed in parallel.
samples = samples(1:(floor(length(samples)/n_pools)*n_pools),:);
M_samples = size(samples, 1);
samples_batch = zeros(M_samples/n_pools, n, n_pools);
for k = 1:n_pools
    idx_samples = ((k-1)*(M_samples/n_pools) + 1):(k*M_samples/n_pools);
    samples_batch(:,:,k) = samples(idx_samples,:);
end
% Transform samples into samples from the initial model
burn_in = 10*options.gibbs_steps; % Rough guess for MCMC burn-in time.
parfor k = 1:n_pools
    samples = squeeze(samples_batch(:,:,k));
    samples = sparse(samples);
    samples_batch(:,:,k) = sample_Kpairwise(samples, J0, VK0, burn_in);
end
% Minimize negative log-likelihood.
grad = @(pars, samples_batch)Dloss(pars, data, emp_cov, p_K_emp, ...
                                   samples_batch, options.gibbs_steps, ...
                                   n_pools);
pars = grad_descent(grad, pars0, options.learning_rate, ... 
                    samples_batch, options.iter);
J_lin = pars(1:(n^2));
VK = pars((n^2+1):end);
J = reshape(J_lin, [n,n]);
end


function [Dloss, samples_batch] = Dloss(pars, data, emp_cov, p_K_emp, ...
                                        samples_batch, gibbs_steps, ...
                                        n_pools)
%Samples the current model J, VK by applying MCMC to past samples in 
%"samples_batch", and uses these to estimate the loss gradient at the
%current model. Processes several batches in parallel.

% Initialize.
n = size(data, 2);
J_lin = pars(1:(n^2));
VK = pars((n^2+1):end);
J = reshape(J_lin, [n,n]);
% Draw samples and estimate model covariance matrix and p(K)
model_covs = zeros(n^2, n_pools);
p_Ks = zeros(n+1, n_pools);
parfor k = 1:n_pools
    samples = squeeze(samples_batch(:,:,k));
    samples = sparse(samples);
    samples = sample_Kpairwise(samples, J, VK, gibbs_steps);
    samples_batch(:,:,k) = samples;
    model_cov_tmp = samples'*samples/length(samples);
    model_covs(:,k) = model_cov_tmp(:);
    K_tmp = sum(samples, 2);
    p_K_tmp = zeros(n+1, 1);
    for i = 1:(n+1)
        p_K_tmp(i) = nnz(K_tmp == (i-1))/length(samples);
    end
    p_Ks(:, k) = p_K_tmp;
end
model_cov = sum(model_covs, 2)/n_pools;
p_K_model = sum(p_Ks, 2)/n_pools;
% Calculate gradient.
DJij = (-model_cov + emp_cov(:));
DK = (-p_K_model + p_K_emp);
Dloss = [DJij; DK];
end