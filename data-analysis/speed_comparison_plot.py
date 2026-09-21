import pandas as pd
import matplotlib.pyplot as plt
import mplcursors

# ==========================================
# 實驗設定與資料路徑
# ==========================================
exp_type = 'dynamic'
t_acc = 1000

# 定義要抓取的資料夾名稱，以及對應的「目標轉速」(用來尋找對齊基準)
compare_groups = {
    '100rpm': 100,
    '200rpm': 200,
    '250rpm': 250,
    '300rpm': 300
}

# 建立畫布
fig, ax = plt.subplots(figsize=(10, 6), num="Multi-RPM Speed Comparison")
lines_for_cursor = []
table_data = []  # 【新增】：用來收集並列印統計數據的清單

# ==========================================
# 讀取、對齊、計算與繪圖迴圈
# ==========================================
for folder, target_rpm in compare_groups.items():
    file_path = f'not_to_commit/Exp/{exp_type}/a={t_acc}ms/{folder}/1_t-w.csv'
    
    try:
        # 讀取轉速數據
        df_tw = pd.read_csv(file_path, header=None, sep='\t').T
        df = pd.DataFrame({'Speed': df_tw[0]})
        
        # 1. 尋找抵達目標轉速的點 (穩態起點)
        tolerance = 0.5
        cond_start = df['Speed'].between(target_rpm - tolerance, target_rpm + tolerance)
        if not cond_start.any():
            print(f"警告：{folder} 找不到抵達 {target_rpm} RPM 的穩態點，將跳過繪製。")
            continue
            
        steady_start_idx = cond_start[cond_start].index[0]
        
        # 2. 往回找從 0 RPM 準備起步的瞬間 (起漲點)
        cond_accel = df['Speed'].loc[:steady_start_idx] <= 2.0
        if cond_accel.any():
            accel_start_idx = cond_accel[cond_accel].index[-1]
        else:
            accel_start_idx = 0
            
        # 3. 往下尋找穩定段的結束點 (轉速跌落瞬間)
        cond_out = ~df['Speed'].loc[steady_start_idx:].between(target_rpm - tolerance, target_rpm + tolerance)
        roll_out = cond_out.rolling(15).sum()
        valid_ends = roll_out[roll_out == 15].index
        
        if len(valid_ends) > 0:
            steady_end_idx = valid_ends[0] - 14 - 2
        else:
            steady_end_idx = df.index[-1]
            
        # 4. 計算時間
        rise_time_ms = (steady_start_idx - accel_start_idx) * 40
        steady_time_ms = (steady_end_idx - steady_start_idx) * 40
        steady_data = df.loc[steady_start_idx:steady_end_idx]

        table_data.append({
            'folder': folder,
            'target': target_rpm,
            'rise': rise_time_ms,
            'steady': steady_time_ms,
            'speed_mean': steady_data['Speed'].mean(),
        })
            
        # 5. 將起漲點設為 t=0，計算相對時間 (毫秒)
        relative_time_ms = (df.index - accel_start_idx) * 40
        
        # 6. 繪製折線圖
        l, = ax.plot(relative_time_ms, df['Speed'], marker='o', ms=5, linestyle='-', linewidth=2, label=folder)
        lines_for_cursor.append(l)
        
    except FileNotFoundError:
        print(f"錯誤：找不到檔案路徑 {file_path}")

# ==========================================
# 在終端機印出精美的數據統計表
# ==========================================
print(f"\n\n{'='*65}")
print(f"📊 跨轉速疊圖數據統計 (皆為各組 1_t-w.csv)")
print(f"{'='*65}")
print(f"{'組別 (資料夾)':<14} | {'目標轉速(rpm)':<14} | {'上升時間(ms)':<14} | {'停留時間(ms)'} | {'穩定轉速平均(rpm)'}")
print("-" * 65)
for row in table_data:
    print(f"{row['folder']:<20} | {row['target']:<17} | {row['rise']:<16} | {row['steady']:<16} | {row['speed_mean']:<16.2f}")
print(f"{'='*65}\n")

# ==========================================
# 圖表視覺細節設定
# ==========================================
ax.set_title("Speed Comparison (Aligned at Acceleration Start)")
ax.set_xlabel("Relative Time (ms)")
ax.set_ylabel("Speed (RPM)")
ax.grid(True, linestyle='--', alpha=0.7)

# 將圖例放置於圖表正下方
ax.legend(loc='upper center', bbox_to_anchor=(0.5, -0.12), ncol=4, frameon=False)
plt.tight_layout()

# ==========================================
# 綁定精確數據游標
# ==========================================
cursor = mplcursors.cursor(lines_for_cursor, hover=False)

@cursor.connect("add")
def on_add(sel):
    line = sel.artist
    x_data, y_data = line.get_xdata(), line.get_ydata()
    
    # 強制吸附真實陣列數據點
    idx = int(round(sel.index))
    real_x = x_data[idx]
    real_y = y_data[idx]
    
    sel.target = (real_x, real_y)
    
    label = line.get_label()
    sel.annotation.set_text(f"{label}\nx={real_x:.0f}\ny={real_y:.2f}")

plt.show()