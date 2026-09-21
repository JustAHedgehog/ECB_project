import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import Button
import numpy as np
import mplcursors

# ==========================================
# 實驗組別與基礎設定
# ==========================================
exp_type = 'dynamic'
# exp_class = f'a={1000}ms'
exp_class = 'change_speed'
# case = '2000rpm'
stage_1 = 382
stage_2 = 492
stage_3 = 382
# stage_4 = 100
case = f'{stage_1}-{stage_2}-{stage_3}'
run_ids = [1, 2, 3]  # 實驗組別編號
sequence_steps = [
    {'name': f'Step 1: 0 -> {stage_1} RPM',   'prev_target': 0,   'curr_target': stage_1},
    {'name': f'Step 2: {stage_1} -> {stage_2} RPM', 'prev_target': stage_1, 'curr_target': stage_2},
    {'name': f'Step 3: {stage_2} -> {stage_3} RPM', 'prev_target': stage_2, 'curr_target': stage_3},
    # {'name': f'Step 4: {stage_3} -> {stage_4} RPM', 'prev_target': stage_3, 'curr_target': stage_4},
]
current_step_idx = 0
cursor = None  # 建立全域游標變數，避免切換圖表時發生記憶體殘留或衝突

# ==========================================
# 1. 預先讀取所有實驗數據
# ==========================================
data_dict = {}
for rid in run_ids:
    # df_tw = pd.read_csv(f'not_to_commit/Exp/{exp_type}/{exp_class}/{case}/{rid}_t-w.csv', header=None, sep='\t').T
    # df_xw = pd.read_csv(f'not_to_commit/Exp/{exp_type}/{exp_class}/{case}/{rid}_x-w.csv', header=None, sep='\t').T
    df_tw = pd.read_csv(f'not_to_commit/CSMMT/Exp_data/normal/Normal_self_table/{rid}_t-w.csv', header=None, sep='\t').T
    df_xw = pd.read_csv(f'not_to_commit/CSMMT/Exp_data/normal/Normal_self_table/{rid}_x-w.csv', header=None, sep='\t').T
    
    df = pd.DataFrame()
    df['Speed'] = df_tw[0]
    df['Torque'] = df_tw[1]
    df['Position'] = df_xw[1]
    data_dict[rid] = df  

## ==========================================
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
# 3. 繪製全域轉速概覽圖 (對齊起漲點版)
# ==========================================
fig_overview, ax_overview = plt.subplots(figsize=(10, 5), num="Overview - Full Speed Profile")
colors = {1: 'skyblue', 2: 'lightgreen', 3: 'sandybrown'}

for rid in run_ids:
    df = data_dict[rid]
    
    # 抓取第一階段 (Step 1) 的起漲點作為全域對齊基準
    if parsed_results[rid] and parsed_results[rid][0] is not None:
        first_accel_idx = parsed_results[rid][0]['accel_start']
    else:
        first_accel_idx = 0  # 防呆機制
        
    # 將 Index 平移並換算成 ms 毫秒
    relative_time_ms = (df.index - first_accel_idx) * 40
    
    # 為了跟你的附圖視覺保持一致，加上了 marker='.'
    ax_overview.plot(relative_time_ms, df['Speed'], color=colors.get(rid, 'gray'), 
                     marker='.', ms=4, linestyle='-', alpha=0.8, label=f'Run {rid}')

ax_overview.set_title("Full Experiment Speed Profile (Aligned Overview)")
ax_overview.set_xlabel("Relative Time from First Acceleration (ms)")
ax_overview.set_ylabel("Speed (RPM)")
ax_overview.legend(loc='upper right')
ax_overview.grid(True)

# 加入游標功能並設定顯示格式
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
# 4. 建立主分析畫布與圖表配置
# ==========================================
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(11, 8), sharex=True, num="Detailed Analysis")
plt.subplots_adjust(bottom=0.15, left=0.1, right=0.95)

# ==========================================
# 更新圖表的函數
# ==========================================
def update_plot(idx):
    global cursor # 宣告使用全域游標變數
    
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

    df_speed_aligned['Average'] = df_speed_aligned.mean(axis=1)
    df_torque_aligned['Average'] = df_torque_aligned.mean(axis=1)
    df_pos_aligned['Average'] = df_pos_aligned.mean(axis=1)
    
    avg_trans_time = np.mean(trans_times_ms)
    avg_end_time = np.mean(end_times_ms)

    colors = {1: 'skyblue', 2: 'lightgreen', 3: 'sandybrown'}
    
    # 建立專屬的 data_lines 列表，將繪製出來的線條收編，排除垂直/水平線！
    data_lines = []
    
    for rid in run_ids:
        if f'Run_{rid}' in df_speed_aligned.columns:
            l1, = ax1.plot(df_speed_aligned.index, df_speed_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, marker='o', ms=4, linestyle='-', label=f'Run {rid}')
            l2, = ax2.plot(df_torque_aligned.index, df_torque_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, marker='o', ms=4, linestyle='-')
            l3, = ax3.plot(df_pos_aligned.index, df_pos_aligned[f'Run_{rid}'], color=colors[rid], alpha=0.8, marker='o', ms=4, linestyle='-')
            data_lines.extend([l1, l2, l3])

    for ax in [ax1, ax2, ax3]:
        # 繪製加減速區段與停留區段
        ax.axvspan(0, avg_trans_time, color='lightcoral', alpha=0.5, label='Transition Zone (Avg)' if ax == ax1 else "")
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

    print(f"\n\n{'='*75}")
    print(f"📊 {step['name']} 數據統計")
    print(f"{'='*75}")
    print(f"{'實驗組數':<6} | {'轉換時間(ms)':<12} | {'停留時間(ms)':<12} | {'轉速平均(rpm)':<15} | {'扭矩平均(Nm)':<14} | {'扭矩標準差'}")
    print("-" * 80)
    for row in table_data:
        print(f"Run {row['rid']:<3} | {row['trans']:<14} | {row['steady']:<14} | {row['mean_spd']:<17.2f} | {row['mean_tq']:<16.2f} | {row['std_tq']:.3f}")
    print(f"{'='*75}")
    
    fig.canvas.draw_idle()

    # 收集所有子圖畫出的線條，並綁定互動游標
    lines = ax1.lines + ax2.lines + ax3.lines
    
    if cursor is not None:
        cursor.remove() # 移除前一個階段舊的游標
        
    cursor = mplcursors.cursor(lines, hover=False) 
    
    @cursor.connect("add")
    def on_add(sel):
        line = sel.artist
        
        # 1. 取得該條線真正的原始數據陣列
        x_data = line.get_xdata()
        y_data = line.get_ydata()
        
        # 2. 四捨五入抓取最接近的「真實資料點」索引
        idx = int(round(sel.index))
        
        # 3. 提取真正的實驗數值
        real_x = x_data[idx]
        real_y = y_data[idx]
        
        # (刪除原先會引發錯誤的 sel.target 賦值)
        # 4. 直接修改彈出視窗的文字，確保顯示的是真實陣列裡的數據
        label = line.get_label()
        if label and not label.startswith('_'):
            sel.annotation.set_text(f"{label}\nx={real_x}\ny={real_y}")
        else:
            sel.annotation.set_text(f"x={real_x}\ny={real_y}")

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