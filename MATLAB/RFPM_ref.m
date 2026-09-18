clear; clc; close all;

%% Physical constants
mu0 = 4*pi*1e-7;      % 真空磁導率 [H/m]

%% PM and material properties
Hc_abs = 868e3;       % N35 coercivity magnitude [A/m]
Br     = 1.17;        % N35 remanence [T]
mur  = Br/(mu0*Hc_abs);  % Alternative calculation, approximately 1.073

sigma_Al = 38e6;      % A1 1060 aluminum conductivity [S/m]

%% Geometry parameters based on Table 3-1
L    = 0.030;         % PM axial length / effective axial length [m]
h_pm = 0.005;         % PM radial thickness [m]
p    = 10;            % Pole number [-]
H    = 0.002;         % Conductor overhang length [m]
g    = 0.003;         % Mechanical air gap [m]
L_cs = 0.003;         % Conductor thickness [m]
w_mag = 0.015;        % Magnet width [m]

Ri   = 0.032;         % Inner yoke inner radius [m]
Rmax = 0.050;         % Maximum outer radius [m]
L_yi = 0.004;         % Inner yoke radial thickness [m]

%% Basic geometry
theta_p = 2*pi/p;

% Inner yoke
Rr = Ri + L_yi;

% Permanent magnet
R_pm_i = Rr;
R_pm_o = R_pm_i + h_pm;

% Calculate magnet arc ratio from magnet width
alpha_m = w_mag / ((Rr + h_pm/2) * theta_p);

if alpha_m <= 0 || alpha_m >= 1
    error('Invalid alpha_m = %.4f. Please check w_mag, Rr, h_pm, and p.', alpha_m);
end

% Magnet mechanical angle
wm_deg = alpha_m * theta_p * 180/pi;

% Air gap and conductor
ge = g + L_cs;
Rci = R_pm_o + g;
Rco = Rci + L_cs;

% Outer yoke
Ro = Rco;
L_yo = Rmax - Rco;

if L_yo <= 0
    error('Invalid geometry: L_yo <= 0. Please check Rmax and radial stack.');
end

R_av = (Rci + Rco)/2;

R_tau = R_pm_o + ge/2;
tau_p = R_tau * theta_p;

R_max = Ro + L_yo;

fprintf('Input w_mag = %.3f mm\n', w_mag*1000);
fprintf('Calculated alpha_m = %.4f\n', alpha_m);
fprintf('PM arc angle wm = %.3f deg\n', wm_deg);
fprintf('Ri = %.3f mm\n', Ri*1000);
fprintf('Rr = %.3f mm\n', Rr*1000);
fprintf('R_pm_i = %.3f mm\n', R_pm_i*1000);
fprintf('R_pm_o = %.3f mm\n', R_pm_o*1000);
fprintf('Rci = %.3f mm\n', Rci*1000);
fprintf('Rco = %.3f mm\n', Rco*1000);
fprintf('L_yo = %.3f mm\n', L_yo*1000);
fprintf('R_max = %.3f mm\n', R_max*1000);
%% PM MMF, Eq. (1)
Fm = Hc_abs*h_pm;

%% ============================================================
% Nonlinear MEC setting
%% ============================================================
use_nonlinear_mu = true;

mu_y_init = 4000;

maxIter = 200;
tol = 0.01;
damping = 0.1;

% Simplified AISI 1008 B-H curve
% AISI 1008 B-H curve
B_data = [ ...
    0.10 0.30 0.50 0.80 1.00 ...
    1.20 1.50 1.70 1.90 2.05 ...
    2.15 2.25 2.35 2.45 2.55 ];

H_data = [ ...
      30   45   60   80  100 ...
     120  180  400 1000 3000 ...
    7000 12000 20000 30000 40000 ];

mu_ii1 = mu_y_init;
mu_ii2 = mu_y_init;
mu_io1 = mu_y_init;
mu_io2 = mu_y_init;

