-- Migration: V18 - Cập nhật quy định hội viên, thêm cột so_ngay_luu_tru và điều chỉnh các hàm nghiệp vụ
-- ----------------------------------------------------------------------------------------------------

-- 1. Thêm cột so_ngay_luu_tru vào hoadon_thue_phong và tính toán giá trị cho dữ liệu hiện tại
ALTER TABLE hoadon.hoadon_thue_phong ADD COLUMN so_ngay_luu_tru INTEGER;

-- Tạm thời vô hiệu hóa tất cả các trigger để cập nhật dữ liệu lịch sử (tránh trigger bảo mật hóa đơn đã thanh toán)
ALTER TABLE hoadon.hoadon_thue_phong DISABLE TRIGGER ALL;

UPDATE hoadon.hoadon_thue_phong
SET so_ngay_luu_tru = COALESCE(EXTRACT(DAY FROM (ngaytra - ngaynhan))::INT, 1);

UPDATE hoadon.hoadon_thue_phong
SET so_ngay_luu_tru = 1
WHERE so_ngay_luu_tru <= 0;

ALTER TABLE hoadon.hoadon_thue_phong ENABLE TRIGGER ALL;

-- 2. Cập nhật hạng hội viên trong bảng muchoivien
-- Đổi hạng Gold (id_mhv = 2) thành Silver (Giảm 15%, trả phòng muộn đến 16:00 chiều)
UPDATE khachhang.muchoivien 
SET hang = 'Silver', dieu_kien_luu_tru = 'Lưu trú tối thiểu 40 đêm', muc_giam_gia = 15.00
WHERE id_mhv = 2;

-- Đổi hạng Diamond (id_mhv = 3) thành Gold (Giảm 30%, trả phòng muộn đến 18:00 tối)
UPDATE khachhang.muchoivien 
SET hang = 'Gold', dieu_kien_luu_tru = 'Lưu trú tối thiểu 80 đêm', muc_giam_gia = 30.00
WHERE id_mhv = 3;

-- 3. Tạo lại hàm trigger tự động nâng hạng hội viên
CREATE OR REPLACE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien()
RETURNS TRIGGER AS $$
DECLARE
    v_id_mhv INT;
BEGIN
    IF NEW.tong_luu_tru >= 80 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Gold';
    ELSIF NEW.tong_luu_tru >= 40 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Silver';
    ELSIF NEW.tong_luu_tru >= 20 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Bronze';
    ELSE
        v_id_mhv := NULL;
    END IF;
    
    NEW.id_mhv := v_id_mhv;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Tạo lại hàm tính tỷ lệ phụ thu check-out muộn
CREATE OR REPLACE FUNCTION hoadon.func_tinh_ti_le_checkout_muon(
    p_hang_hv VARCHAR,
    p_ngaynhan TIMESTAMP,
    p_so_ngay_luu_tru INT,
    p_ngaytra_thucte TIMESTAMP
)
RETURNS NUMERIC AS $$
DECLARE
    v_ngaytra_dukien TIMESTAMP;
    v_expected_date DATE;
    v_checkout_time TIME;
    v_ti_le NUMERIC := 0.00;
BEGIN
    v_ngaytra_dukien := p_ngaynhan + COALESCE(p_so_ngay_luu_tru, 1) * INTERVAL '1 day';

    IF p_ngaytra_thucte IS NULL OR p_ngaytra_thucte <= v_ngaytra_dukien THEN
        RETURN 0.00;
    END IF;

    v_expected_date := v_ngaytra_dukien::date;
    v_checkout_time := p_ngaytra_thucte::time;

    -- Nếu checkout sau ngày dự kiến, tự động tính vượt mức 18:00 (phụ thu 100%)
    IF p_ngaytra_thucte::date > v_expected_date THEN
        RETURN 1.00;
    END IF;

    -- Tính phụ thu dựa trên hạng hội viên
    IF p_hang_hv IS NULL OR p_hang_hv = '' OR p_hang_hv = 'Bronze' THEN
        -- Basic hoặc Bronze:
        -- Trước 14:00: miễn phí
        -- 14:00 - 16:00: phụ thu 30%
        -- 16:00 - 18:00: phụ thu 50%
        -- Sau 18:00: phụ thu 100%
        IF v_checkout_time <= TIME '14:00:00' THEN
            v_ti_le := 0.00;
        ELSIF v_checkout_time <= TIME '16:00:00' THEN
            v_ti_le := 0.30;
        ELSIF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.50;
        ELSE
            v_ti_le := 1.00;
        END IF;
    ELSIF p_hang_hv = 'Silver' THEN
        -- Silver:
        -- Trước 16:00: miễn phí
        -- 16:00 - 18:00: phụ thu 20%
        -- Sau 18:00: phụ thu 100%
        IF v_checkout_time <= TIME '16:00:00' THEN
            v_ti_le := 0.00;
        ELSIF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.20;
        ELSE
            v_ti_le := 1.00;
        END IF;
    ELSIF p_hang_hv = 'Gold' THEN
        -- Gold:
        -- Trước 18:00: miễn phí
        -- Sau 18:00: phụ thu 100%
        IF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.00;
        ELSE
            v_ti_le := 1.00;
        END IF;
    END IF;

    RETURN v_ti_le;
