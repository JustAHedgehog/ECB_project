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