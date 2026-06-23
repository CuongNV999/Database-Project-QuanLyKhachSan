-- Migration: V10 - Add price to facilities and create facility maintenance table

-- 1. Add gia_tien attribute to quanly.cosovatchat with a default value and a check constraint
ALTER TABLE quanly.cosovatchat ADD COLUMN gia_tien MONEY DEFAULT 0::numeric::money;
ALTER TABLE quanly.cosovatchat ADD CONSTRAINT cosovatchat_giatien_check CHECK (gia_tien >= 0::numeric::money);

