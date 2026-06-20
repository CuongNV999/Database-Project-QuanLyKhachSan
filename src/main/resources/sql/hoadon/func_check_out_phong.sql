-- Function: Thực hiện quy trình check-out cho một phòng cụ thể trong hóa đơn
-- Đầu vào: 
--   p_id_hd: Mã hóa đơn
--   p_id_p: Mã phòng cần check-out
--   p_phu_thu_tieu_hao: Chi phí sử dụng vật phẩm tiêu hao (nước suối, trà, bàn chải...)
--   p_phu_thu_hong_hoc: Phí đền bù hư hỏng vật dụng cố định trong phòng (nếu có)
-- Trả về: MONEY (Tổng tiền hóa đơn sau khi cập nhật phụ phí phòng này)

CREATE OR REPLACE FUNCTION hoadon.func_check_out_phong(
    p_id_hd INT,
    p_id_p INT,
    p_phu_thu_tieu_hao MONEY DEFAULT 0::money,
    p_phu_thu_hong_hoc MONEY DEFAULT 0::money
)
RETURNS MONEY AS $$
DECLARE
    v_tong_tien_phong MONEY;
BEGIN
    -- 1. Kiểm tra sự tồn tại của phòng trong hóa đơn
    IF NOT EXISTS (
        SELECT 1 
        FROM hoadon.hoadon_thue_phong 
        WHERE id_hd = p_id_hd AND id_p = p_id_p
    ) THEN
        RAISE EXCEPTION 'Phòng % không có trong hóa đơn %!', p_id_p, p_id_hd;
    END IF;

    -- 2. Cập nhật trạng thái phòng dựa trên việc có vật dụng cố định nào bị hỏng hay không
    -- Nếu có hỏng hóc (phí đền bù > 0) thì chuyển sang 'Đang sửa', ngược lại thì chuyển sang 'Đang dọn dẹp'
    IF p_phu_thu_hong_hoc > 0::money THEN
        UPDATE quanly.phong
        SET trang_thai = 'Đang sửa'
        WHERE id_p = p_id_p;
    ELSE
        UPDATE quanly.phong
        SET trang_thai = 'Đang dọn dẹp'
        WHERE id_p = p_id_p;
    END IF;

    -- 3. Cập nhật thời gian trả thực tế thành hiện tại và cộng dồn các chi phí phụ thu phát sinh vào chi tiết hóa đơn đặt phòng này
    UPDATE hoadon.hoadon_thue_phong
    SET ngaytra = CURRENT_TIMESTAMP,
        phu_thu_tieu_hao = COALESCE(phu_thu_tieu_hao, 0::money) + p_phu_thu_tieu_hao,
        phu_thu_hong_hoc = COALESCE(phu_thu_hong_hoc, 0::money) + p_phu_thu_hong_hoc
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    -- 4. Tính toán lại tổng tiền của riêng phòng này (để cập nhật VAT, phí phục vụ và giảm giá)
    v_tong_tien_phong := hoadon.func_tinh_tien_phong(p_id_hd, p_id_p);

    UPDATE hoadon.hoadon_thue_phong
    SET tong_tien = v_tong_tien_phong
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    -- 5. Tính toán và trả về tổng số tiền của toàn bộ hóa đơn hiện tại
    RETURN hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);
END;
$$ LANGUAGE plpgsql;
