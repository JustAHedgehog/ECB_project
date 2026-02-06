clc;clear;close all;

%% 數據收集設定
rpms = 100:100:1000; % 轉速從 100 到 1000 rpm，每 100 rpm 迭代 (共 10 個轉速點)
gs_mm = 1:1:10; % 氣隙從 1mm 到 13mm，每 1mm 迭代
gs_m = gs_mm * 10^-3; % 轉換為公尺

num_random_sets = 20; % 隨機生成多少組「幾何/材料參數」 (你可以調整這個數字)

% 用於儲存結果的 cell 陣列
% 每個 cell 元素將是一個結構體，包含：
%   - 這一組隨機參數
%   - 對應的 gs 向量
%   - 對應的 rpms 向量
%   - 對應的 T_theory_matrix (gs_num x rpms_num)
results_cell = cell(num_random_sets, 1);

fprintf('開始數據收集 (每一組隨機參數 -> 迭代所有氣隙 -> 迭代所有轉速)...\n');

% 處理每一組隨機參數的生成和其所有氣隙、轉速下的計算
for set_idx = 1:num_random_sets
    current_set_results = struct(); % 用於儲存當前隨機參數組的結果
    
    try
        % 1. 隨機生成一組模型參數
        current_params = generateRandomModelParams(); % 每個 worker 都會獨立生成隨機數

        % 2. 在這組參數下，計算所有氣隙和所有指定轉速的扭矩
        T_theory_matrix = zeros(length(gs_m), length(rpms)); % 預分配扭矩結果矩陣
        
        for g_idx = 1:length(gs_m)
            current_g_m = gs_m(g_idx);
            for rpm_idx = 1:length(rpms)
                rpm_val = rpms(rpm_idx);
                T_theory_matrix(g_idx, rpm_idx) = calculateTorque(current_params, rpm_val, current_g_m);
            end
        end

        % 3. 儲存這一組隨機參數及其所有氣隙、轉速的扭矩結果
        current_set_results.params = current_params;
        current_set_results.rpms = rpms;
        current_set_results.gs_mm = gs_mm; % 儲存 mm 單位，方便查看
        current_set_results.T_theory_matrix = T_theory_matrix;
        current_set_results.error_flag = false; % 標記為成功

    catch ME
        % 處理錯誤，並記錄下來
        warning('在第 %d 組隨機參數計算時發生錯誤: %s', set_idx, ME.message);
        current_set_results.params = []; % 或者儲存導致錯誤的參數
        current_set_results.rpms = rpms;
        current_set_results.gs_mm = gs_mm;
        current_set_results.T_theory_matrix = NaN(length(rpms), length(gs_m)); % 扭矩設為 NaN
        current_set_results.error_flag = true; % 標記為失敗
        current_set_results.error_msg = ME.message;
    end
    
    % 將結果儲存到 for 迴圈的輸出變數中
    results_cell{set_idx} = current_set_results;
end

fprintf('\n數據收集完成！共嘗試 %d 組隨機參數。\n', num_random_sets);

% 清理可能因錯誤而為空的 cell
results_cell = results_cell(~cellfun(@isempty, results_cell));
successful_sets = sum(cellfun(@(x) ~x.error_flag, results_cell));
fprintf('成功收集到 %d 組隨機參數的數據。\n', successful_sets);

%% 數據分析或顯示
if ~isempty(results_cell)
    % 將 results_cell 轉換為一個更方便處理的扁平化表格格式
    % 預估最終表格的行數
    num_rpm_points = length(rpms);
    num_g_points = length(gs_mm);
    total_rows = successful_sets * num_rpm_points * num_g_points;
    
    % 預分配用於最終表格的數據
    all_param_sets_idx = zeros(total_rows, 1);
    all_rpms = zeros(total_rows, 1);
    all_gs_mm = zeros(total_rows, 1);
    all_torques = zeros(total_rows, 1);
    
    % 獲取參數欄位名 (假設第一個成功計算的 params 具有所有欄位)
    first_successful_params = results_cell{find(~cellfun(@(x) x.error_flag, results_cell), 1)}.params;
    param_field_names = fieldnames(first_successful_params);
    all_params_data = zeros(total_rows, length(param_field_names));
    
    current_row = 1;
    for i = 1:length(results_cell)
        if ~results_cell{i}.error_flag % 只處理成功的結果
            % 將矩陣展開為列向量
            [RPM_grid, G_grid] = meshgrid(results_cell{i}.rpms, results_cell{i}.gs_mm);
            
            % 注意這裡的順序，T_theory_matrix 是 (g_idx, rpm_idx)
            % 所以展開時要確保對應
            rpm_vec_for_table = RPM_grid(:);
            g_vec_for_table = G_grid(:);
            torque_vec_for_table = results_cell{i}.T_theory_matrix(:);

            num_points_this_set = length(torque_vec_for_table);
            
            all_param_sets_idx(current_row : current_row + num_points_this_set - 1) = i;
            all_rpms(current_row : current_row + num_points_this_set - 1) = rpm_vec_for_table;
            all_gs_mm(current_row : current_row + num_points_this_set - 1) = g_vec_for_table;
            all_torques(current_row : current_row + num_points_this_set - 1) = torque_vec_for_table;
            
            % 提取並填充參數數據
            for j = 1:length(param_field_names)
                field_val = results_cell{i}.params.(param_field_names{j});
                if isscalar(field_val)
                    all_params_data(current_row : current_row + num_points_this_set - 1, j) = field_val;
                else
                    warning('參數 %s 不是純量，將忽略其在表格中的展開。', param_field_names{j});
                end
            end
            current_row = current_row + num_points_this_set;
        end
    end
    
    % 根據實際成功收集的行數裁剪預分配的陣列
    all_param_sets_idx = all_param_sets_idx(1:current_row-1);
    all_rpms = all_rpms(1:current_row-1);
    all_gs_mm = all_gs_mm(1:current_row-1);
    all_torques = all_torques(1:current_row-1);
    all_params_data = all_params_data(1:current_row-1, :);

    % 創建最終的表格
    data_table = table(all_param_sets_idx, all_rpms, all_gs_mm, all_torques, ...
                       'VariableNames', {'ParamSetID', 'RPM', 'AirGap_mm', 'Torque_Theory'});
    
    % 將展開的參數數據添加到表格中
    params_table = array2table(all_params_data, 'VariableNames', param_field_names);
    data_table = [data_table, params_table];

    disp(' ');
    disp('部分收集到的數據 (前30行):'); % 顯示更多行以展示不同 RPM 和 AirGap
    disp(head(data_table, 30));

    % 將數據保存到文件
    writetable(data_table, 'simulation_data_full_iteration.xlsx');
    fprintf('\n數據已保存到 simulation_data_full_iteration.xlsx\n');
end