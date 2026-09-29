import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker

# 1. 讀取數據，跳過前3行設定檔，將第4行設為欄位名稱
exp_type = 'dynamic'
exp_class = 'change_speed'
stage_1 = 382
stage_2 = 492
stage_3 = 382
# stage_5 = stage_1
# stage_6 = stage_2
case = f'{stage_1}-{stage_2}-{stage_3}'
data_dir = f'not_to_commit/Exp/{exp_type}/{exp_class}/{case}/zero_load_0923'
df = pd.read_csv(f'{data_dir}/4_motor.csv', skiprows=3, header=0)

# 去除原檔中的單位說明列 (ms, Servo motor speed...) 並重設索引
df = df.drop(0).reset_index(drop=True)

# 轉換資料型態為浮點數，以利數學運算
df['Time'] = df['Time'].astype(float)
df['Analog 1'] = df['Analog 1'].astype(float) # 馬達轉速
df['Analog 2'] = df['Analog 2'].astype(float) # 原始脈衝位置

# 2. 進行「補償值展開 (Unwrapping)」
raw_position = df['Analog 2'].values
unwrapped_position = np.copy(raw_position)

compensation = 0
for i in range(1, len(raw_position)):
    # 偵測溢位：若當前數值比上一筆數值小非常多 (差距低於 -50000)
    # 代表發生了 +32767 到 -32768 的跳水
    diff = raw_position[i] - raw_position[i-1]
    
    if diff < -50000:
        compensation += 65536  # 每次跳水，未來的數據都補償 2^16
        
    unwrapped_position[i] = raw_position[i] + compensation

df['Unwrapped Position'] = unwrapped_position

# 3. 繪製圖表
fig, ax1 = plt.subplots(figsize=(10, 6))

# 繪製馬達轉速 (左Y軸)
color = 'tab:blue'
ax1.set_xlabel('Time (ms)')
ax1.set_ylabel('Motor Speed (r/min)', color=color)
ax1.plot(df['Time'], df['Analog 1'], color=color, label='Speed')
ax1.tick_params(axis='y', labelcolor=color)
ax1.grid(True, alpha=0.5)

# 繪製累積位置 (右Y軸)
ax2 = ax1.twinx()  
color = 'tab:green'
ax2.set_ylabel('Cumulative Position (Pulse)', color=color)  
ax2.plot(df['Time'], df['Unwrapped Position'], color=color, marker='o', markersize=2, label='Unwrapped Position')
ax2.tick_params(axis='y', labelcolor=color)
ax2.get_yaxis().set_major_formatter(ticker.FuncFormatter(lambda x, p: format(int(x), ',')))

plt.title('Motor Speed and Unwrapped Position over Time')
fig.tight_layout()  

plt.show()