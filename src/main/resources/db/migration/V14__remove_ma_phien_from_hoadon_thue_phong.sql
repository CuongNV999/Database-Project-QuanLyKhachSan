-- Drop unique constraint and column ma_phien from hoadon.hoadon_thue_phong
ALTER TABLE hoadon.hoadon_thue_phong DROP CONSTRAINT IF EXISTS hoadon_thue_phong_ma_phien_key;
ALTER TABLE hoadon.hoadon_thue_phong DROP COLUMN IF EXISTS ma_phien;
