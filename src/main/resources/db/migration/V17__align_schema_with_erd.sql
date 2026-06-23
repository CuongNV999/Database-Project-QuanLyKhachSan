-- Migration: V17 - Align database schema and objects with ERD

-- 1. Table khachhang.muchoivien: Rename column dieu_kien -> dieu_kien_luu_tru
ALTER TABLE khachhang.muchoivien RENAME COLUMN dieu_kien TO dieu_kien_luu_tru;

-- 2. Table khachhang.hoivien: Rename column diem_tich_luy -> tong_luu_tru, and drop id_cn
ALTER TABLE khachhang.hoivien RENAME COLUMN diem_tich_luy TO tong_luu_tru;

ALTER TABLE khachhang.hoivien DROP CONSTRAINT IF EXISTS hoivien_id_cn_fkey;
DROP INDEX IF EXISTS khachhang.idx_hoivien_id_cn;
ALTER TABLE khachhang.hoivien DROP COLUMN IF EXISTS id_cn;

-- 3. Table khachhang.khachhang: Add column la_knn
ALTER TABLE khachhang.khachhang ADD COLUMN la_knn BOOLEAN DEFAULT FALSE;

-- 4. Table quanly.phong: Add column id_cn and establish relationships
ALTER TABLE quanly.phong ADD COLUMN id_cn INTEGER;
UPDATE quanly.phong p SET id_cn = lp.id_cn FROM quanly.loaiphong lp WHERE p.id_lp = lp.id_lp;
ALTER TABLE quanly.phong ADD CONSTRAINT phong_id_cn_fkey FOREIGN KEY (id_cn) REFERENCES quanly.chinhanh(id_cn) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_phong_id_cn ON quanly.phong(id_cn);



-- 6. Recreate Trigger & Helper Functions due to column/table renames

-- Trigger: khachhang.func_tu_dong_nang_hang_hoi_vien()
CREATE OR REPLACE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien()
RETURNS TRIGGER AS $$
DECLARE
    v_id_mhv INT;
BEGIN
    IF NEW.tong_luu_tru >= 80 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Diamond';
    ELSIF NEW.tong_luu_tru >= 40 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Gold';
    ELSIF NEW.tong_luu_tru >= 20 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Bronze';
    ELSE
        v_id_mhv := NULL;
    END IF;
    
    NEW.id_mhv := v_id_mhv;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tu_dong_nang_hang_hoivien ON khachhang.hoivien;
CREATE TRIGGER trg_tu_dong_nang_hang_hoivien
BEFORE UPDATE OF tong_luu_tru ON khachhang.hoivien
FOR EACH ROW
EXECUTE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien();

-- Trigger: hoadon.func_cap_nhat_diem_tich_luy()
CREATE OR REPLACE FUNCTION hoadon.func_cap_nhat_diem_tich_luy()
RETURNS TRIGGER AS $$
DECLARE
    v_id_hv INT;
    v_tong_so_dem INT := 0;
BEGIN
    IF NEW.trang_thai = 'Đã thanh toán' AND (OLD.trang_thai IS NULL OR OLD.trang_thai != 'Đã thanh toán') THEN
        SELECT id_hv INTO v_id_hv FROM khachhang.khachhang WHERE id_kh = NEW.id_kh;
        IF v_id_hv IS NOT NULL THEN
            SELECT COALESCE(SUM(EXTRACT(DAY FROM (ngaytra - ngaynhan))::INT), 0)
            INTO v_tong_so_dem
            FROM hoadon.hoadon_thue_phong
            WHERE id_hd = NEW.id_hd;
            
            IF v_tong_so_dem <= 0 THEN
                v_tong_so_dem := 1;
            END IF;
            
            UPDATE khachhang.hoivien
            SET tong_luu_tru = tong_luu_tru + v_tong_so_dem
            WHERE id_hv = v_id_hv;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


