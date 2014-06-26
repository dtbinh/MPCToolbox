clear
%% *Simulate Quanser helicopter*
% This is a script that simulates the Quanser 3-DOF helicopter and plots
%   the results in figure 1.
% This file needs the following files to be in the same directory:
%   - _quanser_params.m_ : load model coefficients
%   - _quanser_cont_nl.m_ : nonlinear model state derivative estimation
%   - _quanser_con_sl.m_ : successive linearizations model
%

%% Initialization
x0 = [45; 0; 5; 0; 30; 0]; %Initial state
N = 10; % samples
h = 0.1; % s - sampling time
nu = 2;
nx = 6;
l = 5; %SL horizon i.e. how many steps until a new affine term is calculated
%% Input signal shape
U = ones(nu, N);
% u(:, 1:30) = repmat([3; 3],1,30);
% u(:, 31: 60) = repmat([5; 0],1,30);
% u(:, 61:90) = repmat([0; 5],1,30);
U(1,1:5) = [2 3 2.3 0 3];
U(2,1:5) = [2.2 2.1 1.3 4 3];
U(:,6:10) = ones(2,5)*3;
%% Nonlinear model with ode45
Xtil = zeros(nx, N); %save all states, for plotting
x = x0;
for i = 1:N
    Xtil(:,i) = x; %save current state
    [Tout, Yout] = ode45(@quanser_cont_nl, [0 h], [x; U(:,i)]);
    x = Yout(end, 1:6)'; %get new state
end
%% Nonlinear model with euler discretization
Xhat = zeros(nx, N); %save all states, for plotting
x = x0;
for i = 1:N
    Xhat(:,i) = x; %save current state
    f = quanser_cont_nl([],[x; U(:,i)]);
    xd = f(1:6);
    x = x + h*xd;
end
%% Succesive Liniarization model, discretized with c2d 
Xbard = zeros(nx, N); %save all states, for plotting
x = x0;
[A,B,g] = quanser_cont_sl(x,U(:,1)); %Initial (A,B) pair
C = [1 0 0 0 0 0; 0 0 0 0 1 0];
for i = 1:N
    Xbard(:,i) = x; %save current state
    if mod(i,l) == 0
        [A,B,g] = quanser_cont_sl(x,U(:,i)); %recalculate (A,B,g)
    end
    sys = ss(A,B,C,0);
    sysd = c2d(sys,h, 'zoh');
    sysd.a = eye(nx) + h*A;
    sysd.b = h*B;
    Ad = sysd.a;
    Bd = sysd.b;
    x = Ad*x + Bd*U(:,i) + h*g;
end
% Xbard = zeros(nx, N);
%% Succesive Liniarization model with euler discretization
Xbarc = zeros(nx, N); %save all states, for plotting
x = x0;
[A,B,g] = quanser_cont_sl(x,U(:,1)); %Initial (A,B) pair
for i = 1:N
    Xbarc(:,i) = x; %save current state
    if mod(i,l) == 0
        [A,B,g] = quanser_cont_sl(x,U(:,i)); %recalculate (A,B,g)
    end
    xd = A*x + B*U(:,i) + g;
    x = x + h*xd;
end
% Xbarc = zeros(nx, N);
%% Plotting 
% t = 0:h:((N-1)*h);
t = 1:N;

figure(1);
clf;
whitebg([0 0 0]);

%Plot the input 3 times, for each state pair
for i = 1:3
    subplot(3,3,i);
    plot(t, U(1,:) ,'y--', t, U(2,:), 'c--');
    title('Inputs');
    grid on
    xlabel('[k]');
    ylabel('[volts]');
    if i == 1
        legend('Vf', 'Vb', 'Location', 'Best');
    end
end

%Plot the states
subplot(3,3,1+3);
plot(t,Xtil(1,:), 'b-');
title('Elevation angle $\epsilon$','Interpreter','latex');
hold on
plot(t,Xhat(1,:), 'r:');
plot(t,Xbard(1,:), 'c--');
plot(t,Xbarc(1,:), 'g:');
xlabel('[k]');
ylabel('[deg]');
grid on
legend('NL ode45', 'NL euler', 'SL c2d', 'SL euler', 'Location', 'Best');
hold off

subplot(3,3,4+3);
plot(t,Xtil(2,:), 'b-');
title('Elevation speed $\dot{\epsilon}$','Interpreter','latex');
hold on
plot(t,Xhat(2,:), 'r:');
plot(t,Xbard(2,:), 'c--');
plot(t,Xbarc(2,:), 'g:');
xlabel('[k]');
ylabel('[deg/s]');
grid on
hold off

subplot(3,3,2+3);
plot(t,Xtil(3,:), 'b-');
title('Pitch angle $\theta$','Interpreter','latex');
hold on
plot(t,Xhat(3,:), 'r:');
plot(t,Xbard(3,:), 'c--');
plot(t,Xbarc(3,:), 'g:');
xlabel('[k]');
ylabel('[deg]');
grid on
hold off

subplot(3,3,5+3);
plot(t,Xtil(4,:), 'b-');
title('Pitch speed $\dot{\theta}$','Interpreter','latex');
hold on
plot(t,Xhat(4,:), 'r:');
plot(t,Xbard(4,:), 'c--');
plot(t,Xbarc(4,:), 'g:');
xlabel('[k]');
ylabel('[deg/s]');
grid on
hold off

subplot(3,3,3+3);
plot(t,Xtil(5,:), 'b-');
title('Travel angle $\phi$','Interpreter','latex');
hold on
plot(t,Xhat(5,:), 'r:');
plot(t,Xbard(5,:), 'c--');
plot(t,Xbarc(5,:), 'g:');
xlabel('[k]');
ylabel('[deg]');
grid on
hold off

subplot(3,3,6+3);
plot(t,Xtil(6,:), 'b-');
title('Travel speed $\dot{\phi}$','Interpreter','latex');
hold on
plot(t,Xhat(6,:), 'r:');
plot(t,Xbard(6,:), 'c--');
plot(t,Xbarc(6,:), 'g:');
xlabel('[k]');
ylabel('[deg/s]');
grid on
hold off
