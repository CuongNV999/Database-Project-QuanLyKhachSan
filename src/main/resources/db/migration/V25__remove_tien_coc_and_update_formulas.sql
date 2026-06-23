-- Migration: V25 - Remove columns 'tien_coc' and 'tong_tien' from hoadon_thue_phong, update room and invoice billing formulas, and add helpers/views.

-- ==========================================
-- 1. DROP EXISTING CONFLICTING OBJECTS
-- ==========================================

DROP VIEW IF EXISTS hoadon.v_chi_tiet_hoa_don_thue_phong CASCADE;
DROP VIEW IF EXISTS hoadon.v_doanh_thu_chi_nhanh CASCADE;

DROP FUNCTION IF EXISTS hoadon.func_tinh_tien_phong(INT, INT) CASCADE;
DROP FUNCTION IF EXISTS hoadon.func_tinh_tong_tien_hoa_don(INT) CASCADE;
DROP FUNCTION IF EXISTS hoadon.func_check_out_phong(INT, INT, MONEY, MONEY) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_tim_va_dat_phong_nhanh(INT, INT, INT, VARCHAR, VARCHAR, TIMESTAMP, TIMESTAMP, MONEY, MONEY, VARCHAR, VARCHAR, VARCHAR) CASCADE;
DROP FUNCTION IF EXISTS hoadon.func_thanh_toan_hoa_don(INT, VARCHAR) CASCADE;

-- Drop helpers if they exist
DROP FUNCTION IF EXISTS hoadon.func_tinh_tong_tien_phong(INT) CASCADE;
DROP FUNCTION IF EXISTS hoadon.func_tinh_tong_tien_dich_vu(INT) CASCADE;
DROP FUNCTION IF EXISTS hoadon.func_tinh_tien_coc(INT) CASCADE;
DROP FUNCTION IF EXISTS hoadon.func_tinh_tong_chi_phi(INT) CASCADE;
DROP FUNCTION IF EXISTS hoadon.func_tinh_so_tien_tra_sau(INT) CASCADE;

-- ==========================================
-- 2. DATABASE SCHEMA MODIFICATIONS
-- ==========================================

-- Drop the columns from hoadon_thue_phong
ALTER TABLE hoadon.hoadon_thue_phong DROP COLUMN IF EXISTS tien_coc;
ALTER TABLE hoadon.hoadon_thue_phong DROP COLUMN IF EXISTS tong_tien;

-- ==========================================
-- 3. CREATE NEW HELPER FUNCTIONS
-- ==========================================

-- 3.1. Calculate total base deposit for the invoice
-- Tiền cọc: Tổng của Số lượng mỗi phòng x giá mỗi phòng (Số đêm lưu trú * Giá phòng)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_coc(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tien_coc MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(htp.so_ngay_luu_tru * lp.gia_tien), 0::money)
    INTO v_tien_coc
    FROM hoadon.hoadon_thue_phong htp
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE htp.id_hd = p_id_hd;
    
    RETURN v_tien_coc;
END;
$$ LANGUAGE plpgsql;

-- 3.2. Calculate dynamic room cost for a specific room lease
-- (so_ngay_luu_tru * gia_phong + phu_thu_hong_hoc + phu_thu_tieu_hao) * (1 + ti_le_checkout_muon)
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
    SELECT htp.ngaynhan, htp.ngaytra, htp.so_ngay_luu_tru, 
           COALESCE(htp.phu_thu_tieu_hao, 0::money), COALESCE(htp.phu_thu_hong_hoc, 0::money), 
           h.ngaythanhtoan
    INTO v_ngaynhan, v_ngaytra, v_so_ngay_luu_tru, v_phu_thu_tieu_hao, v_phu_thu_hong_hoc, v_ngaythanhtoan
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

    v_tong_tien := (v_so_ngay * COALESCE(v_gia_tien, 0::money) + v_phu_thu_hong_hoc + v_phu_thu_tieu_hao) * (1.00 + v_ti_le_checkout_muon);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;

-- 3.3. Calculate sum of all room costs for the invoice
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

