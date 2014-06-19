function x = quanser_nonlin_disc(h, x0, u)
% h - timestep
% x0 - initial state
% x - new state
% u - inputs
%% Model params
Jepsilon = 0.86; %kg*m^2
Jtheta = 0.044; %kg*m^2
Jphi = 0.82; %kg*m^2
La = 0.62; %m
Lc = 0.44; %m
Ld = 0.05; %m
Le = 0.02; %m
Lh = 0.177; %m
Mf = 0.69; %kg
Mb = 0.69; %kg
Mc = 1.69; %kg
Km = 0.5; %N/V
g = 9.81; %m/s^2;
niu_epsilon = 0.001; %kg*m^2/s
niu_theta = 0.001; %kg*m^2/s
niu_phi = 0.005; %kg*m^2/s

epsilon = x0(1);
epsilon_d = x0(2);
theta = x0(3);
theta_d = x0(4);
phi = x0(5);
phi_d = x0(6);

deltaa = atan((Ld+Le)/La);
deltac = atan(Ld/Lc);
deltah = atan(Le/Lh);

p1 = (-(Mf + Mb)*g*La + Mc*g*Lc) / Jepsilon;
p2 = (-(Mf + Mb)*g*La*tan(deltaa)+ Mc*g*Lc*tan(deltac))/Jepsilon;
p3 = -niu_epsilon/Jepsilon;
p4 = Km*La/Jepsilon;
p5 = (-Mf + Mb)*g*Lh/Jtheta;
p6 = -(Mf + Mb)*g*Lh*tan(deltah)/Jtheta;
p7 = -niu_theta/Jtheta;
p8 = Km*Lh/Jtheta;
p9 = -niu_phi/Jphi;
p10 = -Km*La/Jphi;
%% Model matrices
F = [ epsilon_d;
      p1*cos(epsilon*pi/180) + p2*(sin(epsilon*pi/180)) + p3*epsilon_d;
      theta_d;
      p5*cos(theta*pi/180) + p6*sin(theta*pi/180) + p7*theta_d;
      phi_d;
      p9*phi_d;
    ];
G1 = [0 p4*cos(theta*pi/180) 0 p8 0 p10*sin(theta*pi/180)]';
G2 = [0 p4*cos(theta*pi/180) 0 -p8 0 p10*sin(theta*pi/180)]';
G = [G1 G2];
%% Calculate new state
x = x0 + h*(F + G*u);