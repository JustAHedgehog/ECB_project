function [g_current_vec, w_range, T_actual] = torqueCurveFitting(T_target_func, target1, target2, best)
    % 準備轉速取樣點
    w_range = linspace(target1(1), target2(1), 20); % 切 20 個點
    required_g = zeros(size(w_range));
    required_g(1) = best.x(1);
    required_g(length(w_range)) = best.x(2);

    % 3. 使用 fzero 或簡單優化找尋每個點對應的 g
    for j = 2:length(w_range)-1
        w_curr = w_range(j);
        T_target_curr = T_target_func(w_curr);
        % 建立一個局部目標：讓 T_sim(g) - T_target = 0
        error_func = @(g) calculateTorque(best.params, w_curr, g) - T_target_curr;
        
        % 在 [g_final, g_ini] 範圍內找解 (g_final 是最小氣隙，g_ini 是最大氣隙)
        try
            required_g(j) = fzero(error_func, [best.x(2), best.x(1)]);
        catch
            % 如果找不到精確解，找最接近的
            required_g(j) = fminbnd(@(g) abs(error_func(g)), best.x(2), best.x(1));
        end
    end

    g_logic = @(w) interp1(w_range, required_g, w, 'pchip');
    T_actual = arrayfun(@(w) calculateTorque(best.params, w, g_logic(w)), w_range);

    % 獲取對應的氣隙向量
    g_current_vec = g_logic(w_range); % 使用 g_logic 計算 omega_range 內每個點的精確氣隙 (m)
end