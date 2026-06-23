-- Migration: V24 - Refactor complex database functions into smaller helper functions

-- ==========================================
-- 1. DROP EXISTING CONFLICTING FUNCTIONS
-- ==========================================

-- Drop main functions that will be recreated
DROP FUNCTION IF EXISTS hoadon.func_tinh_tien_phong(INT, INT) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_tim_va_dat_phong_nhanh(INT, INT, INT, VARCHAR, VARCHAR, TIMESTAMP, TIMESTAMP, MONEY, MONEY, VARCHAR, VARCHAR, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_bao_cao_doanh_thu_va_hieu_suat_chi_nhanh(INT, INT, INT) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_bao_cao_tai_chinh(INT, TIMESTAMP, TIMESTAMP) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_thong_ke_loai_phong_doanh_thu(INT, TIMESTAMP, TIMESTAMP) CASCADE;


-- Drop any new helper functions if they exist (for idempotency)
DROP FUNCTION IF EXISTS hoadon.func_lay_hang_va_giam_gia_hoi_vien(INT) CASCADE;
DROP FUNCTION IF EXISTS hoadon.func_tinh_phu_thu_va_giam_gia(MONEY, NUMERIC, NUMERIC, MONEY, MONEY) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_tim_phong_trong_phu_hop(INT, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TIMESTAMP, TIMESTAMP) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_lay_so_ngay_trong_thang(INT, INT) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_tinh_doanh_thu_dich_vu_chi_nhanh(INT, INT, INT) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_tinh_hieu_suat_phong(INT, INT, INT, INT, INT) CASCADE;

-- ==========================================
-- 2. CREATE HELPER FUNCTIONS
-- ==========================================

-- 2.1. Helper for hoadon.func_tinh_tien_phong
CREATE OR REPLACE FUNCTION hoadon.func_lay_hang_va_giam_gia_hoi_vien(
    p_id_hd INT,
    OUT o_hang_hv VARCHAR,
    OUT o_giam_gia_percent NUMERIC
) AS $$
BEGIN
    SELECT COALESCE(mhv.hang, ''), COALESCE(mhv.muc_giam_gia, 0.00)
    INTO o_hang_hv, o_giam_gia_percent
    FROM hoadon.hoadon h
    JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
    LEFT JOIN khachhang.hoivien hv ON kh.id_hv = hv.id_hv
    LEFT JOIN khachhang.muchoivien mhv ON hv.id_mhv = mhv.id_mhv
    WHERE h.id_hd = p_id_hd;

    o_hang_hv := COALESCE(o_hang_hv, '');
    o_giam_gia_percent := COALESCE(o_giam_gia_percent, 0.00);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION hoadon.func_tinh_phu_thu_va_giam_gia(
    p_gia_phong_goc MONEY,
    p_ti_le_checkout_muon NUMERIC,
    p_giam_gia_percent NUMERIC,
    p_phu_thu MONEY,
    p_tien_coc MONEY
)
RETURNS MONEY AS $$
DECLARE
    v_vat MONEY;
    v_phu_vu MONEY;
    v_phu_thu_checkout MONEY;
    v_uu_dai MONEY;
    v_tong_tien MONEY;
BEGIN
    v_vat := p_gia_phong_goc * 0.08; -- VAT mặc định 8%
    v_phu_vu := p_gia_phong_goc * 0.05; -- Phí phục vụ homestay 5%
    v_phu_thu_checkout := p_gia_phong_goc * p_ti_le_checkout_muon; -- Phụ thu check-out muộn
    v_uu_dai := p_gia_phong_goc * (p_giam_gia_percent / 100); -- Giảm giá hội viên

    -- Tổng chi phí phòng = Giá gốc + VAT + Phục vụ + Phụ thu checkout + Phụ thu khác (vật dụng) - Giảm giá hội viên - Tiền cọc
    v_tong_tien := p_gia_phong_goc + v_vat + v_phu_vu + v_phu_thu_checkout + COALESCE(p_phu_thu, 0::money) - v_uu_dai - COALESCE(p_tien_coc, 0::money);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;

-- 2.2. Helper for quanly.func_tim_va_dat_phong_nhanh
CREATE OR REPLACE FUNCTION quanly.func_tim_phong_trong_phu_hop(
    p_id_cn INT,
    p_chat_luong VARCHAR(100),
    p_loai_giuong VARCHAR(100),
    p_dien_tich VARCHAR(50),
    p_view VARCHAR(100),
    p_doi_tuong VARCHAR(100),
    p_ngaynhan TIMESTAMP,
    p_ngaytra TIMESTAMP,
    OUT o_id_p INT,
    OUT o_gia_tien MONEY
) AS $$
BEGIN
    SELECT p.id_p, lp.gia_tien INTO o_id_p, o_gia_tien
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
END;
$$ LANGUAGE plpgsql;

-- 2.3. Helpers for quanly.func_bao_cao_doanh_thu_va_hieu_suat_chi_nhanh
CREATE OR REPLACE FUNCTION quanly.func_lay_so_ngay_trong_thang(p_thang INT, p_nam INT)
RETURNS INT AS $$
BEGIN
    RETURN EXTRACT(DAY FROM (DATE_TRUNC('month', MAKE_DATE(p_nam, p_thang, 1)) + INTERVAL '1 month' - INTERVAL '1 day'))::INT;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION quanly.func_tinh_doanh_thu_dich_vu_chi_nhanh(
    p_id_cn INT,
    p_thang INT,
    p_nam INT
)
RETURNS MONEY AS $$
DECLARE
    v_tien_dv MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tien_dv
    FROM hoadon.hoadon h
    JOIN hoadon.hoadon_sudung_dichvu hsd ON h.id_hd = hsd.id_hd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE EXISTS (
        SELECT 1 FROM hoadon.hoadon_thue_phong htp
        JOIN quanly.phong p ON htp.id_p = p.id_p
        JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
        WHERE htp.id_hd = h.id_hd AND lp.id_cn = p_id_cn
    )
    AND h.trang_thai = 'Đã thanh toán'
    AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
    AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

    RETURN v_tien_dv;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION quanly.func_tinh_hieu_suat_phong(
    p_id_cn INT,
    p_thang INT,
    p_nam INT,
    p_ngay_trong_thang INT,
    p_tong_so_phong INT
)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    v_tong_so_ngay_thue INT := 0;
    v_hieu_suat NUMERIC(5,2) := 0.00;
BEGIN
    SELECT COALESCE(SUM(
        EXTRACT(DAY FROM (
            LEAST(htp.ngaytra, MAKE_DATE(p_nam, p_thang, p_ngay_trong_thang) + TIME '23:59:59') - 
            GREATEST(htp.ngaynhan, MAKE_DATE(p_nam, p_thang, 1))
        ))::INT
    ), 0) INTO v_tong_so_ngay_thue
    FROM hoadon.hoadon_thue_phong htp
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai != 'Đã hủy'
      AND htp.ngaynhan <= (MAKE_DATE(p_nam, p_thang, p_ngay_trong_thang) + TIME '23:59:59')
      AND htp.ngaytra >= MAKE_DATE(p_nam, p_thang, 1);

    IF v_tong_so_ngay_thue < 0 THEN
        v_tong_so_ngay_thue := 0;
    END IF;

    IF p_tong_so_phong > 0 AND p_ngay_trong_thang > 0 THEN
        v_hieu_suat := (v_tong_so_ngay_thue::numeric / (p_tong_so_phong * p_ngay_trong_thang)) * 100;
        IF v_hieu_suat > 100.00 THEN
            v_hieu_suat := 100.00;
        END IF;
    ELSE
        v_hieu_suat := 0.00;
    END IF;

    RETURN v_hieu_suat;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 3. CREATE REFACTORED MAIN FUNCTIONS
-- ==========================================

-- 3.1. hoadon.func_tinh_tien_phong
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
BEGIN
    SELECT htp.ngaynhan, htp.ngaytra, htp.so_ngay_luu_tru, htp.tien_coc, 
           (COALESCE(htp.phu_thu_tieu_hao, 0::money) + COALESCE(htp.phu_thu_hong_hoc, 0::money)), 
           h.ngaythanhtoan
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

    -- Call helper
    SELECT * INTO v_hang_hv, v_giam_gia_percent 
    FROM hoadon.func_lay_hang_va_giam_gia_hoi_vien(id_hd_input);

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

    -- Call helper
    RETURN hoadon.func_tinh_phu_thu_va_giam_gia(
        v_gia_phong_goc,
        v_ti_le_checkout_muon,
        v_giam_gia_percent,
        v_phu_thu,
        v_tien_coc
    );
END;
$$ LANGUAGE plpgsql;

-- 3.2. quanly.func_tim_va_dat_phong_nhanh
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
    -- Call helper
    SELECT * INTO v_id_p, v_gia_tien
    FROM quanly.func_tim_phong_trong_phu_hop(
        p_id_cn, p_chat_luong, p_loai_giuong,
        p_dien_tich, p_view, p_doi_tuong,
        p_ngaynhan, p_ngaytra
    );

    IF v_id_p IS NULL THEN
        RAISE EXCEPTION 'Không có phòng trống nào thuộc chi nhánh % với chất lượng %, giường %, diện tích %, view %, đối tượng % từ % đến %!', 
            p_id_cn, p_chat_luong, p_loai_giuong, COALESCE(p_dien_tich, 'Bất kỳ'), COALESCE(p_view, 'Bất kỳ'), COALESCE(p_doi_tuong, 'Bất kỳ'), p_ngaynhan, p_ngaytra;
    END IF;

    INSERT INTO hoadon.hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, 'Tiền mặt', p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;

    v_so_ngay_luu_tru := EXTRACT(DAY FROM (p_ngaytra - p_ngaynhan))::INT;
    IF v_so_ngay_luu_tru <= 0 THEN
        v_so_ngay_luu_tru := 1;
    END IF;

    INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, so_ngay_luu_tru, tien_coc, phu_thu_tieu_hao, tong_tien)
    VALUES (v_id_hd, v_id_p, p_ngaynhan, p_ngaytra, v_so_ngay_luu_tru, p_tien_coc, p_phu_thu, 0::money);

    v_tong_tien_phong := hoadon.func_tinh_tien_phong(v_id_hd, v_id_p);

    UPDATE hoadon.hoadon_thue_phong
    SET tong_tien = v_tong_tien_phong
    WHERE id_hd = v_id_hd AND id_p = v_id_p;

    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;

