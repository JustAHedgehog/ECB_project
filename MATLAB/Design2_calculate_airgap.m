%%  Design2_calculate_airgap_with_determined_geometric_dimensions
clc;clear;close all;

%%  理論模型最佳化 導體 2.5mm 背鐵 10mm 磁石厚度4mm k_russel=method4_V2
% myModel_type9;
% simulation_type9;% 未做
% experiment_type9;% 未做

% 理論模型最佳化，根據結果將 myModel_type16.m 的參數帶入
type = 16;

if (type == 15)
    myModel_type15; % 考慮標準品
elseif(type == 16)
    model = MagnetModel16(); % 執行 myModel_type16.m 檔案中的所有內容
    r_av = model.r_av;
    mu_0 = model.mu_0;
    mu_y = model.mu_y;
    r_yo = model.r_yo;
    r_yi = model.r_yi;
    t_y = model.t_y;
    sigma = model.sigma;
    t_c = model.t_c;
    r_co = model.r_co;
    r_ci = model.r_ci;
    H_c = model.H_c;
    B_r = model.B_r;
    mu_r = model.mu_r;
    l_m = model.l_m;
    PM_ratio = model.PM_ratio;
    t_m = model.t_m;
end


%%  選擇數據資料
nodata = [0,0,0,0,0,0,0,0,0,0,0];
%------------------------------@要更改vv-----------------------------------%
% T_sim = T_sim_type1_AG2_p5;
% T_exp = T_exp_type1_AG3_p9;
T_sim = nodata;
T_exp = nodata;
%------------------------------@要更改^^-----------------------------------%


%%  氣隙 AG air gap & 磁極對 p pole pair-----------------------------------%% 
%--------------------------@要更改vv---------------------------------------% 
p = 5; % 磁極對數

% 設計目標       rpm    Nm
design2match = [255.6, 1.833;
                573.0, 18.39];

tolerance = 0.02; %   1%  2% 

aaa = 0;
%--------------------------@要更改^^---------------------------------------% 
match = 1; % 符合第一設計目標點（低轉處）

AG_initial = 200; % 初始氣隙為 200 mm
g = AG_initial * (10^-3); % 轉換單位：m 

theta_p = pi/p; % 極距角 rad
theta_p_deg = theta_p * (180/pi); % 轉換單位：deg

tau_p = r_av * theta_p;

if (type == 15)
    PM_ratio = w_m/tau_p; % 方形磁石標準品回推 PM ratio
elseif(type == 16)
    w_m = PM_ratio * tau_p; % 有 PM ratio 下計算磁石寬度
end

theta_mag = w_m/ r_av; % 磁石所佔的角度(rad)
H = ((r_yo-(r_av+l_m/2))+(r_av-l_m/2)-r_yi)/2; % 外懸長度(if 內外側數值不一致)

