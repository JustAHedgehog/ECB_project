import pandas as pd
import numpy as np

def calculate_features(data_dict, run_ids, sequence_steps):
    parsed_results = {rid: [] for rid in run_ids}
    
    for rid in run_ids:
        df = data_dict[rid]
        
        # 自動偵測取樣頻率
        sample_time_ms = df['Time'].diff().median()
        
        amp_window = max(1, int(200 / sample_time_ms))
        steady_confirm_points = max(1, int(300 / sample_time_ms))
        
        search_start_idx = 0  
        
        for step in sequence_steps:
            prev_tgt = step['prev_target']
            curr_tgt = step['curr_target']
            
            # ==========================================
            # 1. 寬鬆圈出階段 (Rough Zone) - 依賴轉速大範圍切換
            # ==========================================
            loose_tol = 15.0
            cond_in_stage = df['Speed'].loc[search_start_idx:].between(curr_tgt - loose_tol, curr_tgt + loose_tol)
            
            if not cond_in_stage.any():
                parsed_results[rid].append(None)
                continue
                
            rough_start = cond_in_stage[cond_in_stage].index[0]
            
            cond_out = ~df['Speed'].loc[rough_start:].between(curr_tgt - loose_tol, curr_tgt + loose_tol)
            roll_out = cond_out.rolling(steady_confirm_points).sum() 
            valid_ends = roll_out[roll_out == steady_confirm_points].index
            
            rough_end = valid_ends[0] - steady_confirm_points if len(valid_ends) > 0 else df.index[-1]
            
            # ==========================================
            # 2. 尋找起漲點 (Accel Start)
            # ==========================================
            if curr_tgt > prev_tgt:
                cond_accel = df['Speed'].loc[search_start_idx:rough_start] <= (prev_tgt + 2.0)
            else:
                cond_accel = df['Speed'].loc[search_start_idx:rough_start] >= (prev_tgt - 2.0)
                
            accel_start_idx = cond_accel[cond_accel].index[-1] if cond_accel.any() else search_start_idx
            
            # ==========================================
            # 3. 三維度聯合收斂判定 (尾端振幅基準法)
            # ==========================================
            stage_data = df.loc[rough_start:rough_end].copy()
            
            stage_data['std_spd'] = stage_data['Speed'].rolling(amp_window).std()
            stage_data['std_tq'] = stage_data['Torque'].rolling(amp_window).std()
            
            has_pos = 'Position' in stage_data.columns
            if has_pos:
                stage_data['std_pos'] = stage_data['Position'].rolling(amp_window).std()
            
            # 鎖定階梯最後 30% 最穩定的時期，作為純粹的穩態振幅基準 (Noise Floor)
            tail_len = max(1, int(len(stage_data) * 0.3))
            nf_spd = stage_data['std_spd'].iloc[-tail_len:].mean()
            nf_tq = stage_data['std_tq'].iloc[-tail_len:].mean()
            
            # 捨棄初期峰值，直接以尾端穩態振幅的 3 倍作為嚴格收斂門檻 (給予最低保底容錯)
            th_spd = max(nf_spd * 3.0, 0.5)
            th_tq = max(nf_tq * 3.0, 0.15)
            
            cond_steady = (stage_data['std_spd'].rolling(steady_confirm_points).mean() <= th_spd) & \
                          (stage_data['std_tq'].rolling(steady_confirm_points).mean() <= th_tq)
            
            if has_pos:
                nf_pos = stage_data['std_pos'].iloc[-tail_len:].mean()
                th_pos = max(nf_pos * 3.0, 0.05)
                cond_steady = cond_steady & (stage_data['std_pos'].rolling(steady_confirm_points).mean() <= th_pos)
            
            valid_starts = cond_steady[cond_steady].index
            
            if len(valid_starts) > 0:
                steady_start_idx = valid_starts[0] - steady_confirm_points - amp_window + 1
                steady_start_idx = max(steady_start_idx, rough_start)
            else:
                print(f"⚠️ 警告: Run {rid} 在 {step['name']} 未能達成尾端基準收斂。")
                steady_start_idx = rough_start
            # ==========================================
            # 4. 放寬結束點 (徹底解決提早截斷問題)
            # ==========================================
            # 放棄極端敏感的 ±2.0 RPM 判定。
            # 既然確認進入穩態，我們就把黃色穩態區間一路畫到轉速真的準備切換 (rough_end) 為止
            steady_end_idx = rough_end
            
            parsed_results[rid].append({
                'accel_start': accel_start_idx,
                'steady_start': steady_start_idx,
                'steady_end': steady_end_idx
            })
            search_start_idx = steady_end_idx
            
    return parsed_results