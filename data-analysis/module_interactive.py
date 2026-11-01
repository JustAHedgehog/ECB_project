import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.widgets import Button
import numpy as np
import mplcursors

def show_interactive_plot(data_dict, parsed_results, run_ids, sequence_steps, colors):
    fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(11, 8), sharex=True, num="Detailed Analysis")
    plt.subplots_adjust(bottom=0.15, left=0.1, right=0.95)

    current_step_idx = 0
    cursor = None

    def update_plot(idx):
        nonlocal cursor
        step = sequence_steps[idx]
        inspect_target = step['curr_target']
        
        ax1.clear(); ax2.clear(); ax3.clear()
        
        df_speed_aligned, df_torque_aligned, df_pos_aligned = pd.DataFrame(), pd.DataFrame(), pd.DataFrame()
        table_data, trans_times_ms, end_times_ms = [], [], []

        for rid in run_ids:
            res = parsed_results[rid][idx]
            if res is None: continue
            
            a_idx, s_idx, e_idx = res['accel_start'], res['steady_start'], res['steady_end']
            df = data_dict[rid]
            
            chunk = df.loc[max(0, a_idx - 50) : min(len(df)-1, e_idx + 100)]
            # 【修改】：使用真實的 df['Time'] 陣列來計算相對時間
            rel_time = df['Time'].loc[chunk.index].values - df['Time'].iloc[a_idx]
            
            df_speed_aligned[f'Run_{rid}'] = pd.Series(chunk['Speed'].values, index=rel_time)
            df_torque_aligned[f'Run_{rid}'] = pd.Series(chunk['Torque'].values, index=rel_time)
            df_pos_aligned[f'Run_{rid}'] = pd.Series(chunk['Position'].values, index=rel_time)
            c_trans, c_steady = (s_idx - a_idx), (e_idx - s_idx)
            
            # 利用真實的時間陣列來計算轉換與停留的實際毫秒數
            t_trans = df['Time'].iloc[s_idx] - df['Time'].iloc[a_idx]
            t_steady = df['Time'].iloc[e_idx] - df['Time'].iloc[s_idx]
            steady_data = df.loc[s_idx : e_idx]
            
            trans_times_ms.append(t_trans)
            end_times_ms.append(t_trans + t_steady)
            
            table_data.append({
                'rid': rid, 'trans': t_trans, 'trans_count': c_trans, 'steady': t_steady,'steady_count': c_steady,
                'mean_spd': steady_data['Speed'].mean(),
                'mean_tq': steady_data['Torque'].mean(),
                'std_tq': steady_data['Torque'].std()
            })

        if df_speed_aligned.empty: return

        avg_trans_time, avg_end_time = np.mean(trans_times_ms), np.mean(end_times_ms)
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
        ax1.set_ylabel('Speed (RPM)'); ax1.set_title(f"Continuous sequence: {step['name']} ({idx+1}/{len(sequence_steps)})")
        ax1.legend(loc='upper right', bbox_to_anchor=(1.0, 1.0), fontsize='small')
        ax2.set_ylabel('Torque (Nm)')
        ax3.set_ylabel('Position(mm)'); ax3.set_xlabel('Relative Time from Transition Start (ms)')
        ax1.set_xlim(-500, df_speed_aligned.index.max()) 

        print(f"\n\n{'='*75}")
        print(f"📊 {step['name']} 數據統計")
        # 計算總視覺寬度為 107 字元
        print("=" * 107)
        # 直接寫死中文標題，避免 f-string 對中文字元長度計算的誤差
        print("實驗組數 | 轉換時間(ms) | 停留時間(ms) | 轉速平均(rpm) | 扭矩平均(Nm) | 扭矩標準差 | 平均位移(mm) | 位移標準差")
        print("-" * 107)
        
        for row in table_data:
            # 提前算出位移的統計值，讓程式碼更乾淨
            pos_mean = df_pos_aligned[f'Run_{row["rid"]}'].mean()
            pos_std = df_pos_aligned[f'Run_{row["rid"]}'].std()
            
            # 依照上方中英文混合標題的「真實視覺長度」來賦予精確的佔位寬度
            # 中文字算 2 寬度，英文字算 1 寬度
            print(f"Run {row['rid']:<4} | {row['trans']:<12.1f} | {row['steady']:<12.1f} | {row['mean_spd']:<13.2f} | {row['mean_tq']:<12.2f} | {row['std_tq']:<10.3f} | {pos_mean:<12.2f} | {pos_std:<10.2f}")
            
        print("=" * 107)
        
        fig.canvas.draw_idle()

        if cursor is not None:
            cursor.remove()
            
        cursor = mplcursors.cursor(data_lines, hover=False) 
        @cursor.connect("add")
        def on_add(sel):
            line = sel.artist
            idx = int(round(sel.index))
            real_x, real_y = line.get_xdata()[idx], line.get_ydata()[idx]
            sel.target = (real_x, real_y)
            label = line.get_label()
            if label and not label.startswith('_'):
                sel.annotation.set_text(f"{label}\nx={real_x}\ny={real_y}")
            else:
                sel.annotation.set_text(f"x={real_x}\ny={real_y}")

    def next_step(event):
        nonlocal current_step_idx
        if current_step_idx < len(sequence_steps) - 1:
            current_step_idx += 1
            update_plot(current_step_idx)

    def prev_step(event):
        nonlocal current_step_idx
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