%%  開始找氣隙
while true
    if(match == 1)
        rpm = design2match(1,1);
        Nm =  design2match(1,2);
    elseif(match ==2)
        rpm = design2match(2,1);
        Nm =  design2match(2,2);
    end

    omega = rpm / 60 * 2 * pi; % rpm to rad/s

    %%  磁阻參數計算 ----------------------------------------------------------%% 
    A_m = l_m * w_m; % Area of magnet
    R_g = (g+t_c)/(mu_0 * A_m); % TODO 單側雙側不同
    R_m = t_m/(mu_0 * mu_r * A_m);
    P_y = mu_0 * mu_y * t_y/theta_p * log(r_yo/r_yi);
    R_y = P_y^-1;
    
    % R_mm
    criteria_1 = g + t_c;
    criteria_2 = w_m / 2;
    mm = min(criteria_1, criteria_2);
    P_mm = mu_0 * l_m / pi * log(1 + pi * mm / (tau_p * (1 - PM_ratio))); %% 單側雙側不同；在 MATLAB 中，自然對數 ln(x) 用 log(x) 表示
    R_mm = P_mm^-1;
    
    % R_ms
    ms1 = min(w_m/2,(1-PM_ratio) * tau_p/2);
    layer2 = min(g+t_c,ms1);
    
    ms2 = min(H,l_m/2);
    layer3 = min(g+t_c,ms2);
    
    P_1 = mu_0 * l_m/pi * log(pi*layer2/t_m+1);
    P_2 = mu_0 * w_m/pi * log(pi*layer3/t_m+1);
    P_ms = P_1 + P_2;
    R_ms = P_ms^(-1);
    
    % flux_mag  = mu_0 * mu_r * H_c * A_m;
    F_m = H_c * t_m;
    flux_g9 = 4 * R_ms * R_mm * F_m / ...
    (R_mm*(4*R_g+R_y)*(2*R_m+R_ms)+(4*R_m*R_ms+R_y*(2*R_m+R_ms))*(4*R_g+R_y+R_mm));
    
    flux_g = flux_g9;
    B_m = flux_g/A_m; % magnetic flux density
    
    %%  Design1 with 3D correction with my test --------------------------%% 
    S = mu_0 * t_c * sigma * r_av^2. * omega / (2 * (g+t_c+t_m));
    C = cosh(S*(1-PM_ratio).*theta_p/2)./cosh(S*theta_p/2);%  C = exp(-S * theta_0)
    
    T_theory = l_m.*t_c.*sigma.*r_av.^3.*omega.*B_m.^2.*(2.*p)./(2*S).*( ...
    2*C.^2.*sinh(S*PM_ratio*theta_p) ...
     + (C-exp(S*PM_ratio*theta_p/2)).^2.*(exp(-S*PM_ratio*theta_p)-exp(-S*theta_p)) ...
     + (C-exp(-S*PM_ratio*theta_p/2)).^2.*(exp(S*theta_p)-exp(S*PM_ratio*theta_p)));
        
    %%  3D correction ----------------------------------------------------%% 
    %% method 1 軸向IEEE 雙邊磁石(因為雙側磁石改為單側磁石，原本的p改為2p?先沒改)
    % Design optimization of double-sided permanent-Magnet Axial Eddy-Current
    % Couplers for Use in Dynamic Application-IEEE2019
    Beta = (p)/r_av; % Beta = p/r_av 一圈磁石有: 雙側p個(p對) 單側2p個(p對)，所以p改為2p?
    lamda = 2 * H/l_m;
    k_russel_method1 = 1-((2/l_m/Beta * tanh(l_m*Beta/2))/(1+tanh(l_m*Beta/2)*tanh(lamda*l_m*Beta/2)));

    k_russel = k_russel_method1;
    T_theory = T_theory.*k_russel;

    %% 找到符合的氣隙，跳出
    if(abs((Nm-T_theory)/Nm) < tolerance)
        aaa = aaa + 1; 
        T(aaa,1) = g * 1000;% mm
        T(aaa,2) = T_theory;
        
        if(aaa == 1)
            disp('done1');
            match = aaa + 1;% 下個match
            % 找第二點的氣隙
            g = AG_initial;% 初始化
                g = g * (10^-3);% m
        
        elseif(aaa == 2)
            T(aaa,1) = g * 1000;% mm
            T(aaa,2) = T_theory;
            disp('done2');
            break;
        end

    elseif(g<0)
        disp('failed');
        break;
    end

    g = g-0.1 * (10^-3);% 更新氣隙

end

if(g > 0)
    txt = ['To match the design target: with tolerance ' num2str(tolerance*100) ' % '...
        newline 'Air Gap: ' num2str(T(1,1)) '(mm), ' 'Angular Velocity: ' num2str(design2match(1,1)) ' (rpm), ' 'Torque: ' num2str(T(1,2)) '(N-m)'...
        ', Error is: ' num2str((design2match(1,2)-T(1,2))/design2match(1,2)*100) ' % ' ...
        newline 'Air Gap: ' num2str(T(2,1)) '(mm), ' 'Angular Velocity: ' num2str(design2match(2,1)) ' (rpm), ' 'Torque: ' num2str(T(2,2)) '(N-m)'...
        ', Error is: ' num2str((design2match(2,2)-T(2,2))/design2match(2,2)*100) ' % '...
        ];
    
    disp(txt);
end

%%  顯示目前參數數值
disp(' ');
disp(['導體尺寸(mm): ' 'r_co = ' num2str(r_co*1000) ', ' 'r_ci = ' num2str(r_ci*1000) ', ' 't_c = ' num2str(t_c*1000)]);
disp(['背鐵尺寸(mm): ' 'r_yo = ' num2str(r_yo*1000) ', ' 'r_yi = ' num2str(r_yi*1000) ', ' 't_y = ' num2str(t_y*1000)]);
disp(['磁石安裝半徑 r_av(mm): ' num2str(r_av*1000)]);
disp(['磁石比例 PM_ratio: ' num2str(PM_ratio)]);
disp(['磁石尺寸(mm): ' 'l_m = ' num2str(l_m*1000) ', ' 'w_m = ' num2str(w_m*1000) ', ' 't_m = ' num2str(t_m*1000)]);
disp(['氣隙 g(mm):' num2str(g*1000) '       極對數 p:' num2str(p)]);
disp(['外懸長度 H(mm):' num2str(H*1000)]);


