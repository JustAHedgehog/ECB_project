classdef MagnetModel16
    properties
        mu_0       % 真空磁導率 (H·m^-1)
        mu_y       % 背鐵相對磁導率
        r_yo       % 背鐵外徑 (m)
        r_yi       % 背鐵內徑 (m)
        t_y        % 背鐵厚度 (m)
        sigma      % 導體電導率 (S/m)
        mu_c       % 導體磁導率 (H/m)TODO
        t_c        % 導體厚度 (m)
        r_co       % 導體外徑 (m)
        r_ci       % 導體內徑 (m)
        H_c        % 矯頑力 (A/m)
        B_r        % 剩磁 (T)
        mu_r       % 磁石相對磁導率
        l_m        % 磁石軸向長度 (m)
        r_av       % 磁石安裝半徑 (m)
        PM_ratio   % 磁石佔極距的比例
        t_m        % 磁石厚度 (m)
    end

    methods
        % 建構子 (Constructor)
        function obj = MagnetModel16()
            % 真空磁導率
            obj.mu_0 = 4 * pi * 10^-7; % H·m^-1

            % yoke
            obj.mu_y = 4000;
            obj.r_yo = 110 * 10^-3;
                % obj.r_yo = 0.100583024;
            obj.r_yi = 60 * 10^-3;
                % obj.r_yi = 0.025750199;
            obj.t_y  = 5 * 10^-3;
                % obj.t_y  = 0.004944504;

            % conductor
            sigma_Al = 38 * 10^6;         % 純鋁Al  電導率bulk conductivity(S/m)
            % sigma_Al6061= 24.9*10^6;    % 鋁合金Al6061
            % sigma_Cu= 59.5*10^6;        % Cu
            obj.sigma = sigma_Al;
                % obj.sigma = 54290159.76;

            obj.mu_c = 1.257 * 10^-6;   % Al  磁導率 permeability (H/m)
            obj.r_co = obj.r_yo;
            obj.r_ci = obj.r_yi;
            obj.t_c = 2 * 10^-3;
                % obj.t_c = 0.002424;

            % magnet
            obj.H_c = 907 * 10^3; % N40, 矯頑力Hc (A/m)
                % obj.H_c = 900118.4168; % N40, 矯頑力Hc (A/m)
            % B_r_N35 = 1.22; % N35
            % B_r_N38 = 1.26; % N38
            obj.B_r = 1.29; % N40, 剩磁Br (T)
                % obj.B_r = 1.1973481341035; % N40, 剩磁Br (T)
            obj.mu_r = obj.B_r / obj.H_c / obj.mu_0; % 磁石相對磁導率
            obj.l_m = 20 * 10^-3; % m
                % obj.l_m = 0.073526559; % m
            obj.r_av = (170 / 2) * 10^-3; % % 磁石安裝半徑 (m)
                % obj.r_av = 0.063166612; % % 磁石安裝半徑 (m)
            obj.PM_ratio = 0.7;
                % obj.PM_ratio = 0.651440578;
            obj.t_m = 5 * 10^-3; % m
                % obj.t_m = 0.00515709; % m
        end
    end
end