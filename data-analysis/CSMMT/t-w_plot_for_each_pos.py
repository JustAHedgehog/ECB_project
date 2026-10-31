import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os

# 強制關閉任何殘留的 matplotlib 視窗
plt.close('all')

# ==========================================
# 1. 實驗路徑與自調適機構 (SRM) 特性映射
# ==========================================
base_exp_path = r'not_to_commit\CSMMT\Exp_data'

# 目標轉速與物理位移量映射
target_mapping = [
    (382, 0),
    (393, 1.5),
    (404, 3),
    (415, 4.5),
    (426, 6),
    (437, 7.5),
    (448, 9),
    (459, 10.5),
    (470, 12),
    (481, 13.5),
    (492, 15)
]

# 【修改點 1】：在 configs 中加入 zero_load_file 的路徑
configs = {
    'Normal': {
        'folder': 'normal', 
        'colors': {1: 'darkblue', 2: 'royalblue', 3: 'deepskyblue'}, 
        'marker': 'o',
        'label_prefix': 'Normal',
        'avg_color': 'black',
        'zero_load_file': f'{base_exp_path}/normal/zero_load/normal-zero_load_382-492_Results.csv'
    },
    'Slotted': {
        'folder': 'slotted', 
        'colors': {1: 'darkred', 2: 'orangered', 3: 'darkorange'}, 
        'marker': '^',
        'label_prefix': 'Slotted',
        'avg_color': 'dimgray',
        'zero_load_file': f'{base_exp_path}/slotted/zero_load/slotted-zero_load_382-492_Results.csv'
    }
}

run_ids = [1, 2, 3]

# 舊版嚴謹篩選器參數
tolerance = 0.5  
out_window = 15  
min_data_count = 40  # 放寬至 40 避免誤殺高品質短數據

# ==========================================
# 2. 新增：讀取零負載數據的函數
# ==========================================
def get_zero_load_map(file_path):
    """
    讀取零負載結果檔案，並回傳 {Target_Speed: Avg_Torque_mean} 的字典映射。
    """
    try:
        df = pd.read_csv(file_path)
        # 確保轉速作為 key 是整數，以利後續與 target_mapping 匹配
        return dict(zip(df['Target_Speed (RPM)'].astype(int), df['Avg_Torque_mean']))
    except FileNotFoundError:
        print(f"⚠️ 找不到零負載檔案: {file_path}，該構型將不進行扣除。")
        return {}
    except Exception as e:
        print(f"⚠️ 讀取零負載檔案時發生錯誤 {file_path}: {e}")
        return {}

# ==========================================
# 3. 核心邏輯：即時讀取原始檔案並萃取單點穩態
# ==========================================
def get_steady_torque_for_target(file_tw, target_rpm):
    """
    從原始 t-w 檔案中，尋找並計算特定目標轉速的穩態扭矩。
    """
    try:
        df_tw = pd.read_csv(file_tw, header=None, sep='\t').T
    except FileNotFoundError:
        return None
        
    df = pd.DataFrame()
    df['Speed'] = df_tw[0]
    df['Torque'] = df_tw[1]

    # 1. 尋找起始點
    condition_start = df['Speed'].between(target_rpm - tolerance, target_rpm + tolerance)
    valid_starts = df.index[condition_start]
    
    if len(valid_starts) == 0:
        return None  
        
    start_idx = valid_starts[0]
    
    # 2. 尋找結束點 (防線一：轉速出界)
    is_out_of_bounds = ~df['Speed'].between(target_rpm - tolerance, target_rpm + tolerance)
    future_out = is_out_of_bounds.loc[start_idx:]
    consecutive_out = future_out.rolling(window=out_window).sum()
    valid_ends_speed = consecutive_out[consecutive_out == out_window].index
    
    end_idx_speed = valid_ends_speed[0] - (out_window - 1) - 2 if len(valid_ends_speed) > 0 else df.index[-1]
        
    # 3. 尋找結束點 (防線二：扭矩跳崖)
    future_torque_diff = df['Torque'].diff().loc[start_idx:]
    valid_ends_torque = future_torque_diff[future_torque_diff < -5.0].index
    
    end_idx_torque = valid_ends_torque[0] - 1 if len(valid_ends_torque) > 0 else df.index[-1]
        
    end_idx = min(end_idx_speed, end_idx_torque)
        
    # 4. 區間驗證與萃取
    steady_state_data = df.loc[start_idx : end_idx - 1]
    data_count = len(steady_state_data)
    
    if data_count > 0:
        torque_std = steady_state_data['Torque'].std()
        
        if (pd.notna(torque_std) and torque_std > 0.5) or data_count < min_data_count:
            return None
        else:
            return steady_state_data['Torque'].mean()
            
    return None

