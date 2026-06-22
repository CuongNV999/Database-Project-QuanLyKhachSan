-- Migration V29: Restrict Room Statuses to "Đã đặt" and "Còn trống" only
-- 1. Update existing rooms in cleaning or repair status to vacant
UPDATE quanly.phong 
SET trang_thai = 'Còn trống' 
WHERE trang_thai IN ('Đang dọn dẹp', 'Đang sửa');

-- 2. Redefine hoadon.func_check_out_phong
CREATE OR REPLACE FUNCTION hoadon.func_check_out_phong(
    p_id_hd INT,
    p_id_p INT,
    p_phu_thu_tieu_hao MONEY DEFAULT 0::money,
    p_phu_thu_hong_hoc MONEY DEFAULT 0::money
)
RETURNS MONEY AS $$
BEGIN
    -- 1. Kiểm tra sự tồn tại của phòng trong hóa đơn
    IF NOT EXISTS (
        SELECT 1 
        FROM hoadon.hoadon_thue_phong 
        WHERE id_hd = p_id_hd AND id_p = p_id_p
    ) THEN
        RAISE EXCEPTION 'Phòng % không có trong hóa đơn %!', p_id_p, p_id_hd;
    END IF;

    -- 2. Cập nhật trạng thái phòng sang 'Còn trống'
    UPDATE quanly.phong
    SET trang_thai = 'Còn trống'
    WHERE id_p = p_id_p;

    -- 3. Cập nhật thời gian trả thực tế thành hiện tại và lưu các phụ thu phân rã
    UPDATE hoadon.hoadon_thue_phong
    SET ngaytra = CURRENT_TIMESTAMP,
        phu_thu_tieu_hao = COALESCE(phu_thu_tieu_hao, 0::money) + p_phu_thu_tieu_hao,
        phu_thu_hong_hoc = COALESCE(phu_thu_hong_hoc, 0::money) + p_phu_thu_hong_hoc
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    -- 4. Tính toán và trả về tổng số tiền trả sau của toàn bộ hóa đơn hiện tại
    RETURN hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);
END;
$$ LANGUAGE plpgsql;

-- 3. Redefine hoadon.func_thanh_toan_hoa_don
CREATE OR REPLACE FUNCTION hoadon.func_thanh_toan_hoa_don(
    p_id_hd INT,
    p_phuongthuc VARCHAR(100)
)
RETURNS MONEY AS $$
DECLARE
    v_tong_thanh_toan MONEY;
    r RECORD;
BEGIN
    -- 1. Cập nhật ngày thanh toán của hóa đơn thành CURRENT_TIMESTAMP trước khi tính tiền
    UPDATE hoadon.hoadon
    SET ngaythanhtoan = CURRENT_TIMESTAMP
    WHERE id_hd = p_id_hd;

    -- 2. Tính tổng tiền cuối cùng cần thanh toán
    v_tong_thanh_toan := hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);

    -- 3. Cập nhật trạng thái thanh toán và phương thức thanh toán
    UPDATE hoadon.hoadon
    SET trang_thai = 'Đã thanh toán',
        phuongthuc = p_phuongthuc
    WHERE id_hd = p_id_hd;

    -- 4. Giải phóng các phòng trong hóa đơn này sang trạng thái 'Còn trống'
    FOR r IN 
        SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE quanly.phong
        SET trang_thai = 'Còn trống'
        WHERE id_p = r.id_p AND trang_thai != 'Còn trống';
    END LOOP;

    RETURN v_tong_thanh_toan;
END;
$$ LANGUAGE plpgsql;

-- 4. Redefine hoadon.func_chuyen_phong
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

    -- 4. Cập nhật trạng thái phòng cũ sang 'Còn trống'
    UPDATE quanly.phong
    SET trang_thai = 'Còn trống'
    WHERE id_p = p_id_p_cu;

    -- 5. Cập nhật trạng thái phòng mới sang 'Đã đặt'
    UPDATE quanly.phong
    SET trang_thai = 'Đã đặt'
    WHERE id_p = p_id_p_moi;

    RAISE NOTICE 'Chuyển phòng thành công từ % sang % cho hóa đơn %.', p_id_p_cu, p_id_p_moi, p_id_hd;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
