function values = objective(x, Target_Start, Target_End)
    [ECB, mech, traj] = xToParams(x); % 解碼參數
    r_w_min = 0.027 + 0.005;
    r_w_max = ECB.r_yo - 0.005 - 2 * mech.r_r * cot(deg2rad(mech.alpha));

    % 檢查 1：上下界合理性 (如果 min >= max，代表機構塞不進去這點空間)
    if r_w_min >= r_w_max
        penalty = 1e6 + (r_w_min - r_w_max) * 10000; 
        values = [penalty, penalty]; 
        % warning('r_w_min (%.4f mm) >= r_w_max (%.4f mm). Penalty applied.', r_w_min*1000, r_w_max*1000);
        return;
    end

    w_ini = Target_Start(1);T_ini = Target_Start(2);
    w_final = Target_End(1);T_final = Target_End(2);
    
    % 定義搜尋範圍 (單位: m)
    g_search_range = [0.001, 0.025]; % 1mm 到 25mm
    
    % --- 處理 Start 點 ---
    [g_ini, pen_start] = solve_gap_robust(ECB, w_ini, T_ini, g_search_range);
    
    % --- 處理 End 點 ---
    [g_final, pen_end] = solve_gap_robust(ECB, w_final, T_final, g_search_range);
    
    % 如果任何一個點無法達成目標 (有 Penalty)，則直接回傳懲罰值
    if pen_start > 0 || pen_end > 0
        % 懲罰值 = 基礎罰分 + 誤差平方
        % 這裡乘以一個權重 (e.g., 1000) 讓誤差被放大，優於純體積目標
        Total_Penalty = 1e4 + (pen_start + pen_end) * 1000;
        % warning('Design cannot meet target torque. Total Penalty: %.4f', Total_Penalty);
        values = [Total_Penalty, Total_Penalty]; 
        return;
    end

    % --- 物理限制檢查 ---
    % 氣隙邏輯: 高轉速氣隙(g_final) 必須小於 低轉速氣隙(g_ini)
    if g_final >= g_ini
        % 給予一個與 "差距" 成正比的懲罰，引導它修正
        diff = (g_final - g_ini) * 1000; % mm 差
        % warning('Invalid gap relationship: g_final (%.4f mm) >= g_ini (%.4f mm). Penalty applied.', g_final*1000, g_ini*1000);
        values = [1e4 + diff^2, 1e4 + diff^2];
        return;
    end

    try
        w_vec = linspace(w_ini, w_final, 30);
        % 上升段氣隙公式
        g_up = g_ini - (g_ini - g_final) .* ((w_vec - w_ini) ./ (w_final - w_ini)) .^ traj.n_up;
        
        % 計算上升段扭矩
        T_up = zeros(size(w_vec));
        for i = 1:length(w_vec)
            T_up(i) = ECB_BrakingTorque(ECB, w_vec(i), g_up(i));
        end
        
        [F_B, info] = requiredForce(mech, ECB, w_final, g_final, g_ini, 'up');
        w_C = hysteresisPoint(F_B, mech, g_final, g_ini, w_final);
        % 生成 "下降段" 軌跡並計算扭矩 (用於算面積)
        R_hy = (w_final - w_C) / (w_final - w_ini);
        % 若 R_hy 不合理 (<0)，給予懲罰
        if R_hy < 0 || 0.01 - info.den <= 0 || info.Fw <= 0  || (ECB.r_yo - ECB.r_yi) < 0.020
            values = [1e9, 1e9]; warning('Invalid R_hy: %.4f. Penalty applied.', R_hy); return;
        end
        g_down = zeros(size(w_vec));
        for i = 1:length(w_vec)
            w = w_vec(i);
            if w >= w_C
                g_down(i) = g_final; % 保持在最小氣隙
            else
                if w_C == w_ini
                    g_down(i) = g_ini;
                else
                    ratio = (w - w_ini) / (w_C - w_ini);
                    if ratio < 0, ratio = 0; end
                    g_down(i) = g_ini - (g_ini - g_final) * (ratio ^ traj.n_down);
                end
            end
        end
        T_down = zeros(size(w_vec));
        for i = 1:length(w_vec)
            T_down(i) = ECB_BrakingTorque(ECB, w_vec(i), g_down(i));
        end
        
        Area = trapz(w_vec, abs(T_up - T_down)); % hysteresis area
        Volume = pi * ECB.r_yo^2 * (2 * ECB.t_y + ECB.t_m + traj.g_ini + ECB.t_c + 2 * mech.r_r);
        values = [Area, Volume, R_hy];
    catch
        values = [1e5, 1e5];
    end
end