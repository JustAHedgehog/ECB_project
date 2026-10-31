import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import os

# 強制關閉任何殘留的 matplotlib 視窗
plt.close('all')

# ==========================================
# 1. 實驗比較設定與參數
# ==========================================
base_exp_path = r'not_to_commit\CSMMT\Exp_data'
displacement = 0

# 【修改點 1】在設定中加入 zero_load_file 檔案路徑
compare_cases = {
    'Normal': {
        'path': f'{base_exp_path}/normal/{displacement}',
        'colors': {1: 'darkblue', 2: 'royalblue', 3: 'deepskyblue'}, 
        'marker': 'o',
        'label_prefix': 'Normal',
        'avg_color': 'black',
        'zero_load_file': f'{base_exp_path}/normal/zero_load/normal-zero_load_382-492_Results.csv'
    },
    'Slotted': {
        'path': f'{base_exp_path}/slotted/{displacement}',
        'colors': {1: 'darkred', 2: 'orangered', 3: 'darkorange'}, 
        'marker': '^',
        'label_prefix': 'Slotted',
        'avg_color': 'dimgray',
        'zero_load_file': f'{base_exp_path}/slotted/zero_load/slotted-zero_load_382-492_Results.csv'
    }
}

run_ids = [1, 2, 3]  
target_speeds = [382, 393, 404, 415, 426, 437, 448, 459, 470, 481, 492]

# 篩選原則參數 (來自舊版程式)
tolerance = 0.5  
out_window = 15  

# ==========================================
# 2. 新增：讀取零負載數據的函數
# ==========================================
def get_zero_load_map(file_path):
    """
    讀取零負載結果檔案，並回傳 {Target_Speed: Avg_Torque_mean} 的字典映射。
    """
    try:
        df = pd.read_csv(file_path)
        # 確保轉速作為 key 是整數，以利後續與 target_speeds 匹配
        return dict(zip(df['Target_Speed (RPM)'].astype(int), df['Avg_Torque_mean']))
    except FileNotFoundError:
        print(f"⚠️ 找不到零負載檔案: {file_path}，該構型將不進行扣除。")
        return {}
    except Exception as e:
        print(f"⚠️ 讀取零負載檔案時發生錯誤 {file_path}: {e}")
        return {}

# ==========================================
# 3. 核心分析邏輯：舊版嚴謹篩選器
# ==========================================
# 【修改點 2】引入 zero_load_map 參數
def extract_steady_averages_legacy(file_path_tw, file_path_xw, target_speeds, zero_load_map):
    """使用舊版邏輯萃取單次實驗的穩態數據，並扣除基準零負載扭矩"""
    try:
        df_tw = pd.read_csv(file_path_tw, header=None, sep='\t').T
        df_xw = pd.read_csv(file_path_xw, header=None, sep='\t').T
    except FileNotFoundError:
        return None

    df = pd.DataFrame()
    df['Speed'] = df_tw[0]
    df['Torque'] = df_tw[1]
    df['Position'] = df_xw[1]

    # 計算基準位移 x0
    x0 = df.loc[df['Speed'] < 5, 'Position'].mean()
    df['Displacement'] = df['Position'] - x0

    extracted_data = []
    search_start_idx = 0

    for target in target_speeds:
        # 尋找起始點
        condition_start = (df.index >= search_start_idx) & \
                          (df['Speed'].between(target - tolerance, target + tolerance))
        valid_starts = df.index[condition_start]
        
        if len(valid_starts) == 0:
            extracted_data.append({'speed': np.nan, 'torque': np.nan, 'displacement': np.nan})
            continue
            
        start_idx = valid_starts[0] 
        
        # 尋找結束點 (防線一：轉速衰退)
        is_out_of_bounds = ~df['Speed'].between(target - tolerance, target + tolerance)
        future_out = is_out_of_bounds.loc[start_idx:]
        consecutive_out = future_out.rolling(window=out_window).sum()
        valid_ends_speed = consecutive_out[consecutive_out == out_window].index
        
        if len(valid_ends_speed) == 0:
            end_idx_speed = df.index[-1]
        else:
            end_idx_speed = valid_ends_speed[0] - (out_window - 1) - 2
            
        # 防線二：扭矩跳崖
        future_torque_diff = df['Torque'].diff().loc[start_idx:]
        valid_ends_torque = future_torque_diff[future_torque_diff < -5.0].index
        
        if len(valid_ends_torque) == 0:
            end_idx_torque = df.index[-1]
        else:
            end_idx_torque = valid_ends_torque[0] - 1
            
        end_idx = min(end_idx_speed, end_idx_torque)
            
        # 區間萃取
        steady_state_data = df.loc[start_idx : end_idx - 1]
        data_count = len(steady_state_data)
        
        if data_count > 0:
            avg_speed = steady_state_data['Speed'].mean()
            avg_disp = steady_state_data['Displacement'].mean()
            
            torque_std = steady_state_data['Torque'].std()
            is_std_anomaly = pd.notna(torque_std) and torque_std > 0.5
            is_count_anomaly = data_count < 40
            
            if is_std_anomaly or is_count_anomaly:
                avg_torque = np.nan
            else:
                raw_avg_torque = steady_state_data['Torque'].mean()
                # 【修改點 3】計算淨扭矩：從原始平均扭矩中扣除對應轉速的零負載扭矩
                z_torque = zero_load_map.get(target, 0.0) 
                avg_torque = raw_avg_torque - z_torque

            extracted_data.append({
                'speed': avg_speed,
                'torque': avg_torque,
                'displacement': avg_disp
            })
        else:
            extracted_data.append({'speed': np.nan, 'torque': np.nan, 'displacement': np.nan})
            
        search_start_idx = end_idx if end_idx < df.index[-1] else df.index[-1] + 1
        
    return pd.DataFrame(extracted_data)

