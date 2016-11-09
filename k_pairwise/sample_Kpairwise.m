function samples = sample_Kpairwise(samples, J, VK, n_steps)
%sample_Kpairwise Samples K-pairwise model.
%Applies "n_steps" of Gibbs sampling steps to every row in samples.
%
% Syntax: samples = sample_Kpairwise(samples, J, VK, n_steps)
%
% Inputs:
%   samples: Initial samples for Gibbs sampling, 
%            size is number of samples x number of neurons.
%   J: The coupling matrix of the K-pairwise model.
%   VK: The VKs of the K-pairwise model.
%   n_steps: Number of Gibbs sampling steps to apply to every sample.
%
% Outputs:
%   samples: (Approximate) samples from the K-pairwise model.

% Initialize.
[M,n] = size(samples);
neuron_id = 1;
K = sum(samples,2);
J_offdiag = J;
J_offdiag(eye(n)==1)=0;
% Perform n_steps of Gibbs sampling.
for j = 1:n_steps
    K_others = K - samples(:,neuron_id);
    delta_E = J(neuron_id, neuron_id) + 2*samples*J_offdiag(:,neuron_id) + VK(K_others + 2) - VK(K_others + 1);
    p_spike = 1./(1+exp(delta_E));
    samples(:,neuron_id) = rand(M,1) < p_spike;
    K = K_others + samples(:,neuron_id);
    neuron_id = neuron_id + 1;
    if neuron_id == n+1
        neuron_id = 1;
    end
end


end

