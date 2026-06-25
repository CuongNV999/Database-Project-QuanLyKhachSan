-- ============================================================
-- File: 02_create_tables.sql
-- Mục đích: Tạo tất cả các bảng của CSDL quanlykhachsan
-- Phiên bản: Tương đương sau migration V36
-- ============================================================

SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;

-- ============================================================
-- SCHEMA: quanly
-- ============================================================

-- 1. quanly.chinhanh
CREATE TABLE quanly.chinhanh (
    id_cn SERIAL PRIMARY KEY,
    ten_cn VARCHAR(255) NOT NULL,
    dia_chi TEXT
);

-- 2. quanly.chusohuu
CREATE TABLE quanly.chusohuu (
    id_csh SERIAL PRIMARY KEY,
    ten_csh VARCHAR(255) NOT NULL,
    email VARCHAR(255),
    sdt VARCHAR(20)
);

-- 3. quanly.chinhanh_chusohuu (bảng liên kết N-N)
CREATE TABLE quanly.chinhanh_chusohuu (
    id_cn INTEGER NOT NULL,
    id_csh INTEGER NOT NULL,
    PRIMARY KEY (id_cn, id_csh)
);

-- 4. quanly.loaiphong
CREATE TABLE quanly.loaiphong (
    id_lp SERIAL PRIMARY KEY,
    chat_luong VARCHAR(100),
    loai_giuong VARCHAR(50),
    view VARCHAR(100),
    dien_tich VARCHAR(50),
    doi_tuong VARCHAR(100),
    gia_tien MONEY,
    id_cn INTEGER
);

-- 5. quanly.phong
CREATE TABLE quanly.phong (
    id_p SERIAL PRIMARY KEY,
    dia_chi TEXT,
    trang_thai VARCHAR(100),
    id_lp INTEGER,
    id_cn INTEGER
);

-- 6. quanly.cosovatchat
CREATE TABLE quanly.cosovatchat (
    id_csvc SERIAL PRIMARY KEY,
    ten_csvc VARCHAR(255) NOT NULL,
    mo_ta TEXT,
    loai_csvc VARCHAR(50),
    gia_den_bu MONEY DEFAULT 0::numeric::money
);

-- 7. quanly.phong_trangbi_csvc (bảng liên kết N-N)
CREATE TABLE quanly.phong_trangbi_csvc (
    id_p INTEGER NOT NULL,
    id_csvc INTEGER NOT NULL,
    so_luong INTEGER,
    tinh_trang VARCHAR(255),
    PRIMARY KEY (id_p, id_csvc),
    CONSTRAINT phong_trangbi_csvc_so_luong_check CHECK (so_luong >= 0)
);


-- ============================================================
-- SCHEMA: nhansu
-- ============================================================

-- 8. nhansu.nhanvien (bảng chucvu đã bị xóa từ V19, cột luong chuyển sang nhanvien)
CREATE TABLE nhansu.nhanvien (
    id_nv SERIAL PRIMARY KEY,
    ten_nv VARCHAR(255) NOT NULL,
    chuc_vu VARCHAR(100),
    id_cn INTEGER,
    luong MONEY DEFAULT 0::numeric::money
);


-- ============================================================
-- SCHEMA: khachhang
-- ============================================================

-- 9. khachhang.muchoivien (đổi tên từ hanghoivien ở V13, thêm id_mhv, đổi tên cột ở V17)
CREATE TABLE khachhang.muchoivien (
    id_mhv SERIAL PRIMARY KEY,
    hang VARCHAR(50),
    dieu_kien_luu_tru TEXT,
    muc_giam_gia NUMERIC(5,2),
    CONSTRAINT muchoivien_muc_giam_gia_check CHECK (muc_giam_gia >= 0 AND muc_giam_gia <= 100)
);

-- 10. khachhang.hoivien (đổi tên cột diem_tich_luy -> tong_luu_tru ở V17, xóa id_cn ở V17)
CREATE TABLE khachhang.hoivien (
    id_hv SERIAL PRIMARY KEY,
    tong_luu_tru INTEGER DEFAULT 0,
    id_mhv INTEGER
);

-- 11. khachhang.doankhach (xóa so_thanh_vien ở V21, thêm id_truong_doan ở V20)
CREATE TABLE khachhang.doankhach (
    id_doan SERIAL PRIMARY KEY,
    id_truong_doan INTEGER
);

