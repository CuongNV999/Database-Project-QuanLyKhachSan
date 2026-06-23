-- Function: Tính tổng tiền cuối cùng của toàn bộ hóa đơn (Trả sau = Tổng chi phí - Tiền cọc)
-- Đầu vào: p_id_hd (Mã hóa đơn)
-- Trả về: MONEY (Số tiền cần trả sau tại quầy)

CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)
RETURNS MONEY AS $$
BEGIN
    -- Trả về Số tiền 
    RETURN hoadon.func_tinh_so_tien_tra_sau(p_id_hd);
END;
$$ LANGUAGE plpgsql;
