-- Migration: V23 - Make khachhang_treem a standalone entity with a single primary key (id_tre_em)

-- 1. Drop the composite primary key constraint
ALTER TABLE khachhang.khachhang_treem DROP CONSTRAINT IF EXISTS khachhang_treem_pkey;

-- 2. Recreate the sequence for id_tre_em
CREATE SEQUENCE IF NOT EXISTS khachhang.khachhang_treem_id_tre_em_seq START WITH 1001;

-- 3. Set default value for id_tre_em using the recreated sequence
ALTER TABLE khachhang.khachhang_treem ALTER COLUMN id_tre_em SET DEFAULT nextval('khachhang.khachhang_treem_id_tre_em_seq'::regclass);

-- 4. Add new primary key constraint on id_tre_em
ALTER TABLE khachhang.khachhang_treem ADD CONSTRAINT khachhang_treem_pkey PRIMARY KEY (id_tre_em);
