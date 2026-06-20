-- Function: Tính tổng tiền cuối cùng của toàn bộ hóa đơn (Tổng tiền phòng + Tổng tiền dịch vụ đã dùng)
-- Đầu vào: p_id_hd (Mã hóa đơn)
-- Trả về: MONEY

CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tien_phong MONEY := 0::money;
    v_tien_dich_vu MONEY := 0::money;
    v_tong_tien MONEY := 0::money;
    v_trang_thai VARCHAR(50);
    r RECORD;
BEGIN
    -- 1. Lấy trạng thái hiện tại của hóa đơn
    SELECT trang_thai INTO v_trang_thai FROM hoadon.hoadon WHERE id_hd = p_id_hd;

    -- 2. Chỉ thực hiện cập nhật lại tổng tiền từng phòng thuê nếu hóa đơn chưa thanh toán.
    -- Đối với hóa đơn đã thanh toán, thông tin tiền phòng đã được chốt và không được phép sửa đổi (tránh lỗi bảo mật).
    IF COALESCE(v_trang_thai, '') != 'Đã thanh toán' THEN
        FOR r IN 
            SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
        LOOP
            UPDATE hoadon.hoadon_thue_phong
            SET tong_tien = hoadon.func_tinh_tien_phong(p_id_hd, r.id_p)
            WHERE id_hd = p_id_hd AND id_p = r.id_p;
        END LOOP;
    END IF;

    -- 3. Tính tổng tiền thuê các phòng của hóa đơn sau khi đã cập nhật
    SELECT COALESCE(SUM(tong_tien), 0::money)
    INTO v_tien_phong
    FROM hoadon.hoadon_thue_phong
    WHERE id_hd = p_id_hd;

    -- 4. Tính tổng tiền sử dụng dịch vụ của hóa đơn (BUFFET ăn sáng, giặt là, spa...)
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tien_dich_vu
    FROM hoadon.hoadon_sudung_dichvu hsd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE hsd.id_hd = p_id_hd;

    -- Tổng tiền hóa đơn = Tổng tiền phòng + Tiền dịch vụ
    v_tong_tien := v_tien_phong + v_tien_dich_vu;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;
