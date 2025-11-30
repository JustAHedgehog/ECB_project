function params = generateRandomModelParams()
    params = struct();

    % 固定參數
    params.mu_0 = 4 * pi * 10^-7; % 真空磁導率 (H·m^-1)

    % 背鐵
    params.mu_y = 4000;           % 背鐵相對磁導率
    params.r_yo = (rand() * (110 - 40) + 40) * 10^-3;
    params.r_yi = (rand() * (min(60, params.r_yo * 10^3 - 1) - 20) + 20) * 10^-3; % 確保 r_yi < r_yo
    params.t_y = (rand() * (10 - 1) + 1) * 10^-3;
    
    % 導體
    params.sigma = rand() * (59.5e6 - 24.9e6) + 24.9e6;
    params.mu_c = 1.257 * 10^-6;  % 導體磁導率 (H/m)TODO
    params.r_co = params.r_yo;
    params.r_ci = params.r_yi;
    params.t_c = (rand() * (5 - 0.5) + 0.5) * 10^-3;

    % 磁石
    params.H_c = (rand() * (907 - 844) + 844) * 10^3;
    params.B_r = rand() * (1.33 - 1.14) + 1.14;
    params.mu_r = params.B_r / params.H_c / params.mu_0;
    params.l_m = rand() * (params.r_yo - params.r_yi);
    % r_av
    upper_bound_rav = params.r_yo - params.l_m / 2 - 0.001;
    lower_bound_rav = params.r_yi + params.l_m / 2 + 0.001;
    % 檢查是否合法
    if lower_bound_rav > upper_bound_rav
        params.r_av = (params.r_yo + params.r_yi) / 2;
    else
        params.r_av = rand() * (upper_bound_rav - lower_bound_rav) + lower_bound_rav;
    end
    params.PM_ratio = rand() * (0.9 - 0.4) + 0.4;
    params.t_m = (rand() * (9 - 1) + 1) * 10^-3;
    params.p = randi([4, 8]); % 極對數

    % 磁石徑向寬度 w_m (依賴 PM_ratio 和 r_av)
    params.theta_p = pi / params.p; % 極距角 rad
    params.tau_p = params.r_av * params.theta_p;
    params.w_m = params.PM_ratio * params.tau_p; % 理論計算使用，有PM ratio
    params.H = ((params.r_yo - (params.r_av + params.l_m / 2)) + (params.r_av - params.l_m / 2) - params.r_yi) / 2;
end