-- 3.4. Calculate total service cost for the invoice
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_dich_vu(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_tien_dv MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tong_tien_dv
    FROM hoadon.hoadon_sudung_dichvu hsd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE hsd.id_hd = p_id_hd;
    
    RETURN v_tong_tien_dv;
END;
$$ LANGUAGE plpgsql;

-- 3.5. Calculate total overall cost of the invoice
-- Tổng chi phí = Tổng tiền phòng + (Tổng tiền phòng x VAT) + Tổng tiền Dịch vụ - (Tổng tiền phòng x Ưu đãi)
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

-- 3.6. Calculate remaining payment after subtracting deposit
-- Số tiền trả sau = Tổng chi phí - Tiền cọc
CREATE OR REPLACE FUNCTION hoadon.func_tinh_so_tien_tra_sau(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_chi_phi MONEY := 0::money;
    v_tien_coc MONEY := 0::money;
    v_tra_sau MONEY := 0::money;
BEGIN
    v_tong_chi_phi := hoadon.func_tinh_tong_chi_phi(p_id_hd);
    v_tien_coc := hoadon.func_tinh_tien_coc(p_id_hd);
    
    v_tra_sau := v_tong_chi_phi - v_tien_coc;
    
    IF v_tra_sau < 0::money THEN
        v_tra_sau := 0::money;
    END IF;

    RETURN v_tra_sau;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 4. CREATE MAIN FUNCTIONS (REFACTORED)
-- ==========================================

-- 4.1. hoadon.func_tinh_tong_tien_hoa_don (returns Số tiền trả sau for Java / JDBC backward compatibility)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)
RETURNS MONEY AS $$
BEGIN
    RETURN hoadon.func_tinh_so_tien_tra_sau(p_id_hd);
END;
$$ LANGUAGE plpgsql;

-- 4.2. hoadon.func_check_out_phong
CREATE OR REPLACE FUNCTION hoadon.func_check_out_phong(
    p_id_hd INT,
    p_id_p INT,
    p_phu_thu_tieu_hao MONEY DEFAULT 0::money,
    p_phu_thu_hong_hoc MONEY DEFAULT 0::money
)
RETURNS MONEY AS $$
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

    UPDATE hoadon.hoadon_thue_phong
    SET ngaytra = CURRENT_TIMESTAMP,
        phu_thu_tieu_hao = COALESCE(phu_thu_tieu_hao, 0::money) + p_phu_thu_tieu_hao,
        phu_thu_hong_hoc = COALESCE(phu_thu_hong_hoc, 0::money) + p_phu_thu_hong_hoc
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    RETURN hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);
END;
$$ LANGUAGE plpgsql;

-- 4.3. quanly.func_tim_va_dat_phong_nhanh
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
    v_so_ngay_luu_tru INT;
BEGIN
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

    -- Removed columns: tien_coc, tong_tien from insert
    INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, so_ngay_luu_tru, phu_thu_tieu_hao)
    VALUES (v_id_hd, v_id_p, p_ngaynhan, p_ngaytra, v_so_ngay_luu_tru, p_phu_thu);

    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;

-- 4.4. hoadon.func_thanh_toan_hoa_don
CREATE OR REPLACE FUNCTION hoadon.func_thanh_toan_hoa_don(
    p_id_hd INT,
    p_phuongthuc VARCHAR(100)
)
RETURNS MONEY AS $$
DECLARE
    v_tong_thanh_toan MONEY;
    r RECORD;
BEGIN
    UPDATE hoadon.hoadon
    SET ngaythanhtoan = CURRENT_TIMESTAMP
    WHERE id_hd = p_id_hd;

    v_tong_thanh_toan := hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);

    UPDATE hoadon.hoadon
    SET trang_thai = 'Đã thanh toán',
        phuongthuc = p_phuongthuc
    WHERE id_hd = p_id_hd;

    FOR r IN 
        SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE quanly.phong
        SET trang_thai = 'Đang dọn dẹp'
        WHERE id_p = r.id_p AND trang_thai NOT IN ('Đang dọn dẹp', 'Đang sửa');
    END LOOP;

    RETURN v_tong_thanh_toan;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 5. CREATE VIEWS
-- ==========================================

-- 5.1. View to display detailed invoices of room rentals (with computed prices and deposits)
CREATE OR REPLACE VIEW hoadon.v_chi_tiet_hoa_don_thue_phong AS
SELECT 
    htp.id_hd,
    htp.id_p,
    htp.ngaynhan,
    htp.ngaytra,
    htp.so_ngay_luu_tru,
    htp.phu_thu_tieu_hao,
    htp.phu_thu_hong_hoc,
    hoadon.func_tinh_tien_coc(htp.id_hd) AS tong_tien_coc_hoa_don,
    (htp.so_ngay_luu_tru * lp.gia_tien) AS tien_coc_phong,
    hoadon.func_tinh_tien_phong(htp.id_hd, htp.id_p) AS tong_tien_phong
FROM hoadon.hoadon_thue_phong htp
JOIN quanly.phong p ON htp.id_p = p.id_p
JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp;

-- 5.2. Recreate branch revenue view using the refactored dynamic room cost function
CREATE OR REPLACE VIEW hoadon.v_doanh_thu_chi_nhanh AS
SELECT 
    cn.id_cn,
    cn.ten_cn,
    COALESCE(SUM(hoadon.func_tinh_tien_phong(h.id_hd, htp.id_p)), 0::money)::numeric AS tong_doanh_thu_thue_phong,
    COUNT(DISTINCT h.id_hd) AS so_hoa_don
FROM quanly.chinhanh cn
LEFT JOIN quanly.loaiphong lp ON cn.id_cn = lp.id_cn
LEFT JOIN quanly.phong p ON lp.id_lp = p.id_lp
LEFT JOIN hoadon.hoadon_thue_phong htp ON p.id_p = htp.id_p
LEFT JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd AND h.trang_thai = 'Đã thanh toán'
GROUP BY cn.id_cn, cn.ten_cn;
