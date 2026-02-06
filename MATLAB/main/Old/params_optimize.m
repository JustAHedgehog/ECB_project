clc; clear; close all;

%% 1. 定義設計目標
target1 = [255.6, 1.833]; % 低速
target2 = [573.0, 18.39]; % 高速

%% 2. 定義優化變數 (使用比例參數代替絕對尺寸)
% x(1): g_ini (低速氣隙)
% x(2): g_final (高速氣隙)
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
%     g_ini  g_final r_yo   r_yi   t_y    sigma   t_c     H_c    B_r  k_lm   k_pos  PM    t_m
lb = [0.004, 0.003, 0.040, 0.020, 0.001, 24.9e6, 0.0005, 844e3, 1.14, 0.10,  0.00,  0.4, 0.001];
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
    x0(1)=0.008; x0(2)=0.003; % g_ini, g_final
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
        % 線性限制 g_final <= g_ini
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
g_ini = best.x(1); g_final = best.x(2);
T1 = calculateTorque(params, target1(1), g_ini);
T2 = calculateTorque(params, target2(1), g_final);

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

% 1. 建立目標二次曲線函數 (假設通過 0, A, B 三點)
% T = a*w^2 + b*w
pts = [target1(1)^2, target1(1); target2(1)^2, target2(1)]; % 自變數[w^2 w]
vals = [target1(2); target2(2)];
coeffs = pts \ vals; % 求解 [a; b]
a_target = coeffs(1); b_target = coeffs(2);

% 目標函數：給轉速 w，回傳目標扭矩 T
T_target_func = @(w) a_target * w.^2 + b_target * w;

% 2. 準備轉速取樣點
omega_range = linspace(target1(1), target2(1), 20); % 切 20 個點
required_g = zeros(size(omega_range));
required_g(1) = best.x(1);
required_g(length(omega_range)) = best.x(2);

% 3. 使用 fzero 或簡單優化找尋每個點對應的 g
for j = 2:length(omega_range)-1
    w_curr = omega_range(j);
    T_target_curr = T_target_func(w_curr);
    % 建立一個局部目標：讓 T_sim(g) - T_target = 0
    error_func = @(g) calculateTorque(best.params, w_curr, g) - T_target_curr;
    
    % 在 [g_final, g_ini] 範圍內找解 (g_final 是最小氣隙，g_ini 是最大氣隙)
    try
        required_g(j) = fzero(error_func, [best.x(2), best.x(1)]);
    catch
        % 如果找不到精確解，找最接近的
        required_g(j) = fminbnd(@(g) abs(error_func(g)), best.x(2), best.x(1));
    end
end

g_logic = @(w) interp1(omega_range, required_g, w, 'pchip');
T_actual = arrayfun(@(w) calculateTorque(params, w, g_logic(w)), omega_range);

%% --- 軸向推力計算 (配合 g_logic) ---
% 1. 定義機構參數
mech.radius_r = 0.03;      % 滾柱半徑 (m)
mech.L_r      = 0.04;      % 滾柱長度 (m)
mech.density  = 7840;      % S45C 密度 (kg/m^3)
mech.N        = 8;         % 滾子數量
mech.alpha    = 45;        % 楔形角度 (degree)
mech.mu_wedge = 0.1;       % 楔型面摩擦係數
mech.mu_t     = 0.1;       % 背鐵摩擦係數

% 2. 獲取對應的氣隙向量
% 使用 g_logic 計算 omega_range 內每個點的精確氣隙 (m)
g_current_vec = g_logic(omega_range); 

% 3. 呼叫calculateWedgeThrust函數計算推力
F_up   = calculateWedgeThrust(omega_range, g_current_vec, g_ini, mech, 'up');
F_down = calculateWedgeThrust(omega_range, g_current_vec, g_ini, mech, 'down');

