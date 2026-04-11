clc; clear; close all;

% 定義目標扭矩
Target_Start = [255.6, 1.833]; % w_ini, T_ini
Target_End   = [573.0, 18.39]; % w_final, T_final

% 定義優化變數範圍 (Lower Bound, Upper Bound)
%          1    2      3      4       5     6       7    8     9     10     11    12   13   14    15    16    17
%          p   r_yo   r_yi   t_y    t_c    k_lm   k_pos  PM   t_m    r_r    m_r   N   k_m  alpha beta  mu_w  mu_t
lb_geo = [ 3, 0.050, 0.014, 0.001, 0.0005, 0.10,  0.00, 0.4, 0.001, 0.010, 0.010,  3, 0.01, 15,   30,  0.10, 0.10];
ub_geo = [10, 0.110, 0.020, 0.010, 0.005,  0.90,  1.00, 0.9, 0.009, 0.050, 0.300, 12, 0.99, 75,   60,  0.20, 0.60];
% 軌跡參數: [n_up, n_down]，n = 1 為線性, n < 1 為凸, n > 1 為凹
lb_traj = [0.5, 0.5]; 
ub_traj = [3.0, 3.0];

lb = [lb_geo, lb_traj];
ub = [ub_geo, ub_traj];
nvars = length(lb);

% 設定整數變數 (p 是第 1 個變數, N 是第 12 個變數)
IntCon = [1, 12]; 

% NSGA-II 設定
options = optimoptions('gamultiobj', ...
    'PopulationSize', 100, ...
    'ParetoFraction', 0.4, ...
    'MaxGenerations', 50, ...
    'display', 'iter', ...
    'UseParallel', true); % 建議開啟平行運算加速

% 目標函數 (最小化 [Area, R_hy, Volume])
FitnessFcn = @(x) objective(x, Target_Start, Target_End);

% 隨機生成一組解來測試
x_test = lb + rand(1, nvars) .* (ub - lb);
x_test(IntCon) = round(x_test(IntCon)); % 確保整數變數是整數

tic;
val = FitnessFcn(x_test);
time_taken = toc;

fprintf('計算結果: [%f, %f]\n', val(1), val(2));
fprintf('單次計算耗時: %.4f 秒\n', time_taken);
[ECB, mech, traj] = xToParams(x_test); % 解碼參數