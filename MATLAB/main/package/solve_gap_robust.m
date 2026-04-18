function [g_sol, penalty] = solve_gap_robust(params, w, T_target, range)
    % 計算邊界扭矩
    T_max_possible = ECB_BrakingTorque(params, w, range(1)); % g_min (最大扭矩)
    T_min_possible = ECB_BrakingTorque(params, w, range(2)); % g_max (最小扭矩)
    
    if T_target > T_max_possible
        % [情況 A] 設計太弱：即使氣隙最小，扭矩還是不夠
        g_sol = range(1); % 卡在最小值
        penalty = (T_target - T_max_possible)^2; % 懲罰 = 扭矩缺口平方
        
    elseif T_target < T_min_possible
        % [情況 B] 設計太強：即使氣隙最大，扭矩還是太大
        g_sol = range(2); % 卡在最大值
        penalty = (T_min_possible - T_target)^2; % 懲罰 = 扭矩溢出平方
        
    else
        % [情況 C] 目標在範圍內，安全使用 fzero
        try
            calc_err = @(g) ECB_BrakingTorque(params, w, g) - T_target;
            g_sol = fzero(calc_err, range);
            penalty = 0; % 成功求解，無懲罰
        catch
            g_sol = range(1);
            penalty = 1e4; % 求解失敗，給予高懲罰
        end
    end
end