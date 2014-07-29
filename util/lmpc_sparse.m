function [u, X, FVAL, EXITFLAG, OUTPUT] = lmpc_sparse(A, B, Q, R, Nc, ...
    du, dx, x0, xref, uref, Xprev, uprev)
%LMPC_SPARSE Compute the input sequence and predicted output using Linear
%MPC sparse (simultaneous) formulation.
%
%   [U, X, FVAL, EXITFLAG, OUTPUT] = LMPC_SPARSE(A, B, Q, R, Nc, DU, DX,...
%   X0, XREF, UREF, XPREV, UPREV). Compute the input sequence U for the 
%   model described by the model (A,B) using MPC sparse formulation, Nc as
%   a control and prediction horizon, weighting matrices Q and R. DU and DX
%   describe the constraints for the inputs and states, X0 is the starting
%   state, XREF is the state trajectory, UREF is the input trajectory and
%   UPREV contains the last solution, used for a 'warm start'. The input
%   sequence is returned in U, the predicted states in X.FVAL, EXITFLAG and
%   OUTPUT are returned by quadprog internally. See 'help quadprog' for
%   details.
%
%   Input arguments:
%   - A, B: the state-space matrices describing the system dynamic
%   - Q, R: the weighting matrices in the cost function
%   - Nc: the control horizon
%   - DU, DX: the constraint vectors for inputs and states. DU is a 2-by-nu
%   matrix containing constraints for inputs. First line is upper bound,
%   second is lower bound for each input. DX is a 2-by-nx matrix with
%   constraints for states. If the input/state has no lower bound, set it's
%   corresponding value to -Inf. Conversely, if the input/state has no
%   upper bound, set to Inf. 
%       nu - number of inputs, nx - number of states.
%   - X0: the current( initial) state of the system
%   - XREF: the desired( reference) state. Must have nx lines, but can have
%   number of columns in the range [1, Nc].
%   - UREF: the reference input (stabilizing input). Must have nu lines,
%   but can have number of columns in the range [1, Nc]
%   - XPREV: the previously obtained state prediction. This will be used as
%   a starting point for the algorithm, along with uprev. Can be an empty
%   array if there is no previous solution.
%   - UPREV: the previously obtained input solution. This will be used as a
%   starting point for the algorithm. Can be an empty array if there is no
%   previous solution.
%
%   Output arguments:
%   - U: a nu-by-Nc matrix of computed inputs. U(:,1) must be used.
%   - X: a nx-by-Nc matrix of predicted states.
%   - FVAL: the object function value given by the numerical solver, 
%   quadprog.
%   - EXITFLAG: the exitflag from the solver. See 'help quadprog' for 
%   details. EXITFLAG is > 0 if a solution has been found.
%   - OUTPUT: the output from the solver. See 'help quadprog' for details.
%
%   Details for the sparse MPC formulation used can be found in 'Metode de
%   optimizare numerica'(romanian) by prof. I. Necoara, pg 237.

%% Argument processing
nu = size(B,2); %number of inputs
nx = size(A,1); %number of states
if isempty(xref)
    xref = zeros(nx,1);
end
if isempty(uref)
    uref = zeros(nu,1);
end
difx = Nc - size(xref,2);
difu = Nc - size(uref, 2);
% If xref does not have enough columns, append the last column difx times
if difx > 0
    xref = [xref, repmat(xref(:,end), [1 difx])];
end
% For uref same as for xref above
if difu > 0
    uref = [uref, repmat(uref(:,end), [1 difu])];
end
if isempty(Xprev)
    %if there is no previous solution, use the reference as a start point
    Xprev = xref;
else
    Xprev = [Xprev(:,1:end-1), xref(:,end)]; %shift the previous solution
end
if isempty(uprev)
    %if there is no previous solution, use the reference as a start point
    uprev = uref;
else
    uprev = [uprev(:,1:end-1), uref(:,end)]; %shift the previous solution
end
Zprev = [uprev; Xprev];
%% QP definition
ubx = dx(1,:)';
lbx = dx(2,:)';
ubu = du(1,:)';
lbu = du(2,:)';
lb = [lbu; lbx];
ub = [ubu; ubx];
LB = repmat(lb, Nc, 1);
UB = repmat(ub, Nc, 1);
Qsmall = blkdiag(R,Q);
Asmall = [-B eye(nx)];
bsmall= zeros(nx,1);
Q_hat = Qsmall;
A_hat = [-B eye(nx)];
b_hat = A*x0;
for i = 1:Nc-1
    %Add another element to the block diagonal matrices
    Q_hat = blkdiag(Q_hat, Qsmall);
    A_hat = blkdiag(A_hat, Asmall);
    %Add '-A' to the subdiagonal
    lines_l = i*nx + 1;
    lines_u = (i+1)*nx;
    cols_l = i*nu + (i-1)*nx + 1;
    cols_u = i*nu + i*nx;
    A_hat(lines_l: lines_u, cols_l: cols_u)= -A;
end
b_hat = [b_hat; repmat(bsmall, [Nc-1 1])];
zsmall = [ uref; xref];
zref = zsmall(:);
q = -Q_hat*zref;
z0 = Zprev(:);
%% QP solver
rel = version('-release');
rel = rel(1:4); %just the year
relnum = str2double(rel);
switch relnum
    case 2010
        options = optimset(...
            'Display', 'off', 'Diagnostics', 'off', 'LargeScale', 'off');
    case 2011
        options = optimset(...
            'Algorithm', 'interior-point-convex', 'Display', 'off');
    case 2013
        options = optimoptions('quadprog', ...
            'Algorithm', 'interior-point-convex', 'Display', 'off');
    otherwise
        error('Can''t set solver options for this version of Matlab');
end
[Z,FVAL,EXITFLAG, OUTPUT] = quadprog(Q_hat, q, [], [], A_hat, b_hat, ...
    LB,UB, z0, options);
%% Return variables
X = reshape(Z, nu+nx,[]);
u = X(1:nu,:);
X = X(nu+1:end,:);