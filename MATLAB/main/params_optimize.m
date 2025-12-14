%% --- START OF FILE Optimize_Parametric_Logic.m ---
clc; clear; close all;

%% 1. 定義設計目標
target1 = [255.6, 1.833]; % 低速
target2 = [573.0, 18.39]; % 高速

fprintf('=== 參數化邏輯最佳化 (無干涉保證版) ===\n');

%% 2. 定義優化變數 (使用比例參數代替絕對尺寸)
% 我們優化 13 個變數：
% x(1): g1 (低速氣隙)
% x(2): g2 (高速氣隙)
% x(3): r_yo (背鐵外徑) -> 絕對值
% x(4): r_yi (背鐵內徑) -> 絕對值 (但在 constraint 限制與 r_yo 的距離)
% x(5): t_y
% x(6): sigma
% x(7): t_c
% x(8): H_c 矯頑力
% x(9): B_r 剩磁
% x(10): k_lm  <-- [新] 磁石長度佔用比 (0~1)
% x(11): k_pos <-- [新] 磁石安裝位置比 (0~1)
% x(12): PM_ratio
% x(13): t_m

% 設定上下界 (LB, UB)
% 注意 x(8) 和 x(9) 現在是比例，範圍固定為 0~1 (或留點餘裕 0.05~0.95)
%      g1     g2     r_yo   r_yi   t_y    sigma   t_c     H_c    B_r  kl_m   k_pos  PM    t_m
lb = [0.002, 0.001, 0.040, 0.020, 0.001, 24.9e6, 0.0005, 844e3, 1.14, 0.10,  0.00,  0.4, 0.001];
ub = [0.015, 0.012, 0.110, 0.060, 0.010, 59.5e6, 0.0050, 907e3, 1.33, 0.90,  1.00,  0.9, 0.009];

%% 3. 優化選項
options = optimoptions('fmincon', ...
    'Display', 'none', ...
    'Algorithm', 'sqp', ...
    'MaxFunctionEvaluations', 5000, ...
    'StepTolerance', 1e-10, ...
    'ConstraintTolerance', 1e-6);

% 儲存結構
results_p = struct('p', [], 'x', [], 'fval', [], 'params', []);

%% 4. 執行優化 (遍歷極對數 p)
possible_poles = 4:8;

for i = 1:length(possible_poles)
    current_p = possible_poles(i);
    fprintf('優化 p = %d ... ', current_p);
    
    % 初始猜測值 (使用比例係數，例如 0.5 代表在正中間)
    x0 = zeros(1, 13);
    x0(1)=0.008; x0(2)=0.003; % g1, g2
    x0(3)=0.090; x0(4)=0.040; x0(5)=0.005; % r_yo, r_yi, t_y
    x0(6)=35e6; x0(7)=0.002; x0(8)=880e3; x0(9)=1.25; % sigma, t_c, H_c, B_r
    x0(10)=0.5;   % k_lm: 磁石長度佔一半空間
    x0(11)=0.5;   % k_pos: 磁石裝在正中間
    x0(12)=0.7; % PM_ratio
    x0(13)=0.005;  % t_m
    
    % 確保初始值在邊界內
    x0 = max(lb, min(ub, x0));

    % 目標函數
    objFunc = @(x) objectiveCost(x, lb, ub);
    
    % 限制函數 (包含動態幾何解碼)
    nonlconFunc = @(x) parametricConstraints(x, target1, target2, current_p);
    
    % 線性限制 g2 <= g1
    A = [-1, 1, zeros(1,11)]; b = 0;
    
    try
        [x_opt, fval, exitflag] = fmincon(objFunc, x0, A, b, [], [], lb, ub, nonlconFunc, options);
        % fval 純粹反映「成本/體積/行程」；只要 exitflag > 0，代表扭矩誤差已經接近 0 了
        
        results_p(i).p = current_p;
        results_p(i).x = x_opt;
        results_p(i).fval = fval;
        results_p(i).params = xToParams(x_opt, current_p); % 解碼回真實物理參數
        
        if exitflag > 0
            fprintf('成功 (Cost: %.4f)\n', fval);
        else
            fprintf('未完全收斂 (Flag: %d)\n', exitflag);
        end
    catch ME
        fprintf('失敗: %s\n', ME.message);
        results_p(i).fval = Inf;
    end
end

%% 5. 選出最佳解
valid_results = results_p([results_p.fval] ~= Inf);
if isempty(valid_results), error('所有優化均失敗'); end

[~, best_idx] = min([valid_results.fval]);
best = valid_results(best_idx);
params = best.params;

%% 6. 結果顯示
g1 = best.x(1); g2 = best.x(2);
T1 = calculateTorque(params, target1(1), g1);
T2 = calculateTorque(params, target2(1), g2);

