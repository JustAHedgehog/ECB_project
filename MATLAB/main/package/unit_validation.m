% mech.r_r   = 0.03/2;
% mech.m_r   = 4/3 * pi * mech.r_r^3 * 8500;
% mech.N     = 8;
% mech.alpha = 45;
% mech.beta  = 60;
% mech.mu_w  = 0.1;
% mech.mu_t  = 0.1;
% mech.r_omega_ini = 0.075;

% ECB.mu_0 = 4*pi*1e-7;
% ECB.mu_y = 4000;
% ECB.mu_c = 1.257e-6;
% ECB.sigma = 38 * 10^6;
% ECB.H_c = 907 * 10^3; % N40, 矯頑力Hc (A/m)
% ECB.B_r = 1.29;
% ECB.N_harm = 15; % 奇數諧波取前 15 項
% ECB.K_bessel = 50; % 貝索根取前 50 個

% % 1. 讀取獨立變數
% ECB.p = 3; % 極對數
% ECB.r_yo = 0.0574;
% ECB.r_yi = 0.0141;
% ECB.t_y = 0.0019; 
% ECB.r_co = ECB.r_yo; ECB.r_ci = ECB.r_yi;
% ECB.t_c = 0.0006; 
% ECB.PM_ratio = 0.8;
% ECB.t_m = 5 * 10^-3;
% ECB.l_m = 0.02;
% ECB.r_av = 85 * 10^-3;
% ECB.mu_r = ECB.B_r / ECB.H_c / ECB.mu_0;
% ECB.theta_p = pi / ECB.p;
% ECB.tau_p = ECB.r_av * ECB.theta_p;
% ECB.w_m = ECB.PM_ratio * ECB.tau_p;
% ECB.H = (ECB.r_yo - ECB.r_yi - ECB.l_m) / 2;

%      p       r_yo   r_yi     t_y     t_c    k_lm     PM      t_m      r_r    m_r      N      k_r    alpha    beta
x = [9.0000, 0.1001, 0.0148, 0.0071, 0.0030, 0.5659, 0.8002, 0.0055, 0.0146, 0.2457, 11.0000, 0.5769, 53.4678, 55.7349];
% [ECB, mech] = xToParams(x); % 解碼參數
% w_ini = 255.6; w_final = 573.0;
% [T_max_possible,info1] = ECB_BrakingTorque(ECB, w_ini, 0.001); % g_min (最大扭矩)
% [T_min_possible,info2] = ECB_BrakingTorque(ECB, w_final, 0.025); % g_max (最小扭矩)
% fprintf('Max Torque at g=1mm: %.4f Nm, T_sum: %.4f\n', T_max_possible, info1.T_sum);
% fprintf('Min Torque at g=25mm: %.4f Nm, T_sum: %.4f\n', T_min_possible, info2.T_sum);

% for i = 1:10
%     [F_total, info] = requiredForce(mech, ECB, i*100, 0.003, 0.012, 'up');
%     fprintf('Normal Force at %d rpm: %.4f N\n', i*100, info.Nt);
% end

% 定義目標扭矩
Target_Start = [255.6, 1.833]; % w_ini, T_ini
Target_End   = [573.0, 18.39]; % w_final, T_final
g_search_range = [0.001, 0.025]; % 1mm 到 25mm
% 呼叫診斷函數
fprintf('生成數據中...\n');
[results, ECB, mech] = analyze_result(x, Target_Start, Target_End, g_search_range);

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
fprintf('  磁石長度 (l_m) : %.2f mm (佔用比: %.0f%%)\n', ECB.l_m*1000, x(6)*100);
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
plot(results.w_vec, results.g_up * 1000, 'r-', 'LineWidth', 2); hold on;
plot(results.w_vec, results.g_down * 1000, 'b-', 'LineWidth', 2);
xline(results.w_C, 'k--', 'LineWidth', 1.5, 'Label', '釋放點 w_C', 'LabelVerticalAlignment', 'bottom');
xlabel('Speed (rpm)'); ylabel('Air Gap (mm)'); legend('Up Stroke', 'Down Stroke');
title('優化後的氣隙軌跡'); grid on;

subplot(2,1,2);
plot(results.w_vec, results.T_up, 'r-', 'LineWidth', 2); hold on;
plot(results.w_vec, results.T_down, 'b-', 'LineWidth', 2);
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
        eq_up   = @(g) requiredForce(mech, ECB, w, g, g_ini, 'up')   - F_spring(g);
        eq_down = @(g) requiredForce(mech, ECB, w, g, g_ini, 'down') - F_spring(g);
        
        % --- 4. 計算上升/下降段的氣隙軌跡 ---
        % 求解 上升段 g_up
        g_up_vec(i) = gap_search_force(eq_up, g_final, g_ini);

        % 求解 下降段 g_down
        if w >= w_C
            % 轉速還沒降到釋放點，機構處於滯留狀態 (卡在最小氣隙)
            g_down_vec(i) = g_final;
        else
            % 轉速低於釋放點，機構開始回彈，呼叫物理求解器找平衡氣隙
            g_down_vec(i) = gap_search_force(eq_down, g_final, g_ini);
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