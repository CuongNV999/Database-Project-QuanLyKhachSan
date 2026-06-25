-- ============================================================
-- File: 09_seed_data.sql
-- Mục đích: Chèn dữ liệu cố định/tham chiếu cho CSDL quanlykhachsan
-- Phiên bản: Tương đương sau migration V36
-- ============================================================

SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;

-- ============================================================
-- 1. DỮ LIỆU CỐ ĐỊNH: Mức hội viên (muchoivien)
-- ============================================================

-- Hạng Basic (không giảm giá, dành cho hội viên mới chưa đạt mốc)
INSERT INTO khachhang.muchoivien (id_mhv, hang, dieu_kien_luu_tru, muc_giam_gia)
VALUES (4, 'Basic', 'Không có', 0.00)
ON CONFLICT (id_mhv) DO NOTHING;

-- Hạng Bronze (Giảm 5%, lưu trú >= 20 đêm)
INSERT INTO khachhang.muchoivien (id_mhv, hang, dieu_kien_luu_tru, muc_giam_gia)
VALUES (1, 'Bronze', 'Lưu trú tối thiểu 20 đêm', 5.00)
ON CONFLICT (id_mhv) DO NOTHING;

-- Hạng Silver (Giảm 15%, lưu trú >= 40 đêm, check-out muộn đến 16:00 miễn phí)
INSERT INTO khachhang.muchoivien (id_mhv, hang, dieu_kien_luu_tru, muc_giam_gia)
VALUES (2, 'Silver', 'Lưu trú tối thiểu 40 đêm', 15.00)
ON CONFLICT (id_mhv) DO NOTHING;

-- Hạng Gold (Giảm 30%, lưu trú >= 80 đêm, check-out muộn đến 18:00 miễn phí)
INSERT INTO khachhang.muchoivien (id_mhv, hang, dieu_kien_luu_tru, muc_giam_gia)
VALUES (3, 'Gold', 'Lưu trú tối thiểu 80 đêm', 30.00)
ON CONFLICT (id_mhv) DO NOTHING;

-- Đồng bộ sequence cho muchoivien
SELECT pg_catalog.setval('khachhang.muchoivien_id_mhv_seq', 4, true);
