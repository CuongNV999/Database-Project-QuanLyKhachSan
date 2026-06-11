-- Function: Thủ tục tạo nhanh một hóa đơn trống cho khách hàng
-- Câu lệnh tạo hàm trong PostgreSQL:

CREATE OR REPLACE FUNCTION func_them_hoa_don_nhanh(
    p_id_kh INT,
    p_id_nv INT,
    p_phuongthuc VARCHAR(100)
)
RETURNS INT AS $$
DECLARE
    v_id_hd INT;
BEGIN
    INSERT INTO hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, p_phuongthuc, p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;
    
    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;

-- Thử chạy hàm: SELECT func_them_hoa_don_nhanh(101, 5, 'Tiền mặt');
