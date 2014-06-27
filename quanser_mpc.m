clear
%% System initialization
x0 = [15; 0; 30; 0; 20; 0]; %Initial state
u0 = [2; 2]; % [Vf Vb] initial inputs
N = 1000; % samples
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
tk = 1:N;

figure(1);
clf;
whitebg([0 0 0]);

%Plot the input 3 times, for each state pair
for i = 1:3
    subplot(3,3,i);
    plot(tk, U(1,:) ,'y--', tk, U(2,:), 'c:');
    xlabel('samples [k]');
    ylabel('[volts]');
    grid on
    hold off
    if i == 1
        legend('Vf', 'Vb', 'Location', 'Best');
    end
    title('Inputs');
end

%Plot the states
subplot(3,3,1+3);
plot(tk,X(1,:), 'b-');
title('Elevation angle $\epsilon$','Interpreter','latex');
xlabel('[k]');
ylabel('[deg]');
grid on
legend('NL ode45', 'NL euler', 'SL c2d', 'SL euler', 'Location', 'Best');

subplot(3,3,4+3);
plot(tk,X(2,:), 'b-');
title('Elevation speed $\dot{\epsilon}$','Interpreter','latex');
xlabel('[k]');
ylabel('[deg/s]');
grid on

subplot(3,3,2+3);
plot(tk,X(3,:), 'b-');
title('Pitch angle $\theta$','Interpreter','latex');
xlabel('[k]');
ylabel('[deg]');
grid on

subplot(3,3,5+3);
plot(tk,X(4,:), 'b-');
title('Pitch speed $\dot{\theta}$','Interpreter','latex');
xlabel('[k]');
ylabel('[deg/s]');
grid on

subplot(3,3,3+3);
plot(tk,X(5,:), 'b-');
title('Travel angle $\phi$','Interpreter','latex');
xlabel('[k]');
ylabel('[deg]');
grid on

subplot(3,3,6+3);
plot(tk,X(6,:), 'b-');
title('Travel speed $\dot{\phi}$','Interpreter','latex');
xlabel('[k]');
ylabel('[deg/s]');
grid on