function [T_total] = ECB_BrakingTorque(params, rpm, g_curr)
% AFPM_ECB_Analytical_Model：基於 Lubin & Rezzoug (2017) 的 3D 閉式解析解 (Eq. 49)

    %% 1. 參數提取與單位轉換
    mu0 = 4 * pi * 1e-7;
    R1 = params.r_av - params.l_m/2; % 磁鐵內徑 (m)
    R2 = params.r_av + params.l_m/2; % 磁鐵外徑 (m)
    R3 = params.r_yo;                % 導體盤半徑 (m) (邊界條件)
    t_m = params.t_m;                % t_m: 磁鐵厚度 (m)
    g = g_curr;                      % g: 氣隙長度 (m)
    t_c = params.t_c;                % t_c: 導體盤厚度 (m)
    p = params.p;                    % p: 極對數 (Pole pairs)
    Br = params.B_r;                 % Br: 磁鐵剩磁 (T)
    sigma = params.sigma;            % sigma: 導體盤電導率 (S/m)
    PM_ratio = params.PM_ratio;      % PM_ratio: 磁極覆蓋率 (Pole-arc to pole-pitch ratio, alpha)
    Omega = rpm * (2*pi/60); % rpm: 滑差轉速 (RPM), 換算 rad/s
    
    N = params.N_harm; % N_harm: 諧波次數 (奇數 n 的最大值, e.g., 20)
    K = params.K_bessel; % K_bessel: 貝索函數根的數量 (k 的最大值, e.g., 50)
    
    T_sum = 0; % 重置加總變數

    %% 迴圈計算 (對應文獻的雙重求和)
    % 外層迴圈 n (諧波級數)，只取奇數 1, 3, 5...
    for n = 1:2:N
        % 貝索函數的階數 order
        nu = n * p; 
        
        % 內部迴圈 k (貝索函數的根)
        for k = 1:K
            %% Step 1: 計算貝索函數的根 alpha_k
            % 我們需要解 J_nu(x) = 0，然後 alpha_k = x / R3
            % 使用自定義函數尋找第 k 個根
            x_nk = find_bessel_root(nu, k); 
            alpha_k = x_nk / R3;
            
            %% Step 2: 計算磁化係數 M_nk (Eq. 20)
            % 分母項
            J_next = besselj(nu + 1, x_nk); % J_{np+1}(alpha_k * R3)
            denom_Mnk = n * pi * mu0 * R3^2 * J_next^2;
            
            % 正弦項
            sin_term = sin(n * PM_ratio * pi / 2);
            
            % 積分項: int(r * J_nu(alpha_k * r), R1, R2)，為了程式穩健性，使用數值積分 (如果為了速度，可改用解析近似)
            integrand = @(r) r .* besselj(nu, alpha_k .* r);
            integral_val = integral(integrand, R1, R2);
            
            % 組合 M_nk
            Mnk = (8 * Br / denom_Mnk) * sin_term * integral_val;
            
            %% Step 3: 計算複數參數 gamma_k (Eq. 33)
            % 虛數單位 j
            j_imag = 1i; 
            % 注意：這裡的 sigma 是銅的電導率
            gamma_k = sqrt(alpha_k^2 + j_imag * n * p * sigma * mu0 * Omega);
            
            %% Step 4: 計算中間複數因子 r_bar (Eq. 49 下方定義，r_factor 表示文獻中的 "r bar")
            % 定義雙曲函數項以簡化程式碼
            sh_ac = sinh(alpha_k * g);
            ch_ac = cosh(alpha_k * g);
            sh_gd = sinh(gamma_k * t_c);
            ch_gd = cosh(gamma_k * t_c);
            
            sh_abc = sinh(alpha_k * (t_m + g)); % sinh(alpha_k * (b+c))
            ch_abc = cosh(alpha_k * (t_m + g)); % cosh(alpha_k * (b+c))
            
            ratio_g_a = gamma_k / alpha_k;
            
            num_r = sh_ac * ch_gd + ratio_g_a * ch_ac * sh_gd;
            den_r = sh_abc * ch_gd + ratio_g_a * ch_abc * sh_gd;
            
            r_factor = num_r / den_r;
            
            %% Step 5: 計算扭矩增量並累加 (Eq. 49)
            base_term = (Mnk^2 / alpha_k) * (J_next^2) * r_factor * sinh(alpha_k * t_m);
            
            % 公式 (49) 要求: Real{ j * n * base_term }
            % 這相當於: -n * imag(base_term)
            T_sum = T_sum + real(1i * n * base_term);
        end
    end
    
    % 最終係數乘積
    coeff = (pi / 2) * mu0 * R3^2 * p;
    T_total = coeff * T_sum;

end

%% 輔助函數：尋找貝索函數 J_nu(x) = 0 的第 k 個根
function x = find_bessel_root(nu, k)
    % 由於高階貝索函數求解較慢，這裡使用漸近公式作為初值
    % 無零點時使用 McMahon's expansion 近似初猜值
    % Root ~ beta - (4*nu^2-1)/(8*beta) ... where beta = (k + nu/2 - 0.25)*pi
    
    beta = (k + nu/2 - 0.25) * pi;
    guess = beta - (4*nu^2 - 1) / (8 * beta);
    
    % 如果 nu 很大且 k 很小，初值可能不準，設定下限
    if guess <= 0, guess = nu + 1; end 
    
    % 使用 fzero 尋找精確解
    % 定義匿名函數
    bessel_func = @(x) besselj(nu, x);
    
    try
        % 在猜測值附近尋找
        x = fzero(bessel_func, guess);
    catch
        % 如果 fzero 失敗（極少見），嘗試區間搜尋
        % 根通常間隔約 pi
        interval = [guess - 2, guess + 2];
        if interval(1) < 0, interval(1) = 0.1; end
        x = fzero(bessel_func, interval);
    end
end