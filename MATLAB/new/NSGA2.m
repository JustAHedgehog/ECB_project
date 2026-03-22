clc; clear; close all;

% 定義目標扭矩
Target_Start = [255.6, 1.833]; % w_ini, T_ini
Target_End   = [573.0, 18.39]; % w_final, T_final

% 定義優化變數範圍 (Lower Bound, Upper Bound)
%          r_yo   r_yi   t_y    t_c   k_lm   k_pos  PM   t_m    r_r    m_r   N   k_w  alpha mu_w  mu_t
lb_geo = [0.050, 0.014, 0.001, 0.002, 0.10,  0.00, 0.4, 0.001, 0.010, 0.010, 4,  0.01, 15,  0.10, 0.10];
ub_geo = [0.110, 0.040, 0.010, 0.050, 0.90,  1.00, 0.9, 0.009, 0.050, 0.300, 12, 0.99, 75,  0.20, 0.60];
% 軌跡參數: [n_up, n_down]，n = 1 為線性, n < 1 為凸, n > 1 為凹
lb_traj = [0.5, 0.5]; 
ub_traj = [3.0, 3.0];

lb = [lb_geo, lb_traj];
ub = [ub_geo, ub_traj];
nvars = length(lb);

% 設定整數變數 (N 是第 11 個變數)
IntCon = [11]; 

% NSGA-II 設定
options = optimoptions('gamultiobj', ...
    'PopulationSize', 500, ...
    'ParetoFraction', 0.4, ...
    'MaxGenerations', 1000, ...
    'display', 'iter', ...
    'UseParallel', true); % 建議開啟平行運算加速

% 定義函數 Handle
p_fixed = 5;

% 目標函數 (最小化 [Area, R_hy, Volume])
FitnessFcn = @(x) objective(x, p_fixed, Target_Start, Target_End);

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
results = analyze_result(x_optimal, p_fixed, Target_Start, Target_End);

% 3. 檢查是否成功達成目標
if ~results.success
    warning('警告：此最佳解無法完美達到目標扭矩 (存在邊界誤差)。');
    fprintf('g_ini: %.4f m, g_final: %.4f m\n', results.g_ini, results.g_final);
end

fprintf('\n=== 最佳化結果 (Parametric Logic) ===\n');
fprintf('極對數 p = %d\n', results.ECB.p);
fprintf('--------------------------------------\n');
fprintf('【電磁參數】\n');
fprintf('  背鐵外徑 (r_yo): %.2f mm\n', results.ECB.r_yo*1000);
fprintf('  背鐵內徑 (r_yi): %.2f mm\n', results.ECB.r_yi*1000);
fprintf('    -> 可用空間  : %.2f mm\n', (results.ECB.r_yo - results.ECB.r_yi)*1000);
fprintf('  磁石長度 (l_m) : %.2f mm (佔用比: %.0f%%)\n', results.ECB.l_m*1000, x_optimal(5)*100);
fprintf('  安裝半徑 (r_av): %.2f mm (位置比: %.0f%%)\n', results.ECB.r_av*1000, x_optimal(6)*100);
fprintf('  磁石厚度 (t_m) : %.2f mm\n', results.ECB.t_m*1000);
fprintf('\n【扭矩性能】\n');
fprintf('  目標1: %.3f Nm -> 實際: %.3f Nm (Err: %.2f%%)\n', Target_Start(2), results.T_up(1), abs(results.T_up(1)-Target_Start(2))/Target_Start(2)*100);
fprintf('  目標2: %.3f Nm -> 實際: %.3f Nm (Err: %.2f%%)\n', Target_End(2), results.T_down(end), abs(results.T_down(end)-Target_End(2))/Target_End(2)*100);

fprintf('【自調節參數】\n');
fprintf('滾子半徑 (r_r): %.2f mm\n', results.mech.r_r*1000);
fprintf('滾子數量 (N): %d\n', results.mech.N);
fprintf('楔形角度 (alpha): %.2f deg\n', results.mech.alpha);
fprintf('楔形摩擦 (mu_w): %.3f\n', results.mech.mu_w);
fprintf('盤面摩擦 (mu_t): %.3f\n', results.mech.mu_t);
fprintf('遲滯比例: %.4f\n', results.R_hy);

%% 繪圖驗證
figure('Name', '優化結果驗證');

subplot(2,1,1);
plot(results.w_vec, results.g_up * 1000, 'b-', 'LineWidth', 2); hold on;
plot(results.w_vec, results.g_down * 1000, 'r--', 'LineWidth', 2);
ylabel('Air Gap (mm)'); legend('Up Stroke', 'Down Stroke');
title('優化後的氣隙軌跡'); grid on;

subplot(2,1,2);
plot(results.w_vec, results.T_up, 'b-', 'LineWidth', 2); hold on;
plot(results.w_vec, results.T_down, 'r--', 'LineWidth', 2);
% 標示目標點
plot(Target_Start(1), Target_Start(2), 'ko', 'MarkerFaceColor', 'g');
plot(Target_End(1), Target_End(2), 'ko', 'MarkerFaceColor', 'g');
xlabel('Speed (rpm)'); ylabel('Torque (Nm)');
title('對應的扭矩曲線'); grid on;

function data = analyze_result(x, p, Target_Start, Target_End)
    % 1. 解碼參數 (必須與 objective 內一致)
    [ECB, mech, traj] = xToParams(x, p);
    
    % 定義搜尋範圍 (單位: m)
    g_search_range = [0.001, 0.025]; 
    
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
    
    % --- 4. 計算上升段 (Acceleration) ---
    % 氣隙公式
    g_up = g_ini - (g_ini - g_final) .* ((w_vec - Target_Start(1)) ./ (Target_End(1) - Target_Start(1))) .^ traj.n_up;
    
    T_up = zeros(size(w_vec));
    for i = 1:length(w_vec)
        T_up(i) = ECB_BrakingTorque(ECB, w_vec(i), g_up(i));
    end
    
    % --- 5. 計算遲滯點與下降段 (Deceleration) ---
    % 這裡需要計算機構力平衡，找出遲滯釋放點 C
    % B點狀態 (最高轉速)
    F_B= requiredForce(mech, ECB, Target_End(1), g_final, g_ini, 'up');
    
    % 尋找 w_C (下降段推力 = F_total_B 的轉速)
    w_C = hysteresisPoint(F_B, mech, g_final, g_ini, Target_End(1));
    
    R_hy = (Target_End(1) - w_C) / (Target_End(1) - Target_Start(1));
    
    % 計算下降氣隙 g_down
    g_down = zeros(size(w_vec));
    for i = 1:length(w_vec)
        w = w_vec(i);
        if w >= w_C
            g_down(i) = g_final; % 滯留
        else
            % 回復
            if w_C > Target_Start(1)
                ratio = (w - Target_Start(1)) / (w_C - Target_Start(1));
            else
                ratio = 0;
            end
            if ratio < 0, ratio = 0; end
            g_down(i) = g_ini - (g_ini - g_final) * (ratio ^ traj.n_down);
        end
    end
    
    % 計算下降扭矩
    T_down = zeros(size(w_vec));
    for i = 1:length(w_vec)
        T_down(i) = ECB_BrakingTorque(ECB, w_vec(i), g_down(i));
    end
    
    % --- 6. 打包數據回傳 ---
    data.w_vec = w_vec;
    data.g_up = g_up;
    data.g_down = g_down;
    data.T_up = T_up;
    data.T_down = T_down;
    data.w_C = w_C;
    data.R_hy = R_hy;
    data.ECB = ECB;   % 保存幾何參數以便查閱
    data.mech = mech; 
end