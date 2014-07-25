function [u, X, FVAL, EXITFLAG, OUTPUT] = nmpc_fullspace(...
    handle_nlmodeld, h, Q, R, Nc, du, dx, x0, xref, uref, Xprev, uprev)
%NMPC_FULLSPACE Compute the input sequence and predicted output using
%Nonlinear MPC fullspace (simultaneous) approach.
%   [u, X, FVAL, EXITFLAG, OUTPUT] = nmpc_fullspace(handle_nlmodeld, h, ...
%       Q, R, Nc, du, dx, x0, xref, Xprev, uprev). Compute the inputs using
%       the nonlinear (discrete) model function <handle_nlmodel>, using
%       sample time <h>.
%
%   Arguments:
%   - handle_nlmodeld: the discrete nonlinear model function
%   - h: sampling time
%   - Q,R: the weighting matrices in the cost function
%   - Nc: the control horizon
%   - du, dx: the constraint vectors for inputs and states. *du* is a 
%       2-by-nu matrix containing constraints for inputs. First line is 
%       upper bound, second is lower bound for each input. *dx* is a 
%       2-by-nx matrix with constraints for states. If the input/state has 
%       no lower bound, set it's corresponding value to -Inf. Conversely, 
%       if the input/state has no upper bound, set to Inf. 
%       nu - number of inputs, nx - number of states.
%   - x0: the current( initial) state of the system
%   - xref: the desired( reference) state. Must have nx lines, but can have
%       number of columns in the range [1, Nc].
%   - uref: the reference input (stabilizing input). Must have nu lines,
%       but can have number of columns in the range [1, Nc]
%   - Xprev: the previously obtained state prediction. This will be used as
%       a starting point for the algorithm, along with uprev. Can be an 
%       empty array if there is no previous solution.
%   - uprev: the previously obtained input solution. This will be used as
%       a starting point for the algorithm. Can be an empty array if there 
%       is no previous solution.
%   Output arguments:
%   - u: a nu-by-Nc matrix of computed inputs. u(:,1) must be used.
%   - X: a nx-by-Nc matrix of predicted states.
%   - FVAL: the object function value given by the numerical solver, 
%       fmincon.
%   - EXITFLAG: the exitflag from the solver. See 'help fmincon' for 
%       details. EXITFLAG is > 0 if a solution has been found.
%   - OUTPUT: the output from the solver. See 'help fmincon' for details.

%% Argument processing
nu = size(du,2); %number of inputs
nx = size(dx,2); %number of states
if isempty(xref)
    xref = zeros(nx, Nc);
end
if isempty(uref)
    uref = zeros(nu, Nc);
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
if ~isa(handle_nlmodeld, 'function_handle')
    error('handle_nlmodeld must be a function handle.');
end
%% Nonlinear constraints function
    function [C,Ceq] = nonlconfunc(z)
        C = [];
        Xl = reshape(z, nu+nx,[]);
        ul = Xl(1:nu,:);
        Xl = Xl(nu+1:end,:);
        x = x0;
        Ceq = zeros(size(z));
        for i = 1:Nc
            b = Xl(:,i);
            x = handle_nlmodeld(x, ul(:,i), h);
            dif = b - x; %x_{k+1} - f(x_k)
            ceq = [zeros(nu, 1); dif]; %inputs have no eq constraints
            idx_start = (i-1)*(nx+nu)+1;
            idx_end = i*(nx+nu);
            Ceq(idx_start:idx_end) = ceq;
        end
    end
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
Q_hat = Qsmall;
for i = 1:Nc-1
    %Add another element to the block diagonal matrices
    Q_hat = blkdiag(Q_hat, Qsmall);
end
zsmall = [ uref; xref];
zref = zsmall(:);
q = -Q_hat*zref;
z0 = Zprev(:);
%% Nonlinear solver
rel = version('-release');
rel = rel(1:4); %just the year
relnum = str2double(rel);
switch relnum
    case 2010
        options = optimset('Display', 'off');
    case 2011
        options = optimset(...
            'Algorithm', 'sqp', 'Display', 'off');
    case 2013
        options = optimoptions('fmincon', ...
            'Algorithm', 'sqp', 'Display', 'off');
    otherwise
        error('Can''t set solver options for this version of Matlab');
end
[Z ,FVAL,EXITFLAG, OUTPUT] = fmincon(@(z) 0.5*z'*Q_hat*z + q'*z, z0, [],...
    [], [], [], LB, UB, @nonlconfunc, options);
%% Return variables
X = reshape(Z, nu+nx,[]);
u = X(1:nu,:);
X = X(nu+1:end,:);
end