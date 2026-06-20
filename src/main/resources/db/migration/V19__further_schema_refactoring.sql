-- Migration: V19 - Thêm hội viên Basic, xóa bảng chucvu chuyển lương sang nhanvien, và xóa gia_tien của cosovatchat
-- -----------------------------------------------------------------------------------------------------------------

-- 1. Thêm hội viên hạng Basic vào bảng muchoivien
INSERT INTO khachhang.muchoivien (id_mhv, hang, dieu_kien_luu_tru, muc_giam_gia)
VALUES (4, 'Basic', 'Không có', 0.00)
ON CONFLICT (id_mhv) DO NOTHING;

-- Đồng bộ seq cho muchoivien_id_mhv_seq
SELECT pg_catalog.setval('khachhang.muchoivien_id_mhv_seq', 4, true);

-- Cập nhật tất cả hội viên chưa đạt mốc Bronze/Silver/Gold (id_mhv IS NULL) thành Basic (id_mhv = 4)
UPDATE khachhang.hoivien
SET id_mhv = 4
WHERE id_mhv IS NULL;

-- 2. Xóa bảng chucvu, chuyển thuộc tính lương vào nhanvien
-- Thêm cột luong vào bảng nhanvien
ALTER TABLE nhansu.nhanvien ADD COLUMN luong MONEY DEFAULT 0::numeric::money;

-- Sao chép dữ liệu lương từ bảng chucvu sang nhanvien trước khi xóa bảng chucvu
UPDATE nhansu.nhanvien nv
SET luong = cv.luong
FROM nhansu.chucvu cv
WHERE nv.chuc_vu = cv.chuc_vu;

-- Xóa ràng buộc khóa ngoại tới bảng chucvu và xóa bảng chucvu
ALTER TABLE nhansu.nhanvien DROP CONSTRAINT IF EXISTS nhanvien_chuc_vu_fkey;
DROP TABLE IF EXISTS nhansu.chucvu CASCADE;

-- 3. Xóa thuộc tính gia_tien trong bảng cosovatchat
ALTER TABLE quanly.cosovatchat DROP COLUMN IF EXISTS gia_tien CASCADE;

-- 4. Cập nhật lại các hàm trigger và helper liên quan đến hội viên

-- Trigger tự động nâng hạng hội viên
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
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Basic';
    END IF;
    
    NEW.id_mhv := v_id_mhv;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Hàm tính tỷ lệ phụ thu check-out muộn
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

    IF p_ngaytra_thucte::date > v_expected_date THEN
        RETURN 1.00;
    END IF;

    IF p_hang_hv IS NULL OR p_hang_hv = '' OR p_hang_hv = 'Basic' OR p_hang_hv = 'Bronze' THEN
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
