-- Function: Tính tổng tiền cuối cùng của hóa đơn (Tiền phòng + Tiền dịch vụ - Giảm giá hội viên)
-- Trả về: MONEY

CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tien_phong MONEY := 0::money;
    v_tien_dich_vu MONEY := 0::money;
    v_giam_gia_percent NUMERIC(5,2) := 0.00;
    v_tong_tien MONEY := 0::money;
BEGIN
    -- 1. Tính tổng tiền thuê các phòng của hóa đơn
    SELECT COALESCE(SUM(tong_tien), 0::money)
    INTO v_tien_phong
    FROM hoadon.hoadon_thue_phong
    WHERE id_hd = p_id_hd;

    -- 2. Tính tổng tiền sử dụng dịch vụ của hóa đơn
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tien_dich_vu
    FROM hoadon.hoadon_sudung_dichvu hsd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE hsd.id_hd = p_id_hd;

    -- 3. Lấy mức giảm giá hội viên của khách hàng liên kết với hóa đơn (dùng LEFT JOIN đề phòng không phải hội viên)
    SELECT COALESCE(hhv.muc_giam_gia, 0.00)
    INTO v_giam_gia_percent
    FROM hoadon.hoadon h
    JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
    LEFT JOIN khachhang.hoivien hv ON kh.id_hv = hv.id_hv
    LEFT JOIN khachhang.hanghoivien hhv ON hv.hang = hhv.hang
    WHERE h.id_hd = p_id_hd;

    -- Đảm bảo không bị NULL nếu câu truy vấn không trả về dòng nào
    v_giam_gia_percent := COALESCE(v_giam_gia_percent, 0.00);

    -- 4. Tính toán tổng tiền sau giảm giá
    v_tong_tien := (v_tien_phong + v_tien_dich_vu) * (1 - v_giam_gia_percent / 100);

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;

-- Thử chạy: SELECT hoadon.func_tinh_tong_tien_hoa_don(5);
