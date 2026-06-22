-- Helper Function: Tính doanh thu dịch vụ phát sinh của chi nhánh trong một tháng/năm nhất định
-- Đầu vào:
--   p_id_cn: Mã chi nhánh
--   p_thang: Tháng
--   p_nam: Năm
-- Trả về: MONEY (Tổng doanh thu dịch vụ đã thanh toán)

CREATE OR REPLACE FUNCTION quanly.func_tinh_doanh_thu_dich_vu_chi_nhanh(
    p_id_cn INT,
    p_thang INT,
    p_nam INT
)
RETURNS MONEY AS $$
DECLARE
    v_tien_dv MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tien_dv
    FROM hoadon h
    JOIN hoadon_sudung_dichvu hsd ON h.id_hd = hsd.id_hd
    JOIN dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE EXISTS (
        SELECT 1 FROM hoadon_thue_phong htp
        JOIN phong p ON htp.id_p = p.id_p
        JOIN loaiphong lp ON p.id_lp = lp.id_lp
        WHERE htp.id_hd = h.id_hd AND lp.id_cn = p_id_cn
    )
    AND h.trang_thai = 'Đã thanh toán'
    AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
    AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

    RETURN v_tien_dv;
END;
$$ LANGUAGE plpgsql;
