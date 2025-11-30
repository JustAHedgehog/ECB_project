# ECB_project
The project for self-regulating eddy current brakes(ECB) with permanent magnets

## ECB_MATLAB
A_EXP_for_paper_use_AG3to12_V3.m	--繪製實驗與模擬的數值(氣隙3~12mm)
Design2_calculate_airgap.m 		--根據所需轉速與扭矩(ω_max, T_max, ω_min, T_min)，尋找該兩點所需的氣隙
Design2_for_paper_use.m			--計算磁制動扭矩(標註最大與最小值轉速與扭矩)
Design2_for_paper_useV2_255rpm.m	--計算磁制動扭矩(標註255rpm轉速與扭矩)
Design2_for_paper_useV2_573rpm.m	--計算磁制動扭矩(標註573rpm轉速與扭矩)
Design4_mag_force_calculate_V2.m	--計算軸向磁力使用
Design5_ECB_find_pole_pairs.m		--找較佳氣隙
Design5_ECB_find_pole_pairs_JJ.m	--找較佳氣隙(期刊用)
Design6_ECB_find_tm_JJ.m		--找較佳磁石厚度(期刊用)
Design6_ECB_find_tm_V2.m		--找較佳磁石厚度
Design7_ECB_find_tc_JJ.m		--找較佳導體厚度
Design7_ECB_find_tc_V2.m		--找較佳導體厚度
FINAL_TorqueAndForce.m			--計算扭矩與軸向磁力
MESH_versus.m				--不同設定下，模擬的不同結果
size_versus.m				--論文用的比較圖(有無加工特徵點)


========
要接哪個Step2，請看Step1的最後一行自行調整
========

### 系列一(執行Step1會接到Step2)--計算彈簧力、平衡轉速255至573rpm
Design8_PullyCenterForce_with_magnet_Step1_V3.m 
Design8_PullyCenterForce_with_magnet_Step2_V3.m;  --各別的，要另外分(出)還是(回)，摩擦力+線性彈簧影響
Design8_PullyCenterForce_with_magnet_Step2_V4.m;  --合併的圖，可選則開關箭頭(考慮摩擦力與彈簧並聯)
Design8_PullyCenterForce_with_magnet_Step2_V5.m;  --單純加入摩擦力，可選則開關箭頭
Design8_PullyCenterForce_with_magnet_Step2_V6.m;  --各別的，要另外分(出)還是(回)，僅摩擦力影響
simulation_expmodel.m

### 系列二(執行Step1會接到Step2)--計算彈簧力、平衡轉速350至700rpm
Design8_PullyCenterForce_with_magnet_Step1_V3_change_v.m 
Design8_PullyCenterForce_with_magnet_Step2_V4_change_v.m;  --合併的圖，可選則開關箭頭(考慮摩擦力與彈簧並聯)
Design8_PullyCenterForce_with_magnet_Step2_V6_change_v.m;  --各別的，要另外分(出)還是(回)，僅摩擦力影響
simulation_expmodel_change_v.m

### 系列三					--問題定義用示意圖
JJproblem_statement.m
JJproblem_statement2.m
JJproblem_statement4.m
JJproblem_statement5.m
JJproblem_statement6.m
JJproblem_statement7.m
JJproblem_statement8.m
JJproblem_statement9.m

### 系列四--拿來寫動態方程式用的，但是目前轉速是固定方程式的
main1.m					--主程式
main2.m					--讀取幾何參數數值
main3.m					--計算軸向磁力 需要有氣隙、轉速
main4.m					--計算離心力 需要有氣隙、轉速，檔案中包含所需之參數數值
main5.m					--計算彈簧力 需要有氣隙，檔案中包含所需之參數數值

### 系列五--參數的數值資料
myModel_type15.m
myModel_type16.m
simulation_data.m
simulation_expmodel.m
simulation_expmodel_change_v.m
simulation_type10.m
simulation_type11.m
simulation_type9.m
TheorySimu_Type.m