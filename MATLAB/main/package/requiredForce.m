function [F_total, info] = requiredForce(mech, ECB, omega_rpm, g_curr, g_ini, direction)
    % mech_params: 由 xToMechParams 產生的結構體
    % ECB: 包含 C_s, C_e, g_e 的結構體
    % 解包機械參數
    m_r = mech.m_r;
    N   = mech.N;
    r_w_ini = mech.r_omega_ini; % 初始旋轉半徑
    alpha_rad = deg2rad(mech.alpha);
    beta_rad = deg2rad(mech.beta);
    omega_rad = omega_rpm .* pi / 30;
    mu_w = mech.mu_w;
    mu_t = mech.mu_t;
    
    % 機構幾何計算
    disp_x = g_ini - g_curr; % 行程計算
    r_w = r_w_ini + disp_x .* cot(alpha_rad); % 旋轉半徑 r_omega
    
    % 推力計算 (F_wedge)
    s = strcmp(direction, 'up') .* 2 - 1; 
    
    % 1. 計算矩陣元素
    A11 = 1;
    A12 = s * 2 * mu_w * sin(alpha_rad) - 2 * sin(beta_rad) * cos(alpha_rad);
    A21 = s * mu_t;
    A22 = 2 * sin(beta_rad) * sin(alpha_rad) + s * 2 * mu_w * cos(alpha_rad);
    
    B1 = 0;
    B2 = m_r * omega_rad^2 * r_w;
    
    % 2. 計算主行列式 D (相當於 det(A) = A11*A22 - A12*A21)
    D = (A11 * A22) - (A12 * A21);
    
    % 防呆機制：若 D 趨近於 0，代表系統奇異 (例如發生物理上的絕對卡死)
    if abs(D) < 1e-10
        warning('行列式趨近於零，機構可能處於奇異點或無效狀態');
        F_total = NaN;
        return;
    end
    
    % 3. 套用克拉瑪公式展開式
    % Nt = det(A_Nt) / D = (B1*A22 - B2*A12) / D
    Nt = (B1 * A22 - B2 * A12) / D;
    Fw = N * Nt; % 總推力

    % 磁力計算 (F_magnet)
    F_mag = ECB_AxialForce(ECB, omega_rpm, g_curr);
    F_total = Fw + F_mag;

    info.Fw = Fw;
    info.Nt = Nt;
    info.F_mag = F_mag;
    info.r_omega = r_w;
end