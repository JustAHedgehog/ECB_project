import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# 1. 移除 header=None，讓 Pandas 自動把第一列識別為標題
# 這樣底下的資料就會自動保持為正確的數值型態 (Float)
normal_zero_load = pd.read_csv(r'normal\zero_load\normal-zero_load_382-492_Results.csv')
normal_0 = pd.read_csv(r'normal\0\normal-0_Steady_State_Results.csv')
normal_1_5 = pd.read_csv(r'normal\1.5\normal-1.5_Steady_State_Results.csv')
normal_4_5 = pd.read_csv(r'normal\4.5\program\normal-4.5_382-492_Results.csv')
normal_6 = pd.read_csv(r'normal\6\program\normal-6_382-492_Results.csv')
normal_7_5 = pd.read_csv(r'normal\7.5\program\normal-7.5_382-492_Results.csv')
normal_9 = pd.read_csv(r'normal\9\program\normal-9_382-492_Results.csv')
normal_15 = pd.read_csv(r'normal\15\program\normal-15_382-492_Results.csv')
normal_all = pd.read_csv(r'normal\normal.csv')
normal_regulating = pd.read_csv(r'normal\self-regulating\update\normal-self-regulating_382-492_Results.csv')

slotted_zero_load = pd.read_csv(r'slotted\zero_load\slotted-zero_load_382-492_Results.csv')
slotted_0 = pd.read_csv(r'slotted\0\slotted-0_Steady_State_Results.csv')
slotted_1_5 = pd.read_csv(r'slotted\1.5\slotted-1.5_Steady_State_Results.csv')
slotted_4_5 = pd.read_csv(r'slotted\4.5\program\slotted-4.5_382-492_Results.csv')
slotted_6 = pd.read_csv(r'slotted\6\program\slotted-6_382-492_Results.csv')
slotted_7_5 = pd.read_csv(r'slotted\7.5\program\slotted-7.5_382-492_Results.csv')
slotted_9 = pd.read_csv(r'slotted\9\program\slotted-9_382-492_Results.csv')
slotted_15 = pd.read_csv(r'slotted\15\slotted-15_Steady_State_Results.csv')
slotted_all = pd.read_csv(r'slotted\slotted.csv')
slotted_regulating = pd.read_csv(r'slotted\self-regulating\slotted-self-regulating_Steady_State_Results.csv')

# 2. 獲取數據
# 因為第一列已經變成標題，真實數據從 index 0 開始，不需要再切片 [1:12] 了！
# 使用 .iloc[:, 0] 抓取第 0 欄 (轉速)，.iloc[:, 3] 抓取第 3 欄 (平均扭矩)
w_range = normal_0.iloc[:, 0]

# print(normal_regulating.iloc[:, 5])
plt.figure(figsize=(8, 6))

# 3. 繪製散佈圖
number = 'all' # 這裡可以改成你想要的重疊長度，例如 0, 1.5, 7.5, 9, 15, 'all', 'regulating'
match number:
    case 'zero_load':
        plt.scatter(w_range, normal_zero_load.iloc[:, 3], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_zero_load.iloc[:, 3], marker='^', label='Slotted', color='orange')
    case 0:
        plt.scatter(w_range, normal_0.iloc[:, 3] - normal_zero_load.iloc[:, 3], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_0.iloc[:, 3] - slotted_zero_load.iloc[:, 3], marker='^', label='Slotted', color='orange')
    case 1.5:
        plt.scatter(w_range, normal_1_5.iloc[:, 3] - normal_zero_load.iloc[:, 3], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_1_5.iloc[:, 3] - slotted_zero_load.iloc[:, 3], marker='^', label='Slotted', color='orange')
    case 4.5:
        plt.scatter(w_range, normal_4_5.iloc[:, 3] - normal_zero_load.iloc[:, 3], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_4_5.iloc[:, 3] - slotted_zero_load.iloc[:, 3], marker='^', label='Slotted', color='orange')
    case 6:
        plt.scatter(w_range, normal_6.iloc[:, 3] - normal_zero_load.iloc[:, 3], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_6.iloc[:, 3] - slotted_zero_load.iloc[:, 3], marker='^', label='Slotted', color='orange')
    case 7.5:
        plt.scatter(w_range, normal_7_5.iloc[:, 3] - normal_zero_load.iloc[:, 3], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_7_5.iloc[:, 3] - slotted_zero_load.iloc[:, 3], marker='^', label='Slotted', color='orange')
    case 9:
        plt.scatter(w_range, normal_9.iloc[:, 3] - normal_zero_load.iloc[:, 3], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_9.iloc[:, 3] - slotted_zero_load.iloc[:, 3], marker='^', label='Slotted', color='orange')
    case 15:
        plt.scatter(w_range, normal_15.iloc[:, 3] - normal_zero_load.iloc[:, 3], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_15.iloc[:, 3] - slotted_zero_load.iloc[:, 3], marker='^', label='Slotted', color='orange')
    case 'all':
        plt.scatter(w_range, normal_all.iloc[:, 2] - normal_zero_load.iloc[:, 2], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_all.iloc[:, 2] - slotted_zero_load.iloc[:, 2], marker='^', label='Slotted', color='orange')
    case 'regulating':
        # plt.scatter(w_range, normal_regulating.iloc[:, 3] - normal_zero_load.iloc[:, 3], marker='o', label='Normal', color='blue')
        # plt.scatter(w_range, slotted_regulating.iloc[:, 3] - slotted_zero_load.iloc[:, 3], marker='^', label='Slotted', color='orange')
        plt.scatter(w_range, normal_regulating.iloc[:, 5], marker='o', label='Normal', color='blue')
        plt.scatter(w_range, slotted_regulating.iloc[:, 5], marker='^', label='Slotted', color='orange')
    case _:
        print("無效的重疊長度，請選擇有效的數值。")

# plt.title(f'Zero Load Torque Comparison', fontdict={'family': 'Times New Roman', 'size': 18})
# plt.title(f'Torque Comparison for Overlap Length L = {number} mm', fontdict={'family': 'Times New Roman', 'size': 18})
plt.title('Torque Comparison for Defined Overlap Lengths', fontdict={'family': 'Times New Roman', 'size': 18})
# plt.title('Displacement Comparison with Self-Regulating Mechanism', fontdict={'family': 'Times New Roman', 'size': 18})

plt.xlabel('Speed (RPM)', fontdict={'family': 'Times New Roman', 'size': 16})
plt.ylabel('Displacement (mm)', fontdict={'family': 'Times New Roman', 'size': 16})
plt.tight_layout()

# (可選) 讓 Matplotlib 自動依據你的 Float 數據幫你抓 Y 軸刻度
# 如果你要自己設定，確保範圍涵蓋你圖表中的最大值，例如 np.arange(1.5, 4.5, 0.5)
# plt.yticks(np.arange(1.5, 3.0, 0.5)) 
plt.xticks(np.arange(382, 493, 11)) 

plt.grid(True, linestyle='--', alpha=0.6)
plt.legend()
plt.show()