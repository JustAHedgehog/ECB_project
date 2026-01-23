clc;clear;close all;

%% 1. 載入數據
% 讀取數據文件
filename = 'data.xlsx'; % data.xlsx or simulation_data_full_iteration.xlsx
opts = detectImportOptions(filename);
opts.Sheet = 'Sheet1';
% opts.SelectedVariableNames = [1:5];
opts.DataRange = '2:601'; % 一組參數的數據範圍為100行
data_table = readtable(filename, opts);

if isempty(data_table)
    error('錯誤: simulation_data_full_iteration.xlsx 檔案為空或找不到數據。請先運行數據收集腳本。');
end

%% 2. 選擇要繪製的參數組
% 選定 ParamSetID 繪製數據
selected_param_set_ids = 1:5; 

% 獲取所有獨特的 ParamSetID
all_unique_param_ids = unique(data_table.ParamSetID);

% 過濾掉不存在的 ParamSetID
valid_selected_param_ids = selected_param_set_ids(ismember(selected_param_set_ids, all_unique_param_ids));

if isempty(valid_selected_param_ids)
    error('錯誤: 選定的 ParamSetID 範圍中沒有任何有效數據。請檢查數據或選擇其他 ID。');
end

fprintf('正在繪製 ParamSetID: %s 的數據。\n', num2str(valid_selected_param_ids));

%% 3. 設定圖表
figure;
hold on;
box on; % 顯示邊框
grid on; % 顯示網格

% 為每個曲面設定不同的顏色
colors = jet(length(valid_selected_param_ids)); % 從 jet colormap 中取顏色

% 用於圖例的句柄陣列
h_surfaces = gobjects(length(valid_selected_param_ids), 1);
% h_scatters = gobjects(length(valid_selected_param_ids), 1); % 散點句柄不需加入圖例，可省略

%% 4. 迴圈遍歷每個選定的 ParamSetID 並繪製
for i = 1:length(valid_selected_param_ids)
    current_param_set_id = valid_selected_param_ids(i);
    current_color = colors(i, :); % 為當前曲面選擇顏色

    % 過濾出當前參數組的數據
    current_data = data_table(data_table.ParamSetID == current_param_set_id, :);

    if isempty(current_data)
        fprintf('警告: ParamSetID = %d 沒有數據，跳過繪製。\n', current_param_set_id);
        continue;
    end

    % 提取 X, Y, Z 數據
    air_gap = current_data.AirGap_mm;
    angular_velocity_rpm = current_data.RPM;
    torque = current_data.Torque_Theory;

    % 準備網格和插值數據以繪製曲面
    g_grid = linspace(min(air_gap), max(air_gap), 50);
    rpm_grid = linspace(min(angular_velocity_rpm), max(angular_velocity_rpm), 50);
    [X_mesh, Y_mesh] = meshgrid(g_grid, rpm_grid);
    
    Z_mesh = griddata(air_gap, angular_velocity_rpm, torque, X_mesh, Y_mesh, 'natural');

    % 繪製曲面
    h_surf = surf(X_mesh, Y_mesh, Z_mesh);
    set(h_surf, 'FaceAlpha', 0.6); % 半透明曲面
    set(h_surf, 'EdgeColor', [0.5 0.5 0.5]); % 網格顏色
    set(h_surf, 'FaceColor', current_color); % 根據 ParamSetID 設定固定顏色

    % 疊加原始數據點 (作為圓點)
    plot3(air_gap, angular_velocity_rpm, torque, ...
          'o', 'MarkerSize', 6, 'MarkerFaceColor', current_color, 'MarkerEdgeColor', 'k');

    % 儲存曲面句柄用於圖例
    h_surfaces(i) = h_surf;
end

%% 5. 設置軸標籤、標題和圖例
% 獲取當前座標軸句柄
ax = gca;

% 設定 X 軸標籤，並調整旋轉角度
hx = xlabel('Air Gap (mm)');
set(hx, 'Rotation', 10); 

% 設定 Y 軸標籤，並調整旋轉角度
hy = ylabel('Angular Velocity (rpm)');
set(hy, 'Rotation', -20); 

% 設定 Z 軸標籤
hz = zlabel('Torque (N-m)');

title('Air Gap - Angular Velocity - Torque for Multiple Parameter Sets');

% 調整視角
view(3); 

% 調整軸範圍
xlim([min(data_table.AirGap_mm) max(data_table.AirGap_mm)]);
ylim([min(data_table.RPM) max(data_table.RPM)]);
zlim([0 max(data_table.Torque_Theory)]); 

% --- 修改的部分開始 ---
% 1. 檢查哪些曲面是成功繪製的 (過濾掉沒有數據的空句柄)
valid_plots_mask = isgraphics(h_surfaces); 

% 2. 準備圖例文字
legend_entries = cell(length(valid_selected_param_ids), 1);
for i = 1:length(valid_selected_param_ids)
    legend_entries{i} = sprintf('ParamSetID %d', valid_selected_param_ids(i));
end

% 3. 只對有效繪製的曲面添加圖例
if any(valid_plots_mask)
    legend(h_surfaces(valid_plots_mask), legend_entries(valid_plots_mask), 'Location', 'northeast');
else
    warning('沒有有效的曲面可供繪製圖例。');
end

hold off;