-- 3.3. quanly.func_bao_cao_doanh_thu_va_hieu_suat_chi_nhanh
CREATE OR REPLACE FUNCTION quanly.func_bao_cao_doanh_thu_va_hieu_suat_chi_nhanh(
    p_id_cn INT,
    p_thang INT,
    p_nam INT
)
RETURNS TABLE (
    tong_doanh_thu MONEY,
    so_hoa_don_thanh_toan INT,
    so_luot_phong_thue INT,
    hieu_suat_phong_percent NUMERIC(5,2)
) AS $$
DECLARE
    v_tong_doanh_thu MONEY := 0::money;
    v_so_hd INT := 0;
    v_so_phong_thue INT := 0;
    v_tong_so_phong INT := 0;
    v_ngay_trong_thang INT;
    v_hieu_suat NUMERIC(5,2) := 0.00;
BEGIN
    SELECT COUNT(*) INTO v_tong_so_phong
    FROM quanly.phong p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn;

    -- Call helper
    v_ngay_trong_thang := quanly.func_lay_so_ngay_trong_thang(p_thang, p_nam);

    SELECT COALESCE(SUM(htp.tong_tien), 0::money), COUNT(DISTINCT h.id_hd)
    INTO v_tong_doanh_thu, v_so_hd
    FROM hoadon.hoadon h
    JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai = 'Đã thanh toán'
      AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
      AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

    -- Call helper
    v_tong_doanh_thu := v_tong_doanh_thu + quanly.func_tinh_doanh_thu_dich_vu_chi_nhanh(p_id_cn, p_thang, p_nam);

    SELECT COUNT(*) INTO v_so_phong_thue
    FROM hoadon.hoadon_thue_phong htp
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai != 'Đã hủy'
      AND (
          (EXTRACT(MONTH FROM htp.ngaynhan) = p_thang AND EXTRACT(YEAR FROM htp.ngaynhan) = p_nam)
          OR
          (EXTRACT(MONTH FROM htp.ngaytra) = p_thang AND EXTRACT(YEAR FROM htp.ngaytra) = p_nam)
      );

    -- Call helper
    v_hieu_suat := quanly.func_tinh_hieu_suat_phong(p_id_cn, p_thang, p_nam, v_ngay_trong_thang, v_tong_so_phong);

    RETURN QUERY SELECT v_tong_doanh_thu, v_so_hd, v_so_phong_thue, v_hieu_suat;
