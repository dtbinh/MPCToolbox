function [u, X, FVAL, EXITFLAG] = qp_fullstate(A, B, Q, R, Nc, du, dx, x0)
%% QP definition
nu = size(B,2); %number of inputs
nx = size(A,1); %number of states
du(end/2+1:end) = -du(end/2+1:end); %convert negative constraints to positive
dx(end/2+1:end) = -dx(end/2+1:end); %convert negative constraints to positive
Cx = [eye(nx); -eye(nx)];
Cu = [eye(nu); -eye(nu)];
Csmall = blkdiag(Cu,Cx); 
Qsmall = blkdiag(R,Q);
Asmall = [-B eye(nx)];
bsmall= zeros(nx,1);
C_hat = Csmall;
Q_hat = Qsmall;
A_hat = [-B eye(nx)];
b_hat = A*x0;
for i = 1:Nc-1
    %Add another element to the block diagonal matrices
    C_hat = blkdiag(C_hat, Csmall);
    Q_hat = blkdiag(Q_hat, Qsmall);
    A_hat = blkdiag(A_hat, Asmall);
    %Add '-A' to the subdiagonal
    lines_l = i*nx + 1;
    lines_u = (i+1)*nx;
    cols_l = i*nu + (i-1)*nx + 1;
    cols_u = i*nu + i*nx;
    A_hat(lines_l: lines_u, cols_l: cols_u)= -A;
end
d_hat = repmat([du;dx], [Nc 1]);
b_hat = [b_hat; repmat(bsmall, [Nc-1 1])];
q = zeros(size(Q_hat,1),1);
%% QP solver
% options = optimoptions('quadprog', ...
%     'Algorithm', 'interior-point-convex', 'Display', 'off'); %Matlab 2013
options = optimset('Algorithm', 'interior-point-convex', 'Display', 'off'); % Matlab 2011
[Z,FVAL,EXITFLAG] = quadprog(Q_hat, q, C_hat, d_hat, A_hat, b_hat,[],[],[], options);
%% Return variables
X = reshape(Z, nu+nx,[]);
u = X(1:nu,:);
X = X(nu+1:end,:);