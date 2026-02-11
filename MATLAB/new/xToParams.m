function [ECB, mech, traj] = xToParams(x, p)
    ECB = struct();
    ECB.mu_0 = 4*pi*1e-7;
    ECB.mu_y = 4000;
    ECB.mu_c = 1.257e-6;
    ECB.sigma = 38 * 10^6;
    ECB.H_c = 907 * 10^3; % N40, 矯頑力Hc (A/m)
    ECB.B_r = 1.29;
    
    % 1. 讀取獨立變數
    ECB.r_yo = x(1);
    ECB.r_yi = x(2);
    ECB.t_y = x(3); 
    ECB.r_co = ECB.r_yo; ECB.r_ci = ECB.r_yi;
    ECB.t_c = x(4); 
    ECB.PM_ratio = x(7); ECB.t_m = x(8);
    ECB.mu_r = ECB.B_r / ECB.H_c / ECB.mu_0;
    
    % 2. 解碼依賴變數 (Transformations)
    k_lm = x(5);  % 磁石長度比例
    k_pos = x(6); % 磁石位置比例
    
    % 邏輯 A: l_m 必須小於可用空間
    space_available = ECB.r_yo - ECB.r_yi;
    % 為了安全，我們假設最大只能用到空間的 95% (避免完全卡死)
    max_lm = space_available - 0.002; % 留 2mm 餘裕
    if max_lm < 0, max_lm = 0.001; end % 防錯
    
    ECB.l_m = k_lm * max_lm; 
    
    % 推導出 r_av 的可行範圍:
    % 必須讓磁石在背鐵內( r_yi < (r_av - lm/2)  且  (r_av + lm/2) < r_yo )
    min_rav = ECB.r_yi + ECB.l_m/2 + 0.001; % 內側留 1mm
    max_rav = ECB.r_yo - ECB.l_m/2 - 0.001; % 外側留 1mm
    
    % 確保 min < max (理論上由上面的 l_m 邏輯保證了，但再防一次)
    if min_rav > max_rav
        ECB.r_av = (min_rav + max_rav) / 2;
    else
        % 使用 k_pos 線性插值
        ECB.r_av = min_rav + k_pos * (max_rav - min_rav);
    end
    ECB.p = p;
    % 3. 計算其餘參數
    ECB.theta_p = pi / ECB.p;
    ECB.tau_p = ECB.r_av * ECB.theta_p;
    ECB.w_m = ECB.PM_ratio * ECB.tau_p;
    ECB.H = ((ECB.r_yo - (ECB.r_av + ECB.l_m / 2)) + ...
                (ECB.r_av - ECB.l_m / 2) - ECB.r_yi) / 2;
    mech.r_r   = x(9);
    mech.N     = round(x(10));
    mech.alpha = x(11);
    mech.mu_w  = x(12);
    mech.mu_t  = x(13);
    mech.rho   = 7840;
    % 軌跡參數
    traj.n_up = x(14);
    traj.n_down = x(15);
end