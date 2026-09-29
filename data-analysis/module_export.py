import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import mplcursors
import os

def generate_overview_and_export(data_dir, data_dict, parsed_results, run_ids, sequence_steps, exp_class, case, colors):
    # ==========================================
    # A. 建立全域總覽圖 (維持視窗開啟)
    # ==========================================
    fig_overview, ax_overview = plt.subplots(figsize=(10, 5), num="Overview - Full Speed Profile")
    
    for rid in run_ids:
        df = data_dict[rid]
        first_accel_idx = parsed_results[rid][0]['accel_start'] if (parsed_results[rid] and parsed_results[rid][0]) else 0
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
        idx = int(round(sel.index))
        real_x, real_y = line.get_xdata()[idx], line.get_ydata()[idx]
        sel.target = (real_x, real_y)
        sel.annotation.set_text(f"{line.get_label()}\nx={real_x:.0f}\ny={real_y:.2f}")

    # ==========================================
    # B. 背景自動輸出邏輯
    # ==========================================
    print(f"\n[{'='*30} 自動輸出開始 {'='*30}]")
    output_dir = f'{data_dir}/Exported_Results'
    os.makedirs(output_dir, exist_ok=True)

    overview_path = os.path.join(output_dir, f'Overview_{exp_class}_{case}.png')
    fig_overview.savefig(overview_path, dpi=300, bbox_inches='tight')
    print(f"✅ 總覽圖已儲存: {overview_path}")

    all_table_data = []
    fig_export, (ax_e1, ax_e2, ax_e3) = plt.subplots(3, 1, figsize=(11, 8), sharex=True)

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

            c_trans, c_steady = (s_idx - a_idx), (e_idx - s_idx)
            t_trans = c_trans * 40
            t_steady = c_steady * 40
            steady_data = df.loc[s_idx : e_idx]
            
            trans_times_ms.append(t_trans)
            end_times_ms.append(t_trans + t_steady)
            
            all_table_data.append({
                '階段': step['name'], '組別': f'Run {rid}', '轉換時間(ms)': t_trans, '轉換擷取資料數': c_trans, '停留時間(ms)': t_steady, '停留擷取資料數': c_steady,
                '轉速平均(rpm)': round(steady_data['Speed'].mean(), 2),
                '扭矩平均(Nm)': round(steady_data['Torque'].mean(), 2),
                '扭矩標準差': round(steady_data['Torque'].std(), 3)
            })

        if df_speed_aligned.empty: continue

        avg_trans, avg_end = np.mean(trans_times_ms), np.mean(end_times_ms)

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
        ax_e1.set_ylabel('Speed (RPM)'); ax_e1.set_title(step['name'])
        ax_e2.set_ylabel('Torque (Nm)')
        ax_e3.set_ylabel('Position'); ax_e3.set_xlabel('Relative Time from Transition Start (ms)')
        ax_e1.set_xlim(-500, df_speed_aligned.index.max())

        plt.tight_layout()
        step_path = os.path.join(output_dir, f'Step_{idx+1}_{safe_step_name}.png')
        fig_export.savefig(step_path, dpi=300, bbox_inches='tight')
        print(f"✅ 階段圖已儲存: {step_path}")

    plt.close(fig_export)

    if all_table_data:
        df_csv = pd.DataFrame(all_table_data)
        csv_path = os.path.join(output_dir, f'Analysis_Stats_{exp_class}_{case}.csv')
        df_csv.to_csv(csv_path, index=False, encoding='utf-8-sig')
        print(f"✅ 統計總表已儲存: {csv_path}")
        
    print(f"[{'='*30} 自動輸出結束 {'='*30}]\n")