fprintf('\n=== 最佳化結果 (Parametric Logic) ===\n');
fprintf('極對數 p = %d\n', best.p);
fprintf('--------------------------------------\n');
fprintf('【幾何參數 (絕對值)】\n');
fprintf('  背鐵外徑 (r_yo): %.2f mm\n', params.r_yo*1000);
fprintf('  背鐵內徑 (r_yi): %.2f mm\n', params.r_yi*1000);
fprintf('    -> 可用空間  : %.2f mm\n', (params.r_yo - params.r_yi)*1000);
fprintf('  磁石長度 (l_m) : %.2f mm (佔用比: %.0f%%)\n', params.l_m*1000, best.x(10)*100);
fprintf('  安裝半徑 (r_av): %.2f mm (位置比: %.0f%%)\n', params.r_av*1000, best.x(11)*100);
fprintf('  磁石厚度 (t_m) : %.2f mm\n', params.t_m*1000);

fprintf('\n【扭矩性能】\n');
fprintf('  目標1: %.3f Nm -> 實際: %.3f Nm (Err: %.2f%%)\n', target1(2), T1, abs(T1-target1(2))/target1(2)*100);
fprintf('  目標2: %.3f Nm -> 實際: %.3f Nm (Err: %.2f%%)\n', target2(2), T2, abs(T2-target2(2))/target2(2)*100);

%% 7. 將所有成功收斂的組別匯出至 Excel
if ~exist('valid_results', 'var') || isempty(valid_results)
    warning('沒有 valid_results 變數，無法匯出數據。請確認優化過程有成功找到解。');
else
    fprintf('\n正在將 %d 組成功數據寫入 Excel...\n', length(valid_results));
    % 1. 預分配記憶體 (Pre-allocation)
    n = length(valid_results);
    
    % 定義要儲存的欄位
    % 基本資訊
    col_p = zeros(n, 1);
    col_fval = zeros(n, 1);
    
    % 機構與氣隙 (轉成 mm)
    col_g1 = zeros(n, 1);
    col_g2 = zeros(n, 1);
    
    % 固定參數
    col_mu_0 = repelem(4*pi*1e-7,n).'; 
    col_mu_y = repelem(4000,n).';
    col_mu_c = repelem(1.257e-6,n).';

    % 幾何尺寸 (轉成 mm)
    col_r_yo = zeros(n, 1);
    col_r_yi = zeros(n, 1);
    col_t_y = zeros(n, 1);
    col_r_co = zeros(n, 1);
    col_r_ci = zeros(n, 1);
    col_t_c = zeros(n, 1);
    col_t_m = zeros(n, 1);
    col_l_m = zeros(n, 1);
    col_r_av = zeros(n, 1);
    col_PM_ratio = zeros(n, 1);
    
    % 材料性質
    col_B_r = zeros(n, 1);
    col_H_c = zeros(n, 1);
    col_sigma = zeros(n, 1);
    col_mu_r = zeros(n, 1);

    % 剩餘參數
    col_theta_p = zeros(n,1);
    col_tau_p = zeros(n,1);
    col_w_m = zeros(n,1);
    col_H = zeros(n,1);
    
    % 扭矩驗證 (驗證優化結果是否真的達標)
    col_Torque1 = zeros(n, 1);
    col_Torque2 = zeros(n, 1);
    
    % 2. 迴圈提取數據
    for i = 1:n
        res = valid_results(i);
        p_struct = res.params;
        
        % 優化變數 x 裡的氣隙 (依照您的定義 x(1)=g1, x(2)=g2)
        g1_val = res.x(1);
        g2_val = res.x(2);
        
        % 填入數據
        col_p(i) = res.p;
        col_fval(i) = res.fval;
        
        col_g1(i) = g1_val * 1000; % mm
        col_g2(i) = g2_val * 1000; % mm
        
        col_r_yo(i) = p_struct.r_yo * 1000;
        col_r_yi(i) = p_struct.r_yi * 1000;
        col_t_y(i)  = p_struct.t_y * 1000;
        col_r_co(i) = p_struct.r_co * 1000;
        col_r_ci(i) = p_struct.r_ci * 1000;
        col_t_c(i)  = p_struct.t_c * 1000;
        col_t_m(i)  = p_struct.t_m * 1000;
        col_l_m(i)  = p_struct.l_m * 1000;
        col_r_av(i) = p_struct.r_av * 1000;
        col_PM_ratio(i) = p_struct.PM_ratio;
        
        col_B_r(i) = p_struct.B_r;
        col_H_c(i) = p_struct.H_c;
        col_sigma(i) = p_struct.sigma;
        col_mu_r(i) = p_struct.mu_r; 
        
        col_theta_p(i) = p_struct.theta_p;
        col_tau_p(i) = p_struct.tau_p;
        col_w_m(i) = p_struct.w_m * 1000;
        col_H(i) = p_struct.H;
        % 重新計算一次扭矩以記錄
        col_Torque1(i) = T1;
        col_Torque2(i) = T2;
    end
    
    % 3. 建立 Table
    T_out = table(col_p, col_fval, ...
        col_g1, col_g2, ...
        col_mu_0, col_mu_y, col_mu_c, ...
        col_r_yo, col_r_yi, col_t_y, col_sigma, ...
        col_r_co, col_r_ci, col_t_c, col_H_c, col_B_r, ...
        col_r_av, col_l_m, col_t_m, col_PM_ratio, col_mu_r, ...
        col_theta_p, col_tau_p, col_w_m, col_H, ...
        col_Torque1, col_Torque2, ...
        'VariableNames', {'p', 'Cost_fval', ...
                        'Gap_Low', 'Gap_High', ...
                        'mu_0', 'mu_y', 'mu_c', ...
                        'r_yo', 'r_yi', 't_y', 'sigma', ...
                        'r_co', 'r_ci', 't_c', 'H_c', 'B_r', ...
                        'r_av', 'l_m', 't_m', 'PM_ratio', 'mu_r', ...
                        'theta_p', 'tau_p', 'w_m', 'H', ...
                        'Torque_Low', 'Torque_High'});
    % 4. 寫入 Excel
    filename = 'Optimization_Results.xlsx';
    
    % 檢查檔案是否存在，若存在則刪除舊檔 (避免寫入衝突或混淆)
    if exist(filename, 'file')
        delete(filename);
    end
    
    writetable(T_out, filename);
    fprintf('數據已成功儲存至檔案: %s\n', filename);
    
    % 顯示預覽
    disp('數據預覽 (前 5 筆):');
    disp(head(T_out, 5));
