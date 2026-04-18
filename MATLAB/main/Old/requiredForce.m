function [F_total, info] = requiredForce(mech_params, ECB, omega_rpm, g_curr, g_ini, direction)
    % mech_params: 由 xToMechParams 產生的結構體
    % ECB: 包含 C_s, C_e, g_e 的結構體
    
    % 解包機械參數 (使用結構體欄位，程式碼可讀性更高)
    r_r = mech_params.r_r; 
    N   = mech_params.N;
    alpha_rad = deg2rad(mech_params.alpha);
    omega_rad = omega_rpm .* pi / 30;
    
    % 機構幾何計算
    a_i = r_r .* tan(pi .* (N - 2) / (2 .* N));
    disp_x = g_ini - g_curr; % 行程計算
    r_omega = a_i + r_r + disp_x .* cot(alpha_rad) + 0.1 .* mech_params.r_yi; % 旋轉半徑 r_omega
    
    % 推力計算 (F_wedge)
    m_r = 4/3 .* pi .* r_r.^3 .* mech_params.rho;
    s = strcmp(direction, 'up') .* 2 - 1; 
    
    num = m_r .* (omega_rad.^2) .* r_omega .* (cos(alpha_rad) - s .* mech_params.mu_w .* sin(alpha_rad));
    den = (1 - mech_params.mu_w .* mech_params.mu_t) .* sin(alpha_rad) + ...
        s .* (mech_params.mu_w + mech_params.mu_t) .* cos(alpha_rad);
    
    Fw = N .* num / den;
    
    % 磁力計算 (F_magnet)
    Fm = (ECB.C_s - ECB.C_e .* omega_rpm) ./ (g_curr*1000 + ECB.g_e).^2;
    
    F_total = Fw + Fm;

    info.den = den;
    info.Fw = Fw;
    info.Fm = Fm;
    info.r_omega = r_omega;
end