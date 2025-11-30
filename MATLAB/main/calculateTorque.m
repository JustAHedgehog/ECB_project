function T_theory = calculateTorque(params, rpm, g)
    % 從 params 結構體中提取所有變數到函數工作區
    % 這樣可以避免修改原有的計算公式，直接使用其變數名
    fn = fieldnames(params);
    for i = 1:numel(fn)
        eval([fn{i} ' = params.' fn{i} ';']);
    end
    
    % 轉換 rpm 到角速度
    omega = rpm / 60 * 2 * pi; % rpm to rad/s

    %% 磁阻參數計算 ----------------------------------------------------------%%
    A_m = l_m * w_m; % Area of magnet
    R_g = (g + t_c) / (mu_0 * A_m); %% TODO 單側雙側不同

    % R_m
    R_m = t_m / (mu_0 * mu_r * A_m);

    % R_y
    P_y = mu_0 * mu_y * t_y / theta_p * log(r_yo / r_yi);
    R_y = P_y^-1;
    
    % R_mm
    criteria_1 = g + t_c;
    criteria_2 = w_m / 2;
    mm = min(criteria_1, criteria_2);
    P_mm = mu_0 * l_m / pi * log(1 + pi * mm / (tau_p * (1 - PM_ratio))); %% 單側雙側不同；在 MATLAB 中，自然對數 ln(x) 用 log(x) 表示
    R_mm = P_mm^-1;

    % R_ms
    ms1 = min(mm, (tau_p - w_m) / 2);
    A = [criteria_1, H, l_m / 2]; % 因為 MATLAB 至多僅能在2個數值中找最小值，故生成一向量 A
    ms2 = min(A); % 在向量 A 中找最小值的元素
    P_ms1 = mu_0 * l_m / pi * log(1 + pi * ms1 / t_m);
    P_ms2 = mu_0 * w_m / pi * log(1 + pi * ms2 / t_m);
    P_ms = P_ms1 + P_ms2;
    R_ms = P_ms^-1;

    % flux_mag  = mu_0 * mu_r * H_c * A_m;
    F_m = H_c * t_m;
    flux_g = 4 * R_ms * R_mm * F_m / ...
        (R_mm * (4 * R_g + R_y) * (2 * R_m + R_ms) + (4 * R_m * R_ms + R_y * (2 * R_m + R_ms)) * (4 * R_g + R_y + R_mm));
    B_m = flux_g / A_m; % density when -PM_ratio*theta_p/2 <= theta <= PM_ratio*theta_p/2

    %% Design1 with 3D correction with my test --------------------------%%
    S = mu_0 * t_c * sigma * r_av^2 * omega / (2 * (g + t_c + t_m));
    C = cosh((1 - PM_ratio) * S * theta_p / 2) ./ cosh(S * theta_p / 2); % C=exp(-m*theta_0)

    T_k4 = l_m .* t_c .* sigma .* r_av.^3 .* omega .* B_m.^2 .* (2 .* p) ./ (2 * S) .* (...
        2 * C.^2 .* sinh(S * PM_ratio * theta_p) ...
        + (C - exp(S * PM_ratio * theta_p / 2)).^2 .* (exp(-S * PM_ratio * theta_p) - exp(-S * theta_p)) ...
        + (C - exp(-S * PM_ratio * theta_p / 2)).^2 .* (exp(S * theta_p) - exp(S * PM_ratio * theta_p)));

    T_theory = T_k4;

    %% 3D correction ----------------------------------------------------%%
    Beta = (p) / r_av;
    lamda = 2 * H / l_m;
    k_russel_method1 = 1 - (2 / l_m / Beta * tanh(l_m * Beta / 2) / (1 + tanh(l_m * Beta / 2) * tanh(lamda * l_m * Beta / 2)));

    k_russel = k_russel_method1;
    T_theory = T_theory .* k_russel;
end