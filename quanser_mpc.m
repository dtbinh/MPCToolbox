clear
addpath('./quanser');
addpath('./util');
%% System initialization
x0 = [15; 0; 0; 0; 20; 0]; %Initial state
u0 = [2; 2]; % [Vf Vb] initial inputs
N = 2000; % samples
h = 0.1; % s - sampling time
nu = 2;
nx = 6;
Np = 5; % control and prediction horizon
Nc = 5;
%% Cost matrices and constraints
Q = diag([1, 0.01, 0.25, 0.01, 0.01, 0.01],0);
R = diag([1, 1],0);
dx = [45, inf, 50, inf, inf, inf;
      -45, -inf, -50, -inf, -inf, -inf]; %state constraints, positive and negative
du = [5, 5;
      -1, -1]; %input constraints
%% Solver initialization
X = zeros(nx, N); %save all states, for plotting
U = zeros(nu, N); %save all inputs
x = x0;
u = u0;
[A,B,g] = quanser_cont_sl(x,u); %Initial (A,B,g) pair
Ad = eye(nx) + h*A;
Bd = h*B;
x_o = x;
u_o = linsolve(B, -g - A*x);
%% MPC solve
for i = 1:N
    %% Update SL Model
    if mod(i,Np) == 0
        [A,B,g] = quanser_cont_sl(x,u); %recalculate (A,B,g)
        Ad = eye(nx) + h*A;
        Bd = h*B;
        x_o = x;
        u_o = linsolve(B, -g - A*x);
        fprintf('%d ', i);
        if mod(i,20*Np) == 0
            fprintf('\n');
        end
    end
    %% Get next command
    [ue, Xe,FVAL,EXITFLAG] = qp_fullstate(Ad, Bd, Q, R, Nc, du, dx, x);
    if EXITFLAG ~= 1
        fprintf('Iteration %d\n',i)
        error('Quadprog error ');
    end
    ubar = ue(:,1); %use only the first command in the sequence
    u = ubar + u_o;
    %% Data logging
    X(:,i) = x; % save states
    U(:,i) = u; % save inputs
    %% Send to plant
    [Tout, Yout] = ode45(@quanser_cont_nl, [0 h], [x; u]); %f(xk, uk)
    xr = Yout(end, 1:6)'; %get new real state xr, i.e. xr = x(k+1)
    % xr = xr + 0.11.*rand(nx,1).*x;
    % Derivation using euler method
    x(2) = (xr(1) - x(1))/h;
    x(4) = (xr(3) - x(3))/h;
    x(6) = (xr(5) - x(5))/h;
    % Copy absolute encoders values
    x(1) = xr(1);
    x(3) = xr(3);
    x(5) = xr(5);
end
%% Plotting
quanser_plot(X,U,dx, du,'MPC Quanser Plot',1);
quanser_phase_plot(X, 'MPC Quanser Phase-Plot',2);
%% Clean-up
rmpath('./quanser');
rmpath('./util');