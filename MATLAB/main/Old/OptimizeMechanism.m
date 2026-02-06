clear; clc;

%% 1. 定義已知參數與常數
% 電磁力常數 (單位需注意：mm, rpm)
C_s = 26781.2188; % TODO N*mm^2
C_e = 12.3061;    % TODO N*mm^2/rpm
g_e = 2.3717;     % TODO mm
r_yi = 0.02; 

% 目標點位 (轉速 rpm, 氣隙 mm)
target1 = [255.6, 9.810895068];  % TODO 點A, D (低速, 初始氣隙)
target2 = [573.0, 3];   % TODO 點B (高速, 最終氣隙)
g_ini = target1(2);
g_final = target2(2);
% 計算點C的轉速
omega_C = target2(1) - 0.8 * (target2(1) - target1(1));

%% 2. 定義優化變數與邊界
% x = [radius_r, L_r, N, alpha, mu_wedge, mu_t]
% 單位：m, m, 1, deg, 1, 1
lb = [0.010, 0.020, 4,  30, 0.05, 0.05]; % 下界
ub = [0.050, 0.080, 12, 60, 0.20, 0.20]; % 上界
x0 = [0.030, 0.040, 8,  45, 0.10, 0.10]; % 初始值

%% 3. 執行優化 (使用 fmincon)
options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp');

% 目標函數與限制函數
objFunc = @(x) objective_function(x, target1, g_ini, C_s, C_e, g_e, r_yi);
nonlconFunc = @(x) constraints(x, target2, omega_C, g_final, C_s, C_e, g_e, r_yi);

[x_best, fval] = fmincon(objFunc, x0, [], [], [], [], lb, ub, nonlconFunc, options);

%% 4. 結果顯示
fprintf('\n=== 機械參數優化結果 ===\n');
fprintf('滾子半徑 (r_r): %.2f mm\n', x_best(1)*1000);
fprintf('滾子長度 (L_r): %.2f mm\n', x_best(2)*1000);
fprintf('滾子數量 (N): %d\n', round(x_best(3)));
fprintf('楔形角度 (alpha): %.2f deg\n', x_best(4));
fprintf('楔形摩擦 (mu_w): %.3f\n', x_best(5));
fprintf('盤面摩擦 (mu_t): %.3f\n', x_best(6));
fprintf('最小遲滯目標值: %.4f\n', fval);

%% --- 內部函數：磁力計算 ---
function Fm = get_F_magnet(omega, g, Cs, Ce, ge)
    % omega: rpm, g: mm
    Fm = (Cs - Ce * omega) / (g + ge)^2;
end

%% --- 目標函數 ---
function score = objective_function(x, target1, g_ini, Cs, Ce, ge, r_yi)
    omega_A = target1(1);
    Fs_A = get_F_wedge(x, omega_A, g_ini, g_ini, 'up', r_yi) + get_F_magnet(omega_A, g_ini, Cs, Ce, ge);
    Fs_D = get_F_wedge(x, omega_A, g_ini, g_ini, 'down', r_yi) + get_F_magnet(omega_A, g_ini, Cs, Ce, ge);
    score = abs(Fs_D - Fs_A) / abs(Fs_A);
end

% --- 限制函數 ---
function [c, ceq] = constraints(x, target2, omega_C, g_final, Cs, Ce, ge, r_yi)
    omega_B = target2(1);
    % 這裡 g_ini (11) 需與前面的定義一致
    Fs_B = get_F_wedge(x, omega_B, g_final, 11, 'up', r_yi) + get_F_magnet(omega_B, g_final, Cs, Ce, ge);
    Fs_C = get_F_wedge(x, omega_C, g_final, 11, 'down', r_yi) + get_F_magnet(omega_C, g_final, Cs, Ce, ge);
    
    c = [];
    ceq = Fs_B - Fs_C; 
end