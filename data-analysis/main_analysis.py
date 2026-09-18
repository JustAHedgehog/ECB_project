import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# ==========================================
# 1. 實驗參數設定與容器準備
# ==========================================
target_speeds = [382, 393, 404, 415, 426, 437, 448, 459, 470, 481, 492]
tolerance = 0.5  # 轉速容許誤差 (RPM)
out_window = 15  # 轉速出界確認耐心值 (筆數)
exp_id = 4.5  # 實驗組別 (請依據實際情況修改)
exp_type = 'slotted'  # 實驗類型 (normal 或 slotted)

all_runs_results = []
anomaly_log = []

print("開始進行多組實驗批次處理與特徵萃取...\n")

# ==========================================
# 2. 批次處理實驗數據 & 計算基準位移 x0
# ==========================================
for run_id in range(1, 5):
    try:
        # 注意路徑，請依據你實際資料夾位置調整
        df_tw = pd.read_csv(f'{exp_type}/{exp_id}/program/{run_id}_t-w.csv', header=None, sep='\t').T
        df_xw = pd.read_csv(f'{exp_type}/{exp_id}/program/{run_id}_x-w.csv', header=None, sep='\t').T
        # df_tw = pd.read_csv(f'{exp_type}/{run_id}_t-w.csv', header=None, sep='\t').T
        # df_xw = pd.read_csv(f'{exp_type}/{run_id}_x-w.csv', header=None, sep='\t').T
    except FileNotFoundError:
        print(f"找不到第 {run_id} 組的檔案，略過。")
        continue

    df = pd.DataFrame()
    df['Speed'] = df_tw[0]
    df['Torque'] = df_tw[1]
    df['Position'] = df_xw[1]

    # --- 核心新增：動態計算基準位移 x0 ---
    # 抓取該組實驗一開始，轉速小於 5 RPM 的靜止狀態位置作為零點基準
    x0 = df.loc[df['Speed'] < 5, 'Position'].mean()
    df['Displacement'] = df['Position'] - x0

    run_results = []
    search_start_idx = 0

    for target in target_speeds:
        # 尋找起始點
        condition_start = (df.index >= search_start_idx) & \
                          (df['Speed'].between(target - tolerance, target + tolerance))
        valid_starts = df.index[condition_start]
        
        if len(valid_starts) == 0:
            continue
        start_idx = valid_starts[0] 
        
        # 尋找結束點 (雙重防線)
        # 防線一：轉速衰退
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
            
        # 區間萃取與異常監測
        steady_state_data = df.loc[start_idx : end_idx - 1]
        data_count = len(steady_state_data)
        
        if data_count > 0:
            avg_speed = steady_state_data['Speed'].mean()
            # 這裡改為記錄「位移量」而不是絕對位置
            avg_displacement = steady_state_data['Displacement'].mean()
            
            torque_std = steady_state_data['Torque'].std()
            is_std_anomaly = pd.notna(torque_std) and torque_std > 0.5
            is_count_anomaly = data_count < 64
            
            if is_std_anomaly or is_count_anomaly:
                avg_torque = np.nan
                print(f"⚠️ [異常] Run {run_id} | 轉速 {target} RPM -> Std = {torque_std:.2f} Nm, Count = {data_count}")
            else:
                avg_torque = steady_state_data['Torque'].mean()

            run_results.append({
                'Run_ID': run_id,
                'Target_Speed (RPM)': target,
                'Data_Points': data_count,
                'Avg_Speed': avg_speed,
                'Avg_Torque': avg_torque,
                'Avg_Displacement': avg_displacement
            })
        
        search_start_idx = end_idx if end_idx < df.index[-1] else df.index[-1] + 1

    all_runs_results.append(pd.DataFrame(run_results))

# ==========================================
# 3. 跨組資料整合與匯出 CSV
# ==========================================
if len(all_runs_results) > 0:
    final_df = pd.concat(all_runs_results, ignore_index=True)
    
    # 計算跨組平均與標準差
    grand_summary = final_df.groupby('Target_Speed (RPM)').agg({
        'Avg_Speed': ['mean', 'std'],
        'Avg_Torque': ['mean', 'std'],
        'Avg_Displacement': ['mean', 'std']  # 改為位移
    }).round(4)
    
    # 攤平標題名稱並把 Target_Speed 變成正式欄位
    grand_summary.columns = ['_'.join(col).strip() for col in grand_summary.columns.values]
    grand_summary.reset_index(inplace=True)
    
    print("\n=== 跨組平均與標準差總表 ===")
    print(grand_summary)
    
    output_filename = f'{exp_type}/{exp_id}/program/{exp_type}-{exp_id}_382-492_Results.csv'
    # output_filename = 'zero_load/zero_load_Steady_State_Results.csv'
    grand_summary.to_csv(output_filename, index=False)
    print(f"\n✅ 數據已成功匯出至：{output_filename}")

    # ==========================================
    # 4. 繪製並儲存特性曲線圖表
    # ==========================================
    print("開始繪製特性曲線圖表...")
    
    x = grand_summary['Avg_Speed_mean']
    x_err = grand_summary['Avg_Speed_std']

    # --- 圖表一：轉速 vs. 扭矩 ---
    plt.figure(figsize=(8, 5), dpi=120)
    plt.errorbar(x, grand_summary['Avg_Torque_mean'], 
                 xerr=x_err, yerr=grand_summary['Avg_Torque_std'],
                 fmt='o', color='tab:orange', ecolor='red', capsize=5, 
                 linewidth=2, label='Torque (Mean ± STD)')

    plt.xlabel('Average Speed (RPM)', fontsize=12, fontweight='bold')
    plt.ylabel('Torque (Nm)', fontsize=12, fontweight='bold')
    plt.title('Speed vs. Torque Characteristics', fontsize=14, fontweight='bold')
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.legend(loc='upper left')
    plt.tight_layout()
    plt.savefig(f'{exp_type}/{exp_id}/program/{exp_type}-{exp_id}_382-492_Speed_vs_Torque.png')
    # plt.savefig('zero_load/zero_load_Speed_vs_Torque.png')
    plt.close()

    # --- 圖表二：轉速 vs. 位移 ---
    plt.figure(figsize=(8, 5), dpi=120)
    # y 軸標籤加入數學符號顯示 x - x0
    plt.errorbar(x, grand_summary['Avg_Displacement_mean'], 
                 xerr=x_err, yerr=grand_summary['Avg_Displacement_std'],
                 fmt='s', color='tab:blue', ecolor='black', capsize=5, 
                 linewidth=2, label='Displacement (Mean ± STD)')

    plt.xlabel('Average Speed (RPM)', fontsize=12, fontweight='bold')
    plt.ylabel('Displacement $x - x_0$ (mm)', fontsize=12, fontweight='bold')
    plt.title('Speed vs. Displacement Characteristics', fontsize=14, fontweight='bold')
    plt.grid(True, linestyle='--', alpha=0.6)
    plt.legend(loc='upper left')
    plt.tight_layout()
    plt.savefig(f'{exp_type}/{exp_id}/program/{exp_type}-{exp_id}_382-492_Speed_vs_Displacement.png')
    # plt.savefig('zero_load/zero_load_Speed_vs_Displacement.png')
    plt.close()
    
    print("✅ 圖表已成功儲存：'Speed_vs_Torque.png' 與 'Speed_vs_Displacement.png'")

else:
    print("未處理任何數據。")