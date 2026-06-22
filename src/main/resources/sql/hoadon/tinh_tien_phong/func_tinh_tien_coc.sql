-- Function: Tính tổng tiền cọc phòng dự kiến (50% của tổng ngày lưu trú * giá phòng)
-- Đầu vào: p_id_hd (Mã hóa đơn)
-- Trả về: MONEY (Tổng tiền cọc)

CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_coc(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tien_coc MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(htp.so_ngay_luu_tru * lp.gia_tien * 0.5), 0::money)
    INTO v_tien_coc
    FROM hoadon.hoadon_thue_phong htp
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE htp.id_hd = p_id_hd;
    
    RETURN v_tien_coc;
END;
$$ LANGUAGE plpgsql;
