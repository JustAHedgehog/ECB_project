import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.signal import find_peaks
import os

# ==========================================
# 1. 參數設定與資料讀取
# ==========================================
exp_type = 'dynamic'
exp_class = 'delta'
file_path = f'not_to_commit/Exp/{exp_type}/{exp_class}/steady-400-720-triangular/steady_tri_2000-500/1_t-w.csv'  # 動態三角波實驗資料檔案 (請自行修改路徑)
activation_rpm = 300 

print(f"🚀 開始分析動態三角波實驗 (雙向極值萃取)...")

try:
    df = pd.read_csv(file_path)
    if 'time(s)' in df.columns:
        df.rename(columns={'time(s)': 'Time', 'speed(RPM)': 'Speed', 
                           'Torque(N-m)': 'Torque', 'Laser (mm) - Laser': 'Position'}, inplace=True)
except FileNotFoundError:
    print(f"⚠️ 找不到檔案: {file_path}，生成模擬數據供測試...")
    t = np.linspace(0, 20, 2000)
    spd = np.where((t>10)&(t<15), 400 + 250*np.sin((t-10)*np.pi), 200)
    spd = np.where(spd<200, 400, spd) 
    df = pd.DataFrame({'Time': t, 'Speed': spd, 
                       'Torque': np.gradient(spd)*0.2 + np.random.normal(0, 0.5, 2000), 
                       'Position': -spd/100 + 2 + np.random.normal(0, 0.1, 2000)})

x0 = df.loc[df['Speed'] < 10, 'Position'].mean() if (df['Speed'] < 10).any() else df['Position'].iloc[:50].mean()
df['Displacement'] = df['Position'] - x0

# ==========================================
# 2. 自動框出動態區間與波峰/波谷偵測
# ==========================================
dynamic_mask = df['Speed'] > activation_rpm
if not dynamic_mask.any():
    print("⚠️ 數據中未偵測到超過設定觸發轉速的動態區間！")
    exit()

dyn_start = dynamic_mask[dynamic_mask].index[0]
dyn_end = dynamic_mask[dynamic_mask].index[-1]

plot_start = max(0, dyn_start - 200)
plot_end = min(len(df) - 1, dyn_end + 200)
zone_df = df.loc[plot_start:plot_end].reset_index(drop=False)

# 尋找區間切分點
peaks, _ = find_peaks(zone_df['Speed'], height=500, distance=50)
valleys, _ = find_peaks(-zone_df['Speed'], distance=50)

# ==========================================
# 3. 切分區間並萃取【雙向極值】
# ==========================================
results = []
boundaries = [0] + list(valleys) + [len(zone_df) - 1]
boundaries = sorted(list(set(boundaries)))

print("\n📊 動態三角波特徵萃取結果：")
print("-" * 90)
print(f"{'區間':<6} | {'最高轉速':<10} | {'最大扭矩(波峰)':<14} | {'最小扭矩(波谷)':<14} | {'最大位移(最深)':<14} | {'最小位移(回彈)':<14}")
print("-" * 90)

for i in range(len(boundaries) - 1):
    b_start = boundaries[i]
    b_end = boundaries[i+1]
    
    peaks_in_interval = [p for p in peaks if b_start <= p <= b_end]
    
    if len(peaks_in_interval) > 0:
        interval_data = zone_df.loc[b_start:b_end]
        
        # 轉速 (通常只看最高點)
        max_speed = interval_data['Speed'].max()
        idx_s = interval_data['Speed'].idxmax()
        
        # 扭矩 (波峰與波谷)
        max_tq = interval_data['Torque'].max()
        idx_t_max = interval_data['Torque'].idxmax()
        min_tq = interval_data['Torque'].min()
        idx_t_min = interval_data['Torque'].idxmin()
        
        # 位移 (最深處與最高處)
        min_disp = interval_data['Displacement'].min() # 最深負值 (波谷)
        idx_d_min = interval_data['Displacement'].idxmin()
        max_disp = interval_data['Displacement'].max() # 回彈最高值 (波峰)
        idx_d_max = interval_data['Displacement'].idxmax()
        
        results.append({
            'Peak_Index': i+1, 'Max_Speed': max_speed, 'idx_s': idx_s,
            'Max_Torque': max_tq, 'idx_t_max': idx_t_max,
            'Min_Torque': min_tq, 'idx_t_min': idx_t_min,
            'Min_Displacement': min_disp, 'idx_d_min': idx_d_min,
            'Max_Displacement': max_disp, 'idx_d_max': idx_d_max,
            'bounds': (b_start, b_end)
        })
        
        print(f"P{i+1:<5} | {max_speed:<14.1f} | {max_tq:<18.2f} | {min_tq:<18.2f} | {min_disp:<18.2f} | {max_disp:<14.2f}")

