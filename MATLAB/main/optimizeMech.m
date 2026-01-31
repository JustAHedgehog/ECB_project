function [x_best, fval, best_mech_params] = optimizeMech(mech, ECB, w_ini, w_final, g_ini, g_final)
    forceCalcWrapper = @(x, w, g, dir) requiredForce(xToMechParams(x, mech.r_yi), ECB, w, g, g_ini, dir);

    % 定義目標函數
    objFunc = @(x) obj_mech_logic(x, w_ini, g_ini, forceCalcWrapper);
    
    % 定義限制函數
    nonlconFunc = @(x) constraints_logic(x, w_final, mech.omega_C, g_final, g_ini, ECB, mech.r_yi);

    % 執行優化
    options = optimoptions('fmincon', 'Algorithm', 'sqp', 'MaxFunctionEvaluations', 1000);
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

function [c, ceq] = constraints_logic(x, w_final, omega_C, g_final, g_ini, ECB, r_yi)
    params = xToMechParams(x, r_yi);
    [Fs_B, info_B] = requiredForce(params, ECB, w_final, g_final, g_ini, 'up');
    [Fs_C, info_C] = requiredForce(params, ECB, omega_C, g_final, g_ini, 'down');
    
    % --- 定義不等式限制 c <= 0 ---
    % 限制 A: 自鎖防止 (den_down > 0)
    % 檢查 C 點 (下降段) 的分母，要求它至少大於 0.01 (避免數值不穩)
    c1 = 0.01 - info_C.den; 
    
    % 限制 B: 推力必須為正 (Fw > 0) by 檢查負載最大的 B 點
    c2 = -info_B.Fw; 
    
    % % 限制 C: 幾何邊界 (r_omega < 110mm)
    % % 檢查擴張最大的情況 (g_final 時半徑最大)
    % c3 = info_B.r_omega - 0.110; 
    
    % 限制 D: 幾何邊界 (r_omega > r_yi + r_roller)
    % 防止滾子撞進內軸，檢查 g_ini (最小半徑) 情況
    [~, info_A] = requiredForce(params, ECB, w_final, g_ini, g_ini, 'up');
    c4 = (params.r_yi + params.r_r) - info_A.r_omega;

    % 整合所有不等式
    c = [c1; c2; c4];
    
    % --- 定義等式限制 ceq == 0 ---
    % 保持力平衡條件
    ceq = Fs_B - Fs_C; 
end