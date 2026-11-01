import pandas as pd
from module_calc import calculate_features
from module_export import generate_overview_and_export
from module_interactive import show_interactive_plot

# ==========================================
# 實驗組別與基礎設定
# ==========================================
exp_type = 'steady'
exp_class = 'all'
stage_1 = 200
stage_2 = 400
stage_3 = 600
stage_4 = 720
stage_5 = 600
stage_6 = 400
stage_7 = 200
case = f'{stage_1}-{stage_2}-{stage_3}'  # 實驗案例名稱，對應資料夾名稱
run_ids = [1, 2, 3]  # 實驗組別編號，對應資料夾名稱

sequence_steps = [
    {'name': f'Step 1: 0 -> {stage_1} RPM',   'prev_target': 0,   'curr_target': stage_1},
    {'name': f'Step 2: {stage_1} -> {stage_2} RPM', 'prev_target': stage_1, 'curr_target': stage_2},
    {'name': f'Step 3: {stage_2} -> {stage_3} RPM', 'prev_target': stage_2, 'curr_target': stage_3},
    {'name': f'Step 4: {stage_3} -> {stage_4} RPM', 'prev_target': stage_3, 'curr_target': stage_4},
    {'name': f'Step 5: {stage_4} -> {stage_5} RPM', 'prev_target': stage_4, 'curr_target': stage_5},
    {'name': f'Step 6: {stage_5} -> {stage_6} RPM', 'prev_target': stage_5, 'curr_target': stage_6},
    {'name': f'Step 7: {stage_6} -> {stage_7} RPM', 'prev_target': stage_6, 'curr_target': stage_7}
]
colors = {1: 'skyblue', 2: 'lightgreen', 3: 'sandybrown', 4: 'plum', 5: 'salmon'}

# ==========================================
# 1. 預先讀取所有實驗數據
# ==========================================
print("讀取實驗數據中...")
data_dir = f'not_to_commit/Exp/{exp_type}/{exp_class}'
# data_dir = f'not_to_commit/Exp/{exp_type}/{exp_class}/{case}/acc={1000}ms'
data_dict = {}
for rid in run_ids:
    df_tw = pd.read_csv(f'{data_dir}/{rid}_t-w.csv')
    # df_tw = pd.read_csv(f'{data_dir}/{rid}_modified.csv')
    
    df = pd.DataFrame()
    df['Time'] = df_tw['time(s)'] * 1000  # 時間 (ms)
    df['Speed'] = df_tw['speed(RPM)']
    df['Torque'] = df_tw['Torque(N-m)']
    df['Position'] = df_tw['Laser (mm) - Laser']
    data_dict[rid] = df  

# ==========================================
# 2. 先行計算特徵點
# ==========================================
print("計算各階段特徵點...")
parsed_results = calculate_features(data_dict, run_ids, sequence_steps)

# ==========================================
# 3. 繪製全域概覽圖 & 自動輸出結果
# ==========================================
generate_overview_and_export(data_dir, data_dict, parsed_results, run_ids, sequence_steps, exp_class, case, colors)

# ==========================================
# 4. 顯示互動式分析主畫布
# ==========================================
show_interactive_plot(data_dict, parsed_results, run_ids, sequence_steps, colors)