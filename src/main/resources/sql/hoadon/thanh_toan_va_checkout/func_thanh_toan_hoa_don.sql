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
    -- 1. Cập nhật ngày thanh toán của hóa đơn thành CURRENT_TIMESTAMP trước khi tính tiền
    -- (Điều này đảm bảo hàm hoadon.func_tinh_ti_le_checkout_muon sẽ lấy chính xác giờ thanh toán thực tế)
    UPDATE hoadon.hoadon
    SET ngaythanhtoan = CURRENT_TIMESTAMP
    WHERE id_hd = p_id_hd;

    -- 2. Tính tổng tiền cuối cùng cần thanh toán (hàm này sẽ tự động cập nhật lại tổng tiền từng phòng thuê)
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
