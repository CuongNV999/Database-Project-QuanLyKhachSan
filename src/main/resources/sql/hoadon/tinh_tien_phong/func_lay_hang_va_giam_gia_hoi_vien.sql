-- Helper Function: Lấy hạng hội viên và % giảm giá của khách hàng trong hóa đơn
-- Đầu vào: p_id_hd (Mã hóa đơn)
-- Trả về: hang_hv (Hạng hội viên: Basic, Bronze, Silver, Gold hoặc ''), giam_gia_percent (Phần trăm giảm giá)

CREATE OR REPLACE FUNCTION hoadon.func_lay_hang_va_giam_gia_hoi_vien(
    p_id_hd INT,
    OUT o_hang_hv VARCHAR,
    OUT o_giam_gia_percent NUMERIC
) AS $$
BEGIN
    SELECT COALESCE(mhv.hang, ''), COALESCE(mhv.muc_giam_gia, 0.00)
    INTO o_hang_hv, o_giam_gia_percent
    FROM hoadon.hoadon h
    JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
    LEFT JOIN khachhang.hoivien hv ON kh.id_hv = hv.id_hv
    LEFT JOIN khachhang.muchoivien mhv ON hv.id_mhv = mhv.id_mhv
    WHERE h.id_hd = p_id_hd;

    o_hang_hv := COALESCE(o_hang_hv, '');
    o_giam_gia_percent := COALESCE(o_giam_gia_percent, 0.00);
END;
$$ LANGUAGE plpgsql;