end

%% --- 核心函數：參數解碼 (Decoder) ---
function params = xToParams(x, p)
    % 將 [0,1] 的比例係數轉為符合物理限制的絕對尺寸
    
    params = struct();
    params.mu_0 = 4*pi*1e-7; params.mu_y = 4000; params.mu_c = 1.257e-6;
    
    % 1. 讀取獨立變數
    params.r_yo = x(3);
    params.r_yi = x(4);
    params.t_y = x(5); params.sigma = x(6);
    params.r_co = params.r_yo; params.r_ci = params.r_yi;
    params.t_c = x(7); params.H_c = x(8);
    params.B_r = x(9); params.PM_ratio = x(12); params.t_m = x(13);
    params.mu_r = params.B_r / params.H_c / params.mu_0;
    
    % 2. 解碼依賴變數 (Transformations)
    k_lm = x(10);  % 磁石長度比例
    k_pos = x(11); % 磁石位置比例
    
    % 邏輯 A: l_m 必須小於可用空間
    space_available = params.r_yo - params.r_yi;
    % 為了安全，我們假設最大只能用到空間的 95% (避免完全卡死)
    max_lm = space_available - 0.002; % 留 2mm 餘裕
    if max_lm < 0, max_lm = 0.001; end % 防錯
    
    params.l_m = k_lm * max_lm; 
    
    % 邏輯 B: r_av 必須讓磁石在背鐵內
    % 磁石的半徑範圍: [r_av - lm/2, r_av + lm/2]
    % 必須滿足: r_yi < (r_av - lm/2)  且  (r_av + lm/2) < r_yo
    % 推導出 r_av 的可行範圍:
    min_rav = params.r_yi + params.l_m/2 + 0.001; % 內側留 1mm
    max_rav = params.r_yo - params.l_m/2 - 0.001; % 外側留 1mm
    
    % 確保 min < max (理論上由上面的 l_m 邏輯保證了，但再防一次)
    if min_rav > max_rav
        params.r_av = (min_rav + max_rav) / 2;
    else
        % 使用 k_pos 線性插值
        params.r_av = min_rav + k_pos * (max_rav - min_rav);
    end
    params.p = p;
    % 3. 計算其餘參數
    params.theta_p = pi / params.p;
    params.tau_p = params.r_av * params.theta_p;
    params.w_m = params.PM_ratio * params.tau_p;
    params.H = ((params.r_yo - (params.r_av + params.l_m / 2)) + ...
                (params.r_av - params.l_m / 2) - params.r_yi) / 2;
end

function cost = objectiveCost(x, ~, ub)
    % r_yo, t_m, 氣隙變化最小化
    r_yo = x(3); t_m = x(13); g1=x(1); g2=x(2);
    cost = (r_yo/ub(3))^2 + (t_m/ub(13)) + (abs(g1-g2)/0.01)*0.5;
end

function [c, ceq] = parametricConstraints(x, target1, target2, p)
    % 解碼參數
    params = xToParams(x, p);
    g1 = x(1); g2 = x(2);
    
    % 幾何限制
    % 因為我們用了比例參數，大部分幾何干涉已經在 xToParams 被解決了
    % 我們只需要確保 r_yi < r_yo 的基本空間存在
    
    % 限制: r_yo - r_yi >= 20mm (對應 Random code: min(60, r_yo... - 20))
    c1 = 0.020 - (params.r_yo - params.r_yi); 
    
    c = c1; % 不等式限制 (c <= 0)
    
    % 扭矩計算
    try
        T1 = calculateTorque(params, target1(1), g1);
        T2 = calculateTorque(params, target2(1), g2);
        if isnan(T1) || isnan(T2), error('NaN'); end
        ceq = [(T1-target1(2))/target1(2); (T2-target2(2))/target2(2)];
    catch
        ceq = [1e5; 1e5];
    end
end