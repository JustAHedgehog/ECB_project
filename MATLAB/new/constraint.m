function [c, ceq] = constraint(x, p, Target_End)
    [ECB, mech, traj] = xToParams(x, p);
    % 自鎖與物理檢查 (Den > 0) by 檢查最嚴苛點 (下降段, g_final)
    % 隨便帶入一個轉速，重點是 mech 的幾何與摩擦
    [~, info] = requiredForce(mech, ECB, Target_End(1), traj.g_final, traj.g_ini, 'down');
    
    c1 = 0.01 - info.den; % 要求 den > 0.01
    c2 = -info.Fw;        % 要求推力 > 0 (不可為負)
    
    % 幾何邊界
    % 檢查 r_omega 是否超過外徑
    c3 = info.r_omega - ECB.r_yo;
    c4 = 0.020 - (ECB.r_yo - ECB.r_yi); % 要求背鐵內外徑差異至少 20mm
    c = [c1; c2; c3; c4];
    ceq = [];
end