%% ============================================================
% MEC iteration
%% ============================================================
for iter = 1:maxIter

    %% Eq. (2): PM reluctance
    Rm = log(1 + h_pm/(Ri + L_yi)) / ...
        (mu0*mur*alpha_m*theta_p*L);

    %% Eq. (3): effective air-gap reluctance
    Rge = log(1 + ge/(Ri + L_yi + h_pm)) / ...
        (mu0*alpha_m*theta_p*L);

    %% Eq. (5)
    Beta_arg = (ge/2)/(Ri + L_yi + h_pm);
    Beta_arg = min(max(Beta_arg, -1), 1);
    Beta = pi - acos(Beta_arg);

    %% Eq. (6): PM-to-PM leakage permeance
    Pmm = (mu0*L/(2*Beta + (1-alpha_m)*theta_p)) * ...
        log(1 + ge*(2*Beta + (1-alpha_m)*theta_p) / ...
        ((Rr + h_pm)*(1-alpha_m)*theta_p));

    Rmm = 1/Pmm;

    %% Eq. (8)-(9): PM-to-iron leakage
    L1 = min(ge, (Ri + L_yi + h_pm)*(1-alpha_m)*theta_p/2);

    Pmi = (mu0*L/(2*Beta)) * ...
        log(1 + 2*Beta*L1/h_pm);

    Rmi = 1/Pmi;

    %% Eq. (13), (16): yoke areas
    Ai1 = L_yi * L;
    Ai2 = 0.5 * alpha_m * theta_p * (Ri + L_yi) * L;

    Ao1 = L_yo * L;
    Ao2 = 0.5 * alpha_m * theta_p * Ro * L;

    %% Eq. (11)-(15): yoke reluctances
    Ryi1 = (Ri + L_yi/2)*(1-alpha_m)*theta_p / ...
        (mu0*mu_ii1*Ai1);

    Ryi2 = 0.5*alpha_m*theta_p*(Ri + L_yi/2) / ...
        (mu0*mu_ii2*((Ai1 + Ai2)/2));

    Ryo1 = (Ro + L_yo/2)*(1-alpha_m)*theta_p / ...
        (mu0*mu_io1*Ao1);

    Ryo2 = 0.5*alpha_m*theta_p*(Ro + L_yo/2) / ...
        (mu0*mu_io2*((Ao1 + Ao2)/2));

    R_yi = Ryi1 + 2*Ryi2;
    R_yo = Ryo1 + 2*Ryo2;

    %% Eq. (17): MEC matrix
    A = [ 4*Rge + R_yo + Rmm,        0,                  -2*Rmm;
          0,                        2*Rm + Rmi,         -2*Rmi;
         -Rmm,                     -2*Rmi,      2*R_yi + 4*Rmi + 2*Rmm ];

    b = [0; 2*Fm; 0];

    phi = A\b;

    phi_g  = phi(1);
    phi_m  = phi(2);
    phi_yi = phi(3);

    % Important:
    % Eq. (17) does not directly solve phi_yo.
    % For yoke-density checking, outer yoke flux should not simply be phi_g.
    % A practical approximation is to use half-loop flux.
    phi_yo = phi_g/2;

    if ~use_nonlinear_mu
        break;
    end

    %% Eq. (18)-(19): flux density in yokes
    Byi1 = abs(phi_yi) / Ai1;
    Byi2 = abs(phi_yi) / ((Ai1 + Ai2)/2);

    Byo1 = abs(phi_yo) / Ao1;
    Byo2 = abs(phi_yo) / ((Ao1 + Ao2)/2);

    mu_old = [mu_ii1 mu_ii2 mu_io1 mu_io2];

    %% Eq. (20): permeability update
    mu_ii1_hat = get_mu_from_BH(Byi1, B_data, H_data, mu0);
    mu_ii2_hat = get_mu_from_BH(Byi2, B_data, H_data, mu0);
    mu_io1_hat = get_mu_from_BH(Byo1, B_data, H_data, mu0);
    mu_io2_hat = get_mu_from_BH(Byo2, B_data, H_data, mu0);

    mu_ii1 = mu_ii1_hat^damping * mu_ii1^(1-damping);
    mu_ii2 = mu_ii2_hat^damping * mu_ii2^(1-damping);
    mu_io1 = mu_io1_hat^damping * mu_io1^(1-damping);
    mu_io2 = mu_io2_hat^damping * mu_io2^(1-damping);

    mu_new = [mu_ii1 mu_ii2 mu_io1 mu_io2];

    err = max(abs((mu_new - mu_old)./mu_old));

    if err <= tol
        fprintf('Nonlinear MEC converged at iter = %d, err = %.4f\n', iter, err);
        break;
    end

    if iter == maxIter
        fprintf('Warning: nonlinear MEC did not converge. Final err = %.4f\n', err);
    end
