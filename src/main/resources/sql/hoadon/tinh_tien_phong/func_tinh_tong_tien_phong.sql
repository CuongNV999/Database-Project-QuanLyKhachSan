-- Function: Tính tổng tiền phòng của tất cả các phòng thuê trong hóa đơn (đã bao gồm checkout muộn và phụ thu)
-- Đầu vào: p_id_hd (Mã hóa đơn)
-- Trả về: MONEY (Tổng tiền phòng)

CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_phong(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_tien_phong MONEY := 0::money;
    r RECORD;
BEGIN
    FOR r IN 
        SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        v_tong_tien_phong := v_tong_tien_phong + hoadon.func_tinh_tien_phong(p_id_hd, r.id_p);
    END LOOP;
    
    RETURN v_tong_tien_phong;
END;
$$ LANGUAGE plpgsql;
