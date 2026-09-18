import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import Button
import numpy as np

# ==========================================
# 實驗組別與基礎設定
# ==========================================
exp_type = 'dynamic'
t_acc = 1000
case = 2
run_ids = [2, 3]  

# 【修改重點】：根據 Point-table 設定，填入 5 個連續轉速階段
sequence_steps = [
    {'name': 'Step 1: 0 -> 200 RPM',   'prev_target': 0,   'curr_target': 200},
    {'name': 'Step 2: 200 -> 300 RPM', 'prev_target': 200, 'curr_target': 300},
    {'name': 'Step 3: 300 -> 500 RPM', 'prev_target': 300, 'curr_target': 500},
    {'name': 'Step 4: 500 -> 382 RPM', 'prev_target': 500, 'curr_target': 382},
    {'name': 'Step 5: 382 -> 100 RPM', 'prev_target': 382, 'curr_target': 100},
    # 若想分析最後掉回 0 轉的狀況，可解除下方註解：
    # {'name': 'Step 6: 100 -> 0 RPM',   'prev_target': 100, 'curr_target': 0}
]
current_step_idx = 0

# ==========================================
# 1. 預先讀取所有實驗數據
# ==========================================
data_dict = {}
for rid in run_ids:
    # 若你的檔名或路徑有變，請在此處修改
    df_tw = pd.read_csv(f'not_to_commit/Exp/{exp_type}/a={t_acc}ms/case {case}/{rid}_t-w.csv', header=None, sep='\t').T
    df_xw = pd.read_csv(f'not_to_commit/Exp/{exp_type}/a={t_acc}ms/case {case}/{rid}_x-w.csv', header=None, sep='\t').T
    
    df = pd.DataFrame()
    df['Speed'] = df_tw[0]
    df['Torque'] = df_tw[1]
    df['Position'] = df_xw[1]
    data_dict[rid] = df  

# ==========================================
# 2. 循序預計算每個階段的特徵點
# ==========================================
parsed_results = {rid: [] for rid in run_ids}
tolerance = 0.5

for rid in run_ids:
    df = data_dict[rid]
    search_start_idx = 0  
    
    for step in sequence_steps:
        prev_tgt = step['prev_target']
        curr_tgt = step['curr_target']
        
        # A. 找抵達目標轉速的點
        cond_start = df['Speed'].loc[search_start_idx:].between(curr_tgt - tolerance, curr_tgt + tolerance)
        if not cond_start.any():
            parsed_results[rid].append(None)
            continue
            
        steady_start_idx = cond_start[cond_start].index[0]
        
        # B. 往回找轉換起始點
        if curr_tgt > prev_tgt:
            threshold = prev_tgt + 2.0
            cond_accel = df['Speed'].loc[search_start_idx:steady_start_idx] <= threshold
        else:
            threshold = prev_tgt - 2.0
            cond_accel = df['Speed'].loc[search_start_idx:steady_start_idx] >= threshold
            
        if cond_accel.any():
            accel_start_idx = cond_accel[cond_accel].index[-1]
        else:
            accel_start_idx = search_start_idx
            
        # C. 往下找穩定段的結束點
        cond_out = ~df['Speed'].loc[steady_start_idx:].between(curr_tgt - tolerance, curr_tgt + tolerance)
        roll_out = cond_out.rolling(15).sum()
        valid_ends = roll_out[roll_out == 15].index
        
        if len(valid_ends) > 0:
            steady_end_idx = valid_ends[0] - 14 - 2
        else:
            steady_end_idx = df.index[-1]
            
        # D. 記錄結果
        parsed_results[rid].append({
            'accel_start': accel_start_idx,
            'steady_start': steady_start_idx,
            'steady_end': steady_end_idx
        })
        search_start_idx = steady_end_idx

# ==========================================
# 建立畫布與圖表配置
# ==========================================
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(11, 9), sharex=True)
plt.subplots_adjust(bottom=0.15, left=0.1, right=0.95)

