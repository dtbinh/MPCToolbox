clear
addpath('./quanser');
addpath('./util');
%% System initialization
x0 = [0; 0; 0; 0; 0; 0]; %Initial state
u0 = [1; 1]; % [Vf Vb] initial inputs
h = 0.1; % s - sampling time
nu = 2;
nx = 6;
L = 3; % Simulation progress update rate
Nc = 3; % Control and prediction horizon
%% Reference state
savefilename = 'runs/ref3-run9.mat';
%loadfilename = 'references/traj3-noamp-nozerocross.mat';
loadfilename = 'references/ref3.mat';
load(loadfilename); %load XREF and UREF into workspace
% If the file is a 'path' file (not a trajectory file), set the path as a
% reference
if ~exist('XREF','var')
    XREF = XPATH;
    UREF = UPATH;
end
N = size(XREF,2); % Simulation size
%% Cost matrices and constraints
Q = diag([30, .01, 1.5, 0.1, 0, 0],0);
R = diag([4, 4],0);
%state constraints, positive and negative
dx = [ 30,  100,  60,  100,  inf,  inf;
      -30, -100, -60, -100, -inf, -inf];
%input constraints
du = [ 5,  5;
       0,  0];
 %% Model generation
% Set model coefficients. Leave empty for default value
mpc_param= []; % Use nominal model
%Get MPC continous model
mpc_sl = quanser_model('sl', mpc_param);
%% Problem initialization
% Fields not defined here are not fixed and are defined below
problem = struct;
problem.Q = Q;
problem.R = R;
problem.Nc = Nc;
%% Solver initialization
X = zeros(nx, N); %save all states, for plotting
U = zeros(nu, N); %save all inputs
FVAL = zeros(1, N); %save cost value
TEVAL = zeros(1, N); %save calculation time
x = x0;
xr = x0; % 'real' x
u = u0;
%% Countdown
fprintf('Connecting to server in ');
fprintf('10');
for i = 9:-1:0
  pause(1);
  fprintf('...%d',i);
end
fprintf('\n');
%% Setup
statedef;
% URI used to connect to the server model.
uri = 'shmem://foobar:1';
% Use blocking I/O. Do not change this value.
nonblocking = false;
% Connecting to the server using the specified URI
fprintf(1, 'Connecting to the server at URI: %s\n', uri);
stream = stream_connect(uri, nonblocking);
%Messages
fprintf(1, 'Connected to server.\n\n');
%% Process control loop
ue = []; %input estimated solution
try
    for i=1:N
    %% Update SL Model
        %% Receive data
        value = stream_receive_double_array(stream,8);
        tic;
        x = zeros(6,1);
        x(1) = value(3); %Elevation
        x(2) = value(4); %Elevation Rate
        x(3) = value(5); %Pitch
        x(4) = value(6); %Pitch Rate
        x(5) = value(7); %Travel
        x(6) = value(8); %Travel Rate
        if i > 1 %Overwrite derivates (rates) with euler values
            x(2) = (x(1) - X(1,i-1))/h;
            x(4) = (x(3) - X(3,i-1))/h;
            x(6) = (x(5) - X(5,i-1))/h;
        end
        %Do work
        if mod(i,L) == 0 || i == 1
            [A,B,g] = mpc_sl(x,u); %recalculate (A,B,g)
            [x_o, u_o] = affine_eq(A,B,g);
            du_bar = du - repmat(u_o',2,1);
            dx_bar = dx - repmat(x_o',2,1);
            Ad = eye(nx) + h*A;
            Bd = h*B;
            problem.A = Ad;
            problem.B = Bd;
            problem.du = du_bar;
            problem.dx = dx_bar;
            fprintf('%d ', i);
            if mod(i,20*L) == 0
                fprintf('\n');
            end
        end
    %% Get next command
    xbar = x - x_o;
    idif = Nc - 1;
    if i + Nc > N
        idif = N - i;
    end
    urefbar = UREF(:,i:i+idif) - repmat(u_o,[1 idif+1]);
    xrefbar = XREF(:,i:i+idif) - repmat(x_o,[1 idif+1]);
    problem.uref = urefbar;
    problem.xref = xrefbar;
    problem.uprev = ue;
    problem.x0 = xbar;
    [ue, Xe,fval,EXITFLAG, OUTPUT] = lmpc_condensed(problem);
    if EXITFLAG < 0
        fprintf('Iteration %d\n',i)
        fprintf('Message:%s\n', OUTPUT.message);
        error('Solver error');
    end
    ubar = ue(:,1); %use only the first command in the sequence
    u = ubar + u_o;
    teval = toc;
    %% Data logging
    X(:,i) = x; % save states
    U(:,i) = u; % save inputs
    FVAL(i) = fval;
    TEVAL(i) = teval;
    %% Send data
    % Store a double value in the stream send buffer
    us = struct;
    us.Vf = u(1);
    us.Vb = u(2);
    stream_send_array(stream, us);
    % Flush the send buffer to the underlying communications channel
    stream_flush(stream);
    if isempty(value) % then the server closed the connection gracefully
        fprintf(1, '\nServer has closed the connection.\n');
        break;
    end
    end
    % Once the Esc key is pressed, close the stream handle used for
    % communications.
    fprintf(1, '\nShutting down the client...\n');
    stream_send_array(stream, [1 1]);
    stream_close(stream);
    fprintf(1, 'Connection closed\n');
catch
    err = lasterror;
    fprintf(1, '\n%s.\nShutting down the client from catch...\n', err.message);
    stream_send_array(stream, [1 1]);
    stream_close(stream);
    fprintf(1, 'Connection closed\n');
    rethrow(err);
end
%% Plotting
quanser_plot(X, U, dx, du,['titlu' ' Quanser Plot'], 7, XREF);
quanser_phase_plot(X, ['titlu' ' Quanser Phase-Plot'], 8, XREF);
plot_ft(FVAL, TEVAL, ['titlu' ' Quanser Performance'], 9);
%% Save data
simout = struct;
simout.X = X;
simout.U = U;
simout.XREF = XREF;
simout.UREF = UREF;
simout.h = h;
simout.L = L;
simout.Nc = Nc;
simout.Q = Q;
simout.R = R;
simout.dx = dx;
simout.du = du;
simout.mpcparam = mpc_param;
simout.date = datestr(now);
simout.notes = 'Joystick reference run';
save(savefilename, 'simout', '-v7');