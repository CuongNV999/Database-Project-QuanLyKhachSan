-- Function: Tính toán tổng tiền phòng thuê chi tiết (Áp dụng VAT 8%, phí dịch vụ phục vụ 5%, phụ thu check-out muộn, các phụ thu tiêu hao/hỏng hóc và ưu đãi giảm giá phòng hội viên)
-- Đầu vào: 
--   id_hd_input: Mã hóa đơn
--   id_p_input: Mã phòng
-- Trả về: MONEY (Tổng tiền phòng sau giảm giá và phụ thu)

CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_phong(id_hd_input INT, id_p_input INT)
RETURNS MONEY AS $$
DECLARE
    v_ngaynhan TIMESTAMP;
    v_ngaytra TIMESTAMP;
    v_so_ngay_luu_tru INT;
    v_ngaythanhtoan TIMESTAMP;
    v_gia_tien MONEY;
    v_tien_coc MONEY;
    v_phu_thu MONEY; -- Chứa tổng phụ thu vật phẩm tiêu hao và đền bù hư hỏng
    v_so_ngay INT;
    v_gia_phong_goc MONEY;
    v_hang_hv VARCHAR(50);
    v_giam_gia_percent NUMERIC(5,2) := 0.00;
    v_ti_le_checkout_muon NUMERIC := 0.00;
    v_ngaytra_thucte TIMESTAMP;
    
    v_vat MONEY;
    v_phu_vu MONEY;
    v_phu_thu_checkout MONEY;
    v_uu_dai MONEY;
    v_tong_tien MONEY;
BEGIN
    -- 1. Lấy thông tin ngày nhận, ngày trả, số ngày lưu trú, tiền đặt cọc, các loại phụ thu khác và ngày thanh toán thực tế
    SELECT htp.ngaynhan, htp.ngaytra, htp.so_ngay_luu_tru, htp.tien_coc, htp.phu_thu, h.ngaythanhtoan
    INTO v_ngaynhan, v_ngaytra, v_so_ngay_luu_tru, v_tien_coc, v_phu_thu, v_ngaythanhtoan
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

    v_gia_phong_goc := v_so_ngay * COALESCE(v_gia_tien, 0::money);

    -- 4. Lấy thông tin hạng và giảm giá hội viên của khách hàng lẻ
    SELECT COALESCE(mhv.hang, ''), COALESCE(mhv.muc_giam_gia, 0.00)
    INTO v_hang_hv, v_giam_gia_percent
    FROM hoadon.hoadon h
    JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
    LEFT JOIN khachhang.hoivien hv ON kh.id_hv = hv.id_hv
    LEFT JOIN khachhang.muchoivien mhv ON hv.id_mhv = mhv.id_mhv
    WHERE h.id_hd = id_hd_input;

    v_hang_hv := COALESCE(v_hang_hv, '');
    v_giam_gia_percent := COALESCE(v_giam_gia_percent, 0.00);

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

    -- 7. Tính toán các chi phí chi tiết 
    v_vat := v_gia_phong_goc * 0.08; -- VAT mặc định 8%
    v_phu_vu := v_gia_phong_goc * 0.05; -- Phí phục vụ homestay 5%
    v_phu_thu_checkout := v_gia_phong_goc * v_ti_le_checkout_muon; -- Phụ thu check-out muộn
    v_uu_dai := v_gia_phong_goc * (v_giam_gia_percent / 100); -- Giảm giá hội viên

    -- Tổng chi phí phòng = Giá gốc + VAT + Phục vụ + Phụ thu checkout + Phụ thu khác (vật dụng) - Giảm giá hội viên - Tiền cọc
    v_tong_tien := v_gia_phong_goc + v_vat + v_phu_vu + v_phu_thu_checkout + COALESCE(v_phu_thu, 0::money) - v_uu_dai - COALESCE(v_tien_coc, 0::money);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;