# ==========================================
# 更新圖表的函數
# ==========================================
def update_plot(idx):
    step = sequence_steps[idx]
    inspect_target = step['curr_target']
    
    ax1.clear(); ax2.clear(); ax3.clear()
    
    df_speed_aligned = pd.DataFrame()
    df_torque_aligned = pd.DataFrame()
    df_pos_aligned = pd.DataFrame()
    table_data = []
    
    # 收集繪圖所需的區段時間以計算平均值
    trans_times_ms = []
    end_times_ms = []

    for rid in run_ids:
        res = parsed_results[rid][idx]
        if res is None: continue
        
        a_idx, s_idx, e_idx = res['accel_start'], res['steady_start'], res['steady_end']
        df = data_dict[rid]
        
        chunk = df.loc[max(0, a_idx - 50) : min(len(df)-1, e_idx + 100)]
        relative_time_ms = (chunk.index - a_idx) * 40
        
        df_speed_aligned[f'Run_{rid}'] = pd.Series(chunk['Speed'].values, index=relative_time_ms)
        df_torque_aligned[f'Run_{rid}'] = pd.Series(chunk['Torque'].values, index=relative_time_ms)
        df_pos_aligned[f'Run_{rid}'] = pd.Series(chunk['Position'].values, index=relative_time_ms)
        
        transition_time_ms = (s_idx - a_idx) * 40
        steady_time_ms = (e_idx - s_idx) * 40
        steady_data = df.loc[s_idx : e_idx]
        
        trans_times_ms.append(transition_time_ms)
        end_times_ms.append(transition_time_ms + steady_time_ms)
        
        table_data.append({
            'rid': rid,
            'trans': transition_time_ms,
            'steady': steady_time_ms,
            'mean_spd': steady_data['Speed'].mean(),
            'mean_tq': steady_data['Torque'].mean(),
            'std_tq': steady_data['Torque'].std()
        })

    if df_speed_aligned.empty: return

    # 計算平均值
    df_speed_aligned['Average'] = df_speed_aligned.mean(axis=1)
    df_torque_aligned['Average'] = df_torque_aligned.mean(axis=1)
    df_pos_aligned['Average'] = df_pos_aligned.mean(axis=1)
    
    avg_trans_time = np.mean(trans_times_ms)
    avg_end_time = np.mean(end_times_ms)

    colors = {1: 'skyblue', 2: 'lightgreen', 3: 'sandybrown'}
    for rid in run_ids:
        if f'Run_{rid}' in df_speed_aligned.columns:
            ax1.plot(df_speed_aligned.index, df_speed_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, linestyle='--', label=f'Run {rid}')
            ax2.plot(df_torque_aligned.index, df_torque_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, linestyle='--')
            ax3.plot(df_pos_aligned.index, df_pos_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, linestyle='--')

    ax1.plot(df_speed_aligned.index, df_speed_aligned['Average'], color='black', linewidth=2, label='CALC Average')
    ax2.plot(df_torque_aligned.index, df_torque_aligned['Average'], color='black', linewidth=2, label='CALC Average')
    ax3.plot(df_pos_aligned.index, df_pos_aligned['Average'], color='purple', linewidth=2, label='CALC Average')

    for ax in [ax1, ax2, ax3]:
        # 繪製加減速區段 (淺藍色) 與 停留區段 (黃色)
        ax.axvspan(0, avg_trans_time, color='lightblue', alpha=0.5, label='Transition Zone (Avg)' if ax == ax1 else "")
        ax.axvspan(avg_trans_time, avg_end_time, color='yellow', alpha=0.3, label='Steady Zone (Avg)' if ax == ax1 else "")
        
        # 標示分界線
        ax.axvline(0, color='blue', linestyle='-.', linewidth=2, alpha=0.6, label='Transition Start (t=0)' if ax == ax1 else "")
        ax.axvline(avg_trans_time, color='green', linestyle='-', linewidth=2, alpha=0.6, label='Steady Start (Avg)' if ax == ax1 else "")
        ax.axvline(avg_end_time, color='red', linestyle='-', linewidth=2, alpha=0.6, label='Steady End (Avg)' if ax == ax1 else "")
        
        ax.grid(True)
        
    ax1.axhline(inspect_target, color='gray', linestyle='-.', label=f'Target ({inspect_target})')
    
    ax1.set_ylabel('Speed (RPM)')
    ax1.set_title(f"Continuous sequence: {step['name']} ({idx+1}/{len(sequence_steps)})")
    ax1.legend(loc='upper right', bbox_to_anchor=(1.0, 1.0), fontsize='small')
    ax2.set_ylabel('Torque (Nm)')
    
    ax3.set_ylabel('Position')
    ax3.set_xlabel('Relative Time from Transition Start (ms)')

    max_time = df_speed_aligned.index.max()
    ax1.set_xlim(-500, max_time) 

    # 在終端機印出數據統計表
    print(f"\n\n{'='*75}")
    print(f"📊 {step['name']} 數據統計")
    print(f"{'='*75}")
    print(f"{'實驗組數':<6} | {'轉換時間(ms)':<12} | {'停留時間(ms)':<12} | {'轉速平均(rpm)':<15} | {'扭矩平均(Nm)':<14} | {'扭矩標準差'}")
    print("-" * 80)
    
    for row in table_data:
        print(f"Run {row['rid']:<3} | {row['trans']:<14} | {row['steady']:<14} | {row['mean_spd']:<17.2f} | {row['mean_tq']:<16.2f} | {row['std_tq']:.3f}")
    print(f"{'='*75}")
    
    fig.canvas.draw_idle()

# ==========================================
# 按鈕事件綁定
# ==========================================
def next_step(event):
    global current_step_idx
    if current_step_idx < len(sequence_steps) - 1:
        current_step_idx += 1
        update_plot(current_step_idx)

def prev_step(event):
    global current_step_idx
    if current_step_idx > 0:
        current_step_idx -= 1
        update_plot(current_step_idx)

axprev = plt.axes([0.3, 0.05, 0.15, 0.05])
axnext = plt.axes([0.55, 0.05, 0.15, 0.05])

bprev = Button(axprev, 'Previous Step')
bnext = Button(axnext, 'Next Step')

bprev.on_clicked(prev_step)
bnext.on_clicked(next_step)

update_plot(current_step_idx)
plt.show()