%% --- 驗證與繪圖 ---
figure;
subplot(2,1,1);
yyaxis left
plot(omega_range, g_current_vec * 1000, '-o', 'DisplayName', 'g fit');
ylabel('Air Gap (mm)');
yyaxis right
plot(omega_range, T_target_func(omega_range), 'k--', 'LineWidth', 2, 'DisplayName', 'Target (Quadratic)'); hold on;
plot(omega_range, T_actual, 'ro', 'DisplayName', 'Actual (fitting)');
ylabel('Torque (N-m)'); 
ax = gca; % 获取当前坐标轴对象
ax.YColor = 'k'; % 设置 Y 轴颜色为蓝色 (g)
xlabel('Speed (rpm)');
legend('Location', 'north');
grid on;
title('Torque Validification & Air Gap Variation');

% 機構推力與氣隙關係
subplot(2,1,2);
yyaxis left
plot(omega_range, g_current_vec * 1000, '-o', 'DisplayName', 'g fit');
ylabel('Air Gap (mm)');
yyaxis right
plot(omega_range, F_up, 'o-', 'LineWidth', 2, 'DisplayName', 'ACC'); hold on;
plot(omega_range, F_down, 'go-', 'LineWidth', 2, 'DisplayName', 'DEC');
ylabel('Axial Thrust (N)');
xlabel('Speed (rpm)');
legend('Location', 'north');
grid on;
title('Wedge Mechanism Thrust Analysis (With Friction Hysteresis)');

%% 7. 將所有成功收斂的組別匯出至 Excel
% if ~exist('valid_results', 'var') || isempty(valid_results)
%     warning('沒有 valid_results 變數，無法匯出數據。請確認優化過程有成功找到解。');
% else
%     fprintf('\n正在將 %d 組成功數據寫入 Excel...\n', length(valid_results));
%     % 1. 預分配記憶體 (Pre-allocation)
%     n = length(valid_results);
    
%     % 定義要儲存的欄位
%     col_p = zeros(n, 1);
%     col_fval = zeros(n, 1);
    
%     % 機構與氣隙 (轉成 mm)
%     col_g_ini = zeros(n, 1);
%     col_g_final = zeros(n, 1);

%     % 幾何尺寸 (轉成 mm)
%     col_r_yo = zeros(n, 1);
%     col_r_yi = zeros(n, 1);
%     col_t_y = zeros(n, 1);
%     col_r_co = zeros(n, 1);
%     col_r_ci = zeros(n, 1);
%     col_t_c = zeros(n, 1);
%     col_t_m = zeros(n, 1);
%     col_l_m = zeros(n, 1);
%     col_r_av = zeros(n, 1);
%     col_PM_ratio = zeros(n, 1);
    
%     % 材料性質
%     col_B_r = zeros(n, 1);
%     col_H_c = zeros(n, 1);
%     col_sigma = zeros(n, 1);
%     col_mu_r = zeros(n, 1);

%     % 剩餘參數
%     col_theta_p = zeros(n,1);
%     col_tau_p = zeros(n,1);
%     col_w_m = zeros(n,1);
%     col_H = zeros(n,1);
    
%     % 扭矩驗證 (驗證優化結果是否真的達標)
%     col_Torque1 = zeros(n, 1);
%     col_Torque2 = zeros(n, 1);
    
%     % 2. 迴圈提取數據
%     for i = 1:n
%         res = valid_results(i);
%         p_struct = res.params;
        
%         % 優化變數 x 裡的氣隙 (依照您的定義 x(1)=g_ini, x(2)=g_final)
%         g_ini_val = res.x(1);
%         g_final_val = res.x(2);
        
%         % 填入數據
%         col_p(i) = res.p;
%         col_fval(i) = res.fval;
        
%         col_g_ini(i) = g_ini_val * 1000; % mm
%         col_g_final(i) = g_final_val * 1000; % mm
        
