import pandas as pd

def calculate_features(data_dict, run_ids, sequence_steps, tolerance):
    parsed_results = {rid: [] for rid in run_ids}
    
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
            
    return parsed_results