-- Migration: V30 - Drop obsolete 9-argument overloaded quanly.func_tim_va_dat_phong_nhanh to resolve overloading ambiguity
DROP FUNCTION IF EXISTS quanly.func_tim_va_dat_phong_nhanh(INT, INT, INT, VARCHAR, VARCHAR, TIMESTAMP, TIMESTAMP, MONEY, MONEY) CASCADE;
