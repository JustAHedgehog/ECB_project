import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import Button
import numpy as np

# ==========================================
# 實驗組別與基礎設定
# ==========================================
exp_type = 'dynamic'
t_acc = 1000
t_static = 10
run_ids = [1, 2, 3]  
target_rpms = list(range(382, 493, 11))
current_idx = 0

# ==========================================
# 1. 預先讀取並儲存所有實驗數據
# ==========================================
data_dict = {}
for rid in run_ids:
    df_tw = pd.read_csv(f'not_to_commit/Exp/{exp_type}/a={t_acc}ms/{rid}_t-w.csv', header=None, sep='\t').T
    df_xw = pd.read_csv(f'not_to_commit/Exp/{exp_type}/a={t_acc}ms/{rid}_x-w.csv', header=None, sep='\t').T
    
    df = pd.DataFrame()
    df['Speed'] = df_tw[0]
    df['Torque'] = df_tw[1]
    df['Position'] = df_xw[1]
    data_dict[rid] = df  

# ==========================================
# 建立畫布與圖表配置
# ==========================================
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(10, 9), sharex=True)
plt.subplots_adjust(bottom=0.15, left=0.1, right=0.95)

# ==========================================
# 更新圖表的函數
# ==========================================
def update_plot(idx):
    inspect_target = target_rpms[idx]
    
    # 決定前一個目標轉速 (用來抓起漲點)
    if idx == 0:
        prev_target = 0
    else:
        prev_target = target_rpms[idx-1]
    accel_threshold = prev_target + 2.0  # 容許 2 RPM 的雜訊
    
    ax1.clear(); ax2.clear(); ax3.clear()
    
    df_speed_aligned = pd.DataFrame()
    df_torque_aligned = pd.DataFrame()
    df_pos_aligned = pd.DataFrame()

    tolerance = 0.5
    
    # 2. 迴圈處理每一次的實驗，尋找各自的【起漲點】
    for rid in run_ids:
        df = data_dict[rid]
        
        # 先找抵達目標轉速的點
        condition_start = df['Speed'].between(inspect_target - tolerance, inspect_target + tolerance)
        valid_starts = df.index[condition_start]
        
        if len(valid_starts) == 0:
            print(f"警告：Run {rid} 找不到符合 {inspect_target} RPM 的點")
            continue
            
        start_idx = valid_starts[0]
        
        # 從抵達點往回找起漲點
        past_data = df.loc[:start_idx-1]
        possible_accel_starts = past_data[past_data['Speed'] <= accel_threshold].index
        
        if len(possible_accel_starts) > 0:
            accel_start_idx = possible_accel_starts[-1]
        else:
            accel_start_idx = max(0, start_idx - 50)
        
        # 將 accel_start_idx 當作 t=0 點
        relative_time_ms = (df.index - accel_start_idx) * 40
        
        # 將資料以「相對時間」存入 DataFrame
        df_speed_aligned[f'Run_{rid}'] = pd.Series(df['Speed'].values, index=relative_time_ms)
        df_torque_aligned[f'Run_{rid}'] = pd.Series(df['Torque'].values, index=relative_time_ms)
        df_pos_aligned[f'Run_{rid}'] = pd.Series(df['Position'].values, index=relative_time_ms)

    if df_speed_aligned.empty:
        ax1.set_title(f'Diagnostic Tool - Target {inspect_target} RPM (No Data!)', color='red')
        fig.canvas.draw_idle()
        return

    # 3. 計算平均值
    df_speed_aligned['Average'] = df_speed_aligned.mean(axis=1)
    df_torque_aligned['Average'] = df_torque_aligned.mean(axis=1)
    df_pos_aligned['Average'] = df_pos_aligned.mean(axis=1)

    # 4. 繪圖
    colors = {1: 'skyblue', 2: 'lightgreen', 3: 'sandybrown'}
    
    for rid in run_ids:
        if f'Run_{rid}' in df_speed_aligned.columns:
            ax1.plot(df_speed_aligned.index, df_speed_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, linestyle='--', label=f'Run {rid}')
            ax2.plot(df_torque_aligned.index, df_torque_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, linestyle='--')
            ax3.plot(df_pos_aligned.index, df_pos_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, linestyle='--')

    ax1.plot(df_speed_aligned.index, df_speed_aligned['Average'], color='black', linewidth=2, label='CALC Average')
    ax2.plot(df_torque_aligned.index, df_torque_aligned['Average'], color='black', linewidth=2, label='CALC Average')
    ax3.plot(df_pos_aligned.index, df_pos_aligned['Average'], color='purple', linewidth=2, label='CALC Average')

    # 標示對齊基準線 (現在 t=0 代表起漲點)
    for ax in [ax1, ax2, ax3]:
        ax.axvline(0, color='blue', linestyle='-.', linewidth=2, alpha=0.6, label='Acceleration Start (t=0)' if ax == ax1 else "")
        ax.grid(True)
        
    ax1.axhline(inspect_target, color='gray', linestyle='-.', label=f'Target ({inspect_target})')
    
    ax1.set_ylabel('Speed (RPM)')
    ax1.set_title(f'Multi-Run Overlay & Average @ {inspect_target} RPM (Aligned by Accel Start)')
    ax1.legend(loc='lower right')
    
    ax2.set_ylabel('Torque (Nm)')
    ax2.legend(loc='lower right')
    
    ax3.set_ylabel('Position')
    ax3.set_xlabel('Relative Time from Acceleration Start (ms)')
    ax3.legend(loc='lower right')

    # 【修改重點】：解除 4000ms 限制，讓右側邊界自動延伸至數據最尾端
    # 左側依舊保留 -500ms 的緩衝空間以觀察起漲前狀態
    max_time = df_speed_aligned.index.max()
    ax1.set_xlim(-500, max_time) 

    fig.canvas.draw_idle()

# ==========================================
# 按鈕事件綁定
# ==========================================
def next_rpm(event):
    global current_idx
    if current_idx < len(target_rpms) - 1:
        current_idx += 1
        update_plot(current_idx)

def prev_rpm(event):
    global current_idx
    if current_idx > 0:
        current_idx -= 1
        update_plot(current_idx)

axprev = plt.axes([0.3, 0.05, 0.15, 0.05])
axnext = plt.axes([0.55, 0.05, 0.15, 0.05])

bprev = Button(axprev, 'Previous RPM')
bnext = Button(axnext, 'Next RPM')

bprev.on_clicked(prev_rpm)
bnext.on_clicked(next_rpm)

update_plot(current_idx)
plt.show()