-- Migration: V28 - Remove maintenance table and related functions

-- 1. Drop the baotri / cosovatchat_duoc_baotri tables if they exist
DROP TABLE IF EXISTS quanly.baotri CASCADE;
DROP TABLE IF EXISTS quanly.cosovatchat_duoc_baotri CASCADE;

-- 2. Drop the thong_ke_tan_suat_hong_hoc function if it exists
DROP FUNCTION IF EXISTS quanly.func_thong_ke_tan_suat_hong_hoc(INTEGER);
