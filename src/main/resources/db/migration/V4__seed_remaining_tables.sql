-- -------------------------------------------------------------
-- Seed data for remaining empty tables in public schema
-- -------------------------------------------------------------

-- 1. Seed public.chusohuu (Branch Owners)
INSERT INTO public.chusohuu (id_csh, ten_csh, email, sdt) VALUES
(1, 'Nguyễn Văn An', 'an.nguyen@owner.homestay.vn', '0901234567'),
(2, 'Trần Thị Bình', 'binh.tran@owner.homestay.vn', '0912345678'),
(3, 'Lê Hoài Nam', 'nam.le@owner.homestay.vn', '0923456789'),
(4, 'Phạm Minh Đức', 'duc.pham@owner.homestay.vn', '0934567890'),
(5, 'Hoàng Thu Trang', 'trang.hoang@owner.homestay.vn', '0945678901')
ON CONFLICT (id_csh) DO NOTHING;

SELECT pg_catalog.setval('public.chusohuu_id_csh_seq', 5, true);

-- 2. Seed public.chinhanh_chusohuu
INSERT INTO public.chinhanh_chusohuu (id_cn, id_csh) VALUES
(1, 1), (2, 1),
(3, 2), (4, 2),
(5, 3), (6, 3),
(7, 4), (8, 4),
(9, 5), (10, 5),
(1, 2), (5, 4)
ON CONFLICT (id_cn, id_csh) DO NOTHING;

-- 3. Seed public.dichvu (Services)
INSERT INTO public.dichvu (id_dv, ten_dv, gia, loai_dv) VALUES
(1, 'Ăn sáng buffet tại nhà hàng', 150000.00, 'Ẩm thực'),
(2, 'Dịch vụ giặt ủi nhanh', 50000.00, 'Giặt là'),
(3, 'Thuê xe máy tự lái (24h)', 150000.00, 'Phương tiện'),
(4, 'Xe đón/tiễn sân bay (4 chỗ)', 450000.00, 'Vận chuyển'),
(5, 'Massage & Spa trị liệu (60 phút)', 350000.00, 'Chăm sóc sức khỏe'),
(6, 'Nước ngọt/Bia mini bar', 25500.00, 'Ẩm thực'),
(7, 'Đặt tour du lịch địa phương', 400000.00, 'Giải trí'),
(8, 'Tổ chức tiệc nướng BBQ ngoài trời', 600000.00, 'Dịch vụ gia đình'),
(9, 'Trang trí phòng trăng mật/sinh nhật', 300000.00, 'Sự kiện'),
(10, 'Thuê phao bơi & Đồ tắm', 30000.00, 'Tiện ích')
ON CONFLICT (id_dv) DO NOTHING;

SELECT pg_catalog.setval('public.dichvu_id_dv_seq', 10, true);

-- 4. Seed public.doankhach
INSERT INTO public.doankhach (id_doan, so_thanh_vien) VALUES
(1, 3), (2, 4), (3, 5), (4, 2), (5, 6),
(6, 3), (7, 4), (8, 5), (9, 2), (10, 7),
(11, 3), (12, 4), (13, 5), (14, 2), (15, 6),
(16, 3), (17, 4), (18, 5), (19, 2), (20, 8)
ON CONFLICT (id_doan) DO NOTHING;

SELECT pg_catalog.setval('public.doankhach_id_doan_seq', 20, true);

-- Link existing customers to these groups in public.khachhang
-- (Only run updates if we are not already linked or we just want to ensure linkage)
UPDATE public.khachhang SET id_doan = 1 WHERE id_kh BETWEEN 101 AND 103 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 2 WHERE id_kh BETWEEN 104 AND 107 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 3 WHERE id_kh BETWEEN 108 AND 112 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 4 WHERE id_kh BETWEEN 113 AND 114 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 5 WHERE id_kh BETWEEN 115 AND 120 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 6 WHERE id_kh BETWEEN 121 AND 123 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 7 WHERE id_kh BETWEEN 124 AND 127 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 8 WHERE id_kh BETWEEN 128 AND 132 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 9 WHERE id_kh BETWEEN 133 AND 134 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 10 WHERE id_kh BETWEEN 135 AND 141 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 11 WHERE id_kh BETWEEN 142 AND 144 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 12 WHERE id_kh BETWEEN 145 AND 148 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 13 WHERE id_kh BETWEEN 149 AND 153 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 14 WHERE id_kh BETWEEN 154 AND 155 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 15 WHERE id_kh BETWEEN 156 AND 161 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 16 WHERE id_kh BETWEEN 162 AND 164 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 17 WHERE id_kh BETWEEN 165 AND 168 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 18 WHERE id_kh BETWEEN 169 AND 173 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 19 WHERE id_kh BETWEEN 174 AND 175 AND id_doan IS NULL;
UPDATE public.khachhang SET id_doan = 20 WHERE id_kh BETWEEN 176 AND 183 AND id_doan IS NULL;

