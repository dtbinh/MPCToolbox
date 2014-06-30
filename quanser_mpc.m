clear
%% System initialization
x0 = [15; 0; 30; 0; 20; 0]; %Initial state
u0 = [2; 2]; % [Vf Vb] initial inputs
N = 100; % samples
h = 0.1; % s - sampling time
nu = 2;
nx = 6;
Np = 5; % control and prediction horizon
%% Cost matrices and constraints
Q = diag([1, 0.01, 1, 0.01, 1, 0.01],0);
R = diag([0.3, 0.3],0);
dx = [inf; inf; inf; inf; inf; inf;
      -inf; -inf; -inf; -inf; -inf; -inf]; %state constraints, positive and negative
du = [inf; inf;
      -inf; -inf]; %input constraints
%% Solver initialization
X = zeros(nx, N); %save all states, for plotting
U = zeros(nu, N); %save all inputs
x = x0;
u = u0;
[A,B,g] = quanser_cont_sl(x,u); %Initial (A,B,g) pair
C = [1 0 0 0 0 0; 0 0 0 0 1 0];
sys = ss(A,B,C,0);
sysd = c2d(sys,h, 'zoh');
sysd.a = eye(nx) + h*A;
sysd.b = h*B;
Ad = sysd.a;
Bd = sysd.b;
x_o = x;
u_o = linsolve(B, -g - A*x);
%% MPC solve
for i = 1:N
    [ue, Xe] = qp_fullstate(Ad, Bd, Q, R, Np, du, dx, x);
    ubar = ue(:,1); %use only the first command in the sequence
    u = ubar + u_o;
    X(:,i) = x; % save states
    U(:,i) = u; % save inputs
    [Tout, Yout] = ode45(@quanser_cont_nl, [0 h], [x; u]); %f(xk, uk)
    x = Yout(end, 1:6)'; %get new state, i.e. x = x(k)
    if mod(i,Np) == 0
        [A,B,g] = quanser_cont_sl(x,u); %recalculate (A,B,g)
        sys = ss(A,B,C,0);
        sysd = c2d(sys,h, 'zoh');
        sysd.a = eye(nx) + h*A;
        sysd.b = h*B;
        Ad = sysd.a;
        Bd = sysd.b;
        x_o = x;
        u_o = linsolve(B, -g - A*x);
%         fprintf('%d ', i);
%         if mod(i,20*Np) == 0
%             fprintf('\n');
%         end
    end
end
%% Plotting
t = 1:N;

figure(1);
clf;
whitebg([0 0 0]);
rows = 3;
cols = 3;

Sx = {'b-', 'r-', 'b-', 'r-', 'b-', 'r-'};
Su = {'y--', 'c:'};
titles = {'Elevation angle $\epsilon$'; 'Elevation speed $\dot{\epsilon}$';
    'Pitch angle $\theta$';'Pitch speed $\dot{\theta}$';
    'Travel angle $\phi$';'Travel speed $\dot{\phi}$'};
ylabels = {'[deg]','[deg/s]','[deg]','[deg/s]','[deg]','[deg/s]'};

%Plot inputs
for i = 1:cols
    subplot(rows, cols, i);
    plot(t, U(1,:) ,Su{1}, t, U(2,:), Su{2});
    xlabel('samples [k]');
    ylabel('[volts]');
    title('Inputs');
    grid on
    if i == 1
        legend('Vf', 'Vb', 'Location', 'Best');
    end
end

% Plot states
for i = 1:3
    %Plot state
    pos = i + cols;
    k = 2*i - 1;
    subplot(rows, cols, pos );
    plot(t, X(k,:) ,Sx{k});
    title(titles{k},'Interpreter','latex');
    xlabel('[k]');
    ylabel(ylabels{k});
    grid on 
    if i == 1
        legend('NL ode45', 'Location', 'Best');
    end
    %Plot secondary state - its derivative
    subplot(rows, cols, pos + cols);
    plot(t, X(k+1,:) ,Sx{k+1});
    title(titles{k+1},'Interpreter','latex');
    xlabel('[k]');
    ylabel(ylabels{k+1});
    grid on
end