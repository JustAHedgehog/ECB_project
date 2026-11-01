import pandas as pd
import os
import glob

def convert_legacy_to_new(tw_path, xw_path, output_path, sample_time_ms=40):
    """
    將舊版的橫式 t-w 與 x-w 檔案整合成新版標準直式 CSV
    """
    try:
        # 讀取舊版橫式檔案並轉置 (.T)
        df_tw = pd.read_csv(tw_path, header=None, sep='\t').T
        df_xw = pd.read_csv(xw_path, header=None, sep='\t').T
        
        # 建立全新的 DataFrame
        df_new = pd.DataFrame()
        
        # 根據舊版 40ms (0.04s) 的取樣率，自動生成時間軸 (秒)
        df_new['time(s)'] = df_tw.index * (sample_time_ms / 1000.0)
        
        # 將資料塞入對應的新版標題中
        df_new['speed(RPM)'] = df_tw[0]
        df_new['Torque(N-m)'] = df_tw[1]
        
        # 抓取 x-w 的 Row 1 作為位移資料
        df_new['Laser (mm) - Laser'] = df_xw[1]
        
        # 輸出為標準直式 CSV (避免中文路徑亂碼)
        df_new.to_csv(output_path, index=False, encoding='utf-8-sig')
        print(f"✅ 成功轉換: {os.path.basename(output_path)}")
        
    except Exception as e:
        print(f"❌ 轉換 {tw_path} 失敗: {e}")

def batch_convert_folder(folder_path, sample_time_ms=40):
    """
    批次處理資料夾內所有的 _t-w.csv 與 _x-w.csv
    """
    print(f"開始搜尋資料夾: {folder_path} ...")
    
    # 尋找資料夾內所有結尾是 _t-w.csv 的檔案
    tw_files = glob.glob(os.path.join(folder_path, '*_t-w.csv'))
    
    if not tw_files:
        print("找不到任何 _t-w.csv 檔案，請確認路徑是否正確。")
        return

    for tw_file in tw_files:
        # 自動推斷對應的 x-w 檔案路徑
        xw_file = tw_file.replace('_t-w.csv', '_x-w.csv')
        
        # 設定輸出檔名 (例如：1_modified.csv)
        out_file = tw_file.replace('_t-w.csv', '_modified.csv')
        
        if os.path.exists(xw_file):
            convert_legacy_to_new(tw_file, xw_file, out_file, sample_time_ms)
        else:
            print(f"⚠️ 找不到與 {os.path.basename(tw_file)} 搭配的 _x-w.csv，跳過轉換。")

# ==========================================
# 執行區塊
# ==========================================
if __name__ == "__main__":
    # 將 target_folder 替換成你存放舊資料的資料夾路徑
    # 支援相對路徑，例如 '.' 代表當前資料夾，或是 'not_to_commit/Exp/...'
    target_folder = r'not_to_commit\CSMMT\Exp_data\normal\zero_load' 
    
    # 執行批次轉換 (預設舊資料是 40ms，若有不同可修改數字)
    batch_convert_folder(target_folder, sample_time_ms=40)