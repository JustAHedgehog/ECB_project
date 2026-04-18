function w_C = hysteresisPoint(F_target, mech, ECB, g_final, g_ini, w_max)
    % 目標函數: F_down(w) - F_target = 0
    err_func = @(w) get_F_diff(w, F_target, mech, ECB, g_final, g_ini);
    
    % --- 1. 先計算並檢查兩端點 ---
    val_0 = err_func(0);
    val_max = err_func(w_max);
    
    % --- 2. 檢查奇異點 (摩擦自鎖) ---
    if isnan(val_0) || isnan(val_max)
        w_C = -3; % 標記為失敗 (摩擦自鎖)
        warning('F_down returned NaN at w=0 or w=w_max, indicating possible friction lock. Hysteresis point cannot be determined.');
        return;
    end
    
    % --- 3. 檢查磁力吸死 ---
    if val_0 * val_max > 0
        % 如果 val_0 也是大於 0，代表在 w=0 時，磁力 F_mag(0) > F_target
        % 這代表機構被磁鐵「吸死」了，永遠不會釋放。
        w_C = -2; % 標記為失敗 (磁力吸死)
        warning('F_down does not cross F_target within the range [0, w_max]. Possible magnetic lock detected. Hysteresis point cannot be determined.');
        return;
    end
    
    % --- 4. 兩端點一正一負，安全進入 fzero ---
    try
        opts = optimset('Display', 'off'); % 關閉警告加速運算
        w_C = fzero(err_func, [0, w_max], opts);
    catch
        w_C = -1; % 標記失敗 (未知收斂錯誤)
    end
end

function diff = get_F_diff(w, F_target, mech, ECB, g_final, g_ini)
    [F_down, ~] = requiredForce(mech, ECB, w, g_final, g_ini, 'down');
    diff = F_down - F_target;
end

