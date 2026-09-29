import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import Button
import numpy as np
import mplcursors
import os

# ==========================================
# 實驗組別與基礎設定
# ==========================================
exp_type = 'dynamic'
exp_class = 'change_speed'
stage_1 = 382
stage_2 = 492
stage_3 = 382
case = f'{stage_1}-{stage_2}-{stage_3}'
run_ids = [1, 2, 3, 4]  
sequence_steps = [
    {'name': f'Step 1: 0 -> {stage_1} RPM',   'prev_target': 0,   'curr_target': stage_1},
    {'name': f'Step 2: {stage_1} -> {stage_2} RPM', 'prev_target': stage_1, 'curr_target': stage_2},
    {'name': f'Step 3: {stage_2} -> {stage_3} RPM', 'prev_target': stage_2, 'curr_target': stage_3},
]
current_step_idx = 0
cursor = None  
data_dir = f'not_to_commit/Exp/{exp_type}/{exp_class}/{case}/zero_load'
# ==========================================
# 1. 預先讀取所有實驗數據
# ==========================================
data_dict = {}
for rid in run_ids:
    df_tw = pd.read_csv(f'{data_dir}/{rid}_t-w.csv', header=None, sep='\t').T
    df_xw = pd.read_csv(f'{data_dir}/{rid}_x-w.csv', header=None, sep='\t').T
    
    df = pd.DataFrame()
    df['Speed'] = df_tw[0]
    df['Torque'] = df_tw[1]
    df['Position'] = df_xw[1]
    data_dict[rid] = df  

# ==========================================
# 2. 先行計算：循序預計算每個階段的特徵點
# ==========================================
parsed_results = {rid: [] for rid in run_ids}
tolerance = 0.5

for rid in run_ids:
    df = data_dict[rid]
    search_start_idx = 0  
    
    for step in sequence_steps:
        prev_tgt = step['prev_target']
        curr_tgt = step['curr_target']
        
        cond_start = df['Speed'].loc[search_start_idx:].between(curr_tgt - tolerance, curr_tgt + tolerance)
        if not cond_start.any():
            parsed_results[rid].append(None)
            continue
            
        steady_start_idx = cond_start[cond_start].index[0]
        
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
            
        cond_out = ~df['Speed'].loc[steady_start_idx:].between(curr_tgt - tolerance, curr_tgt + tolerance)
        roll_out = cond_out.rolling(15).sum()
        valid_ends = roll_out[roll_out == 15].index
        
        if len(valid_ends) > 0:
            steady_end_idx = valid_ends[0] - 14 - 2
        else:
            steady_end_idx = df.index[-1]
            
        parsed_results[rid].append({
            'accel_start': accel_start_idx,
            'steady_start': steady_start_idx,
            'steady_end': steady_end_idx
        })
        search_start_idx = steady_end_idx

# ==========================================
# 3. 繪製全域轉速概覽圖
# ==========================================
fig_overview, ax_overview = plt.subplots(figsize=(10, 5), num="Overview - Full Speed Profile")
colors = {1: 'skyblue', 2: 'lightgreen', 3: 'sandybrown', 4: 'plum', 5: 'salmon'}

for rid in run_ids:
    df = data_dict[rid]
    if parsed_results[rid] and parsed_results[rid][0] is not None:
        first_accel_idx = parsed_results[rid][0]['accel_start']
    else:
        first_accel_idx = 0 
        
    relative_time_ms = (df.index - first_accel_idx) * 40
    ax_overview.plot(relative_time_ms, df['Speed'], color=colors.get(rid, 'gray'), 
                     marker='.', ms=4, linestyle='-', alpha=0.8, label=f'Run {rid}')

ax_overview.set_title("Full Experiment Speed Profile (Aligned Overview)")
ax_overview.set_xlabel("Relative Time from First Acceleration (ms)")
ax_overview.set_ylabel("Speed (RPM)")
ax_overview.legend(loc='upper right')
ax_overview.grid(True)

