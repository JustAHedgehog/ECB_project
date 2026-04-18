function values = objective(x, Target_Start, Target_End, g_search_range)
    [ECB, mech] = xToParams(x); % 解碼參數
    r_w_min = 0.027 + 0.005;
    r_w_max = ECB.r_yo - 0.005 - 2 * mech.r_r * cot(deg2rad(mech.alpha));

    % 檢查 1：上下界合理性 (如果 min >= max，代表機構塞不進去這點空間)
    if r_w_min >= r_w_max
        penalty = 6e6 + (r_w_min - r_w_max) * 1000; 
        values = [penalty, penalty, penalty]; 
        % warning('r_w_min (%.4f mm) >= r_w_max (%.4f mm). Penalty applied.', r_w_min*1000, r_w_max*1000);
        return;
    end

    w_ini = Target_Start(1);T_ini = Target_Start(2);
    w_final = Target_End(1);T_final = Target_End(2);
    
    % % 定義搜尋範圍 (單位: m)
    % g_search_range = [0.001, 0.025]; % 1mm 到 25mm
    
    % 3. 反求 g_ini, g_final
    [g_ini, pen_start] = solve_gap_robust(ECB, w_ini, T_ini, g_search_range);
    [g_final, pen_end] = solve_gap_robust(ECB, w_final, T_final, g_search_range);
    
    % 如果任何一個點無法達成目標 (有 Penalty)，則直接回傳懲罰值
    if pen_start > 0 || pen_end > 0
        % 懲罰值 = 基礎罰分 + 誤差平方
        Total_Penalty = 5e6 + (pen_start + pen_end) * 1000;
        % warning('Design cannot meet target torque. Total Penalty: %.4f', Total_Penalty);
        values = [Total_Penalty, Total_Penalty, Total_Penalty]; 
        return;
    end

    % --- 物理限制檢查 ---
    % 氣隙邏輯: 高轉速氣隙(g_final) 必須小於 低轉速氣隙(g_ini)
    if g_final >= g_ini
        diff = (g_final - g_ini) * 1000; % mm 差
        % warning('Invalid gap relationship: g_final (%.4f mm) >= g_ini (%.4f mm). Penalty applied.', g_final*1000, g_ini*1000);
        values = [4e6 + diff^2, 4e6 + diff^2, 4e6 + diff^2];
        return;
    end

    [F_s1, ~] = requiredForce(mech, ECB, w_ini, g_ini, g_ini, 'up'); % 忽略摩擦估算k
    [F_s2, info] = requiredForce(mech, ECB, w_final, g_final, g_ini, 'up');
    % 計算彈簧剛度 k (N/mm)，並檢查其合理性
    k_spring = (F_s2 - F_s1) / (g_ini - g_final);
    lb = k_spring - 53 * 10^3; ub = 157 * 10^3 - k_spring;
    if lb * ub < 0
        if lb < 0
            values = [3e6 + lb^2, 3e6 + lb^2, 3e6 + lb^2];
        else
            values = [3e6 + ub^2, 3e6 + ub^2, 3e6 + ub^2];
        end
        % warning('Unrealistic spring stiffness: %.2f N/m. Penalty applied.', k_spring);
        return;
    end
    % 定義任意氣隙 g 下的彈簧力函數
    F_spring = @(g) F_s1 + k_spring * (g_ini - g);
    % 算出 g_vec 與 T-N curve (使用 fzero)
    w_vec = linspace(w_ini, w_final, 10); % 優化時切10等分即可
    T_up = zeros(1, 10);
    T_down = zeros(1, 10);
    g_up_vec = zeros(1, 10);
    g_down_vec = zeros(1, 10);
    
    w_C = hysteresisPoint(F_s2, mech, ECB, g_final, g_ini, w_final);
    % 生成 "下降段" 軌跡並計算扭矩 (用於算面積)
    R_hy = (w_final - w_C) / (w_final - w_ini);
    % 若 R_hy 不合理 (<0)，給予懲罰
    if R_hy < 0 || info.Fw <= 0 || (ECB.r_yo - ECB.r_yi) < 0.020
        values = [2e6, 2e6, 2e6]; 
        % warning('Invalid R_hy: %.4f. Penalty applied.', R_hy); 
        return;
    end

    for i = 1:length(w_vec)
        w = w_vec(i);
        
        % 定義力平衡方程式： [機構與磁力總推力] - [彈簧力] = 0
        eq_up   = @(g) requiredForce(mech, ECB, w, g, g_final, 'up')   - F_spring(g);
        eq_down = @(g) requiredForce(mech, ECB, w, g, g_final, 'down') - F_spring(g);
        
        % 求解 上升段 g_up
        try
            % 限制搜尋範圍在 [g_final, g_ini]
            g_up_vec(i) = fzero(eq_up, [g_final, g_ini]);
        catch
            g_up_vec(i) = g_final; % 若無解則代表被卡死在最底
        end

        % 求解 下降段 g_down
        if w >= w_C
            g_down_vec(i) = g_final; % 保持在最小氣隙
        else
            if w_C == w_ini
                g_down_vec(i) = g_ini;
            else
                try
                    % 為了加速，建議加上 optimset('Display','off')
                    opts = optimset('Display','off');
                    g_down_vec(i) = fzero(eq_down, [g_final, g_ini], opts);
                catch
                    g_down_vec(i) = g_ini; % 若 fzero 失敗，設定一個安全預設值
                end
            end
        end
        
        % 計算對應的扭矩
        T_up(i)   = ECB_BrakingTorque(ECB, w, g_up_vec(i));
        T_down(i) = ECB_BrakingTorque(ECB, w, g_down_vec(i));
    end
    
    Area = trapz(w_vec, abs(T_up - T_down)); % hysteresis area
    Volume = pi * ECB.r_yo^2 * (2 * ECB.t_y + ECB.t_m + g_ini + ECB.t_c + 2 * mech.r_r);
    values = [Area, Volume, R_hy];
end