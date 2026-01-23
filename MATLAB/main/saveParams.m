function saveParams(valid_results, T1, T2, filename)
    if ~exist('valid_results', 'var') || isempty(valid_results)
        warning('沒有 valid_results 變數，無法匯出數據。請確認優化過程有成功找到解。');
    else
        fprintf('\n正在將 %d 組成功數據寫入 Excel...\n', length(valid_results));
        % 預分配記憶體 (Pre-allocation)
        n = length(valid_results);
        
        % 定義要儲存的欄位
        col_p = zeros(n, 1);
        col_fval = zeros(n, 1);
        
        % 機構與氣隙 (轉成 mm)
        col_g_ini = zeros(n, 1);
        col_g_final = zeros(n, 1);

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
        
        % 迴圈提取數據
        for i = 1:n
            res = valid_results(i);
            p_struct = res.params;
            
            % 優化變數 x 裡的氣隙 (依照您的定義 x(1)=g_ini, x(2)=g_final)
            g_ini_val = res.x(1);
            g_final_val = res.x(2);
            
            % 填入數據
            col_p(i) = res.p;
            col_fval(i) = res.fval;
            
            col_g_ini(i) = g_ini_val * 1000; % mm
            col_g_final(i) = g_final_val * 1000; % mm
            
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

        % 建立 Table
        T_out = table(col_p, col_fval, ...
            col_g_ini, col_g_final, ...
            col_r_yo, col_r_yi, col_t_y, col_sigma, ...
            col_r_co, col_r_ci, col_t_c, col_H_c, col_B_r, ...
            col_r_av, col_l_m, col_t_m, col_PM_ratio, col_mu_r, ...
            col_theta_p, col_tau_p, col_w_m, col_H, ...
            col_Torque1, col_Torque2, ...
            'VariableNames', {'p', 'Cost_fval', ...
                            'Gap_Low', 'Gap_High', ...
                            'r_yo', 'r_yi', 't_y', 'sigma', ...
                            'r_co', 'r_ci', 't_c', 'H_c', 'B_r', ...
                            'r_av', 'l_m', 't_m', 'PM_ratio', 'mu_r', ...
                            'theta_p', 'tau_p', 'w_m', 'H', ...
                            'Torque_Low', 'Torque_High'});
        % 寫入 Excel
        
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
end