function values = objective(x, p, Target_Start, Target_End)
    [ECB, mech, traj] = xToParams(x, p); % 解碼參數
    r_w_min = 3 * ECB.r_yi;
    r_w_max = ECB.r_yo - 0.005 - 2 * mech.r_r * cot(deg2rad(mech.alpha));

    % 檢查 1：上下界合理性 (如果 min >= max，代表機構塞不進去這點空間)
    if r_w_min >= r_w_max
        values = [1e9, 1e9]; % 給予高懲罰，直接跳過這組解
        return;
    end

    % 計算 r_omega 基準位置 (k_pos 就是你 x 陣列裡 0~1 的那個變數)
    mech.r_omega_ini = r_w_min + mech.k_w * (r_w_max - r_w_min);

    w_ini = Target_Start(1);T_ini = Target_Start(2);
    w_final = Target_End(1);T_final = Target_End(2);
    
    % % 定義匿名函數：給定 g，計算 (T_calc - T_target)
    % calc_err = @(g, w, T_t) calculateTorque(ECB, w, g) - T_t;
    % % 使用 fzero 尋找氣隙 (搜尋範圍 1mm ~ 20mm)
    % try
    %     g_ini = fzero(@(g) calc_err(g, w_ini, T_ini), [0.001, 0.020]);
    %     g_final = fzero(@(g) calc_err(g, w_final, T_final), [0.001, 0.020]);
    % catch ME % 捕捉錯誤訊息到變數 ME
    %     fprintf('g fzero failed: %s\n', ME.message); 
    %     values = [1e9, 1e9]; return;
    % end
    % % 物理限制檢查：g_ini 必須大於 g_final (轉速高氣隙小)
    % if g_ini <= g_final
    %     values = [1e9, 1e9]; return;
    % end

    % 定義搜尋範圍 (單位: m)
    g_search_range = [0.001, 0.025]; % 1mm 到 25mm
    
    % --- 處理 Start 點 ---
    [g_ini, pen_start] = solve_gap_robust(ECB, w_ini, T_ini, g_search_range);
    
    % --- 處理 End 點 ---
    [g_final, pen_end] = solve_gap_robust(ECB, w_final, T_final, g_search_range);
    
    % 如果任何一個點無法達成目標 (有 Penalty)，則直接回傳懲罰值
    if pen_start > 0 || pen_end > 0
        % 懲罰值 = 基礎罰分 + 誤差平方 (讓演算法知道誰比較接近)
        % 這裡乘以一個權重 (e.g., 1000) 讓誤差被放大，優於純體積目標
        Total_Penalty = 1e4 + (pen_start + pen_end) * 1000;
        values = [Total_Penalty, Total_Penalty]; 
        return;
    end
    
    % --- 物理限制檢查 ---
    % 1. 氣隙邏輯: 高轉速氣隙(g_final) 必須小於 低轉速氣隙(g_ini)
    if g_final >= g_ini
        % 給予一個與 "差距" 成正比的懲罰，引導它修正
        diff = (g_final - g_ini) * 1000; % mm 差
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
            values = [1e9, 1e9]; return;
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