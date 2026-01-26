function valid_results = optimizeECB(target1, target2, lb, ub, x0)
    options = optimoptions('fmincon', ...
    'Display', 'none', ...
    'Algorithm', 'sqp', ...
    'MaxFunctionEvaluations', 5000, ...
    'StepTolerance', 1e-10, ...
    'ConstraintTolerance', 1e-6);
    % 儲存結構
    results_p = struct('p', [], 'x', [], 'fval', [], 'params', []);
    possible_poles = 4:8;
    for i = 1:length(possible_poles)
        current_p = possible_poles(i);
        fprintf('優化 p = %d ... ', current_p);
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
    % 選出最佳解
    valid_results = results_p([results_p.fval] ~= Inf);
end

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