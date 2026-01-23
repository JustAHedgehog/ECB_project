%% --- START OF FILE Plot_2D_AirGap_vs_Torque.m ---
clc; clear; close all;

%% 1. 載入數據
filename = 'simulation_data_full_iteration.xlsx';
if exist(filename, 'file')
    data_table = readtable(filename);
else
    error('錯誤: 找不到檔案 %s。', filename);
end

%% 2. 選擇要繪製的參數組 (請在此處修改 ID)
selected_param_set_ids = 1:3; % 修改這裡來變更要觀察的 ID

% 獲取並驗證 ID
all_unique_param_ids = unique(data_table.ParamSetID);
valid_selected_param_ids = selected_param_set_ids(ismember(selected_param_set_ids, all_unique_param_ids));

if isempty(valid_selected_param_ids)
    error('錯誤: 選定的範圍中沒有任何有效數據。');
end

fprintf('正在繪製 Air Gap vs Torque (2D), ParamSetID: %s\n', num2str(valid_selected_param_ids));

%% 3. 設定圖表
figure('Name', '2D Plot: Air Gap vs Torque', 'Color', 'w');
hold on;
box on;
grid on;

title('Air Gap vs Torque', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Air Gap (mm)', 'FontSize', 11);
ylabel('Torque (N-m)', 'FontSize', 11);

% 設定顏色
colors = jet(length(valid_selected_param_ids));

% 用於圖例的句柄
h_lines = gobjects(length(valid_selected_param_ids), 1);

%% 4. 迴圈繪製
for i = 1:length(valid_selected_param_ids)
    current_id = valid_selected_param_ids(i);
    current_color = colors(i, :);
    
    % 篩選數據
    current_data = data_table(data_table.ParamSetID == current_id, :);
    
    if isempty(current_data), continue; end
    
    % 繪製散點
    % 這裡展示的是該參數組在"所有轉速條件下"的氣隙-扭矩分佈
    h_p = plot(current_data.AirGap_mm, current_data.Torque_Theory, ...
         'o', 'MarkerSize', 6, ...
         'MarkerEdgeColor', 'k', ...
         'MarkerFaceColor', current_color);
     
    h_lines(i) = h_p(1); % 儲存句柄用於圖例
end

%% 5. 添加圖例
legend_entries = cell(length(valid_selected_param_ids), 1);
for i = 1:length(valid_selected_param_ids)
    legend_entries{i} = sprintf('ParamSetID %d', valid_selected_param_ids(i));
end

valid_mask = isgraphics(h_lines);
if any(valid_mask)
    legend(h_lines(valid_mask), legend_entries(valid_mask), ...
        'Location', 'bestoutside'); % 圖例放在圖表外側
else
    warning('沒有有效的數據可供繪製圖例。');
end

hold off;