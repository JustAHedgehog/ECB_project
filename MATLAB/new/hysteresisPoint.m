function w_C = hysteresisPoint(F_target, mech, g_final, g_ini, w_max)
    % 目標函數: F_down(w) - F_target = 0
    err_func = @(w) get_F_diff(w, F_target, mech, g_final, g_ini);
    
    try
        % 在 [0, w_max] 範圍內找解
        w_C = fzero(err_func, [0, w_max]);
    catch
        w_C = -1; % 標記失敗
    end
end

function diff = get_F_diff(w, F_target, mech, g_final, g_ini)
    [F_down, ~] = requiredForce(mech, ECB, w, g_final, g_ini, 'down');
    diff = F_down - F_target;
end