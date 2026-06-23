-- Migration: V32 - Create booking and cancellation action history log table and populate it with existing records
CREATE TABLE hoadon.lich_su_thao_tac (
    id_ls SERIAL PRIMARY KEY,
    thao_tac VARCHAR(50) NOT NULL, -- 'Đặt phòng' hoặc 'Hủy đặt phòng'
    id_hd INT NOT NULL,
    id_kh INT,
    ho_ten_kh VARCHAR(255),
    id_nv INT,
    ten_nv VARCHAR(255),
    id_p INT,
    thoi_gian TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Seed with existing booking actions
INSERT INTO hoadon.lich_su_thao_tac (thao_tac, id_hd, id_kh, ho_ten_kh, id_nv, ten_nv, id_p, thoi_gian)
SELECT 
    'Đặt phòng'::varchar,
    h.id_hd,
    h.id_kh,
    kh.ho_ten,
    h.id_nv,
    nv.ten_nv,
    htp.id_p,
    COALESCE(htp.ngaynhan, h.ngaylap::timestamp)
FROM hoadon.hoadon h
JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
LEFT JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
LEFT JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv;

-- Seed with existing cancellation actions
INSERT INTO hoadon.lich_su_thao_tac (thao_tac, id_hd, id_kh, ho_ten_kh, id_nv, ten_nv, id_p, thoi_gian)
SELECT 
    'Hủy đặt phòng'::varchar,
    h.id_hd,
    h.id_kh,
    kh.ho_ten,
    h.id_nv,
    nv.ten_nv,
    htp.id_p,
    COALESCE(h.ngaythanhtoan::timestamp, h.ngaylap::timestamp + interval '2 hours')
FROM hoadon.hoadon h
JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
LEFT JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
LEFT JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv
WHERE h.trang_thai = 'Đã hủy';
