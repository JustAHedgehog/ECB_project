% myModel_type16
% 導體 2.5mm 改 2mm
% 背鐵 10mm 改 5mm
% 磁石厚度 5mm



%% 磁石安裝半徑
r_av = 170 / 2; % mm
r_av = r_av * (10^-3); % m

%% 真空磁導率
mu_0 = 4*pi*10^-7; % constant (H·m^-1) (T·m/A)

%% yoke
mu_y = 4000;
r_yo = 110; % mm
r_yo = r_yo*(10^-3); % m
r_yi = 60; % mm
r_yi = r_yi*(10^-3); % m
% t_y = 10; % mm
t_y = 5; % mm
t_y = t_y*(10^-3); % m

%% conductor
% sigma_Al= 37.8*10^6;      %   Al  電導率bulk conductivity(S/m)=(mho/m)=(ohm^-1 m^-1)
sigma_Al = 38*10^6;          %   純鋁Al  電導率bulk conductivity(S/m)=(mho/m)=(ohm^-1 m^-1)
sigma_Al6061 = 24.9*10^6;    %   鋁合金Al6061  電導率bulk conductivity(S/m)=(mho/m)=(ohm^-1 m^-1)
sigma_Cu = 59.5*10^6;        %   Cu  電導率bulk conductivity(S/m)=(mho/m)=(ohm^-1 m^-1)

sigma = sigma_Al;

mu_c_Al = 1.257*10^-6;   %   Al  磁導率 permeability (H/m)
mu_c = mu_c_Al;

t_c = 2; % mm
t_c = t_c* (10^-3); % m
    
r_co = r_yo;
r_ci = r_yi;
    

%% magnet 
H_c= 907 *10^3; %  N40     %矯頑力Hc   magnetic coercivity(A/m)

B_r_N35 = 1.22; %  N35     %剩磁Br     Remanence(T)
B_r_N38 = 1.26; %  N38     %剩磁Br     Remanence(T)
B_r_N40 = 1.29; %  N40     %剩磁Br     Remanence(T)
B_r = B_r_N40;

mu_r = B_r/H_c/mu_0;       % 磁導率     magnetic permeability

l_m = 20; % mm
l_m = l_m *(10^-3); % m

PM_ratio = 0.7;
% w_m = 40;
% w_m = w_m *(10^-3); % m

t_m = 5; % mm
t_m = t_m *(10^-3); % m