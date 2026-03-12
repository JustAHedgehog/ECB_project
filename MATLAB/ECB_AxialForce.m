function Fz = ECB_AxialForce(speed_rpm, c_gap)
    % =========================================================
    % 軸向永磁渦電流制動器 (AFPM-ECB) 軸向力解析計算
    % 參考文獻：3-D Analytical Model for Axial-Flux Eddy-Current Couplings...
    % =========================================================

    %% 0. 定義基本物理量與幾何參數 (參照 Table I)
    mu0 = 4 * pi * 1e-7;   % 真空磁導率 (H/m)
    
    % 幾何尺寸 (將 mm 轉換為 m)
    R1 = 30e-3;            % 磁鐵內徑
    R2 = 60e-3;            % 磁鐵外徑
    R0 = 15e-3;            % 銅盤內徑
    R3 = 75e-3;            % 銅盤外徑
    b = 10e-3;             % 磁鐵厚度
    c = c_gap;             % 氣隙厚度 (可變數, 例如 3e-3)
    d = 5e-3;              % 銅盤厚度
    
    alpha_p = 0.9;         % 極弧係數 (Pole-arc to pole-pitch ratio)
    p = 5;                 % 極對數
    Br = 1.25;             % 剩磁 (T)
    sigma = 57e6;          % 銅導電率 (S/m)
    
    % 展開諧波項數 (Table I 建議為 10)
    N_harmonics = 10;
    K_harmonics = 10;
    
    %% 衍生參數計算
    Rm = (R1 + R2) / 2;    % 平均半徑
    L = R2 - R1;           % 磁鐵徑向長度
    H = R3 - R0;           % 銅盤徑向長度
    tau = Rm * pi / p;     % 極距
    
    % 將轉速轉換為線速度 Vx (m/s)
    Omega = speed_rpm * (2 * pi / 60); % 機械角速度 (rad/s)
    Vx = Omega * Rm;                   % 導體盤在平均半徑的線速度

    %% 核心計算迴圈
    Summation_Term = 0; % 初始化雙重迴圈的總和
    
    % 步驟 4: 雙層迴圈 (確保 n 與 k 皆為奇數)
    for n_idx = 1:N_harmonics
        n = 2 * n_idx - 1;  % 產生奇數 1, 3, 5...
        
        for k_idx = 1:K_harmonics
            k = 2 * k_idx - 1; % 產生奇數 1, 3, 5...
            
            % --- 步驟 1：計算空間頻率係數 α_nk 與 γ_nk (公式 16, 27) ---
            alpha_nk = sqrt((n * pi / H)^2 + (k * pi / tau)^2);
            
            % 注意 γ_nk 內部含有虛數 1i
            gamma_nk = sqrt((n * pi / H)^2 + (k * pi / tau)^2 + 1i * sigma * mu0 * Vx * (k * pi / tau));
            
            % --- 步驟 2：計算磁化展開係數 M_nk (公式 19) ---
            % 注意：推導常數項為 16 * Br / (pi^2 * mu0 * n * k)
            M_nk = (16 * Br) / (pi^2 * mu0 * n * k) * sin(k * alpha_p * pi / 2) * sin(n * (pi/2) * (L / H));
            
            % --- 步驟 3：計算核心複數參數 r_bar (附錄 A.3, A.4) ---
            chi_nk = alpha_nk / gamma_nk;
            
            num_r = cosh(alpha_nk * c) * sinh(gamma_nk * d) + chi_nk * sinh(alpha_nk * c) * cosh(gamma_nk * d);
            den_r = cosh(alpha_nk * (b + c)) * sinh(gamma_nk * d) + chi_nk * sinh(alpha_nk * (b + c)) * cosh(gamma_nk * d);
            r_bar = - (num_r / den_r);
            
            % 提取共軛複數與絕對值平方
            r_bar_conj = conj(r_bar); 
            r_abs_sq = abs(r_bar)^2; % 即論文公式(41)中的 r^2
            
            % --- 步驟 4-2：計算單項加總 (公式 41 中括號內的項) ---
            % Term = M_nk^2 * (1 + |r|^2 + (r + r*) * cosh(alpha_nk * b))
            term = M_nk^2 * (1 + r_abs_sq + (r_bar + r_bar_conj) * cosh(alpha_nk * b));
            
            Summation_Term = Summation_Term + term;
        end
    end
    
    %% 最終軸向力 F_z 計算 (公式 41)
    % 注意：由於取絕對值及共軛相加，Summation_Term 理論上會消除虛部，為確保安全只取實部
    Fz = 0.25 * mu0 * p * tau * H * real(Summation_Term); 
end