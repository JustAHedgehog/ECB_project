clc; clear; close all;

% 定義目標扭矩
Target_Start = [255.6, 1.833]; % w_ini, T_ini
Target_End   = [573.0, 18.39]; % w_final, T_final

% 定義優化變數範圍 (Lower Bound, Upper Bound)
%      1    2      3      4       5     6      7    8      9     10   11   12   13      14
%      p   r_yo   r_yi   t_y    t_c    k_lm   PM   t_m    r_r    m_r   N   k_r alpha  beta
lb = [ 3, 0.050, 0.014, 0.001, 0.001, 0.10, 0.5, 0.002, 0.010, 0.010,  3, 0.01,   15,   30];
ub = [10, 0.110, 0.020, 0.010, 0.005, 0.90, 0.9, 0.010, 0.050, 0.300, 12, 0.99,   75,   60];

nvars = length(lb);
g_search_range = [0.001, 0.025];

% 設定整數變數 (p 是第 1 個變數, N 是第 12 個變數)
IntCon = [1, 11]; 

% NSGA-II 設定
options = optimoptions('gamultiobj', ...
    'PopulationSize', 100, ...
    'ParetoFraction', 0.4, ...
    'MaxGenerations', 10, ...
    'display', 'iter', ...
    'UseParallel', true); % 建議開啟平行運算加速


% 目標函數 (最小化 [Area, R_hy, Volume])
FitnessFcn = @(x) objective(x, Target_Start, Target_End, g_search_range);

% 執行優化
[x_pareto, f_pareto, exitflag, output] = gamultiobj(FitnessFcn, ...    % 目標函數
    nvars, ...         % 變數數量
    [], [], ...        % 線性不等式限制 (A, b)
    [], [], ...        % 線性等式限制 (Aeq, beq)
    lb, ub, ...        % 變數上下界
    [], ...            % 非線性限制函數 (若改用 Penalty 法可設為 [])
    IntCon,...         % 整數限制
    options...         % 優化選項
);

%% 從優化結果中取出最佳解
% 假設 f_pareto 的第 1 欄是面積，我們取面積最小的解來觀察
[~, best_idx] = min(f_pareto(:, 1)); 
x_optimal = x_pareto(best_idx, :);

% 呼叫診斷函數
[results, ECB, mech] = analyze_result(x_optimal, Target_Start, Target_End, g_search_range);

% 3. 檢查是否成功達成目標
if ~results.success
    warning('警告：此最佳解無法完美達到目標扭矩 (存在邊界誤差)。');
    fprintf('g_ini: %.4f m, g_final: %.4f m\n', results.g_ini, results.g_final);
end

fprintf('\n=== 最佳化結果 (Parametric Logic) ===\n');
fprintf('極對數 p = %d\n', ECB.p);
fprintf('--------------------------------------\n');
fprintf('【電磁參數】\n');
fprintf('  背鐵外徑 (r_yo): %.2f mm\n', ECB.r_yo*1000);
fprintf('  背鐵內徑 (r_yi): %.2f mm\n', ECB.r_yi*1000);
fprintf('    -> 可用空間  : %.2f mm\n', (ECB.r_yo - ECB.r_yi)*1000);
fprintf('  背鐵厚度 (t_y) : %.2f mm\n', ECB.t_y*1000);
fprintf('  導體盤厚度 (t_c) : %.2f mm\n', ECB.t_c*1000);
fprintf('  磁石長度 (l_m) : %.2f mm (佔用比: %.0f%%)\n', ECB.l_m*1000, x_optimal(6)*100);
fprintf('  安裝半徑 (r_av): %.2f mm\n', ECB.r_av*1000);
fprintf('  磁石厚度 (t_m) : %.2f mm, 徑向佔比: %.0f%%\n', ECB.t_m*1000, ECB.PM_ratio*100);
fprintf('\n【扭矩性能】\n');
fprintf('  目標1: %.3f Nm -> 實際: %.3f Nm (g_ini: %.4f mm, Err: %.2f%%)\n', Target_Start(2), results.T_up(1), results.g_ini*1000, abs(results.T_up(1)-Target_Start(2))/Target_Start(2)*100);
fprintf('  目標2: %.3f Nm -> 實際: %.3f Nm (g_final: %.4f mm, Err: %.2f%%)\n', Target_End(2), results.T_down(end), results.g_final*1000, abs(results.T_down(end)-Target_End(2))/Target_End(2)*100);
fprintf('\n【自調節參數】\n');
fprintf('滾子半徑 (r_r): %.2f mm\n', mech.r_r*1000);
fprintf('滾子數量 (N): %d\n', mech.N);
fprintf('彈簧常數 (k): %.2f N/mm\n', mech.k_spring * 1e-3);
fprintf('楔形角度 (alpha): %.2f deg\n', mech.alpha);
fprintf('V-cut 角度 (beta): %.3f deg\n', mech.beta);
fprintf('遲滯比例: %.4f\n', results.R_hy);

