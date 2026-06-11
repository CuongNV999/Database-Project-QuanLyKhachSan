-- Function/Procedure: Chuyển phòng cho khách đang lưu trú
-- Đầu vào: 
-- 1. p_id_hd: Mã hóa đơn hiện tại
-- 2. p_id_p_cu: Mã phòng cũ cần chuyển đi
-- 3. p_id_p_moi: Mã phòng mới cần chuyển tới
-- Trả về: BOOLEAN (TRUE nếu chuyển thành công, FALSE nếu thất bại)

CREATE OR REPLACE FUNCTION hoadon.func_chuyen_phong(
    p_id_hd INT,
    p_id_p_cu INT,
    p_id_p_moi INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_trang_thai_moi VARCHAR(100);
    v_exists BOOLEAN;
BEGIN
    -- 1. Kiểm tra xem phòng mới có trống không
    SELECT trang_thai INTO v_trang_thai_moi
    FROM quanly.phong
    WHERE id_p = p_id_p_moi;

    IF v_trang_thai_moi != 'Còn trống' THEN
        RAISE NOTICE 'Phòng mới (ID: %) không ở trạng thái trống! Không thể chuyển.', p_id_p_moi;
        RETURN FALSE;
    END IF;

    -- 2. Kiểm tra xem phòng cũ có thuộc hóa đơn này không
    SELECT EXISTS(
        SELECT 1 FROM hoadon.hoadon_thue_phong 
        WHERE id_hd = p_id_hd AND id_p = p_id_p_cu
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE NOTICE 'Phòng cũ (ID: %) không được đăng ký trong hóa đơn (ID: %)!', p_id_p_cu, p_id_hd;
        RETURN FALSE;
    END IF;

    -- 3. Cập nhật phòng mới vào chi tiết hóa đơn thuê phòng
    UPDATE hoadon.hoadon_thue_phong
    SET id_p = p_id_p_moi
    WHERE id_hd = p_id_hd AND id_p = p_id_p_cu;

    -- 4. Cập nhật trạng thái phòng cũ sang 'Đang dọn dẹp'
    UPDATE quanly.phong
    SET trang_thai = 'Đang dọn dẹp'
    WHERE id_p = p_id_p_cu;

    -- 5. Cập nhật trạng thái phòng mới sang 'Đã đặt'
    UPDATE quanly.phong
    SET trang_thai = 'Đã đặt'
    WHERE id_p = p_id_p_moi;

    RAISE NOTICE 'Chuyển phòng thành công từ % sang % cho hóa đơn %.', p_id_p_cu, p_id_p_moi, p_id_hd;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Thử chạy: SELECT hoadon.func_chuyen_phong(1, 1, 2);
