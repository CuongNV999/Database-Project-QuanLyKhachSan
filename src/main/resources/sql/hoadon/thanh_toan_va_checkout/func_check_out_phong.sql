-- Function: Thực hiện quy trình check-out cho một phòng cụ thể trong hóa đơn
-- Đầu vào: 
--   p_id_hd: Mã hóa đơn
--   p_id_p: Mã phòng cần check-out
--   p_phu_thu_tieu_hao: Chi phí sử dụng vật phẩm tiêu hao (nước suối, trà, bàn chải...)
--   p_phu_thu_hong_hoc: Phí đền bù hư hỏng vật dụng cố định trong phòng (nếu có)
-- Trả về: MONEY (Tổng tiền hóa đơn trả sau hiện tại)

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

    -- 3. Cập nhật thời gian trả thực tế thành hiện tại
    UPDATE hoadon.hoadon_thue_phong
    SET ngaytra = CURRENT_TIMESTAMP
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    -- 4. Lưu các phụ thu vào bảng mới
    IF p_phu_thu_tieu_hao > 0::money THEN
        IF EXISTS (SELECT 1 FROM hoadon.phu_thu_phong WHERE id_hd = p_id_hd AND id_p = p_id_p AND loai_phu_thu = 'Tiêu hao') THEN
            UPDATE hoadon.phu_thu_phong
            SET so_tien = so_tien + p_phu_thu_tieu_hao
            WHERE id_hd = p_id_hd AND id_p = p_id_p AND loai_phu_thu = 'Tiêu hao';
        ELSE
            INSERT INTO hoadon.phu_thu_phong (id_hd, id_p, loai_phu_thu, so_tien)
            VALUES (p_id_hd, p_id_p, 'Tiêu hao', p_phu_thu_tieu_hao);
        END IF;
    END IF;

    IF p_phu_thu_hong_hoc > 0::money THEN
        IF EXISTS (SELECT 1 FROM hoadon.phu_thu_phong WHERE id_hd = p_id_hd AND id_p = p_id_p AND loai_phu_thu = 'Hỏng hóc') THEN
            UPDATE hoadon.phu_thu_phong
            SET so_tien = so_tien + p_phu_thu_hong_hoc
            WHERE id_hd = p_id_hd AND id_p = p_id_p AND loai_phu_thu = 'Hỏng hóc';
        ELSE
            INSERT INTO hoadon.phu_thu_phong (id_hd, id_p, loai_phu_thu, so_tien)
            VALUES (p_id_hd, p_id_p, 'Hỏng hóc', p_phu_thu_hong_hoc);
        END IF;
    END IF;

    -- 5. Tính toán và trả về tổng số tiền trả sau của toàn bộ hóa đơn hiện tại
    RETURN hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);
END;
$$ LANGUAGE plpgsql;
