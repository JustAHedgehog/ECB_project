function f = objective(x, p)
    % x 是演算法傳進來的一組變數
    [ECB, mech] = xToParams(x, p);
    
    % 建立 Wrapper
    forceCalcWrapper = @(mech_p, ecb, w, g, g_ini, dir) requiredForce(mech_p, ecb, w, g, g_ini, dir);
    
    % 2. 計算物理遲滯比 R_hy
    [R_hy, w_C, is_valid_R] = hysteresis(ECB, mech, w_ini, w_final, forceCalcWrapper);
    
    % 如果計算出的遲滯無效(例如負值)，給予極大懲罰
    penalty_R = 0;
    if ~is_valid_R
        penalty_R = 1000; % 懲罰項
    end

    % 3. 計算遲滯面積 (Area)
    % 這裡需要重新生成包含真實 w_C 的下降路徑
    try
        % 上升段積分
        w_vec = linspace(w_ini, w_final, 20);
        [~, T_up] = solve_equilibrium_path(params, mech, w_vec, 'up', w_final, w_C);
        
        % 下降段積分 (關鍵：從 w_final -> w_C 保持，w_C -> w_ini 釋放)
        [~, T_down] = solve_equilibrium_path(params, mech, w_vec, 'down', w_final, w_C);
        
        Area = trapz(w_vec, abs(T_up - T_down));
    catch
        Area = 1e6; % 計算失敗懲罰
    end
    % 4. 計算體積
    Volume = pi * params.r_yo^2 * (2*params.t_m + params.g1 + 0.030);
    
    % 5. 輸出目標 (最小化面積, 最小化 R_hy, 最小化體積)
    % 注意：如果你希望 R_hy 越大越好，請加負號
    % 根據你的描述 "目標函數為最小化... R_hy"，保持正號即可
    f = [Area + penalty_R, R_hy + penalty_R, Volume];
end