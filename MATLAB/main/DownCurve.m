function [w_down, g_down_vec, T_down] = DownCurve(params, target1, target2, g_ini, g_final, mech)
    % DownCurve - 計算下降段的氣隙軌跡與所需推力
    %
    % 輸入:
    %   params, ECB : 電磁與常數結構體
    %   target1, target2 : [轉速, 扭矩] 目標
    %   g_ini, g_final : 最大與最小氣隙 (m)
    %   mech : 包含 R_hy, 機構尺寸等參數
    
    %% 1. 定義關鍵點位 (C, D, E)
    % 點 C: 遲滯開始點 (轉速下降，但氣隙剛開始要變)
    w_C = mech.omega_C; 
    T_C = mech.T_C;
    
    % 點 D: 低速遲滯點 (對應 Target 1 的轉速，但扭矩較高)
    w_D = target1(1); 
    T_D = mech.T_D;
    
    % 點 E: 回歸點 (完全回到初始狀態)
    w_E = mech.omega_E;
    T_E = mech.T_E;
    
    %% 2. 建立扭矩擬合函數 (針對 C-D-E 段)
    % 必須按轉速由小到大排序供插值使用
    pts_w = [w_E, w_D, w_C];
    pts_T = [T_E, T_D, T_C];
    
    % 使用 PCHIP (保形插值) 避免曲線震盪
    T_release_func = @(w) interp1(pts_w, pts_T, w, 'pchip');
    
    %% 3. 執行路徑掃描 (從最高轉速降到最低轉速)
    % 建立轉速向量 (從 target2 降到 w_E)
    w_down = linspace(target2(1), w_E, 50);
    g_down_vec = zeros(size(w_down));
    T_down = zeros(size(w_down));
    
    for i = 1:length(w_down)
        w_curr = w_down(i);
        
        if w_curr >= w_C
            % --- Phase 1: 保持段 (Holding) ---
            % 在 C 點之前，氣隙保持在最小氣隙
            g_down_vec(i) = g_final;
        else
            % --- Phase 2: 釋放段 (Release) ---
            % 氣隙變大，扭矩跟隨 C-D-E 曲線
            T_target = T_release_func(w_curr);
            
            % 逆向求解氣隙 g
            % 目標: T_sim(g) - T_target = 0
            error_func = @(g) calculateTorque(params, w_curr, g) - T_target;
            
            % 在 [g_final, g_ini] 之間找解
            try
                g_down_vec(i) = fzero(error_func, [g_final, g_ini]);
            catch
                % 若 fzero 失敗，用 fminbnd 找最接近的
                g_down_vec(i) = fminbnd(@(g) abs(error_func(g)), g_final, g_ini);
            end
        end
        
        % 紀錄實際扭矩 (Double Check)
        T_down(i) = calculateTorque(params, w_curr, g_down_vec(i));
    end
end