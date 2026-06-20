-- Migration: V13 - Refactor membership tables and attributes to match ERD

-- 1. Drop index and foreign key constraints on hoivien
ALTER TABLE khachhang.hoivien DROP CONSTRAINT IF EXISTS hoivien_hang_fkey;
DROP INDEX IF EXISTS khachhang.idx_hoivien_hang;

-- 2. Rename hanghoivien to muchoivien
ALTER TABLE khachhang.hanghoivien RENAME TO muchoivien;

-- 3. Rename check constraint
ALTER TABLE khachhang.muchoivien RENAME CONSTRAINT hanghoivien_muc_giam_gia_check TO muchoivien_muc_giam_gia_check;
ALTER TABLE khachhang.muchoivien RENAME CONSTRAINT hanghoivien_pkey TO muchoivien_pkey_old;

-- 4. Add id_mhv SERIAL column and set as primary key
ALTER TABLE khachhang.muchoivien ADD COLUMN id_mhv SERIAL;
ALTER TABLE khachhang.muchoivien DROP CONSTRAINT muchoivien_pkey_old;
ALTER TABLE khachhang.muchoivien ADD CONSTRAINT muchoivien_pkey PRIMARY KEY (id_mhv);

-- 5. Add id_mhv column to hoivien
ALTER TABLE khachhang.hoivien ADD COLUMN id_mhv INTEGER;

-- 6. Populate hoivien.id_mhv by matching old hang value
UPDATE khachhang.hoivien hv
SET id_mhv = mhv.id_mhv
FROM khachhang.muchoivien mhv
WHERE hv.hang = mhv.hang;

-- 7. Drop old hang column from hoivien
ALTER TABLE khachhang.hoivien DROP COLUMN hang;

-- 8. Add foreign key constraint and index to hoivien
ALTER TABLE khachhang.hoivien ADD CONSTRAINT hoivien_id_mhv_fkey FOREIGN KEY (id_mhv) REFERENCES khachhang.muchoivien(id_mhv) ON DELETE SET NULL;
CREATE INDEX idx_hoivien_id_mhv ON khachhang.hoivien USING btree (id_mhv);


-- 9. Recreate trigger function: khachhang.func_tu_dong_nang_hang_hoi_vien
CREATE OR REPLACE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien()
RETURNS TRIGGER AS $$
DECLARE
    v_id_mhv INT;
BEGIN
    -- Xác định hạng hội viên dựa trên điểm tích lũy:
    -- < 100 điểm: Hạng NULL
    -- Từ 100 đến 299 điểm: Bronze
    -- Từ 300 đến 799 điểm: Silver
    -- Từ 800 điểm trở lên: Gold
    IF NEW.diem_tich_luy >= 800 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Gold';
    ELSIF NEW.diem_tich_luy >= 300 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Silver';
    ELSIF NEW.diem_tich_luy >= 100 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Bronze';
    ELSE
        v_id_mhv := NULL;
    END IF;
    
    NEW.id_mhv := v_id_mhv;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-register loyalty rank trigger
DROP TRIGGER IF EXISTS trg_tu_dong_nang_hang_hoivien ON khachhang.hoivien;
CREATE TRIGGER trg_tu_dong_nang_hang_hoivien
BEFORE UPDATE OF diem_tich_luy ON khachhang.hoivien
FOR EACH ROW
EXECUTE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien();


-- 10. Recreate helper function: hoadon.func_tinh_tong_tien_hoa_don
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tien_phong MONEY := 0::money;
    v_tien_dich_vu MONEY := 0::money;
    v_giam_gia_percent NUMERIC(5,2) := 0.00;
    v_tong_tien MONEY := 0::money;
BEGIN
    -- 1. Tính tổng tiền thuê các phòng của hóa đơn
    SELECT COALESCE(SUM(tong_tien), 0::money)
    INTO v_tien_phong
    FROM hoadon.hoadon_thue_phong
    WHERE id_hd = p_id_hd;

    -- 2. Tính tổng tiền sử dụng dịch vụ của hóa đơn
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tien_dich_vu
    FROM hoadon.hoadon_sudung_dichvu hsd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE hsd.id_hd = p_id_hd;

    -- 3. Lấy mức giảm giá hội viên của khách hàng liên kết với hóa đơn (dùng LEFT JOIN đề phòng không phải hội viên)
    SELECT COALESCE(mhv.muc_giam_gia, 0.00)
    INTO v_giam_gia_percent
    FROM hoadon.hoadon h
    JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
    LEFT JOIN khachhang.hoivien hv ON kh.id_hv = hv.id_hv
    LEFT JOIN khachhang.muchoivien mhv ON hv.id_mhv = mhv.id_mhv
    WHERE h.id_hd = p_id_hd;

    -- Đảm bảo không bị NULL nếu câu truy vấn không trả về dòng nào
    v_giam_gia_percent := COALESCE(v_giam_gia_percent, 0.00);

    -- 4. Tính toán tổng tiền sau giảm giá
    v_tong_tien := (v_tien_phong + v_tien_dich_vu) * (1 - v_giam_gia_percent / 100);

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;