# ==========================================
# 4. 執行分析與疊圖繪製
# ==========================================
print("🚀 開始即時讀取原始檔案、扣除零負載並萃取穩態數據繪圖...")

# 建立資料暫存區，用於計算平均值
collected_data = {
    'Normal': {speed: [] for speed, _ in target_mapping},
    'Slotted': {speed: [] for speed, _ in target_mapping}
}

# 階段一：收集所有的實驗數據並扣除零負載
for config_name, config_info in configs.items():
    # 【修改點 2】：在處理該構型前，先讀取對應的零負載數據字典
    zero_load_map = get_zero_load_map(config_info['zero_load_file'])
    
    for target_speed, disp in target_mapping:
        disp_str = str(int(disp)) if disp == int(disp) else str(disp)
        folder_path = os.path.join(base_exp_path, config_info['folder'], disp_str)
        
        for rid in run_ids:
            file_tw = os.path.join(folder_path, f"{rid}_t-w.csv")
            raw_tq = get_steady_torque_for_target(file_tw, target_speed)
            
            if raw_tq is not None:
                # 【修改點 3】：扣除零負載扭矩 (若字典中沒有該轉速則扣 0.0)
                z_torque = zero_load_map.get(target_speed, 0.0)
                net_tq = raw_tq - z_torque
                
                # 暫存有效且已扣除背景的淨扭矩數據 (存放 tuple: (Run編號, 淨扭矩值))
                collected_data[config_name][target_speed].append((rid, net_tq))

# 階段二：繪圖
fig, ax = plt.subplots(figsize=(8, 6), num="Net Braking Torque Comparison")
added_legends = set()

for config_name, config_info in configs.items():
    avg_speeds = []
    avg_torques = []
    
    for target_speed, disp in target_mapping:
        valid_points = collected_data[config_name][target_speed]
        
        if not valid_points:
            continue
            
        # 繪製各個 Run 的散佈點
        for rid, tq_val in valid_points:
            point_color = config_info['colors'][rid]
            legend_label = f"{config_info['label_prefix']} (Run {rid})"
            
            if legend_label not in added_legends:
                ax.scatter(target_speed, tq_val, color=point_color, 
                           marker=config_info['marker'], alpha=0.6, label=legend_label)
                added_legends.add(legend_label)
            else:
                ax.scatter(target_speed, tq_val, color=point_color, 
                           marker=config_info['marker'], alpha=0.6)
        
        # 【修改點 4】：解開註解，計算並收集該目標轉速下的「平均淨扭矩」
        mean_tq = np.mean([tq for _, tq in valid_points])
        avg_speeds.append(target_speed)
        avg_torques.append(mean_tq)
        
    # # 【修改點 5】：解開註解，繪製平均點標記
    # if avg_speeds:
    #     avg_label = f"{config_info['label_prefix']} (Average)"
    #     ax.scatter(avg_speeds, avg_torques, color=config_info['avg_color'], 
    #             marker=config_info['marker'], s=70, label=avg_label)

# ==========================================
# 5. 圖表視覺細節與存檔
# ==========================================
# 【修改點 6】：將標題與 Y 軸名稱調整為 Net Torque
ax.set_title("Net Torque Comparison for Defined Overlap Lengths", fontsize=18, fontfamily='Times New Roman')
ax.set_xlabel("Speed (RPM)", fontsize=16, fontfamily='Times New Roman')
ax.set_ylabel("Net Torque (N·m)", fontsize=16, fontfamily='Times New Roman')

# 強制 X 軸刻度為 11 個標準目標轉速
x_ticks = [m[0] for m in target_mapping]
ax.set_xticks(x_ticks)

ax.grid(True, linestyle='--', alpha=0.5)
# 設定雙排圖例，讓標籤整齊排列
ax.legend(loc='upper left', fontsize=10, ncol=2) 
fig.tight_layout()

# 自動存檔 (有需要可解除註解)
# output_filename = "Net_Braking_Torque_DirectRead_Colored.png"
# fig.savefig(output_filename, dpi=300, bbox_inches='tight')
# print(f"\n🎉 原始檔案掃描分析完成！疊圖已成功儲存為: {output_filename}")

plt.show()