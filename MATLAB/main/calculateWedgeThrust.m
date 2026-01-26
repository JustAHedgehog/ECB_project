function [F_wedge, r_omega] = calculateWedgeThrust(omega_rpm, g_curr, g_ini, mech, direction)
    % direction: 'up' 為上升段 (Engagement), 'down' 為下降段 (Disengagement)
    density = 7840;
    omega_rad = omega_rpm * (pi / 30);
    m_r = pi * mech(1)^2 * mech(2) * density;
    alpha_rad = deg2rad(mech(4));
    
    x = max(0, g_ini - g_curr); % 確保行程不為負
    r_omega = mech(1) + x * tan(alpha_rad);
    
    % 根據方向設定正負號切換
    if strcmpi(direction, 'up')
        s = 1; % 上升段：分子用 -, 分母用 +
    else
        s = -1; % 下降段：分子用 +, 分母用 -
    end
    
    % 簡潔的統一公式
    % 分子: ... (cos(a) - s * mu_w * sin(a))
    num = m_r .* (omega_rad.^2) .* r_omega .* (cos(alpha_rad) - s * mech(5) * sin(alpha_rad));
    
    % 分母: ... sin(a) + s * (mu_w + mu_t) * cos(a)
    den = (1 - mech(5) * mech(6)) * sin(alpha_rad) + s * (mech(5) + mech(6)) * cos(alpha_rad);
    
    F_wedge = mech(3) * (num ./ den);
end