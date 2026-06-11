-- Function: Hủy đặt phòng và giải phóng trạng thái phòng liên quan
CREATE OR REPLACE FUNCTION hoadon.func_huy_dat_phong(
    p_id_hd INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_trang_thai VARCHAR(100);
    r RECORD;
BEGIN
    -- 1. Kiểm tra trạng thái hóa đơn
    SELECT trang_thai INTO v_trang_thai
    FROM hoadon
    WHERE id_hd = p_id_hd;

    IF v_trang_thai IS NULL THEN
        RAISE NOTICE 'Hóa đơn không tồn tại (Mã HĐ: %)!', p_id_hd;
        RETURN FALSE;
    ELSIF v_trang_thai = 'Đã thanh toán' THEN
        RAISE NOTICE 'Hóa đơn đã được thanh toán, không thể hủy!';
        RETURN FALSE;
    ELSIF v_trang_thai = 'Đã hủy' THEN
        RAISE NOTICE 'Hóa đơn đã được hủy trước đó!';
        RETURN TRUE;
    END IF;

    -- 2. Cập nhật trạng thái phòng sang 'Còn trống'
    FOR r IN 
        SELECT id_p FROM hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE phong
        SET trang_thai = 'Còn trống'
        WHERE id_p = r.id_p;
    END LOOP;

    -- 3. Cập nhật trạng thái hóa đơn sang 'Đã hủy'
    UPDATE hoadon
    SET trang_thai = 'Đã hủy'
    WHERE id_hd = p_id_hd;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
