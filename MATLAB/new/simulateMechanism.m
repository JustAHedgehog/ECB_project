function [g_vec, is_valid] = simulateMechanism(omega_vec, params, mode)
    g_vec = zeros(size(omega_vec));
    is_valid = true;
    
    % 根據模式設定摩擦力方向
    if strcmp(mode, 'ACC')
        mu_dir = 1; % 阻礙開啟
    else
        mu_dir = -1; % 阻礙復位
    end
    
    for i = 1:length(omega_vec)
        w = omega_vec(i);
        
        % 定義力平衡函數: f(gap) = F_cen - F_spring - F_mag - F_fric
        % 注意: 你要把 Slide 5 的所有公式寫在這個 force_balance 裡
        fun = @(gap) force_balance(gap, w, params, mu_dir);
        
        % 求解 gap，搜尋範圍設為 [g_min, g_max] (例如 2mm ~ 15mm)
        try
            g_sol = fzero(fun, [0.002, 0.015]); 
            g_vec(i) = g_sol;
        catch
            % 找不到解 (機構卡死或力量不夠)
            is_valid = false;
            return;
        end
    end
end