END;
$$ LANGUAGE plpgsql;

-- 3.4. quanly.func_bao_cao_tai_chinh
CREATE OR REPLACE FUNCTION quanly.func_bao_cao_tai_chinh(
    p_id_cn INT,
    p_tu_ngay TIMESTAMP,
    p_den_ngay TIMESTAMP
)
RETURNS TABLE (
    tong_doanh_thu_thuc_te MONEY,
    tien_coc_phong_online MONEY,
    tong_phu_thu_tieu_hao MONEY,
    tong_den_bu_hong_hoc MONEY
) AS $$
DECLARE
    v_tong_doanh_thu MONEY := 0::money;
    v_tien_coc_online MONEY := 0::money;
    v_tieu_hao MONEY := 0::money;
    v_hong_hoc MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(hoadon.func_tinh_tong_tien_hoa_don(h.id_hd)), 0::money)
    INTO v_tong_doanh_thu
    FROM hoadon.hoadon h
    JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv
    WHERE h.trang_thai = 'Đã thanh toán'
      AND (p_id_cn = -1 OR nv.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay;

    SELECT COALESCE(SUM(htp.tien_coc), 0::money)
    INTO v_tien_coc_online
    FROM hoadon.hoadon h
    JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE h.trang_thai IN ('Đã đặt', 'Đã cọc')
      AND (p_id_cn = -1 OR lp.id_cn = p_id_cn)
      AND htp.ngaynhan >= CURRENT_TIMESTAMP;

    SELECT COALESCE(SUM(htp.phu_thu_tieu_hao), 0::money), COALESCE(SUM(htp.phu_thu_hong_hoc), 0::money)
    INTO v_tieu_hao, v_hong_hoc
    FROM hoadon.hoadon h
    JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE h.trang_thai = 'Đã thanh toán'
      AND (p_id_cn = -1 OR lp.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay;

    RETURN QUERY SELECT v_tong_doanh_thu, v_tien_coc_online, v_tieu_hao, v_hong_hoc;
END;
$$ LANGUAGE plpgsql;

-- 3.5. quanly.func_thong_ke_loai_phong_doanh_thu
CREATE OR REPLACE FUNCTION quanly.func_thong_ke_loai_phong_doanh_thu(
    p_id_cn INT,
    p_tu_ngay TIMESTAMP,
    p_den_ngay TIMESTAMP
)
RETURNS TABLE (
    ten_loai_phong VARCHAR(255),
    tong_doanh_thu MONEY
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (lp.chat_luong || ' - ' || lp.loai_giuong)::VARCHAR(255) AS ten_loai_phong,
        COALESCE(SUM(htp.tong_tien), 0::money) AS tong_doanh_thu
    FROM hoadon.hoadon_thue_phong htp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE h.trang_thai = 'Đã thanh toán'
      AND (p_id_cn = -1 OR lp.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay
    GROUP BY lp.chat_luong, lp.loai_giuong
    ORDER BY tong_doanh_thu DESC;
END;
$$ LANGUAGE plpgsql;


