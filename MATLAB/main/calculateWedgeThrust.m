function [F_wedge, r_omega] = calculateWedgeThrust(omega_rpm, g_curr, g_ini, mech, direction)
    % direction: 'up' 為上升段 (Engagement), 'down' 為下降段 (Disengagement)
    
    omega_rad = omega_rpm * (pi / 30);
    m_r = pi * mech.radius_r^2 * mech.L_r * mech.density;
    alpha_rad = deg2rad(mech.alpha);
    
    x = max(0, g_ini - g_curr); % 確保行程不為負
    r_omega = mech.radius_r + x * tan(alpha_rad);
    
    % 根據方向設定正負號切換
    if strcmpi(direction, 'up')
        s = 1; % 上升段：分子用 -, 分母用 +
    else
        s = -1; % 下降段：分子用 +, 分母用 -
    end
    
    % 簡潔的統一公式
    % 分子: ... (cos(a) - s * mu_w * sin(a))
    num = m_r .* (omega_rad.^2) .* r_omega .* (cos(alpha_rad) - s * mech.mu_wedge * sin(alpha_rad));
    
    % 分母: ... sin(a) + s * (mu_w + mu_t) * cos(a)
    den = (1 - mech.mu_wedge * mech.mu_t) * sin(alpha_rad) + s * (mech.mu_wedge + mech.mu_t) * cos(alpha_rad);
    
    F_wedge = mech.N * (num ./ den);
end