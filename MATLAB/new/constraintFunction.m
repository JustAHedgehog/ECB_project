function [c, ceq] = constraintFunction(x)
    [ECB, mech, ~] = xToParams(x);
    [Fs_B, info_B] = requiredForce(mech, ECB, w_final, g_final, g_ini, 'up');
    [Fs_C, info_C] = requiredForce(mech, ECB, omega_C, g_final, g_ini, 'down');
    [R_hy, ~, is_valid] = hysteresis(ECB, mech, w_ini, w_final, forceCalcWrapper);
    % --- 定義不等式限制 c <= 0 ---
    % 限制 A: 自鎖防止 (den_down > 0)
    % 檢查 C 點 (下降段) 的分母，要求它至少大於 0.01 (避免數值不穩)
    c1 = 0.01 - info_C.den;
    
    % 限制 B: 推力必須為正 (Fw > 0) by 檢查負載最大的 B 點
    c2 = -info_B.Fw;
    
    % 限制 C: 幾何邊界 (r_omega < 110mm)
    % 檢查擴張最大的情況 (g_final 時半徑最大)
    c3 = info_B.r_omega - 0.110; 
    
    % 限制 D: 幾何邊界 (r_omega > r_yi + r_roller)
    % 防止滾子撞進內軸，檢查 g_ini (最小半徑) 情況
    [~, info_A] = requiredForce(mech, ECB, w_final, g_ini, g_ini, 'up');
    c4 = (mech.r_yi + mech.r_r) - info_A.r_omega;

    % 如果計算本身無效(is_valid=false)，c2 給一個大值強制不通過
    if ~is_valid
        c5 = 10;
    else
        % R_hy 必須 > 0.05 (避免接近 0 的無效設計)
        c5 = 0.05 - R_hy_calc;
    end

    % 整合所有不等式
    c = [c1; c2; c3; c4; c5];
    
    % --- 定義等式限制 ceq == 0 ---
    % 保持力平衡條件
    ceq = Fs_B - Fs_C;
end