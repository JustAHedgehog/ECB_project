clc; clear; close all;
import ECB_optimize.*
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
lb = [0.004, 0.003, 0.040, 0.020, 0.001, 24.9e6, 0.0005, 844e3, 1.14, 0.10,  0.00,  0.4, 0.001];
ub = [0.015, 0.012, 0.110, 0.060, 0.010, 59.5e6, 0.0050, 907e3, 1.33, 0.90,  1.00,  0.9, 0.009];

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

%% 最佳化
valid_results = ECB_optimize(target1, target2, lb, ub, x0);
if isempty(valid_results), error('所有優化均失敗'); end
[~, best_idx] = min([valid_results.fval]);
best = valid_results(best_idx);
params = best.params;

% 結果顯示
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

%% 機構參數最佳化
[x_best, fval] = mech_optimize(params.r_yi, target1(1), target2(1), g_ini, g_final);
fprintf('\n=== 機械參數優化結果 ===\n');
fprintf('滾子半徑 (r_r): %.2f mm\n', x_best(1)*1000);
fprintf('滾子長度 (L_r): %.2f mm\n', x_best(2)*1000);
fprintf('滾子數量 (N): %d\n', round(x_best(3)));
fprintf('楔形角度 (alpha): %.2f deg\n', x_best(4));
fprintf('楔形摩擦 (mu_w): %.3f\n', x_best(5));
fprintf('盤面摩擦 (mu_t): %.3f\n', x_best(6));
fprintf('最小遲滯目標值: %.4f\n', fval);

%% 將所有成功收斂的組別匯出至 Excel
% filename = 'Results_1.xlsx';
% saveParams(valid_results, T1, T2, filename);