END;
$$ LANGUAGE plpgsql;

-- 5. Tạo lại hàm tính tiền phòng chi tiết
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_phong(id_hd_input INT, id_p_input INT)
RETURNS MONEY AS $$
DECLARE
    v_ngaynhan TIMESTAMP;
    v_ngaytra TIMESTAMP;
    v_so_ngay_luu_tru INT;
    v_ngaythanhtoan TIMESTAMP;
    v_gia_tien MONEY;
    v_tien_coc MONEY;
    v_phu_thu MONEY;
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
    SELECT htp.ngaynhan, htp.ngaytra, htp.so_ngay_luu_tru, htp.tien_coc, htp.phu_thu, h.ngaythanhtoan
    INTO v_ngaynhan, v_ngaytra, v_so_ngay_luu_tru, v_tien_coc, v_phu_thu, v_ngaythanhtoan
    FROM hoadon.hoadon_thue_phong htp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE htp.id_hd = id_hd_input AND htp.id_p = id_p_input;

    SELECT lp.gia_tien
    INTO v_gia_tien
    FROM quanly.phong p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE p.id_p = id_p_input;

    v_so_ngay := COALESCE(v_so_ngay_luu_tru, 1);
    IF v_so_ngay <= 0 THEN
        v_so_ngay := 1;
    END IF;

    v_gia_phong_goc := v_so_ngay * COALESCE(v_gia_tien, 0::money);

    SELECT COALESCE(mhv.hang, ''), COALESCE(mhv.muc_giam_gia, 0.00)
    INTO v_hang_hv, v_giam_gia_percent
    FROM hoadon.hoadon h
    JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
    LEFT JOIN khachhang.hoivien hv ON kh.id_hv = hv.id_hv
    LEFT JOIN khachhang.muchoivien mhv ON hv.id_mhv = mhv.id_mhv
    WHERE h.id_hd = id_hd_input;

    v_hang_hv := COALESCE(v_hang_hv, '');
    v_giam_gia_percent := COALESCE(v_giam_gia_percent, 0.00);

    -- Xác định thời gian checkout thực tế để tính phụ thu check-out muộn
    v_ngaytra_thucte := v_ngaytra;
    IF v_ngaythanhtoan IS NULL AND CURRENT_TIMESTAMP > (v_ngaynhan + v_so_ngay * INTERVAL '1 day') THEN
        v_ngaytra_thucte := CURRENT_TIMESTAMP;
    END IF;

    v_ti_le_checkout_muon := hoadon.func_tinh_ti_le_checkout_muon(
        v_hang_hv, 
        v_ngaynhan,
        v_so_ngay,
        v_ngaytra_thucte
    );

    v_vat := v_gia_phong_goc * 0.08;
    v_phu_vu := v_gia_phong_goc * 0.05;
    v_phu_thu_checkout := v_gia_phong_goc * v_ti_le_checkout_muon;
    v_uu_dai := v_gia_phong_goc * (v_giam_gia_percent / 100);

    v_tong_tien := v_gia_phong_goc + v_vat + v_phu_vu + v_phu_thu_checkout + COALESCE(v_phu_thu, 0::money) - v_uu_dai - COALESCE(v_tien_coc, 0::money);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;

