function p = xToMechParams(x, r_yi_fixed)
    % 將優化向量轉換為具名的物理參數結構體
    p.r_r   = x(1);
    p.L_r   = x(2);
    p.N     = round(x(3));
    p.alpha = x(4);
    p.mu_w  = x(5);
    p.mu_t  = x(6);
    
    % 固定參數也一起打包，方便後續計算
    p.r_yi  = r_yi_fixed;
    p.rho   = 7840;
end