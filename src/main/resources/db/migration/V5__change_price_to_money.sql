-- -------------------------------------------------------------
-- 1. Configure database level lc_monetary
-- -------------------------------------------------------------
ALTER DATABASE quanlykhachsan SET lc_monetary TO 'vi-VN';
SET lc_monetary TO 'vi-VN';

-- -------------------------------------------------------------
-- 2. Drop dependent views, functions and check constraints
-- -------------------------------------------------------------
DROP VIEW IF EXISTS public.v_doanh_thu_chi_nhanh;
DROP VIEW IF EXISTS public.v_phong_status_detail;
DROP TRIGGER IF EXISTS trg_sau_khi_thanh_toan_hoadon ON public.hoadon;
DROP FUNCTION IF EXISTS public.func_cap_nhat_diem_tich_luy() CASCADE;
DROP FUNCTION IF EXISTS public.func_tinh_tien_phong(integer, integer) CASCADE;

-- Drop constraints that compare with numeric
ALTER TABLE public.chucvu DROP CONSTRAINT IF EXISTS chucvu_luong_check;
ALTER TABLE public.dichvu DROP CONSTRAINT IF EXISTS dichvu_gia_check;

-- -------------------------------------------------------------
-- 3. Alter columns and convert values from USD to VND (rate 25,000)
-- -------------------------------------------------------------

-- public.chucvu (luong)
ALTER TABLE public.chucvu ALTER COLUMN luong TYPE money USING (luong * 25000)::money;

-- public.cosovatchat (gia_den_bu)
ALTER TABLE public.cosovatchat ALTER COLUMN gia_den_bu TYPE money USING (gia_den_bu * 25000)::money;

-- public.dichvu (gia) - already in VND, just convert type
ALTER TABLE public.dichvu ALTER COLUMN gia TYPE money USING gia::money;

-- public.loaiphong (gia_tien)
ALTER TABLE public.loaiphong ALTER COLUMN gia_tien TYPE money USING (gia_tien * 25000)::money;

-- public.hoadon_thue_phong (tien_coc, phu_thu, tong_tien)
ALTER TABLE public.hoadon_thue_phong ALTER COLUMN tien_coc TYPE money USING (tien_coc * 25000)::money;
ALTER TABLE public.hoadon_thue_phong ALTER COLUMN phu_thu TYPE money USING (phu_thu * 25000)::money;
ALTER TABLE public.hoadon_thue_phong ALTER COLUMN tong_tien TYPE money USING (tong_tien * 25000)::money;

-- Re-add constraints comparing with money type
ALTER TABLE public.chucvu ADD CONSTRAINT chucvu_luong_check CHECK (luong >= 0::numeric::money);
ALTER TABLE public.dichvu ADD CONSTRAINT dichvu_gia_check CHECK (gia >= 0::numeric::money);

-- -------------------------------------------------------------
-- 4. Recreate functions and views
-- -------------------------------------------------------------

-- Recreate func_tinh_tien_phong returning MONEY
CREATE OR REPLACE FUNCTION public.func_tinh_tien_phong(id_hd_input INT, id_p_input INT)
RETURNS MONEY AS $$
DECLARE
    v_ngaynhan TIMESTAMP;
    v_ngaytra TIMESTAMP;
    v_gia_tien MONEY;
    v_tien_coc MONEY;
    v_phu_thu MONEY;
    v_so_ngay INT;
    v_tong_tien MONEY;
BEGIN
    SELECT ngaynhan, ngaytra, tien_coc, phu_thu
    INTO v_ngaynhan, v_ngaytra, v_tien_coc, v_phu_thu
    FROM public.hoadon_thue_phong
    WHERE id_hd = id_hd_input AND id_p = id_p_input;

    SELECT lp.gia_tien
    INTO v_gia_tien
    FROM public.phong p
    JOIN public.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE p.id_p = id_p_input;

    v_so_ngay := EXTRACT(DAY FROM (v_ngaytra - v_ngaynhan))::INT;
    IF v_so_ngay <= 0 THEN
        v_so_ngay := 1;
    END IF;

    v_tong_tien := (v_so_ngay * COALESCE(v_gia_tien, 0::money)) + COALESCE(v_phu_thu, 0::money) - COALESCE(v_tien_coc, 0::money);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;

-- Recreate func_cap_nhat_diem_tich_luy supporting MONEY
CREATE OR REPLACE FUNCTION public.func_cap_nhat_diem_tich_luy()
RETURNS TRIGGER AS $$
DECLARE
    v_id_hv INT;
    v_diem_tich_luy_cong INT;
    v_tong_tien_phong MONEY;
BEGIN
    IF NEW.trang_thai = 'Đã thanh toán' AND (OLD.trang_thai IS NULL OR OLD.trang_thai != 'Đã thanh toán') THEN
        SELECT id_hv INTO v_id_hv
        FROM public.khachhang
        WHERE id_kh = NEW.id_kh;

        IF v_id_hv IS NOT NULL THEN
            SELECT COALESCE(SUM(tong_tien), 0::money)
            INTO v_tong_tien_phong
            FROM public.hoadon_thue_phong
            WHERE id_hd = NEW.id_hd;

            v_diem_tich_luy_cong := (v_tong_tien_phong::numeric / 100000)::INT;

            IF v_diem_tich_luy_cong > 0 THEN
                UPDATE public.hoivien
                SET diem_tich_luy = diem_tich_luy + v_diem_tich_luy_cong
                WHERE id_hv = v_id_hv;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sau_khi_thanh_toan_hoadon
AFTER UPDATE OF trang_thai ON public.hoadon
FOR EACH ROW
EXECUTE FUNCTION public.func_cap_nhat_diem_tich_luy();

-- Recreate v_phong_status_detail casting money to numeric for JDBC
CREATE OR REPLACE VIEW public.v_phong_status_detail AS
SELECT 
    p.id_p,
    cn.ten_cn,
    p.dia_chi,
    lp.chat_luong,
    lp.loai_giuong,
    lp.view,
    lp.dien_tich,
    lp.gia_tien::numeric AS gia_tien,
    p.trang_thai
FROM public.phong p
LEFT JOIN public.loaiphong lp ON p.id_lp = lp.id_lp
LEFT JOIN public.chinhanh cn ON lp.id_cn = cn.id_cn;

-- Recreate v_doanh_thu_chi_nhanh casting money to numeric for JDBC
CREATE OR REPLACE VIEW public.v_doanh_thu_chi_nhanh AS
SELECT 
    cn.id_cn,
    cn.ten_cn,
    COALESCE(SUM(htp.tong_tien), 0::money)::numeric AS tong_doanh_thu_thue_phong,
    COUNT(DISTINCT h.id_hd) AS so_hoa_don
FROM public.chinhanh cn
LEFT JOIN public.loaiphong lp ON cn.id_cn = lp.id_cn
LEFT JOIN public.phong p ON lp.id_lp = p.id_lp
LEFT JOIN public.hoadon_thue_phong htp ON p.id_p = htp.id_p
LEFT JOIN public.hoadon h ON htp.id_hd = h.id_hd AND h.trang_thai = 'Đã thanh toán'
GROUP BY cn.id_cn, cn.ten_cn;
