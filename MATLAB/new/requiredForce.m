function [F_total, info] = requiredForce(mech, ~, omega_rpm, g_curr, g_ini, direction)
    % mech_params: 由 xToMechParams 產生的結構體
    % ECB: 包含 C_s, C_e, g_e 的結構體
    % 解包機械參數
    m_r = mech.m_r;
    N   = mech.N;
    r_w_ini = mech.r_omega_ini; % 初始旋轉半徑
    alpha_rad = deg2rad(mech.alpha);
    omega_rad = omega_rpm .* pi / 30;
    
    % 機構幾何計算
    disp_x = g_ini - g_curr; % 行程計算
    r_w = r_w_ini + disp_x .* cot(alpha_rad); % 旋轉半徑 r_omega
    
    % 推力計算 (F_wedge)
    s = strcmp(direction, 'up') .* 2 - 1; 
    
    num = m_r .* (omega_rad.^2) .* r_w .* (cos(alpha_rad) - s .* mech.mu_w .* sin(alpha_rad));
    den = (1 - mech.mu_w .* mech.mu_t) .* sin(alpha_rad) + ...
        s .* (mech.mu_w + mech.mu_t) .* cos(alpha_rad);
    
    Fw = N .* num / den;
    
    % 磁力計算 (F_magnet)
    % Fm = (ECB.C_s - ECB.C_e .* omega_rpm) ./ (g_curr*1000 + ECB.g_e).^2;
    % F_attr = 26781.2188 ./ (g_curr*1000 + 2.3717).^2; % 靜磁吸力
    % F_rep = 12.3061 .* omega_rpm ./ (g_curr*1000 + 2.3717).^2; % 渦電流斥力
    F_mag = ECB_axialForce(ECB, rpm, g_curr);
    F_total = Fw + F_mag;

    info.den = den;
    info.Fw = Fw;
    info.F_mag = F_mag;
    info.r_omega = r_w;
end