-- 5. Seed public.truongdoan (Group Leaders)
INSERT INTO public.truongdoan (id_doan, id_kh) VALUES
(1, 101),
(2, 104),
(3, 108),
(4, 113),
(5, 115),
(6, 121),
(7, 124),
(8, 128),
(9, 133),
(10, 135),
(11, 142),
(12, 145),
(13, 149),
(14, 154),
(15, 156),
(16, 162),
(17, 165),
(18, 169),
(19, 174),
(20, 176)
ON CONFLICT (id_doan) DO NOTHING;

-- 6. Seed public.hoadon_sudung_dichvu (Service usage for ~20% of the invoices)
INSERT INTO public.hoadon_sudung_dichvu (id_hd, id_dv, so_luong)
SELECT DISTINCT ON (h.id_hd)
    h.id_hd,
    (1 + (h.id_hd * 3) % 10)::int AS id_dv,
    (1 + (h.id_hd * 7) % 5)::int AS so_luong
FROM public.hoadon h
WHERE h.id_hd % 5 = 0
  AND NOT EXISTS (SELECT 1 FROM public.hoadon_sudung_dichvu);

-- 7. Seed public.khachhang_treem (Children under 18)
INSERT INTO public.khachhang_treem (id_kh, ten_tre_em, tuoi)
SELECT 
    id_kh,
    'Trẻ em của ' || ho_ten AS ten_tre_em,
    (1 + (id_kh % 15))::int AS tuoi
FROM public.khachhang
WHERE id_kh BETWEEN 500 AND 600 AND id_kh % 3 = 0
  AND NOT EXISTS (SELECT 1 FROM public.khachhang_treem);

SELECT pg_catalog.setval('public.khachhang_treem_id_tre_em_seq', (SELECT COALESCE(MAX(id_tre_em), 1) FROM public.khachhang_treem), true);

-- 8. Seed public.phong_trangbi_csvc (Equip amenities for all 100 rooms)
-- Only seed if phong_trangbi_csvc is currently empty
INSERT INTO public.phong_trangbi_csvc (id_p, id_csvc, so_luong, tinh_trang)
SELECT id_p, 1, 1 + (id_p % 2), 'Tốt' FROM public.phong
WHERE NOT EXISTS (SELECT 1 FROM public.phong_trangbi_csvc);

INSERT INTO public.phong_trangbi_csvc (id_p, id_csvc, so_luong, tinh_trang)
SELECT id_p, 2, 1, 'Tốt' FROM public.phong
WHERE NOT EXISTS (SELECT 1 FROM public.phong_trangbi_csvc WHERE id_csvc = 2);

INSERT INTO public.phong_trangbi_csvc (id_p, id_csvc, so_luong, tinh_trang)
SELECT id_p, 3, 2, 'Tốt' FROM public.phong
WHERE NOT EXISTS (SELECT 1 FROM public.phong_trangbi_csvc WHERE id_csvc = 3);

INSERT INTO public.phong_trangbi_csvc (id_p, id_csvc, so_luong, tinh_trang)
SELECT id_p, 4, 2, 'Tốt' FROM public.phong
WHERE NOT EXISTS (SELECT 1 FROM public.phong_trangbi_csvc WHERE id_csvc = 4);

INSERT INTO public.phong_trangbi_csvc (id_p, id_csvc, so_luong, tinh_trang)
SELECT id_p, 5, 2, 'Mới' FROM public.phong
WHERE NOT EXISTS (SELECT 1 FROM public.phong_trangbi_csvc WHERE id_csvc = 5);

INSERT INTO public.phong_trangbi_csvc (id_p, id_csvc, so_luong, tinh_trang)
SELECT id_p, 6, 2, 'Mới' FROM public.phong
WHERE NOT EXISTS (SELECT 1 FROM public.phong_trangbi_csvc WHERE id_csvc = 6);
