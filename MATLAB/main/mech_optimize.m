function [x_best, fval] = mech_optimize(r_yi, w_ini, w_final, g_ini, g_final)
    %% 1. 定義已知參數與常數
    % 電磁力常數 (單位需注意：mm, rpm)
    C_s = 26781.2188; % TODO N*mm^2
    C_e = 12.3061;    % TODO N*mm^2/rpm
    g_e = 2.3717;     % TODO mm

    % 計算遲滯點C的轉速
    w_hysteresis = w_final - 0.8 * (w_final - w_ini);

    %% 2. 定義優化變數與邊界
    % x = [radius_r, L_r, N, alpha, mu_wedge, mu_t]
    % 單位：m, m, 1, deg, 1, 1
    lb = [0.010, 0.020, 4,  30, 0.05, 0.05]; % 下界
    ub = [0.050, 0.080, 12, 60, 0.20, 0.20]; % 上界
    x0 = [0.030, 0.040, 8,  45, 0.10, 0.10]; % 初始值

    %% 3. 執行優化 (使用 fmincon)
    options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp');

    % 目標函數與限制函數
    objFunc = @(x) objective_function(x, w_ini, g_ini, C_s, C_e, g_e, r_yi);
    nonlconFunc = @(x) constraints(x, w_final, w_hysteresis, g_final, C_s, C_e, g_e, r_yi);

    [x_best, fval] = fmincon(objFunc, x0, [], [], [], [], lb, ub, nonlconFunc, options);

end

%% --- 目標函數 ---
function score = objective_function(x, w_ini, g_ini, Cs, Ce, ge, r_yi)
    Fs_A = get_F_wedge(x, w_ini, g_ini, g_ini, 'up', r_yi) + get_F_magnet(w_ini, g_ini, Cs, Ce, ge);
    Fs_D = get_F_wedge(x, w_ini, g_ini, g_ini, 'down', r_yi) + get_F_magnet(w_ini, g_ini, Cs, Ce, ge);
    score = abs(Fs_D - Fs_A) / abs(Fs_A);
end

% --- 限制函數 ---
function [c, ceq] = constraints(x, w_final, omega_C, g_final, Cs, Ce, ge, r_yi)
    % 這裡 g_ini (11) 需與前面的定義一致
    Fs_B = get_F_wedge(x, w_final, g_final, 11, 'up', r_yi) + get_F_magnet(w_final, g_final, Cs, Ce, ge);
    Fs_C = get_F_wedge(x, omega_C, g_final, 11, 'down', r_yi) + get_F_magnet(omega_C, g_final, Cs, Ce, ge);
    
    c = [];
    ceq = Fs_B - Fs_C; 
end

%% --- 內部函數 ---
% 磁力計算
function Fm = get_F_magnet(omega, g, Cs, Ce, ge)
    % omega: rpm, g: mm
    Fm = (Cs - Ce * omega) / (g + ge)^2;
end

% 軸向推力
function Fw = get_F_wedge(x, omega_rpm, g_curr, g_ini, direction, r_yi)
    % x: 優化變數向量 [radius_r, L_r, N, alpha, mu_w, mu_t]
    r_r = x(1); 
    L_r = x(2); % 這裡假設 L_omega = L_r
    N = round(x(3)); 
    alpha = x(4); 
    mu_w = x(5); 
    mu_t = x(6);
    
    rho = 7840;
    omega_rad = omega_rpm * pi / 30;
    alpha_rad = deg2rad(alpha);
    
    % --- 新增的幾何修正邏輯 ---
    % 1. 計算多邊形心距 (Apothem) a_i
    % 內角一半為 pi*(N-2)/(2*N)
    a_i = 0.5 * L_r * tan(pi * (N - 2) / (2 * N));
    
    % 2. 行程 x (單位轉換為 m)
    disp_x = (g_ini - g_curr) / 1000;
    
    % 3. 修正後的旋轉半徑 r_omega (注意 r_yi 單位應為 m)
    % 公式: r_w = a_i + radius_r + x*tan(alpha) + 0.1*r_yi
    r_omega = a_i + r_r + disp_x * tan(alpha_rad) + 0.1 * r_yi;
    
    % --- 推力計算 ---
    m_r = pi * r_r^2 * L_r * rho;
    s = strcmp(direction, 'up') * 2 - 1; 
    
    num = m_r * (omega_rad^2) * r_omega * (cos(alpha_rad) - s * mu_w * sin(alpha_rad));
    den = (1 - mu_w * mu_t) * sin(alpha_rad) + s * (mu_w + mu_t) * cos(alpha_rad);
    
    Fw = N * num / den;
end