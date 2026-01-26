clc; clear; close all;
import optimizeECB.*
import calculateTorque.*
import optimizeMech.*
import torqueCurveFitting.*
import saveParams.*

%% 定義設計目標與變數
target1 = [255.6, 1.833]; % 低速
target2 = [573.0, 18.39]; % 高速

% 優化變數
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
ECB.lb = [0.004, 0.003, 0.040, 0.020, 0.001, 24.9e6, 0.0005, 844e3, 1.14, 0.10,  0.00,  0.4, 0.001];
ECB.ub = [0.015, 0.012, 0.110, 0.060, 0.010, 59.5e6, 0.0050, 907e3, 1.33, 0.90,  1.00,  0.9, 0.009];

% 初始猜測值 (使用比例係數，例如 0.5 代表在正中間)
ECB.x0 = zeros(1, 13);
ECB.x0(1)=0.008; ECB.x0(2)=0.003; % g_ini, g_final
ECB.x0(3)=0.090; ECB.x0(4)=0.040; ECB.x0(5)=0.005; % r_yo, r_yi, t_y
ECB.x0(6)=35e6; ECB.x0(7)=0.002; ECB.x0(8)=880e3; ECB.x0(9)=1.25; % sigma, t_c, H_c, B_r
ECB.x0(10)=0.5;   % k_lm: 磁石長度佔一半空間
ECB.x0(11)=0.5;   % k_pos: 磁石裝在正中間
ECB.x0(12)=0.7; % PM_ratio
ECB.x0(13)=0.005;  % t_m

% 確保初始值在邊界內
ECB.x0 = max(ECB.lb, min(ECB.ub, ECB.x0));

%% 最佳化
valid_results = optimizeECB(target1, target2, ECB.lb, ECB.ub, ECB.x0);
if isempty(valid_results), error('所有優化均失敗'); end
[~, best_idx] = min([valid_results.fval]);
best = valid_results(best_idx);
params = best.params;

% 結果顯示
g_ini = best.x(1); g_final = best.x(2);
T1 = calculateTorque(params, target1(1), g_ini);
T2 = calculateTorque(params, target2(1), g_final);

% fprintf('\n=== 最佳化結果 (Parametric Logic) ===\n');
% fprintf('極對數 p = %d\n', best.p);
% fprintf('--------------------------------------\n');
% fprintf('【幾何參數 (絕對值)】\n');
% fprintf('  背鐵外徑 (r_yo): %.2f mm\n', params.r_yo*1000);
% fprintf('  背鐵內徑 (r_yi): %.2f mm\n', params.r_yi*1000);
% fprintf('    -> 可用空間  : %.2f mm\n', (params.r_yo - params.r_yi)*1000);
% fprintf('  磁石長度 (l_m) : %.2f mm (佔用比: %.0f%%)\n', params.l_m*1000, best.x(10)*100);
% fprintf('  安裝半徑 (r_av): %.2f mm (位置比: %.0f%%)\n', params.r_av*1000, best.x(11)*100);
% fprintf('  磁石厚度 (t_m) : %.2f mm\n', params.t_m*1000);
% fprintf('\n【扭矩性能】\n');
% fprintf('  目標1: %.3f Nm -> 實際: %.3f Nm (Err: %.2f%%)\n', target1(2), T1, abs(T1-target1(2))/target1(2)*100);
% fprintf('  目標2: %.3f Nm -> 實際: %.3f Nm (Err: %.2f%%)\n', target2(2), T2, abs(T2-target2(2))/target2(2)*100);

%% 將ECB所有成功收斂的組別匯出至 Excel
% filename = 'Results_1.xlsx';
% saveParams(valid_results, T1, T2, filename);

%% 機構參數最佳化
% 電磁力常數 (單位需注意：mm, rpm)
ECB.C_s = 26781.2188; % TODO N*mm^2
ECB.C_e = 12.3061;    % TODO N*mm^2/rpm
ECB.g_e = 2.3717;     % TODO mm

% 定義優化變數與邊界
% x = [radius_r, L_r, N, alpha, mu_wedge, mu_t]
% 單位：m, m, 1, deg, 1, 1
mech.lb = [0.010, 0.020, 4,  30, 0.05, 0.05];
mech.ub = [0.050, 0.080, 12, 60, 0.20, 0.20];
mech.x0 = [0.030, 0.040, 8,  45, 0.10, 0.10];
mech.r_yi = params.r_yi;

[mech_best, fval, best_params] = optimizeMech(mech, ECB, target1(1), target2(1), g_ini, g_final);
fprintf('\n=== 機械參數優化結果 ===\n');
fprintf('滾子半徑 (r_r): %.2f mm\n', mech_best(1)*1000);
fprintf('滾子長度 (L_r): %.2f mm\n', mech_best(2)*1000);
fprintf('滾子數量 (N): %d\n', mech_best(3));
fprintf('楔形角度 (alpha): %.2f deg\n', mech_best(4));
fprintf('楔形摩擦 (mu_w): %.3f\n', mech_best(5));
fprintf('盤面摩擦 (mu_t): %.3f\n', mech_best(6));
fprintf('最小遲滯目標值: %.4f\n', fval);

% 建立目標二次曲線函數 (假設通過 0, A, B 三點)
% T = a*w^2 + b*w
pts = [target1(1)^2, target1(1); target2(1)^2, target2(1)]; % 自變數[w^2 w]
vals = [target1(2); target2(2)];
coeffs = pts \ vals; % 求解 [a; b]
a_target = coeffs(1); b_target = coeffs(2);

% 目標函數：給轉速 w，回傳目標扭矩 T
T_target_func = @(w) a_target * w.^2 + b_target * w;
[g_current_vec, w_range, T_actual] = torqueCurveFitting(T_target_func, target1, target2, best);

% 計算彈力的上下限
[F_up, Fw_up, Fm_up] = requiredForce(best_params, ECB, w_range, g_current_vec, g_ini, 'up');
[F_down, Fw_down, Fm_down] = requiredForce(best_params, ECB, w_range, g_current_vec, g_ini, 'down');


%% --- 驗證與繪圖 ---
figure;
subplot(2,1,1);
yyaxis left
plot(w_range, g_current_vec * 1000, '-o', 'DisplayName', 'g fit');
ylabel('Air Gap (mm)');
yyaxis right
plot(w_range, T_target_func(w_range), 'k--', 'LineWidth', 2, 'DisplayName', 'Target (Quadratic)'); hold on;
plot(w_range, T_actual, 'ro', 'DisplayName', 'Actual (fitting)');
ylabel('Torque (N-m)'); 
ax = gca; % 获取当前坐标轴对象
ax.YColor = 'k'; % 设置 Y 轴颜色
xlabel('Speed (rpm)');
legend('Location', 'north');
grid on;
title('Torque Validification & Air Gap Variation');

% 機構推力與氣隙關係
subplot(2,1,2);
yyaxis left
plot(w_range, g_current_vec * 1000, '-o', 'DisplayName', 'g fit');
ylabel('Air Gap (mm)');
yyaxis right
plot(w_range, F_up, 'o-', 'LineWidth', 2, 'DisplayName', 'ACC'); hold on;
plot(w_range, F_down, 'go-', 'LineWidth', 2, 'DisplayName', 'DEC');
ylabel('Required Force(N)');
xlabel('Speed (rpm)');
legend('Location', 'north');
grid on;
title('Wedge Mechanism Thrust Analysis (With Friction Hysteresis)');
