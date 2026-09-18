import pandas as pd
import matplotlib.pyplot as plt

# 1. 讀取你手動修正過的最終結果檔
exp_id = 7.5  # 實驗組別 (請依據實際情況修改)
exp_type = 'normal'  # 實驗類型 (normal 或 slotted)
df = pd.read_csv(f'{exp_type}/{exp_id}/{exp_type}-{exp_id}_Steady_State_Results.csv')

# 提取 X 軸數據與對應的誤差 (使用實際測得的平均轉速與標準差)
x = df['Avg_Speed_mean']
x_err = df['Avg_Speed_std']

# ==========================================
# 圖表一：轉速 vs. 扭矩 (Speed vs. Torque)
# ==========================================
plt.figure(figsize=(8, 5), dpi=120)

# 使用 errorbar 繪製帶有誤差線的折線圖
# yerr 帶入扭矩標準差，xerr 帶入轉速標準差
plt.errorbar(x, df['Avg_Torque_mean'], 
             xerr=x_err, yerr=df['Avg_Torque_std'],
             fmt='o', color='tab:orange', ecolor='red', capsize=5, 
             linewidth=2, label='Torque (Mean ± STD)')

plt.xlabel('Average Speed (RPM)', fontsize=12, fontweight='bold')
plt.ylabel('Torque (Nm)', fontsize=12, fontweight='bold')
plt.title('Speed vs. Torque Characteristics', fontsize=14, fontweight='bold')
plt.grid(True, linestyle='--', alpha=0.6)
plt.legend(loc='upper left')
plt.tight_layout()

# 存檔與顯示
plt.savefig(f'{exp_type}/{exp_id}/{exp_type}-{exp_id}_Speed_vs_Torque.png')
plt.show()

# ==========================================
# 圖表二：轉速 vs. 位置 (Speed vs. Position)
# ==========================================
plt.figure(figsize=(8, 5), dpi=120)

# 使用 errorbar 繪製帶有誤差線的折線圖
# yerr 帶入位置標準差
plt.errorbar(x, df['Avg_Displacement_mean'], 
             xerr=x_err, yerr=df['Avg_Displacement_std'],
             fmt='s', color='tab:blue', ecolor='black', capsize=5, 
             linewidth=2, label='Displacement (Mean ± STD)')

plt.xlabel('Average Speed (RPM)', fontsize=12, fontweight='bold')
plt.ylabel('Displacement (mm)', fontsize=12, fontweight='bold')
plt.title('Speed vs. Displacement Characteristics', fontsize=14, fontweight='bold')
plt.grid(True, linestyle='--', alpha=0.6)
plt.legend(loc='upper left')
plt.tight_layout()

# 存檔與顯示
plt.savefig(f'{exp_type}/{exp_id}/{exp_type}-{exp_id}_Speed_vs_Displacement.png')
plt.show()