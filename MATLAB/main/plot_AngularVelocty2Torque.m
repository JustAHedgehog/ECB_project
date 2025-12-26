%% --- START OF FILE Plot_2D_RPM_vs_Torque_MultiGap.m ---
clc; clear; close all;

%% 1. 載入數據
filename = 'data.xlsx';
if exist(filename, 'file')
    data_table = readtable(filename);
else
    error('錯誤: 找不到檔案 %s。', filename);
end

%% 2. 選擇要觀察的 ParamSetID
target_id = 1; 

% 篩選出該 ID 的所有數據
current_param_data = data_table(data_table.ParamSetID == target_id, :);

if isempty(current_param_data)
    error('錯誤: 找不到 ParamSetID %d 的數據。', target_id);
end

% 獲取該 ID 下所有不重複的氣隙值 (13組)
unique_gaps = unique(current_param_data.AirGap_mm);
num_gaps = length(unique_gaps);

fprintf('正在針對 ID %d 繪製 %d 條氣隙曲線...\n', target_id, num_gaps);

%% 3. 設定圖表
figure('Name', sprintf('ParamSetID %d: RPM vs Torque for Multi-AirGap', target_id));
hold on; box on; grid on;

title(sprintf('RPM vs Torque (ParamSetID: %d)', target_id), 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Angular Velocity (rpm)', 'FontSize', 11);
ylabel('Torque (N-m)', 'FontSize', 11);

% 使用 colormap 讓 13 條線有漸層顏色 (例如從藍色到紅色)
colors = jet(num_gaps);

%% 4. 迴圈繪製各個氣隙的曲線
h_lines = gobjects(num_gaps, 1); % 用於存儲圖例句柄

for j = 1:num_gaps
    current_gap = unique_gaps(j);
    % 篩選出目前這個氣隙的所有數據點
    gap_data = current_param_data(current_param_data.AirGap_mm == current_gap, :);
    gap_data = sortrows(gap_data, 'RPM'); % 確保數據是按 RPM 排序
    
    % 繪製線條與散點 ('-o' 表示線加圓點)
    h_p = plot(gap_data.RPM, gap_data.Torque_Theory, '-o', ...
        'LineWidth', 1.2, ...
        'MarkerSize', 4, ...
        'Color', colors(j, :), ...
        'MarkerFaceColor', colors(j, :));
    
    h_lines(j) = h_p;
end

%% 5. 添加圖例 (顯示對應的氣隙數值)
% 建立圖例文字，例如 "AirGap 1 mm"
legend_labels = arrayfun(@(x) sprintf('AirGap %d mm', x), unique_gaps, 'UniformOutput', false);

legend(h_lines, legend_labels, ...
    'Location', 'eastoutside', ...
    'FontSize', 9, ...
    'NumColumns', 1); % 如果線太多，可以改成 2 欄

hold off;