end

%% Eq. (22): PM-produced air-gap flux density
Bpm = abs(phi_g) / (alpha_m*tau_p*L);

fprintf('phi_g = %.4e Wb\n', phi_g);
fprintf('Bpm = %.4f T\n', Bpm);

%% Eq. (46): demagnetization check
Hm_over_Hc = 1 - Bpm/Br;
fprintf('Hm/Hc = %.4f\n', Hm_over_Hc);

%% Final yoke flux-density check
Byi1 = abs(phi_yi) / Ai1;
Byi2 = abs(phi_yi) / ((Ai1 + Ai2)/2);

Byo1 = abs(phi_yo) / Ao1;
Byo2 = abs(phi_yo) / ((Ao1 + Ao2)/2);

fprintf('\nYoke flux density check:\n');
fprintf('Byi1 = %.3f T\n', Byi1);
fprintf('Byi2 = %.3f T\n', Byi2);
fprintf('Byo1 = %.3f T\n', Byo1);
fprintf('Byo2 = %.3f T\n', Byo2);

fprintf('\nFinal relative permeabilities:\n');
fprintf('mu_ii1 = %.1f\n', mu_ii1);
fprintf('mu_ii2 = %.1f\n', mu_ii2);
fprintf('mu_io1 = %.1f\n', mu_io1);
fprintf('mu_io2 = %.1f\n', mu_io2);

%% ============================================================
% Eq. (41)-(43): 3D correction factor
%% ============================================================
alphaL = 2*H/L;
x3d = p*L/(4*R_av);

lambda = tanh(x3d)*tanh(alphaL*x3d);
Ks = 1 - tanh(x3d)/(x3d*(1 + lambda));

sigma_3D = Ks*sigma_Al;

fprintf('\n3D correction factor Ks = %.4f\n', Ks);
fprintf('sigma_2D = %.3e S/m\n', sigma_Al);
fprintf('sigma_3D = %.3e S/m\n', sigma_3D);

%% ============================================================
% Torque-speed curve
% Eq. (35): calculate both 2D and 3D corrected torque
%% ============================================================
rpm = linspace(0, 800, 801).';
omega = rpm/60*2*pi;

Torque_2D = torque_mohammadi_eq35( ...
    omega, sigma_Al, mu0, L, p, Bpm, Rco, Rci, ...
    g, L_cs, h_pm, alpha_m);

Torque_3D = torque_mohammadi_eq35( ...
    omega, sigma_3D, mu0, L, p, Bpm, Rco, Rci, ...
    g, L_cs, h_pm, alpha_m);

%% Display key comparison points
target_rpm = [0; 200; 400; 600; 800];
Torque2D_key = interp1(rpm, Torque_2D, target_rpm);
Torque3D_key = interp1(rpm, Torque_3D, target_rpm);

KEY = table(target_rpm, Torque2D_key, Torque3D_key, ...
    'VariableNames', {'rpm','Torque_2D_Nm','Torque_3D_Nm'});

fprintf('\nKey torque values for literature comparison:\n');
disp(KEY);

%% Full table
TBL = table(rpm, Torque_2D, Torque_3D, ...
    'VariableNames', {'rpm','Torque_2D_Nm','Torque_3D_Nm'});

