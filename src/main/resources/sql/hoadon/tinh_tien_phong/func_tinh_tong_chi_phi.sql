-- Function: Tính tổng chi phí của toàn bộ hóa đơn (sau VAT 8%, tiền dịch vụ và ưu đãi hội viên)
-- Đầu vào: p_id_hd (Mã hóa đơn)
-- Trả về: MONEY (Tổng chi phí chuyến đi)

CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_chi_phi(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_tien_phong MONEY := 0::money;
    v_tong_tien_dv MONEY := 0::money;
    v_vat MONEY := 0::money;
    v_uu_dai MONEY := 0::money;
    v_giam_gia_percent NUMERIC(5,2) := 0.00;
    v_hang_hv VARCHAR(50);
    v_tong_chi_phi MONEY := 0::money;
BEGIN
    v_tong_tien_phong := hoadon.func_tinh_tong_tien_phong(p_id_hd);
    v_tong_tien_dv := hoadon.func_tinh_tong_tien_dich_vu(p_id_hd);

    SELECT * INTO v_hang_hv, v_giam_gia_percent 
    FROM hoadon.func_lay_hang_va_giam_gia_hoi_vien(p_id_hd);

    v_vat := v_tong_tien_phong * 0.08; -- VAT 8%
    v_uu_dai := v_tong_tien_phong * (v_giam_gia_percent / 100.0); -- Ưu đãi

    v_tong_chi_phi := v_tong_tien_phong + v_vat + v_tong_tien_dv - v_uu_dai;
    
    IF v_tong_chi_phi < 0::money THEN
        v_tong_chi_phi := 0::money;
    END IF;

    RETURN v_tong_chi_phi;
END;
$$ LANGUAGE plpgsql;