-- 6. Tạo lại hàm check-out phòng
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
    IF NOT EXISTS (
        SELECT 1 
        FROM hoadon.hoadon_thue_phong 
        WHERE id_hd = p_id_hd AND id_p = p_id_p
    ) THEN
        RAISE EXCEPTION 'Phòng % không có trong hóa đơn %!', p_id_p, p_id_hd;
    END IF;

    IF p_phu_thu_hong_hoc > 0::money THEN
        UPDATE quanly.phong
        SET trang_thai = 'Đang sửa'
        WHERE id_p = p_id_p;
    ELSE
        UPDATE quanly.phong
        SET trang_thai = 'Đang dọn dẹp'
        WHERE id_p = p_id_p;
    END IF;

    -- Cập nhật thời gian trả thực tế thành hiện tại và lưu các phụ thu phân rã
    UPDATE hoadon.hoadon_thue_phong
    SET ngaytra = CURRENT_TIMESTAMP,
        phu_thu_tieu_hao = COALESCE(phu_thu_tieu_hao, 0::money) + p_phu_thu_tieu_hao,
        phu_thu_hong_hoc = COALESCE(phu_thu_hong_hoc, 0::money) + p_phu_thu_hong_hoc,
        phu_thu = COALESCE(phu_thu, 0::money) + p_phu_thu_tieu_hao + p_phu_thu_hong_hoc
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    v_tong_tien_phong := hoadon.func_tinh_tien_phong(p_id_hd, p_id_p);

    UPDATE hoadon.hoadon_thue_phong
    SET tong_tien = v_tong_tien_phong
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    RETURN hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);
END;
$$ LANGUAGE plpgsql;

-- 7. Tạo lại hàm tìm và đặt phòng nhanh
CREATE OR REPLACE FUNCTION quanly.func_tim_va_dat_phong_nhanh(
    p_id_kh INT,
    p_id_nv INT,
    p_id_cn INT,
    p_chat_luong VARCHAR(100),
    p_loai_giuong VARCHAR(100),
    p_ngaynhan TIMESTAMP,
    p_ngaytra TIMESTAMP,
    p_tien_coc MONEY DEFAULT 0::money,
    p_phu_thu MONEY DEFAULT 0::money,
    p_dien_tich VARCHAR(50) DEFAULT NULL,
    p_view VARCHAR(100) DEFAULT NULL,
    p_doi_tuong VARCHAR(100) DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    v_id_p INT;
    v_id_hd INT;
    v_gia_tien MONEY;
    v_tong_tien_phong MONEY;
    v_so_ngay_luu_tru INT;
BEGIN
    SELECT p.id_p, lp.gia_tien INTO v_id_p, v_gia_tien
    FROM quanly.phong p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND lp.chat_luong = p_chat_luong
      AND lp.loai_giuong = p_loai_giuong
      AND (p_dien_tich IS NULL OR lp.dien_tich = p_dien_tich)
      AND (p_view IS NULL OR lp.view = p_view)
      AND (p_doi_tuong IS NULL OR lp.doi_tuong = p_doi_tuong)
      AND p.trang_thai = 'Còn trống'
      AND NOT EXISTS (
          SELECT 1 
          FROM hoadon.hoadon_thue_phong htp
          JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
          WHERE htp.id_p = p.id_p
            AND h.trang_thai != 'Đã hủy'
            AND htp.ngaynhan < p_ngaytra
            AND htp.ngaytra > p_ngaynhan
      )
    LIMIT 1;

    IF v_id_p IS NULL THEN
        RAISE EXCEPTION 'Không có phòng trống nào thuộc chi nhánh % với chất lượng %, giường %, diện tích %, view %, đối tượng % từ % đến %!', 
            p_id_cn, p_chat_luong, p_loai_giuong, COALESCE(p_dien_tich, 'Bất kỳ'), COALESCE(p_view, 'Bất kỳ'), COALESCE(p_doi_tuong, 'Bất kỳ'), p_ngaynhan, p_ngaytra;
    END IF;

    INSERT INTO hoadon.hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, 'Tiền mặt', p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;

    -- Tính so_ngay_luu_tru để chèn trực tiếp
    v_so_ngay_luu_tru := EXTRACT(DAY FROM (p_ngaytra - p_ngaynhan))::INT;
    IF v_so_ngay_luu_tru <= 0 THEN
        v_so_ngay_luu_tru := 1;
    END IF;

    INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, so_ngay_luu_tru, tien_coc, phu_thu, tong_tien)
    VALUES (v_id_hd, v_id_p, p_ngaynhan, p_ngaytra, v_so_ngay_luu_tru, p_tien_coc, p_phu_thu, 0::money);

    v_tong_tien_phong := hoadon.func_tinh_tien_phong(v_id_hd, v_id_p);

    UPDATE hoadon.hoadon_thue_phong
    SET tong_tien = v_tong_tien_phong
    WHERE id_hd = v_id_hd AND id_p = v_id_p;

    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;
