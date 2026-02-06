clc; clear; close all;
% 1. 設定變數範圍 (LB, UB)
nvars = 17; % 變數數量

%    g_ini  g_final  r_yo   r_yi   t_y    t_c    B_r   k_lm   k_pos   PM   t_m     r_r  N alpha mu_w  mu_t
lb = [0.004, 0.003, 0.040, 0.020, 0.001, 0.0005, 1.14, 0.10,  0.00,  0.4, 0.001, 0.010, 4,  30, 0.10, 0.10];
ub = [0.015, 0.012, 0.110, 0.060, 0.010, 0.0050, 1.33, 0.90,  1.00,  0.9, 0.009, 0.050, 12, 60, 0.20, 0.60];

% 2. 設定 NSGA-II 參數
options = optimoptions('gamultiobj', ...
    'PopulationSize', 100, ...     % 種群大小
    'MaxGenerations', 200, ...     % 迭代代數
    'ParetoFraction', 0.35, ...    % 帕雷托前緣保留比例
    'UseParallel', true, ...       % 開啟平行運算
    'PlotFcn', @gaplotpareto);     % 繪製 Pareto 圖

fprintf('開始執行 NSGA-II 多目標優化...\n');
results_p = struct('p', [], 'x', [], 'fval', [], 'params', []);
possible_poles = 4:8;
constraint = @(x) constraintFunction(x);
for i = 1:length(possible_poles)
    current_p = possible_poles(i);
    fprintf('優化 p = %d ... ', current_p);
    fittnessFunction = @(x) objective(x, current_p);
    [x_pareto, f_val] = gamultiobj(fittnessFunction, nvars, [], [], [], [], lb, ub, constraint, options);
    
    results_p(i).p = current_p;
    results_p(i).x = x_pareto;
    results_p(i).fval = f_val;
    results_p(i).params = xToParams(x_pareto, current_p); % 解碼回真實物理參數
end

fprintf('優化完成，共找到 %d 組 Pareto 解。\n', size(x_pareto, 1));

% 假設我們最看重 "遲滯面積 (Obj 1)"，選一個面積最小的解來畫圖
[~, best_idx] = min(f_pareto(:, 1)); 
x_best = x_pareto(best_idx, :);

% 繪製最佳解的性能曲線
plot_solution(x_best);