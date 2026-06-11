-- Function/Procedure: Thực hiện quy trình thanh toán hóa đơn và giải phóng phòng
-- Đầu vào: p_id_hd (Mã hóa đơn), p_phuongthuc (Phương thức thanh toán)
-- Trả về: MONEY (Tổng số tiền đã thanh toán)

CREATE OR REPLACE FUNCTION hoadon.func_thanh_toan_hoa_don(
    p_id_hd INT,
    p_phuongthuc VARCHAR(100)
)
RETURNS MONEY AS $$
DECLARE
    v_tong_thanh_toan MONEY;
    r RECORD;
BEGIN
    -- 1. Tính tổng tiền cuối cùng cần thanh toán
    v_tong_thanh_toan := hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);

    -- 2. Cập nhật thông tin thanh toán cho hóa đơn
    UPDATE hoadon.hoadon
    SET trang_thai = 'Đã thanh toán',
        ngaythanhtoan = CURRENT_DATE,
        phuongthuc = p_phuongthuc
    WHERE id_hd = p_id_hd;

    -- 3. Cập nhật trạng thái các phòng trong hóa đơn này sang 'Đang dọn dẹp'
    FOR r IN 
        SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE quanly.phong
        SET trang_thai = 'Đang dọn dẹp'
        WHERE id_p = r.id_p;
    END LOOP;

    RETURN v_tong_thanh_toan;
END;
$$ LANGUAGE plpgsql;

-- Thử chạy: SELECT hoadon.func_thanh_toan_hoa_don(5, 'Thẻ tín dụng');
