import pandas as pd
import matplotlib.pyplot as plt
import mplcursors

# ==========================================
# 實驗設定與資料路徑
# ==========================================
base_path = 'not_to_commit/Exp/dynamic/change_speed/382-492-382'

# 定義要抓取的機構資料夾名稱，以及圖例顯示標籤
mechanisms = {
    'change_spring': 'Change Spring',
    'not_changed': 'Not Changed',
    'zero_load': 'Zero Load'
}

# 建立畫布
fig, ax = plt.subplots(figsize=(10, 6), num="Mechanism Comparison (382-492-382)")
lines_for_cursor = []

# 以第一階段 382 RPM 作為起漲點尋找的基準
initial_target_rpm = 382 

# ==========================================
# 讀取、對齊與繪圖迴圈
# ==========================================
for folder, label_name in mechanisms.items():
    # 強制抓取第二組數據 (2_t-w.csv)
    file_path = f'{base_path}/{folder}/1_t-w.csv'
    
    try:
        # 讀取轉速數據
        df_tw = pd.read_csv(file_path, header=None, sep='\t').T
        df = pd.DataFrame({'Speed': df_tw[0]})
        
        # 1. 尋找第一次抵達 382 RPM 的點
        tolerance = 0.5
        cond_start = df['Speed'].between(initial_target_rpm - tolerance, initial_target_rpm + tolerance)
        if not cond_start.any():
            print(f"警告：{folder} 找不到抵達 {initial_target_rpm} RPM 的點，將跳過繪製。")
            continue
            
        steady_start_idx = cond_start[cond_start].index[0]
        
        # 2. 往回找從 0 RPM 準備起步的瞬間 (起漲點)
        cond_accel = df['Speed'].loc[:steady_start_idx] <= 2.0
        if cond_accel.any():
            accel_start_idx = cond_accel[cond_accel].index[-1]
        else:
            accel_start_idx = 0
            
        # 3. 將起漲點設為 t=0，計算相對時間 (毫秒)
        relative_time_ms = (df.index - accel_start_idx) * 40
        
        # 4. 繪製完整折線圖 (加入 alpha 透明度讓重疊處更清晰)
        l, = ax.plot(relative_time_ms, df['Speed'], marker='.', ms=4, linestyle='-', linewidth=2, alpha=0.75, label=label_name)
        lines_for_cursor.append(l)
        
    except FileNotFoundError:
        print(f"錯誤：找不到檔案路徑 {file_path}")

# ==========================================
# 圖表視覺細節設定
# ==========================================
ax.set_title("Motor Speed Characteristics Under Different Mechanisms")
ax.set_xlabel("Relative Time (ms)")
ax.set_ylabel("Speed (RPM)")
ax.grid(True, linestyle='--', alpha=0.7)

# 將圖例放置於圖表正下方
ax.legend(loc='upper center', bbox_to_anchor=(0.5, -0.12), ncol=3, frameon=False)
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