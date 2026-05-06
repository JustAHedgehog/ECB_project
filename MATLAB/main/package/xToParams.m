function [ECB, mech] = xToParams(x)
    ECB = struct();
    ECB.mu_0 = 4*pi*1e-7;
    ECB.mu_y = 4000;
    ECB.mu_c = 1.257e-6;
    ECB.sigma = 38 * 10^6;
    ECB.H_c = 907 * 10^3; % N40, 矯頑力Hc (A/m)
    ECB.B_r = 1.29;
    ECB.N_harm = 15; % 奇數諧波取前 15 項
    ECB.K_bessel = 50; % 貝索根取前 50 個
    
    % 1. 讀取獨立變數
    ECB.p = x(1); % 極對數
    ECB.r_yo = x(2);
    ECB.r_yi = x(3);
    ECB.t_y = x(4); 
    ECB.r_co = ECB.r_yo; ECB.r_ci = ECB.r_yi;
    ECB.t_c = x(5); 
    ECB.PM_ratio = x(7);
    ECB.t_m = x(8);
    
    % 邏輯 A: l_m 必須小於可用空間
    space_available = ECB.r_yo - ECB.r_yi;
    % 為了安全，我們假設最大只能用到空間的 95% (避免完全卡死)
    max_lm = space_available - 0.002; % 留 2mm 餘裕
    if max_lm < 0, max_lm = 0.001; end % 防錯
    k_lm = x(6);  % 磁石長度比例
    ECB.l_m = k_lm * max_lm;
    ECB.r_av = (ECB.r_yo + ECB.r_yi) / 2;
    
    % 計算其餘參數
    ECB.mu_r = ECB.B_r / ECB.H_c / ECB.mu_0;
    ECB.theta_p = pi / ECB.p;
    ECB.tau_p = ECB.r_av * ECB.theta_p;
    ECB.w_m = ECB.PM_ratio * ECB.tau_p;
    ECB.H = ((ECB.r_yo - (ECB.r_av + ECB.l_m / 2)) + ...
                (ECB.r_av - ECB.l_m / 2) - ECB.r_yi) / 2;
    % ECB.H = (ECB.r_yo - ECB.r_yi - ECB.l_m) / 2;

    mech.r_r   = x(9);
    mech.m_r   = x(10);
    mech.N     = x(11);
    mech.k_r   = x(12);
    mech.alpha = x(13);
    mech.beta  = x(14);
    mech.mu_w  = 0.1;
    mech.mu_t  = 0.1;
    r_w_min = 0.027 + 0.005;
    r_w_max = ECB.r_yo - 0.005 - 2 * mech.r_r * cot(deg2rad(mech.alpha));
    % 計算 r_omega 基準位置
    mech.r_omega_ini = r_w_min + mech.k_r * (r_w_max - r_w_min);
end