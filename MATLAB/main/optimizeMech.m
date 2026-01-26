function [x_best, fval, best_mech_params] = optimizeMech(mech, ECB, w_ini, w_final, g_ini, g_final)
    % 計算 C 點轉速
    omega_C = w_final - 0.8 * (w_final - w_ini);
    forceCalcWrapper = @(x, w, g, dir) requiredForce(xToMechParams(x, mech.r_yi), ECB, w, g, g_ini, dir);

    % 定義目標函數 (現在變得很乾淨)
    objFunc = @(x) obj_mech_logic(x, w_ini, g_ini, forceCalcWrapper);
    
    % 定義限制函數
    nonlconFunc = @(x) constraints_logic(x, w_final, omega_C, g_final, forceCalcWrapper);

    % 執行優化
    options = optimoptions('fmincon', 'Display', 'iter', 'Algorithm', 'sqp');
    [x_best, fval] = fmincon(objFunc, mech.x0, [], [], [], [], mech.lb, mech.ub, nonlconFunc, options);
    
    % 回傳最終的結構體，方便外部使用
    best_mech_params = xToMechParams(x_best, mech.r_yi);
end

function score = obj_mech_logic(x, w_ini, g_ini, calcFunc)
    % calcFunc 已經包含了 constants，只需要變數
    Fs_A = calcFunc(x, w_ini, g_ini, 'up');
    Fs_D = calcFunc(x, w_ini, g_ini, 'down');
    score = abs(Fs_D - Fs_A) / abs(Fs_A);
end

function [c, ceq] = constraints_logic(x, w_final, omega_C, g_final, calcFunc)
    Fs_B = calcFunc(x, w_final, g_final, 'up');
    Fs_C = calcFunc(x, omega_C, g_final, 'down');
    c = [];
    ceq = Fs_B - Fs_C; 
end