-- 12. khachhang.khachhang (thêm la_knn ở V17)
CREATE TABLE khachhang.khachhang (
    id_kh SERIAL PRIMARY KEY,
    cccd VARCHAR(20),
    dia_chi TEXT,
    ho_ten VARCHAR(255) NOT NULL,
    sdt VARCHAR(20),
    quoc_tich VARCHAR(100),
    passport VARCHAR(50),
    visa VARCHAR(50),
    id_hv INTEGER,
    id_doan INTEGER,
    la_knn BOOLEAN DEFAULT FALSE,
    CONSTRAINT khachhang_cccd_key UNIQUE (cccd)
);

-- 13. khachhang.khachhang_treem (standalone entity từ V23, single PK id_tre_em)
CREATE SEQUENCE IF NOT EXISTS khachhang.khachhang_treem_id_tre_em_seq START WITH 1001;

CREATE TABLE khachhang.khachhang_treem (
    id_tre_em INTEGER DEFAULT nextval('khachhang.khachhang_treem_id_tre_em_seq'::regclass) NOT NULL,
    id_kh INTEGER NOT NULL,
    ten_tre_em VARCHAR(255) NOT NULL,
    tuoi INTEGER,
    PRIMARY KEY (id_tre_em),
    CONSTRAINT khachhang_treem_tuoi_check CHECK (tuoi >= 0)
);


-- ============================================================
-- SCHEMA: hoadon
-- ============================================================

-- 14. hoadon.dichvu
CREATE TABLE hoadon.dichvu (
    id_dv SERIAL PRIMARY KEY,
    ten_dv VARCHAR(255) NOT NULL,
    gia MONEY,
    loai_dv VARCHAR(100),
    CONSTRAINT dichvu_gia_check CHECK (gia >= 0::numeric::money)
);

-- 15. hoadon.hoadon
CREATE TABLE hoadon.hoadon (
    id_hd SERIAL PRIMARY KEY,
    trang_thai VARCHAR(100),
    ngaylap DATE DEFAULT CURRENT_DATE,
    ngaythanhtoan TIMESTAMP WITHOUT TIME ZONE,
    phuongthuc VARCHAR(100),
    id_kh INTEGER,
    id_nv INTEGER
);

-- 16. hoadon.hoadon_thue_phong (sau V36: không còn tien_coc, tong_tien, phu_thu, phu_thu_tieu_hao, phu_thu_hong_hoc)
CREATE TABLE hoadon.hoadon_thue_phong (
    id_hd INTEGER NOT NULL,
    id_p INTEGER NOT NULL,
    ngaynhan TIMESTAMP WITHOUT TIME ZONE,
    ngaytra TIMESTAMP WITHOUT TIME ZONE,
    so_ngay_luu_tru INTEGER,
    PRIMARY KEY (id_hd, id_p),
    CONSTRAINT hoadon_thue_phong_so_ngay_luu_tru_check CHECK (so_ngay_luu_tru > 0)
);

-- 17. hoadon.hoadon_sudung_dichvu
CREATE TABLE hoadon.hoadon_sudung_dichvu (
    id_hd INTEGER NOT NULL,
    id_dv INTEGER NOT NULL,
    so_luong INTEGER,
    PRIMARY KEY (id_hd, id_dv),
    CONSTRAINT hoadon_sudung_dichvu_so_luong_check CHECK (so_luong > 0)
);

-- 18. hoadon.phu_thu_phong (bảng mới từ V36 - normalized surcharges)
CREATE TABLE hoadon.phu_thu_phong (
    id_hd INTEGER NOT NULL,
    id_p INTEGER NOT NULL,
    loai_phu_thu VARCHAR(100) NOT NULL, -- 'Tiêu hao' hoặc 'Hỏng hóc'
    so_tien MONEY NOT NULL DEFAULT 0::money,
    PRIMARY KEY (id_hd, id_p, loai_phu_thu)
);

-- 19. hoadon.lich_su_thao_tac (bảng mới từ V32)
CREATE TABLE hoadon.lich_su_thao_tac (
    id_ls SERIAL PRIMARY KEY,
    thao_tac VARCHAR(50) NOT NULL, -- 'Đặt phòng', 'Hủy đặt phòng', 'Thanh toán (Check-out)'
    id_hd INTEGER NOT NULL,
    id_kh INTEGER,
    ho_ten_kh VARCHAR(255),
    id_nv INTEGER,
    ten_nv VARCHAR(255),
    id_p INTEGER,
    thoi_gian TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