cursor_overview = mplcursors.cursor(ax_overview.lines, hover=False)
@cursor_overview.connect("add")
def on_add_overview(sel):
    line = sel.artist
    x_data, y_data = line.get_xdata(), line.get_ydata()
    idx = int(round(sel.index))
    real_x, real_y = x_data[idx], y_data[idx]
    sel.target = (real_x, real_y)
    label = line.get_label()
    sel.annotation.set_text(f"{label}\nx={real_x:.0f}\ny={real_y:.2f}")

# ==========================================
# 自動輸出分析結果的函式
# ==========================================
def output_export():
    print(f"\n[{'='*30} 自動輸出開始 {'='*30}]")
    output_dir = data_dir
    os.makedirs(output_dir, exist_ok=True)

    # 1. 輸出全域總覽圖
    overview_path = os.path.join(output_dir, f'Overview_{exp_class}_{case}.png')
    fig_overview.savefig(overview_path, dpi=300, bbox_inches='tight')
    print(f"✅ 總覽圖已儲存: {overview_path}")

    all_table_data = []
    # 建立一個背景用的畫布，避免干擾主視窗
    fig_export, (ax_e1, ax_e2, ax_e3) = plt.subplots(3, 1, figsize=(11, 8), sharex=True)

    # 2. 迴圈處理並輸出每個階段的圖片與數據
    for idx, step in enumerate(sequence_steps):
        safe_step_name = step['name'].replace(":", "").replace("->", "to").replace(" ", "_")
        ax_e1.clear(); ax_e2.clear(); ax_e3.clear()
        
        df_speed_aligned, df_torque_aligned, df_pos_aligned = pd.DataFrame(), pd.DataFrame(), pd.DataFrame()
        trans_times_ms, end_times_ms = [], []

        for rid in run_ids:
            res = parsed_results[rid][idx]
            if res is None: continue
            
            a_idx, s_idx, e_idx = res['accel_start'], res['steady_start'], res['steady_end']
            df = data_dict[rid]
            
            chunk = df.loc[max(0, a_idx - 50) : min(len(df)-1, e_idx + 100)]
            rel_time = (chunk.index - a_idx) * 40
            
            df_speed_aligned[f'Run_{rid}'] = pd.Series(chunk['Speed'].values, index=rel_time)
            df_torque_aligned[f'Run_{rid}'] = pd.Series(chunk['Torque'].values, index=rel_time)
            df_pos_aligned[f'Run_{rid}'] = pd.Series(chunk['Position'].values, index=rel_time)
            
            t_trans = (s_idx - a_idx) * 40
            t_steady = (e_idx - s_idx) * 40
            steady_data = df.loc[s_idx : e_idx]
            
            trans_times_ms.append(t_trans)
            end_times_ms.append(t_trans + t_steady)
            
            all_table_data.append({
                '階段': step['name'],
                '組別': f'Run {rid}',
                '轉換時間(ms)': t_trans,
                '停留時間(ms)': t_steady,
                '轉速平均(rpm)': round(steady_data['Speed'].mean(), 2),
                '扭矩平均(Nm)': round(steady_data['Torque'].mean(), 2),
                '扭矩標準差': round(steady_data['Torque'].std(), 3)
            })

        if df_speed_aligned.empty: continue

        avg_trans = np.mean(trans_times_ms)
        avg_end = np.mean(end_times_ms)

        for rid in run_ids:
            if f'Run_{rid}' in df_speed_aligned.columns:
                ax_e1.plot(df_speed_aligned.index, df_speed_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, marker='o', ms=4, linestyle='-')
                ax_e2.plot(df_torque_aligned.index, df_torque_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, marker='o', ms=4, linestyle='-')
                ax_e3.plot(df_pos_aligned.index, df_pos_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, marker='o', ms=4, linestyle='-')

        for ax in [ax_e1, ax_e2, ax_e3]:
            ax.axvspan(0, avg_trans, color='lightcoral', alpha=0.5)
            ax.axvspan(avg_trans, avg_end, color='yellow', alpha=0.3)
            ax.axvline(0, color='blue', linestyle='-.', linewidth=2, alpha=0.6)
            ax.axvline(avg_trans, color='green', linestyle='-', linewidth=2, alpha=0.6)
            ax.axvline(avg_end, color='red', linestyle='-', linewidth=2, alpha=0.6)
            ax.grid(True)
            
        ax_e1.axhline(step['curr_target'], color='gray', linestyle='-.')
        ax_e1.set_ylabel('Speed (RPM)')
        ax_e1.set_title(step['name'])
        ax_e2.set_ylabel('Torque (Nm)')
        ax_e3.set_ylabel('Position')
        ax_e3.set_xlabel('Relative Time from Transition Start (ms)')
        ax_e1.set_xlim(-500, df_speed_aligned.index.max())

        plt.tight_layout()
        step_path = os.path.join(output_dir, f'Step_{idx+1}_{safe_step_name}.png')
        fig_export.savefig(step_path, dpi=300, bbox_inches='tight')
        print(f"✅ 階段圖已儲存: {step_path}")

    plt.close(fig_export)

    # 3. 輸出包含所有階段數據的 CSV 總表
    if all_table_data:
        df_csv = pd.DataFrame(all_table_data)
        csv_path = os.path.join(output_dir, f'Analysis_Stats_{exp_class}_{case}.csv')
        df_csv.to_csv(csv_path, index=False, encoding='utf-8-sig')
        print(f"✅ 統計總表已儲存: {csv_path}")
        
    print(f"[{'='*30} 自動輸出結束 {'='*30}]\n")

