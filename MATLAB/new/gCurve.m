function g = gCurve(w, w_start, w_end, g_start, g_end, n)
    % 正規化轉速 (0 ~ 1)
    if w_end == w_start
        ratio = 0; % 避免除以零
    else
        ratio = (w - w_start) / (w_end - w_start);
    end
    
    % 確保 ratio 在 0~1 之間
    ratio = max(0, min(1, ratio));
    % 冪次插值: g 隨 w 增加而減少 (g_start -> g_end)
    % Formula: g = g_start - (g_start - g_end) * ratio^n
    g = g_start - (g_start - g_end) .* (ratio .^ n);
end