-- Function: Tính tổng tiền các dịch vụ đã sử dụng trong hóa đơn
-- Đầu vào: p_id_hd (Mã hóa đơn)
-- Trả về: MONEY (Tổng tiền dịch vụ)

CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_dich_vu(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_tien_dv MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tong_tien_dv
    FROM hoadon.hoadon_sudung_dichvu hsd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE hsd.id_hd = p_id_hd;
    
    RETURN v_tong_tien_dv;
END;
$$ LANGUAGE plpgsql;
