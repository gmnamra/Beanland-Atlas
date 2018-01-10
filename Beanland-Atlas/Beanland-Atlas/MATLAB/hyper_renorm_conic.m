function [ conic_coeff ] = hyper_renorm_conic( data, weights, f0, req_theta_sim, max_iter)
%Use weighted hyper renormalisation to fit a conic to data points of
%varying intensity

sym = @(mat)0.5*(mat+mat.');

%Number of non-zero data elements
nnz_px = nnz(data);

%Hyper-renormalisation matrices
epsilon = zeros(6);
epsilon(5) = f0*f0;
epsilons = cell(nnz_px, 1);

V0 = zeros(6, 6);
V0(3, 3) = 4.0*f0*f0;
V0(4, 4) = 4.0*f0*f0;

M = zeros(6, 6);
N = zeros(6, 6);

e = zeros(6, 1);
e(1, 1) = 1.0;
e(3, 1) = 1.0;

%Construct the matrix M and sum the weights
k = 0;
sum_weights = 0.0;
[h, w] = size(data);
for y = 1:h
    for x = 1:w
        if data(y, x)
            %Create and store epsilon matrices for future calculations
            epsilon(0) = x*x;
            epsilon(1) = 2.0*y*x;
            epsilon(2) = y*y;
            epsilon(3) = 2.0*f0*x;
            epsilon(4) = 2.0*f0*y;
            epsilons{k} = epsilon;
            
            %Accumulate it into the hyper-renormalisation matrix with a
            %weight of 1.0
            M = M + epsilon * epsilon.';
            
            %Accumulate the pixel weight
            sum_weights = sum_weights + weights(y, x);
            
            k = k+1;
        end
    end
end

%Use the sum of the weights to normalise the wieghts
norm_weights = weights / sum_weights;

%Get the eigenvalues and eigenvectors of the matrix
[eig_vects, eig_val] = eigs(M, 5, 'largestreal');

%Calculate the psuedoinverse of M of truncated rank 5
M5 = eig_vects(:, 1)*eig_vects(:, 1) / eig_val(1, 1) + ...
    eig_vects(:, 2)*eig_vects(:, 2) / eig_val(2, 2) + ...
    eig_vects(:, 3)*eig_vects(:, 3) / eig_val(3, 3) + ...
    eig_vects(:, 4)*eig_vects(:, 4) / eig_val(4, 4) + ...
    eig_vects(:, 5)*eig_vects(:, 5) / eig_val(5, 5);

%Construct the matrix N
k = 0;
V = cell(nnz_px, 1);
for y = 1:h
    for x = 1:w
        if data(y, x)
            %Calculate the elements of V0 that vary
            V0(0, 0) = 4.0*x*x;
            V0(0, 1) = 4.0*x*y;
            V0(0, 3) = 4.0*f0*x;
            V0(1, 0) = 4.0*x*y;
            V0(1, 1) = 4.0*(x*x + y*y);
            V0(1, 2) = 4.0*x*y;
            V0(1, 3) = 4.0*f0*y;
            V0(1, 4) = 4.0*f0*x;
            V0(2, 1) = 4.0*x*y;
            V0(2, 2) = 4.0*y*y;
            V0(2, 4) = 4.0*f0*y;
            V0(3, 0) = 4.0*f0*x;
            V0(3, 1) = 4.0*f0*y;
            V0(4, 1) = 4.0*f0*x;
            V0(4, 2) = 4.0*f0*y;
            
            %Store the value so that it doesn't have to be recalculated
            V{k} = V0;
            
            %Accumulate weighted contribution to N
            N = N + norm_weights(y, x) * ( V{k} + 2*sym(epsilons{k}*e) - ...
            (1.0 / double(nnz_px)) * (dot(epsilons{k}, (M5*epsilons{k})) * V{k} + ...
            2.0 * sym( V{k} * M5 * epsilons{k} * epsilons{k}.' ) ) );
            
            k = k+1;
        end
    end
end

%Solve N * theta = 1/lambda * M * theta to get the eigenvector theta 
%corresponding to the largest eigenvalue 1/lambda
theta_prev = zeros(6, 1);
[theta, ~] = eigs(N/M, 1, 'largestreal');

%Reweight the eigenvalue equation construction until it's eigenvectors from
%successive iterations converge
theta = real(theta);
iter = 0;
while theta_sim(theta, theta_prev) > req_theta_sim && iter < max_iter
    theta_prev = theta;
    
    %Reconstruct the matrices of the eigenvector equation
    M = zeros(6, 6);
    N = zeros(6, 6);
    
    %Construct the matrix M and calculate the new weights
    W = cell(nnz_px, 1);
    k = 0;
    for y = 1:h
        for x = 1:w
            if data(y, x)
                %Calculate the new weight using the eigenvector and the
                %noise susceptibility
                W{k} = 1.0 / dot(theta, V{k}*theta);
                
                %Accumulate contributions to the hyper-renormalisation matrix with a
                %weight of 1.0
                M = M + W{k} * epsilons{k} * epsilons{k}.';

                k = k+1;
            end
        end
    end

    %Get the eigenvalues and eigenvectors of the matrix
    [eig_vects, eig_val] = eigs(M, 5, 'largestreal');

    %Calculate the psuedoinverse of M of truncated rank 5
    M5 = eig_vects(:, 1)*eig_vects(:, 1) / eig_val(1, 1) + ...
        eig_vects(:, 2)*eig_vects(:, 2) / eig_val(2, 2) + ...
        eig_vects(:, 3)*eig_vects(:, 3) / eig_val(3, 3) + ...
        eig_vects(:, 4)*eig_vects(:, 4) / eig_val(4, 4) + ...
        eig_vects(:, 5)*eig_vects(:, 5) / eig_val(5, 5);

    %Construct the matrix N
    k = 0;
    for y = 1:h
        for x = 1:w
            if data(y, x)
                %Accumulate weighted contribution to N
                N = N + norm_weights(y, x) * W{k} * ( V{k} + 2*sym(epsilons{k}*e) - ...
                (1.0 / double(nnz_px)) * (W{k} * dot(epsilons{k}, (M5*epsilons{k})) * V{k} + ...
                2.0 * sym( V{k} * M5 * epsilons{k} * epsilons{k}.' ) ) );

                k = k+1;
            end
        end
    end

    %Solve N * theta = 1/lambda * M * theta to get the eigenvector theta 
    %corresponding to the largest eigenvalue 1/lambda
    [theta, ~] = eigs(N/M, 1, 'largestreal');
    
    iter = iter + 1;
end

conic_coeff = theta;
end

function [ sim ] = theta_sim(theta1, theta2)
%Calculate a similarity measure between 2 vectors or arbitrary length. The
%metric is the larger amplitude times the angle, in radians, between them
%divided by  the smaller amplitude

theta1_amp = sqrt(sum(theta1*theta1));
theta2_amp = sqrt(sum(theta2*theta2));
angle = acos( dot(theta1, theta2) / theta1_amp + theta2_amp );

sim = angle*max([(theta1_amp/theta2_amp) (theta2_amp/theta1_amp)]); 
end