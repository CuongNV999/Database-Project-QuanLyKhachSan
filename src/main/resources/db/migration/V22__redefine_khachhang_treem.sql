-- Migration: V22 - Redefine khachhang_treem composite primary key (drop default sequence from id_tre_em)

-- 1. Remove the default sequence value from id_tre_em
ALTER TABLE khachhang.khachhang_treem ALTER COLUMN id_tre_em DROP DEFAULT;

-- 2. Drop the sequence as it is no longer used for local discriminators
DROP SEQUENCE IF EXISTS khachhang.khachhang_treem_id_tre_em_seq CASCADE;