%         col_r_yo(i) = p_struct.r_yo * 1000;
%         col_r_yi(i) = p_struct.r_yi * 1000;
%         col_t_y(i)  = p_struct.t_y * 1000;
%         col_r_co(i) = p_struct.r_co * 1000;
%         col_r_ci(i) = p_struct.r_ci * 1000;
%         col_t_c(i)  = p_struct.t_c * 1000;
%         col_t_m(i)  = p_struct.t_m * 1000;
%         col_l_m(i)  = p_struct.l_m * 1000;
%         col_r_av(i) = p_struct.r_av * 1000;
%         col_PM_ratio(i) = p_struct.PM_ratio;
        
%         col_B_r(i) = p_struct.B_r;
%         col_H_c(i) = p_struct.H_c;
%         col_sigma(i) = p_struct.sigma;
%         col_mu_r(i) = p_struct.mu_r; 
        
%         col_theta_p(i) = p_struct.theta_p;
%         col_tau_p(i) = p_struct.tau_p;
%         col_w_m(i) = p_struct.w_m * 1000;
%         col_H(i) = p_struct.H;
%         % 重新計算一次扭矩以記錄
%         col_Torque1(i) = T1;
%         col_Torque2(i) = T2;
%     end
    
%     % 3. 建立 Table
%     T_out = table(col_p, col_fval, ...
%         col_g_ini, col_g_final, ...
%         col_r_yo, col_r_yi, col_t_y, col_sigma, ...
%         col_r_co, col_r_ci, col_t_c, col_H_c, col_B_r, ...
%         col_r_av, col_l_m, col_t_m, col_PM_ratio, col_mu_r, ...
%         col_theta_p, col_tau_p, col_w_m, col_H, ...
%         col_Torque1, col_Torque2, ...
%         'VariableNames', {'p', 'Cost_fval', ...
%                         'Gap_Low', 'Gap_High', ...
%                         'r_yo', 'r_yi', 't_y', 'sigma', ...
%                         'r_co', 'r_ci', 't_c', 'H_c', 'B_r', ...
%                         'r_av', 'l_m', 't_m', 'PM_ratio', 'mu_r', ...
%                         'theta_p', 'tau_p', 'w_m', 'H', ...
%                         'Torque_Low', 'Torque_High'});
%     % 4. 寫入 Excel
%     filename = 'Optimization_Results_1.xlsx';
    
%     % 檢查檔案是否存在，若存在則刪除舊檔 (避免寫入衝突或混淆)
%     if exist(filename, 'file')
%         delete(filename);
%     end
    
%     writetable(T_out, filename);
%     fprintf('數據已成功儲存至檔案: %s\n', filename);
    
%     % 顯示預覽
%     disp('數據預覽 (前 5 筆):');
%     disp(head(T_out, 5));
% end

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
    
    % 推導出 r_av 的可行範圍:
    % 必須讓磁石在背鐵內( r_yi < (r_av - lm/2)  且  (r_av + lm/2) < r_yo )
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
    r_yo = x(3); t_m = x(13); g_ini=x(1); g_final=x(2);
    cost = (r_yo/ub(3))^2 + (t_m/ub(13)) + (abs(g_ini-g_final)/0.01)*0.5;
end

function [c, ceq] = parametricConstraints(x, target1, target2, p)
    % 解碼參數
    params = xToParams(x, p);
    g_ini = x(1); g_final = x(2);
    
    % 限制: r_yo - r_yi >= 20mm (對應 Random code: min(60, r_yo... - 20))
    c1 = 0.020 - (params.r_yo - params.r_yi); 
    
    c = c1; % 不等式限制 (c <= 0)
    
    % 扭矩計算
    try
        T1 = calculateTorque(params, target1(1), g_ini);
        T2 = calculateTorque(params, target2(1), g_final);
        if isnan(T1) || isnan(T2), error('NaN'); end
        ceq = [(T1-target1(2))/target1(2); (T2-target2(2))/target2(2)];
    catch
        ceq = [1e5; 1e5];
    end
end