T_C = ECB_BrakingTorque(ECB, results.w_C, results.g_final); % 釋放點的扭矩值
%% 繪圖驗證
figure('Name', '優化結果驗證');
subplot(2,1,1);
plot(results.w_vec, results.g_up * 1000, 'r--', 'LineWidth', 2); hold on;
plot(results.w_vec, results.g_down * 1000, 'b--', 'LineWidth', 2);
xline(results.w_C, 'k--', 'LineWidth', 1.5, 'Label', '釋放點 w_C', 'LabelVerticalAlignment', 'bottom');
ylabel('Air Gap (mm)'); legend('Up Stroke', 'Down Stroke');
title('優化後的氣隙軌跡'); grid on;

subplot(2,1,2);
plot(results.w_vec, results.T_up, 'r--', 'LineWidth', 2); hold on;
plot(results.w_vec, results.T_down, 'b--', 'LineWidth', 2);
% 標示目標點
plot(Target_Start(1), Target_Start(2), 'ko', 'MarkerFaceColor', 'g');
plot(Target_End(1), Target_End(2), 'ko', 'MarkerFaceColor', 'g');
% 標示釋放點
plot(results.w_C, T_C, 'ko', 'MarkerFaceColor', 'm', 'MarkerSize', 8, 'DisplayName', '釋放點 w_C');
xlabel('Speed (rpm)'); ylabel('Torque (Nm)');
title('對應的扭矩曲線'); grid on;

function [data, ECB, mech] = analyze_result(x, Target_Start, Target_End, g_search_range)
    % 1. 解碼參數
    [ECB, mech] = xToParams(x);
    % --- 2. 使用 Robust Solver 反求 g_ini 和 g_final ---
    % 即使最佳解可能稍有誤差，我們也要算出它實際的物理狀態
    [g_ini, pen_start] = solve_gap_robust(ECB, Target_Start(1), Target_Start(2), g_search_range);
    [g_final, pen_end] = solve_gap_robust(ECB, Target_End(1), Target_End(2), g_search_range);
    
    % 紀錄是否達成目標 (若 penalty > 0 代表該設計無法完美達到目標扭矩)
    data.success = (pen_start == 0 && pen_end == 0);
    data.g_ini = g_ini;
    data.g_final = g_final;
    
    % --- 3. 生成運作區間數據 ---
    % 解析度設高一點 (例如 100 點) 以獲得平滑曲線
    w_vec = linspace(Target_Start(1), Target_End(1), 100);
    T_up = zeros(1, 100); 
    T_down = zeros(1, 100);
    g_up_vec = zeros(1, 100);
    g_down_vec = zeros(1, 100);

    F_s1 = requiredForce(mech, ECB, Target_Start(1), g_final, g_ini, 'up');
    F_s2 = requiredForce(mech, ECB, Target_End(1), g_final, g_ini, 'up');
    mech.k_spring = (F_s2 - F_s1) / (g_ini - g_final);
    F_spring = @(g) F_s1 + mech.k_spring * (g_ini - g);
    w_C = hysteresisPoint(F_s2, mech, ECB, g_final, g_ini, Target_End(1));
    R_hy = (Target_End(1) - w_C) / (Target_End(1) - Target_Start(1));

    for i = 1:length(w_vec)
        w = w_vec(i);
        
        % 定義力平衡方程式： [機構與磁力總推力] - [彈簧力] = 0
        eq_up   = @(g) requiredForce(mech, ECB, w, g, g_final, 'up')   - F_spring(g);
        eq_down = @(g) requiredForce(mech, ECB, w, g, g_final, 'down') - F_spring(g);
        
        % --- 4. 計算上升/下降段的氣隙軌跡 ---
        try
            % 限制搜尋範圍在 [g_final, g_ini]
            g_up_vec(i) = fzero(eq_up, [g_final, g_ini]);
        catch
            g_up_vec(i) = g_final; % 若無解則代表被卡死在最底
        end

        if w >= w_C
            g_down_vec(i) = g_final; % 保持在最小氣隙
        else
            if w_C == Target_Start(1)
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
    
    % --- 5. 打包數據回傳 ---
    data.w_vec = w_vec;
    data.g_up = g_up_vec;
    data.g_down = g_down_vec;
    data.T_up = T_up;
    data.T_down = T_down;
    data.w_C = w_C;
    data.R_hy = R_hy;
end