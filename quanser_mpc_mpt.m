clear
addpath('./quanser');
addpath('./util');
%% System initialization
x0 = [30; 0; -5; 0; 40; 0]; %Initial state
xref = [20; 0; 0; 0; 0; 0]; %Reference state 
u0 = [2; 2]; % [Vf Vb] initial inputs
N = 1000; % samples
h = 0.1; % s - sampling time
nu = 2;
nx = 6;
Np = 3; % control and prediction horizon
Nc = 3;
%% Cost matrices and constraints
Q = diag([10, 1, 10, 1, 10, 1],0);
R = diag([0.01, 0.01],0);
dx = [60, inf, 45, inf, 180, inf;
      -60, -inf, -45, -inf, -180, -inf]; %state constraints, positive and negative
du = [5, 5;
      0, 0]; %input constraints
%% Solver initialization
X = zeros(nx, N); %save all states, for plotting
U = zeros(nu, N); %save all inputs
x = x0;
xr = x0; % 'real' x
u = u0;
%% MPC solve
for i = 1:N
    %% Update SL Model
    if mod(i,Np) == 0 || i == 1
        [A,B,g] = quanser_cont_sl(x,u); %recalculate (A,B,g)
        [x_o, u_o] = affine_eq(A,B,g);
        du_bar = du - repmat(u_o',2,1);
        dx_bar = dx - repmat(x_o',2,1);
        Ad = eye(nx) + h*A;
        Bd = h*B;
        sys = LTISystem('A', Ad, 'B', Bd, 'Ts', h); % check this?
        ctrl = MPCController(sys, Nc);
        ctrl.model.x.min = dx_bar(2,:)';
        ctrl.model.x.max = dx_bar(1,:)';
        ctrl.model.u.min = du_bar(2,:)';
        ctrl.model.u.max = du_bar(1,:)';
        ctrl.model.x.penalty = QuadFunction(Q);
        ctrl.model.u.penalty = QuadFunction(R);
        fprintf('%d ', i);
        if mod(i,20*Np) == 0
            fprintf('\n');
        end
    end
    %% Get next command
    xbar = x - x_o;
    ubar = ctrl.evaluate(xbar);
    u = ubar + u_o;
    %% Data logging
    X(:,i) = x; % save states
    U(:,i) = u; % save inputs
    %% Send to plant
    xr = quanser_disc_nl(xr,u,h);
    x = xr + 0.0*rand(nx,1) + 0.0*rand(nx,1).*xr;
end
%% Plotting
quanser_plot(X,U,dx, du,'MPC-SL(MPT) Quanser Plot',5);
quanser_phase_plot(X, 'MPC-SL(MPT) Quanser Phase-Plot',6);
