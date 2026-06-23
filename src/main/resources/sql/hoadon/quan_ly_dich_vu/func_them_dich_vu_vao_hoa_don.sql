-- Function: Thêm hoặc cập nhật dịch vụ sử dụng cho hóa đơn
CREATE OR REPLACE FUNCTION hoadon.func_them_dich_vu_vao_hoa_don(
    p_id_hd INT,
    p_id_dv INT,
    p_so_luong INT
)
RETURNS MONEY AS $$
DECLARE
    v_trang_thai VARCHAR(100);
    v_gia_dv MONEY;
    v_exist_count INT;
    v_tong_tien_dv MONEY;
BEGIN
    -- 1. Kiểm tra trạng thái hóa đơn
    SELECT trang_thai INTO v_trang_thai
    FROM hoadon
    WHERE id_hd = p_id_hd;

    IF v_trang_thai IS NULL THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại (Mã HĐ: %)!', p_id_hd;
    ELSIF v_trang_thai = 'Đã thanh toán' OR v_trang_thai = 'Đã hủy' THEN
        RAISE EXCEPTION 'Không thể thêm dịch vụ vào hóa đơn ở trạng thái %!', v_trang_thai;
    END IF;

    -- 2. Kiểm tra số lượng hợp lệ
    IF p_so_luong <= 0 THEN
        RAISE EXCEPTION 'Số lượng dịch vụ phải lớn hơn 0!';
    END IF;

    -- 3. Lấy giá dịch vụ
    SELECT gia INTO v_gia_dv
    FROM dichvu
    WHERE id_dv = p_id_dv;

    IF v_gia_dv IS NULL THEN
        RAISE EXCEPTION 'Dịch vụ không tồn tại (Mã DV: %)!', p_id_dv;
    END IF;

    -- 4. Thêm hoặc cập nhật số lượng
    SELECT COUNT(*) INTO v_exist_count
    FROM hoadon_sudung_dichvu
    WHERE id_hd = p_id_hd AND id_dv = p_id_dv;

    IF v_exist_count > 0 THEN
        UPDATE hoadon_sudung_dichvu
        SET so_luong = so_luong + p_so_luong
        WHERE id_hd = p_id_hd AND id_dv = p_id_dv;
    ELSE
        INSERT INTO hoadon_sudung_dichvu (id_hd, id_dv, so_luong)
        VALUES (p_id_hd, p_id_dv, p_so_luong);
    END IF;

    -- 5. Trả về tổng tiền cho dịch vụ này
    SELECT (so_luong * v_gia_dv) INTO v_tong_tien_dv
    FROM hoadon_sudung_dichvu
    WHERE id_hd = p_id_hd AND id_dv = p_id_dv;

    RETURN v_tong_tien_dv;
END;
$$ LANGUAGE plpgsql;