# 執行自動輸出
output_export()

# ==========================================
# 4. 建立主分析畫布與圖表配置 (維持原互動功能)
# ==========================================
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(11, 8), sharex=True, num="Detailed Analysis")
plt.subplots_adjust(bottom=0.15, left=0.1, right=0.95)

def update_plot(idx):
    global cursor 
    step = sequence_steps[idx]
    inspect_target = step['curr_target']
    
    ax1.clear(); ax2.clear(); ax3.clear()
    
    df_speed_aligned = pd.DataFrame()
    df_torque_aligned = pd.DataFrame()
    df_pos_aligned = pd.DataFrame()
    table_data = []
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

    avg_trans_time = np.mean(trans_times_ms)
    avg_end_time = np.mean(end_times_ms)
    
    data_lines = []
    for rid in run_ids:
        if f'Run_{rid}' in df_speed_aligned.columns:
            l1, = ax1.plot(df_speed_aligned.index, df_speed_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, marker='o', ms=4, linestyle='-', label=f'Run {rid}')
            l2, = ax2.plot(df_torque_aligned.index, df_torque_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, marker='o', ms=4, linestyle='-')
            l3, = ax3.plot(df_pos_aligned.index, df_pos_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, marker='o', ms=4, linestyle='-')
            data_lines.extend([l1, l2, l3])

    for ax in [ax1, ax2, ax3]:
        ax.axvspan(0, avg_trans_time, color='lightcoral', alpha=0.5, label='Transition Zone (Avg)' if ax == ax1 else "")
        ax.axvspan(avg_trans_time, avg_end_time, color='yellow', alpha=0.3, label='Steady Zone (Avg)' if ax == ax1 else "")
        
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

    print(f"\n\n{'='*75}")
    print(f"📊 {step['name']} 數據統計")
    print(f"{'='*75}")
    print(f"{'實驗組數':<6} | {'轉換時間(ms)':<12} | {'停留時間(ms)':<12} | {'轉速平均(rpm)':<15} | {'扭矩平均(Nm)':<14} | {'扭矩標準差'}")
    print("-" * 80)
    for row in table_data:
        print(f"Run {row['rid']:<3} | {row['trans']:<14} | {row['steady']:<14} | {row['mean_spd']:<17.2f} | {row['mean_tq']:<16.2f} | {row['std_tq']:.3f}")
    print(f"{'='*75}")
    
    fig.canvas.draw_idle()

    if cursor is not None:
        cursor.remove()
        
    cursor = mplcursors.cursor(data_lines, hover=False) 
    
    @cursor.connect("add")
    def on_add(sel):
        line = sel.artist
        x_data = line.get_xdata()
        y_data = line.get_ydata()
        
        idx = int(round(sel.index))
        real_x = x_data[idx]
        real_y = y_data[idx]
        
        label = line.get_label()
        if label and not label.startswith('_'):
            sel.annotation.set_text(f"{label}\nx={real_x}\ny={real_y}")
        else:
            sel.annotation.set_text(f"x={real_x}\ny={real_y}")

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