%% Plot
figure;
plot(rpm, Torque_2D, 'LineWidth', 1.8); hold on;
plot(rpm, Torque_3D, '--', 'LineWidth', 1.8);
grid on;
xlabel('Relative speed (rpm)');
ylabel('Torque (N·m)');
title('Torque-speed curve: 2D and 3D-corrected analytical model');
legend('2D analytical torque', '3D-corrected analytical torque', ...
    'Location', 'northwest');
xlim([min(rpm) max(rpm)]);

%% Export
writetable(TBL, 'torque_speed_Mohammadi2014_literature_check.csv');
disp('已輸出 torque_speed_Mohammadi2014_literature_check.csv');

%% ============================================================
% Local functions
%% ============================================================

function Torque = torque_mohammadi_eq35(omega, sigma, mu0, L, p, Bm, ...
    Rco, Rci, g, Lcs, hpm, alpha_m)

    Torque = zeros(size(omega));

    idx = omega > 0;

    m = mu0*sigma.*omega(idx).*(Rco^3 - Rci^3) ./ ...
        (6*(g + Lcs + hpm));

    arg = m*pi/p;

    T1 = (L*sigma.*omega(idx).*p.*Bm.^2.*(Rco^4 - Rci^4)) ./ ...
        (4*m);

    T2 = ((2.*cosh((1-alpha_m).*arg))./cosh(arg)) .* ...
        (sinh(alpha_m.*arg) - sinh((2-alpha_m).*arg)) + ...
        2.*(cosh((1-alpha_m).*arg)).^2 .* tanh(arg) + ...
        sinh(2.*(1-alpha_m).*arg);

    Torque(idx) = abs(T1.*T2);

end

function mu_r = get_mu_from_BH(B, B_data, H_data, mu0)

    B = abs(B);

    if B <= min(B_data)
        H = H_data(1);
    elseif B >= max(B_data)
        H = H_data(end);
    else
        H = interp1(B_data, H_data, B, 'linear');
    end

    mu_r = B/(mu0*H);

    if ~isfinite(mu_r) || mu_r < 1
        mu_r = 1;
    end

end
%% ============================================================
% Export yoke flux density data for saturation comparison plot
%% ============================================================

B_sat_limit = 1.6;   % AISI 1008 design saturation limit [T]

YOKE = table( ...
    ["Byi1"; "Byi2"; "Byo1"; "Byo2"], ...
    [Byi1; Byi2; Byo1; Byo2], ...
    repmat(B_sat_limit, 4, 1), ...
    'VariableNames', {'Region','FluxDensity_T','SaturationLimit_T'});

save('yoke_flux_density_results.mat', ...
    'Byi1', 'Byi2', 'Byo1', 'Byo2', 'B_sat_limit');

writetable(YOKE, 'yoke_flux_density_results.csv');

disp('已輸出 yoke_flux_density_results.mat');
disp('已輸出 yoke_flux_density_results.csv');
%% ============================================================
% Export conductor thickness and skin depth data
%% ============================================================

rpm_skin = [400; 800];
omega_mech_skin = rpm_skin/60*2*pi;
omega_e_skin = (p/2).*omega_mech_skin;   % p is pole number
skin_depth = sqrt(2 ./ (omega_e_skin * mu0 * sigma_Al));   % [m]

Lcs_data = repmat(L_cs, size(rpm_skin));  % [m]

SKIN = table( ...
    rpm_skin, ...
    omega_e_skin, ...
    Lcs_data*1000, ...
    skin_depth*1000, ...
    'VariableNames', {'rpm','omega_e_rad_s','Lcs_mm','skin_depth_mm'});

save('skin_depth_results.mat', ...
    'rpm_skin', 'omega_e_skin', 'L_cs', 'skin_depth');

writetable(SKIN, 'skin_depth_results.csv');

disp('已輸出 skin_depth_results.mat');
disp('已輸出 skin_depth_results.csv');