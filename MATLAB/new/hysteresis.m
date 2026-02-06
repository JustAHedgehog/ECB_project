function [R_hy, w_C, is_valid] = hysteresis(ECB, mech, w_ini, w_final, requiredForceFunc)
    % - 透過力平衡逆向求解遲滯比
    %
    % 輸入:
    %   params, mech, ECB: 參數結構體
    %   w_ini, w_final: 轉速範圍 (rpm)
    %   requiredForceFunc: 指向 requiredForce 的 function handle
    %
    % 輸出:
    %   R_hy: 計算出的遲滯比
    %   w_C:  下降段的保持極限轉速
    %   is_valid: 布林值，若找不到解或 R_hy <= 0 則為 false
    
    
    % 1. 計算 B 點 (上升段頂點) 的 Required Force
    % 這是彈簧在壓縮到 g_final 時所施加的反作用力基準
    [F_req_B, ~] = requiredForceFunc(mech, ECB, w_final, 'up');
    
    % 2. 定義誤差函數
    % 我們要找 w_C，使得 F_down(w_C) == F_req_B
    % 目標: F_down(w) - F_B = 0
    target_func = @(w) calculate_F_diff(w, F_req_B, mech, ECB, requiredForceFunc);
    
    % 3. 求解 w_C
    % 搜索範圍: [0, w_final]
    % 注意: 物理上遲滯通常會讓 w_C < w_final。
    try
        % 檢查邊界符號，確保 fzero 能運作
        f_low = target_func(0);
        f_high = target_func(w_final);
        
        if f_low * f_high < 0
            w_C = fzero(target_func, [0, w_final]);
            is_valid = true;
        else
            % 如果兩端同號，代表沒有交點 (通常代表摩擦力太小或參數不合理)
            w_C = w_final; 
            is_valid = false;
        end
    catch
        w_C = w_final;
        is_valid = false;
    end
    
    % 4. 計算 R_hy
    % R_hy = (w_final - w_C) / (w_final - w_ini)
    den = w_final - w_ini;
    if den < 1e-4, den = 1e-4; end % 防除以零
    
    R_hy = (w_final - w_C) / den;
    
    % 5. 安全性檢查
    if R_hy <= 0 || isnan(R_hy)
        R_hy = 0; 
        is_valid = false; % 標記為無效設計，讓優化器懲罰它
    end
end

% 輔助函數: 用來給 fzero 呼叫
function diff = calculate_F_diff(w, F_target, mech, ECB, funcHandle)
    % 計算下降段推力
    [F_down, ~] = funcHandle(mech, ECB, w, 'down');
    
    diff = F_down - F_target;
end