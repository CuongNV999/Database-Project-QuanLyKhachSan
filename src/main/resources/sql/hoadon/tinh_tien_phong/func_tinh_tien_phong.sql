-- Function: Tính toán tổng tiền phòng thuê 
-- Formula: (so_ngay_luu_tru * gia_phong + phu_thu_hong_hoc + phu_thu_tieu_hao) * (1 + ti_le_checkout_muon)
-- Đầu vào: 
--   id_hd_input: Mã hóa đơn
--   id_p_input: Mã phòng
-- Trả về: MONEY (Tổng tiền phòng)

CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_phong(id_hd_input INT, id_p_input INT)
RETURNS MONEY AS $$
DECLARE
    v_ngaynhan TIMESTAMP;
    v_ngaytra TIMESTAMP;
    v_so_ngay_luu_tru INT;
    v_ngaythanhtoan TIMESTAMP;
    v_gia_tien MONEY;
    v_phu_thu_tieu_hao MONEY;
    v_phu_thu_hong_hoc MONEY;
    v_so_ngay INT;
    v_hang_hv VARCHAR(50);
    v_giam_gia_percent NUMERIC(5,2) := 0.00;
    v_ti_le_checkout_muon NUMERIC := 0.00;
    v_ngaytra_thucte TIMESTAMP;
    v_tong_tien MONEY;
BEGIN
    -- 1. Lấy thông tin ngày nhận, ngày trả, số ngày lưu trú, các loại phụ thu và ngày thanh toán thực tế
    SELECT htp.ngaynhan, htp.ngaytra, htp.so_ngay_luu_tru, 
           COALESCE(htp.phu_thu_tieu_hao, 0::money), COALESCE(htp.phu_thu_hong_hoc, 0::money), 
           h.ngaythanhtoan
    INTO v_ngaynhan, v_ngaytra, v_so_ngay_luu_tru, v_phu_thu_tieu_hao, v_phu_thu_hong_hoc, v_ngaythanhtoan
    FROM hoadon.hoadon_thue_phong htp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE htp.id_hd = id_hd_input AND htp.id_p = id_p_input;

    -- 2. Lấy giá phòng niêm yết của loại phòng này
    SELECT lp.gia_tien
    INTO v_gia_tien
    FROM quanly.phong p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE p.id_p = id_p_input;

    -- 3. Tính số đêm lưu trú (sử dụng cột so_ngay_luu_tru, tối thiểu 1 đêm)
    v_so_ngay := COALESCE(v_so_ngay_luu_tru, 1);
    IF v_so_ngay <= 0 THEN
        v_so_ngay := 1;
    END IF;

    -- 4. Lấy thông tin hạng và giảm giá hội viên từ helper function
    SELECT * INTO v_hang_hv, v_giam_gia_percent 
    FROM hoadon.func_lay_hang_va_giam_gia_hoi_vien(id_hd_input);

    -- 5. Xác định thời gian checkout thực tế để tính phụ thu check-out muộn
    v_ngaytra_thucte := v_ngaytra;
    IF v_ngaythanhtoan IS NULL AND CURRENT_TIMESTAMP > (v_ngaynhan + v_so_ngay * INTERVAL '1 day') THEN
        v_ngaytra_thucte := CURRENT_TIMESTAMP;
    END IF;

    -- 6. Tính phụ thu check-out muộn
    v_ti_le_checkout_muon := hoadon.func_tinh_ti_le_checkout_muon(
        v_hang_hv, 
        v_ngaynhan,
        v_so_ngay,
        v_ngaytra_thucte
    );

    -- 7. Tính toán tổng chi phí phòng:
    -- (so_ngay_luu_tru * gia_phong + phu_thu_hong_hoc + phu_thu_tieu_hao) * (1 + ti_le_checkout_muon)
    v_tong_tien := (v_so_ngay * COALESCE(v_gia_tien, 0::money) + v_phu_thu_hong_hoc + v_phu_thu_tieu_hao) * (1.00 + v_ti_le_checkout_muon);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;
