-- Migration: V10 - Add price to facilities and create facility maintenance table

-- 1. Add gia_tien attribute to quanly.cosovatchat with a default value and a check constraint
ALTER TABLE quanly.cosovatchat ADD COLUMN gia_tien MONEY DEFAULT 0::numeric::money;
ALTER TABLE quanly.cosovatchat ADD CONSTRAINT cosovatchat_giatien_check CHECK (gia_tien >= 0::numeric::money);

-- 2. Create quanly.cosovatchat_duoc_baotri table
CREATE TABLE quanly.cosovatchat_duoc_baotri (
    id_bao_tri SERIAL PRIMARY KEY,
    id_csvc INTEGER NOT NULL,
    thoi_gian_bat_dau TIMESTAMP NOT NULL,
    thoi_gian_ket_thuc TIMESTAMP,
    CONSTRAINT fk_cosovatchat_baotri FOREIGN KEY (id_csvc) REFERENCES quanly.cosovatchat(id_csvc) ON DELETE CASCADE,
    CONSTRAINT chk_ngay_bao_tri CHECK (thoi_gian_ket_thuc IS NULL OR thoi_gian_ket_thuc >= thoi_gian_bat_dau)
);
