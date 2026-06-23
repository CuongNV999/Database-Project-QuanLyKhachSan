-- Function: Tính số tiền thực tế khách cần trả sau tại quầy (Tổng chi phí - Tiền cọc)
-- Đầu vào: p_id_hd (Mã hóa đơn)
-- Trả về: MONEY (Số tiền trả sau thực tế)

CREATE OR REPLACE FUNCTION hoadon.func_tinh_so_tien_tra_sau(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_chi_phi MONEY := 0::money;
    v_tien_coc MONEY := 0::money;
    v_tra_sau MONEY := 0::money;
BEGIN
    v_tong_chi_phi := hoadon.func_tinh_tong_chi_phi(p_id_hd);
    v_tien_coc := hoadon.func_tinh_tien_coc(p_id_hd);
    
    v_tra_sau := v_tong_chi_phi - v_tien_coc;
    
    IF v_tra_sau < 0::money THEN
        v_tra_sau := 0::money;
    END IF;

    RETURN v_tra_sau;
END;
$$ LANGUAGE plpgsql;