# ==========================================
# 4. 執行分析與彙整
# ==========================================
print("開始讀取原始數據並透過舊版篩選器萃取穩態值...\n")
final_results = {}

for case_name, config in compare_cases.items():
    final_results[case_name] = {}
    
    # 【修改點 4】在處理每一種構型前，先讀取並建立對應的零負載字典
    zero_load_map = get_zero_load_map(config['zero_load_file'])
    
    for rid in run_ids:
        file_tw = f"{config['path']}/{rid}_t-w.csv"
        file_xw = f"{config['path']}/{rid}_x-w.csv"
        
        res_df = extract_steady_averages_legacy(file_tw, file_xw, target_speeds, zero_load_map)
        
        if res_df is not None:
            final_results[case_name][rid] = res_df
            print(f"✅ 成功萃取: {case_name} - Run {rid}")
        else:
            print(f"⚠️ 找不到資料: {case_name} - Run {rid} (路徑: {file_tw})")

# 計算各構型的平均值
averages = {}
for case_name, runs_dict in final_results.items():
    if runs_dict:
        combined_df = pd.concat(runs_dict.values())
        averages[case_name] = combined_df.groupby(combined_df.index).mean()

# ==========================================
# 5. 繪製圖表 (分為兩個獨立視窗輸出)
# ==========================================
fig_torque, ax_torque = plt.subplots(figsize=(8, 6), num="Net Torque vs Speed")
fig_pos, ax_pos = plt.subplots(figsize=(8, 6), num="Displacement vs Speed")

for case_name, runs_dict in final_results.items():
    config = compare_cases[case_name]
    
    # --- 繪製個別的三組數據 ---
    for rid, df in runs_dict.items():
        point_color = config['colors'][rid]
        legend_label = f"{config['label_prefix']} (Run {rid})"
        
        # 繪製扭矩
        ax_torque.scatter(df['speed'], df['torque'], 
                          color=point_color, marker=config['marker'], alpha=0.6, label=legend_label)
        # 繪製位移
        ax_pos.scatter(df['speed'], df['displacement'], 
                       color=point_color, marker=config['marker'], alpha=0.6, label=legend_label)

    # --- 繪製平均趨勢線 ---
    if case_name in averages:
        avg_df = averages[case_name]
        avg_label = f"{config['label_prefix']} (Average)"
        
        # 扭矩平均標記
        ax_torque.scatter(avg_df['speed'], avg_df['torque'], 
                       color=config['avg_color'], marker=config['marker'], s=70, label=avg_label)
        
        # 位移平均標記
        ax_pos.scatter(avg_df['speed'], avg_df['displacement'], 
                    color=config['avg_color'], marker=config['marker'], s=70, label=avg_label)

# --- 扭矩圖設定 ---
ax_torque.set_title(f"Net Torque Comparison for Overlap Length = {displacement} mm", fontsize=18, fontfamily='Times New Roman')
ax_torque.set_xlabel("Average Speed (RPM)", fontsize=16, fontfamily='Times New Roman')
# 【修改點 5】修改 Y 軸名稱為淨扭矩 (Net Torque)
ax_torque.set_ylabel("Average Net Torque (Nm)", fontsize=16, fontfamily='Times New Roman')
ax_torque.grid(True, linestyle='--', alpha=0.5)
ax_torque.legend(loc='upper left', ncol=2, fontsize=10) 
ax_torque.set_xticks(target_speeds)
fig_torque.tight_layout()

# --- 位移圖設定 ---
ax_pos.set_title(f"Displacement Comparison for Overlap Length = {displacement} mm", fontsize=18, fontfamily='Times New Roman')
ax_pos.set_xlabel("Average Speed (RPM)", fontsize=16, fontfamily='Times New Roman')
ax_pos.set_ylabel("Displacement $x - x_0$ (mm)", fontsize=16, fontfamily='Times New Roman')
ax_pos.grid(True, linestyle='--', alpha=0.5)
ax_pos.legend(loc='upper left', ncol=2, fontsize=10)
ax_pos.set_xticks(target_speeds)
fig_pos.tight_layout()

print(f"\n🎉 繪圖完成！已自動載入零負載數據並計算淨制動扭矩。")
plt.show()