function g_sol = gap_search_force(eq_func, g_final, g_ini)
    % eq_func = (總推力) - (彈簧力)
    % 若值 > 0，推力較強，機構會往 g_final 壓縮
    % 若值 < 0，彈簧較強，機構會往 g_ini 彈開
    
    val_final = eq_func(g_final);
    val_ini   = eq_func(g_ini);
    
    % 1. 考慮浮點數誤差，若非常接近 0，直接視為在邊界上
    tol = 1e-5;
    if abs(val_final) < tol
        g_sol = g_final; 
        return;
    end
    if abs(val_ini) < tol
        g_sol = g_ini; 
        return;
    end
    
    % 2. 檢查區間內是否有交點 (一正一負)
    if val_final * val_ini < 0
        opts = optimset('Display', 'off'); % 加速與保持版面乾淨而已，對運算結果沒有影響
        try
            g_sol = fzero(eq_func,[g_final, g_ini], opts);
        catch
            % 極端情況下防呆，回傳較接近 0 的那一端
            if abs(val_final) < abs(val_ini), g_sol = g_final; else, g_sol = g_ini; end
        end
    else
        % 3. 兩端點同號，代表區間內沒有力平衡點！
        % 這時必須由物理直覺接管：
        if val_ini > 0 
            % 淨力為正 (總推力 > 彈簧力)，機構被徹底壓死
            g_sol = g_final;
        else
            % 淨力為負 (總推力 < 彈簧力)，機構被徹底彈開
            g_sol = g_ini;
        end
    end
end