print("-" * 90)

# ==========================================
# 4. 繪製精準特徵標記圖 (紅點=波峰, 藍點=波谷)
# ==========================================
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(8, 9), sharex=True)

# 畫出基礎波形
ax1.plot(zone_df['Time'], zone_df['Speed'], color='skyblue', label='Speed')
ax2.plot(zone_df['Time'], zone_df['Torque'], color='lightgray', label='Torque Signal')
ax3.plot(zone_df['Time'], zone_df['Displacement'], color='lightgreen', label='Displacement')

for i, res in enumerate(results):
    # --- 轉速標記 ---
    t_s = zone_df.loc[res['idx_s'], 'Time']
    ax1.plot(t_s, res['Max_Speed'], 'ro', ms=6)
    ax1.annotate(f"P{i+1}", (t_s, res['Max_Speed']), xytext=(0, 10), textcoords='offset points', ha='center', fontweight='bold')
    
    # --- 扭矩標記 (紅點波峰 / 藍點波谷) ---
    t_t_max = zone_df.loc[res['idx_t_max'], 'Time']
    ax2.plot(t_t_max, res['Max_Torque'], 'ro', ms=6, label='Max Torque' if i==0 else "")
    ax2.annotate(f"{res['Max_Torque']:.1f}", (t_t_max, res['Max_Torque']), xytext=(0, 8), textcoords='offset points', ha='center', color='darkred')
    
    t_t_min = zone_df.loc[res['idx_t_min'], 'Time']
    ax2.plot(t_t_min, res['Min_Torque'], 'bo', ms=6, label='Min Torque' if i==0 else "")
    ax2.annotate(f"{res['Min_Torque']:.1f}", (t_t_min, res['Min_Torque']), xytext=(0, -15), textcoords='offset points', ha='center', color='darkblue')
    
    # --- 位移標記 (紅點回彈 / 藍點最深) ---
    # 最深處 (負值極大) 以藍點標示
    t_d_min = zone_df.loc[res['idx_d_min'], 'Time']
    ax3.plot(t_d_min, res['Min_Displacement'], 'bo', ms=6, label='Max Depth' if i==0 else "")
    ax3.annotate(f"{res['Min_Displacement']:.2f}", (t_d_min, res['Min_Displacement']), xytext=(0, -15), textcoords='offset points', ha='center', color='darkblue')
    
    # 回彈最高處 以紅點標示
    t_d_max = zone_df.loc[res['idx_d_max'], 'Time']
    ax3.plot(t_d_max, res['Max_Displacement'], 'ro', ms=6, label='Max Rebound' if i==0 else "")
    ax3.annotate(f"{res['Max_Displacement']:.2f}", (t_d_max, res['Max_Displacement']), xytext=(0, 8), textcoords='offset points', ha='center', color='darkred')

    # 畫出區間分隔線
    t_bound = zone_df.loc[res['bounds'][0], 'Time']
    for ax in [ax1, ax2, ax3]:
        ax.axvline(t_bound, color='gray', linestyle=':', alpha=0.5)

# 視覺設定
ax1.set_title("Dynamic Triangle Wave: Peak & Valley Analysis", fontsize=15, fontweight='bold', fontfamily='Times New Roman')
ax1.set_ylabel("Speed (RPM)", fontsize=12)
ax2.set_ylabel("Torque (Nm)", fontsize=12)
ax3.set_ylabel("Displacement (mm)", fontsize=12)
ax3.set_xlabel("Time (ms)", fontsize=12)

for ax in [ax1, ax2, ax3]:
    ax.grid(True, linestyle='--', alpha=0.6)
    if ax != ax1:
        ax.legend(loc='upper right', fontsize=9)

plt.tight_layout()
plt.savefig('Triangle_Wave_Full_Extremes.png', dpi=300)
print("✅ 雙向極值萃取圖已儲存為: Triangle_Wave_Full_Extremes.png")
plt.show()