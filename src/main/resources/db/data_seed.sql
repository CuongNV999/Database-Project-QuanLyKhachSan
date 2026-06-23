-- Set environment configurations
SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

-- Temporarily bypass all triggers and constraints for clean inserts
SET session_replication_role = 'replica';

-- Truncate all tables cascadingly
TRUNCATE TABLE 
    quanly.chinhanh, 
    quanly.chusohuu, 
    quanly.chinhanh_chusohuu, 
    quanly.loaiphong, 
    quanly.phong, 
    quanly.cosovatchat, 
    quanly.phong_trangbi_csvc, 
    nhansu.nhanvien, 
    khachhang.muchoivien, 
    khachhang.hoivien, 
    khachhang.doankhach, 
    khachhang.khachhang, 
    khachhang.khachhang_treem, 
    hoadon.dichvu, 
    hoadon.hoadon, 
    hoadon.hoadon_thue_phong, 
    hoadon.hoadon_sudung_dichvu
CASCADE;

-- 1. Seed muchoivien
INSERT INTO khachhang.muchoivien (id_mhv, hang, dieu_kien_luu_tru, muc_giam_gia) VALUES
(1, 'Bronze', 'Lưu trú tối thiểu 20 đêm', 5.00),
(2, 'Silver', 'Lưu trú tối thiểu 40 đêm', 15.00),
(3, 'Gold', 'Lưu trú tối thiểu 80 đêm', 30.00),
(4, 'Basic', 'Không có', 0.00);

-- 2. Seed dichvu
INSERT INTO hoadon.dichvu (id_dv, ten_dv, gia, loai_dv) VALUES
(1, 'Giặt là quần áo', 30000::numeric::money, 'Giặt là'),
(2, 'Thuê xe máy', 150000::numeric::money, 'Phương tiện'),
(3, 'Ăn sáng buffet', 120000::numeric::money, 'Ẩm thực'),
(4, 'Massage toàn thân', 400000::numeric::money, 'Spa'),
(5, 'Nước ngọt từ Minibar', 20000::numeric::money, 'Ẩm thực'),
(6, 'Thuê phao & kính bơi', 30000::numeric::money, 'Giải trí'),
(7, 'Xe điện đưa đón', 50000::numeric::money, 'Vận chuyển');

-- 3. Seed cosovatchat
INSERT INTO quanly.cosovatchat (id_csvc, ten_csvc, mo_ta, loai_csvc, gia_den_bu) VALUES
(1, 'Giường ngủ', 'Giường ngủ gỗ xoan đào', 'Cố định', 1500000::numeric::money),
(2, 'Tivi', 'Smart TV Samsung 43 inch', 'Cố định', 5000000::numeric::money),
(3, 'Điều hòa', 'Điều hòa Daikin 9000 BTU', 'Cố định', 7000000::numeric::money),
(4, 'Khăn tắm', 'Khăn tắm cotton trắng', 'Luân chuyển', 100000::numeric::money),
(5, 'Ga giường', 'Ga giường trắng thêu logo', 'Luân chuyển', 200000::numeric::money),
(6, 'Bàn chải', 'Bàn chải tre dùng 1 lần', 'Tiêu hao', 10000::numeric::money),
(7, 'Nước suối', 'Nước suối đóng chai 500ml', 'Tiêu hao', 15000::numeric::money);

-- 4. Dynamic Data Generation via PL/pgSQL DO block
DO $$
DECLARE
    v_i INT;
    v_c INT;
    v_t INT;
    v_r INT;
    v_e INT;
    v_id_lp INT;
    v_id_p INT;
    v_id_nv INT;
    
    -- Variables for variable branch scale
    v_room_counts INT[] := ARRAY[20, 25, 18, 15, 22, 12, 10, 10, 8, 14];
    v_num_rooms INT;
    v_num_receptionists INT;
    v_num_cleaners INT;
    -- Name arrays for generating realistic names pseudorandomly
    v_last_names TEXT[] := ARRAY['Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Phan', 'Vũ', 'Võ', 'Đặng', 'Bùi'];
    v_mid_names TEXT[] := ARRAY['Văn', 'Thị', 'Minh', 'Anh', 'Đức', 'Duy', 'Hữu', 'Quốc', 'Thanh', 'Ngọc'];
    v_first_names TEXT[] := ARRAY['Nam', 'Trang', 'Hùng', 'Lan', 'Tuấn', 'Hương', 'Hải', 'Bình', 'Sơn', 'Linh', 'Huy', 'Mai', 'Đạt', 'Vy', 'Cường'];
    
    v_foreign_first TEXT[] := ARRAY['John', 'Mary', 'David', 'James', 'Emily', 'Robert', 'Linda', 'Michael', 'Sarah', 'William', 'Jessica', 'Thomas', 'Daniel', 'Karen', 'Nancy'];
    v_foreign_last TEXT[] := ARRAY['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Miller', 'Davis', 'Wilson', 'Anderson', 'Taylor', 'Thomas', 'White', 'Martin', 'Jackson', 'Thompson'];

    -- Address arrays
    v_local_streets TEXT[] := ARRAY['Lê Lợi', 'Nguyễn Huệ', 'Trần Hưng Đạo', 'Phố Cổ', 'Hai Bà Trưng', 'Lý Tự Trọng', 'Điện Biên Phủ', 'Hùng Vương', 'Kim Mã', 'Giải Phóng'];
    v_local_districts TEXT[] := ARRAY['Quận 1', 'Quận 3', 'Quận Hoàn Kiếm', 'Quận Ba Đình', 'Quận Cầu Giấy', 'Quận Hải Châu', 'Quận Ninh Kiều', 'Quận Sơn Trà', 'Quận Liên Chiểu', 'Quận Bình Thạnh'];
    v_local_cities TEXT[] := ARRAY['Hà Nội', 'TP. Hồ Chí Minh', 'Đà Nẵng', 'Nha Trang', 'Phú Quốc', 'Cần Thơ', 'Hải Phòng', 'Huế', 'Đà Lạt', 'Vũng Tàu'];

    v_foreign_addresses TEXT[] := ARRAY['Broadway, New York, USA', 'Oxford Street, London, UK', 'Champs-Élysées, Paris, France', 'Shinjuku, Tokyo, Japan', 'Gangnam, Seoul, South Korea', 'George Street, Sydney, Australia', 'Orchard Road, Singapore', 'Nathan Road, Hong Kong', 'Kaufingerstraße, Munich, Germany', 'Rua Augusta, Lisbon, Portugal'];
    
    v_child_names TEXT[] := ARRAY['Bé Gia Bảo', 'Bé Minh Thư', 'Bé Tuấn Kiệt', 'Bé Bảo Vy', 'Bé Phúc Lâm', 'Bé Cát Tường', 'Bé Thiên Ân', 'Bé Phương Anh', 'Bé Khánh An', 'Bé Nhật Minh'];
    
    -- Variables for room rental calculation
    v_id_hd INT;
    v_id_kh INT;
    v_ngaylap DATE;
    v_ngaynhan TIMESTAMP;
    v_ngaytra TIMESTAMP;
    v_so_ngay INT;
    v_tien_coc MONEY;
    v_phu_tieu_hao MONEY;
    v_phu_hong_hoc MONEY;
    v_phu_thu MONEY;
    v_gia_tien MONEY;
    v_discount_pct NUMERIC;
    v_base MONEY;
    v_vat MONEY;
    v_service MONEY;
    v_discount MONEY;
    v_tong_tien MONEY;
    v_trang_thai VARCHAR(100);
BEGIN
    -- A. Generate 10 Branches (id_cn: 1 to 10)
    FOR v_c IN 1..10 LOOP
        INSERT INTO quanly.chinhanh (id_cn, ten_cn, dia_chi) VALUES
        (v_c, 
         CASE v_c
            WHEN 1 THEN 'Hanoi Central Homestay'
            WHEN 2 THEN 'Saigon Riverview Homestay'
            WHEN 3 THEN 'Da Nang Beach Homestay'
            WHEN 4 THEN 'Nha Trang Bay Homestay'
            WHEN 5 THEN 'Phu Quoc Sunset Homestay'
            WHEN 6 THEN 'Dalat Pine Homestay'
            WHEN 7 THEN 'Hoi An Ancient Homestay'
            WHEN 8 THEN 'Hue Citadel Homestay'
            WHEN 9 THEN 'Sapa Mountain Homestay'
            ELSE 'Vung Tau Ocean Homestay'
         END,
         CASE v_c
            WHEN 1 THEN 'Hoàn Kiếm, Hà Nội'
            WHEN 2 THEN 'Quận 1, TP. Hồ Chí Minh'
            WHEN 3 THEN 'Ngũ Hành Sơn, Đà Nẵng'
            WHEN 4 THEN 'Trần Phú, Nha Trang'
            WHEN 5 THEN 'Dương Đông, Phú Quốc'
            WHEN 6 THEN 'Trần Hưng Đạo, Đà Lạt'
            WHEN 7 THEN 'Cẩm Châu, Hội An'
            WHEN 8 THEN 'Lê Lợi, Huế'
            WHEN 9 THEN 'Mường Hoa, Sapa'
            ELSE 'Thùy Vân, Vũng Tàu'
         END);
    END LOOP;

    -- B. Generate 5 Owners (id_csh: 1 to 5)
    FOR v_i IN 1..5 LOOP
        INSERT INTO quanly.chusohuu (id_csh, ten_csh, email, sdt) VALUES
        (v_i, 
         CASE v_i
            WHEN 1 THEN 'Nguyễn Văn An'
            WHEN 2 THEN 'Trần Thị Bình'
            WHEN 3 THEN 'Lê Hoài Nam'
            WHEN 4 THEN 'Phạm Minh Đức'
            ELSE 'Hoàng Thu Trang'
         END,
         CASE v_i
            WHEN 1 THEN 'an.nguyen@homestay.vn'
            WHEN 2 THEN 'binh.tran@homestay.vn'
            WHEN 3 THEN 'nam.le@homestay.vn'
            WHEN 4 THEN 'duc.pham@homestay.vn'
            ELSE 'trang.hoang@homestay.vn'
         END,
         '09' || lpad(v_i::text, 8, '1'));
    END LOOP;

    -- C. Link owners and branches
    FOR v_c IN 1..10 LOOP
        INSERT INTO quanly.chinhanh_chusohuu (id_cn, id_csh) VALUES
        (v_c, (v_c % 5) + 1);
    END LOOP;

    -- D. Generate 5 Room Types per Branch (id_lp: 1 to 50)
    FOR v_c IN 1..10 LOOP
        FOR v_t IN 1..5 LOOP
            v_id_lp := (v_c - 1) * 5 + v_t;
            INSERT INTO quanly.loaiphong (id_lp, chat_luong, loai_giuong, view, dien_tich, doi_tuong, gia_tien, id_cn) VALUES
            (v_id_lp,
             CASE v_t
                WHEN 1 THEN 'Standard'
                WHEN 2 THEN 'Superior'
                WHEN 3 THEN 'Deluxe'
                WHEN 4 THEN 'Suite'
                ELSE 'Family'
             END,
             CASE v_t
                WHEN 1 THEN 'Single'
                WHEN 2 THEN 'Double'
                WHEN 3 THEN 'Double'
                WHEN 4 THEN 'King'
                ELSE 'Double'
             END,
             CASE v_t
                WHEN 1 THEN 'City View'
                WHEN 2 THEN 'Garden View'
                WHEN 3 THEN 'City View'
                WHEN 4 THEN 'Sea View'
                ELSE 'Sea View'
             END,
             CASE v_t
                WHEN 1 THEN '20m2'
                WHEN 2 THEN '25m2'
                WHEN 3 THEN '32m2'
                WHEN 4 THEN '45m2'
                ELSE '50m2'
             END,
             CASE v_t
                WHEN 1 THEN '1 người'
                WHEN 2 THEN '2 người'
                WHEN 3 THEN '2 người'
                WHEN 4 THEN '2 người'
                ELSE '4 người'
             END,
             CASE v_t
                WHEN 1 THEN 300000
                WHEN 2 THEN 500000
                WHEN 3 THEN 800000
                WHEN 4 THEN 1500000
                ELSE 1200000
             END::numeric::money,
             v_c);
        END LOOP;
    END LOOP;

    -- E. Generate Rooms per Branch based on branch scale (id_p: c * 100 + r)
    FOR v_c IN 1..10 LOOP
        v_num_rooms := v_room_counts[v_c];
        FOR v_r IN 1..v_num_rooms LOOP
            v_id_p := v_c * 100 + v_r;
            v_id_lp := (v_c - 1) * 5 + ((v_r - 1) % 5 + 1);
            INSERT INTO quanly.phong (id_p, dia_chi, trang_thai, id_lp, id_cn) VALUES
            (v_id_p, 
             'Phòng ' || v_id_p || ', Tầng ' || ((v_r - 1) / 5 + 1),
             'Còn trống', 
             v_id_lp, 
             v_c);
        END LOOP;
    END LOOP;

    -- F. Equip each room with 5 facilities
    -- Bed (id_csvc=1), TV (2), AC (3), Towel (4), Ga giường (5)
    FOR v_c IN 1..10 LOOP
        v_num_rooms := v_room_counts[v_c];
        FOR v_r IN 1..v_num_rooms LOOP
            v_id_p := v_c * 100 + v_r;
            FOR v_i IN 1..5 LOOP
                INSERT INTO quanly.phong_trangbi_csvc (id_p, id_csvc, so_luong, tinh_trang) VALUES
                (v_id_p, v_i, CASE v_i WHEN 4 THEN 2 WHEN 5 THEN 2 ELSE 1 END, 'Tốt');
            END LOOP;
        END LOOP;
    END LOOP;

    -- G. Seed staff members dynamically based on branch scale
    v_id_nv := 0;
    FOR v_c IN 1..10 LOOP
        v_num_rooms := v_room_counts[v_c];
        v_num_receptionists := CASE WHEN v_num_rooms < 12 THEN 1 WHEN v_num_rooms <= 20 THEN 2 ELSE 3 END;
        v_num_cleaners := CASE WHEN v_num_rooms < 10 THEN 1 WHEN v_num_rooms <= 15 THEN 2 WHEN v_num_rooms <= 20 THEN 3 ELSE 4 END;
        
        -- 1. Manager (Quản lý) - 1 per branch
        v_id_nv := v_id_nv + 1;
        INSERT INTO nhansu.nhanvien (id_nv, ten_nv, chuc_vu, id_cn, luong) VALUES
        (v_id_nv,
         v_last_names[(v_id_nv % 10) + 1] || ' ' || v_mid_names[((v_id_nv / 3) % 10) + 1] || ' ' || v_first_names[((v_id_nv / 7) % 15) + 1],
         'Quản lý',
         v_c,
         16000000::numeric::money);
         
        -- 2. Receptionists (Lễ tân)
        FOR v_i IN 1..v_num_receptionists LOOP
            v_id_nv := v_id_nv + 1;
            INSERT INTO nhansu.nhanvien (id_nv, ten_nv, chuc_vu, id_cn, luong) VALUES
            (v_id_nv,
             v_last_names[(v_id_nv % 10) + 1] || ' ' || v_mid_names[((v_id_nv / 3) % 10) + 1] || ' ' || v_first_names[((v_id_nv / 7) % 15) + 1],
             'Lễ tân',
             v_c,
             7500000::numeric::money);
        END LOOP;
        
        -- 3. Cleaners (Dọn phòng)
        FOR v_i IN 1..v_num_cleaners LOOP
            v_id_nv := v_id_nv + 1;
            INSERT INTO nhansu.nhanvien (id_nv, ten_nv, chuc_vu, id_cn, luong) VALUES
            (v_id_nv,
             v_last_names[(v_id_nv % 10) + 1] || ' ' || v_mid_names[((v_id_nv / 3) % 10) + 1] || ' ' || v_first_names[((v_id_nv / 7) % 15) + 1],
             'Dọn phòng',
             v_c,
             6000000::numeric::money);
        END LOOP;
    END LOOP;

    -- H. Generate 2,000 Member accounts
    FOR v_i IN 1..2000 LOOP
        INSERT INTO khachhang.hoivien (id_hv, tong_luu_tru, id_mhv) VALUES
        (v_i,
         v_i % 110,
         CASE 
            WHEN v_i % 110 >= 80 THEN 3 -- Gold
            WHEN v_i % 110 >= 40 THEN 2 -- Silver
            WHEN v_i % 110 >= 20 THEN 1 -- Bronze
            ELSE 4 -- Basic
         END);
    END LOOP;

    -- I. Generate 1,000 groups
    FOR v_i IN 1..1000 LOOP
        INSERT INTO khachhang.doankhach (id_doan, id_truong_doan) VALUES
        (v_i, NULL);
    END LOOP;

    -- J. Generate 10,000 Customers (la_knn correctly set, with realistic names and addresses)
    FOR v_i IN 1..10000 LOOP
        INSERT INTO khachhang.khachhang (id_kh, cccd, dia_chi, ho_ten, sdt, quoc_tich, passport, visa, id_hv, id_doan, la_knn) VALUES
        (v_i,
         -- cccd
         CASE WHEN v_i % 4 = 0 THEN NULL ELSE '00120' || lpad(v_i::text, 7, '0') END,
         -- dia_chi
         CASE WHEN v_i % 4 = 0 THEN 
            (v_i % 999 + 1)::text || ' ' || v_foreign_addresses[(v_i % 10) + 1]
         ELSE
            (v_i % 99 + 1)::text || ' Đường ' || v_local_streets[(v_i % 10) + 1] || ', ' || v_local_districts[((v_i / 10) % 10) + 1] || ', ' || v_local_cities[((v_i / 100) % 10) + 1]
         END,
         -- ho_ten
         CASE WHEN v_i % 4 = 0 THEN 
            v_foreign_first[(v_i % 15) + 1] || ' ' || v_foreign_last[((v_i / 15) % 15) + 1]
         ELSE 
            v_last_names[(v_i % 10) + 1] || ' ' || v_mid_names[((v_i / 10) % 10) + 1] || ' ' || v_first_names[((v_i / 100) % 15) + 1]
         END,
         -- sdt
         '09' || lpad(v_i::text, 8, '0'),
         -- quoc_tich
         CASE WHEN v_i % 4 = 0 THEN 
            CASE v_i % 5
                WHEN 0 THEN 'Mỹ'
                WHEN 1 THEN 'Anh'
                WHEN 2 THEN 'Hàn Quốc'
                WHEN 3 THEN 'Nhật Bản'
                ELSE 'Pháp'
            END
         ELSE 'Việt Nam' END,
         -- passport
         CASE WHEN v_i % 4 = 0 THEN 'PP' || lpad(v_i::text, 8, '0') ELSE NULL END,
         -- visa
         CASE WHEN v_i % 4 = 0 THEN 'VS' || lpad(v_i::text, 8, '0') ELSE NULL END,
         -- id_hv (first 2000 customers are members)
         CASE WHEN v_i <= 2000 THEN v_i ELSE NULL END,
         -- id_doan (from 2001 to 6000 are in groups)
         CASE WHEN v_i > 2000 AND v_i <= 6000 THEN ((v_i - 2001) % 1000) + 1 ELSE NULL END,
         -- la_knn
         CASE WHEN v_i % 4 = 0 THEN TRUE ELSE FALSE END);
    END LOOP;

    -- Update group leaders to the first member of each group
    UPDATE khachhang.doankhach SET id_truong_doan = 2000 + id_doan;

    -- K. Generate 1,000 Child customers
    FOR v_i IN 1..1000 LOOP
        INSERT INTO khachhang.khachhang_treem (id_kh, id_tre_em, ten_tre_em, tuoi) VALUES
        (2000 + v_i, v_i, v_child_names[(v_i % 10) + 1], (v_i % 12) + 1);
    END LOOP;

    -- L. Generate 8,000 Invoices (ngaylap spread over 2026)
    FOR v_i IN 1..8000 LOOP
        v_trang_thai := CASE 
                            WHEN v_i <= 7200 THEN 'Đã thanh toán'
                            WHEN v_i <= 7700 THEN 'Đã đặt'
                            ELSE 'Đã hủy'
                         END;
        v_ngaylap := '2026-01-01'::date + (v_i % 160) * INTERVAL '1 day';
        
        INSERT INTO hoadon.hoadon (id_hd, trang_thai, ngaylap, ngaythanhtoan, phuongthuc, id_kh, id_nv) VALUES
        (v_i,
         v_trang_thai,
         v_ngaylap,
         CASE WHEN v_trang_thai = 'Đã thanh toán' THEN v_ngaylap + ((v_i % 3) + 1) * INTERVAL '1 day' ELSE NULL END,
         CASE WHEN v_trang_thai = 'Đã thanh toán' THEN 
            CASE WHEN v_i % 2 = 0 THEN 'Chuyển khoản' ELSE 'Tiền mặt' END
         ELSE NULL END,
         (v_i * 17) % 10000 + 1, -- id_kh
         (v_i * 3) % 54 + 1      -- id_nv
        );
    END LOOP;

    -- M. Generate 8,500 Room Rentals (hoadon_thue_phong)
    FOR v_i IN 1..8500 LOOP
        v_id_hd := (v_i - 1) % 8000 + 1;
        
        -- Pick a room in a branch
        v_c := (v_i % 10) + 1; -- branch
        v_r := ((v_i / 10) % v_room_counts[v_c]) + 1; -- room index
        v_id_p := v_c * 100 + v_r;
        
        SELECT h.id_kh, h.ngaylap, h.trang_thai INTO v_id_kh, v_ngaylap, v_trang_thai FROM hoadon.hoadon h WHERE h.id_hd = v_id_hd;
        
        v_ngaynhan := v_ngaylap::timestamp + '14:00:00'::time;
        v_so_ngay := (v_i % 5) + 1; -- 1 to 5 nights
        v_ngaytra := v_ngaynhan + v_so_ngay * INTERVAL '1 day';
        
        v_phu_tieu_hao := CASE WHEN v_i % 7 = 0 THEN 50000 ELSE 0 END::numeric::money;
        v_phu_hong_hoc := CASE WHEN v_i % 25 = 0 THEN 300000 ELSE 0 END::numeric::money;

        INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, so_luong, ngaynhan, ngaytra, phu_thu_tieu_hao, phu_thu_hong_hoc, so_ngay_luu_tru) VALUES
        (v_id_hd, 
         v_id_p, 
         1, 
         v_ngaynhan, 
         v_ngaytra, 
         v_phu_tieu_hao, 
         v_phu_hong_hoc, 
         v_so_ngay)
        ON CONFLICT (id_hd, id_p) DO NOTHING;
    END LOOP;

    -- N. Generate 6,000 Service Usages
    FOR v_i IN 1..6000 LOOP
        INSERT INTO hoadon.hoadon_sudung_dichvu (id_hd, id_dv, so_luong) VALUES
        ((v_i * 13) % 8000 + 1, (v_i % 7) + 1, (v_i % 3) + 1);
    END LOOP;
END;
$$;

-- Add specific demo cases for Branch 1 (Hanoi Central Homestay)
-- Ensure we have a few clean customers for demo
INSERT INTO khachhang.khachhang (id_kh, ho_ten, sdt, dia_chi, quoc_tich, la_knn) VALUES
(10001, 'Nguyen Demo CheckIn', '0999888777', 'Hà Nội', 'Việt Nam', FALSE),
(10002, 'Nguyen Demo Overdue', '0999888666', 'Đà Nẵng', 'Việt Nam', FALSE)
ON CONFLICT (id_kh) DO NOTHING;

-- Demo case 1: Sắp Check-In today (2026-06-22) for room 101
INSERT INTO hoadon.hoadon (id_hd, trang_thai, ngaylap, id_kh, id_nv) VALUES
(9001, 'Đã đặt', '2026-06-22', 10001, 2)
ON CONFLICT (id_hd) DO NOTHING;

INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, so_luong, ngaynhan, ngaytra, phu_thu_tieu_hao, phu_thu_hong_hoc, so_ngay_luu_tru) VALUES
(9001, 101, 1, '2026-06-22 14:00:00', '2026-06-25 12:00:00', 0::money, 0::money, 3)
ON CONFLICT (id_hd, id_p) DO NOTHING;

-- Update room 101 state to 'Đã đặt'
UPDATE quanly.phong SET trang_thai = 'Đã đặt' WHERE id_p = 101;

-- Demo case 2: Quá Hạn Check-Out (Expected check-out: 2026-06-21) for room 102
INSERT INTO hoadon.hoadon (id_hd, trang_thai, ngaylap, id_kh, id_nv) VALUES
(9002, 'Đã đặt', '2026-06-18', 10002, 2)
ON CONFLICT (id_hd) DO NOTHING;

INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, so_luong, ngaynhan, ngaytra, phu_thu_tieu_hao, phu_thu_hong_hoc, so_ngay_luu_tru) VALUES
(9002, 102, 1, '2026-06-18 14:00:00', '2026-06-21 12:00:00', 0::money, 0::money, 3)
ON CONFLICT (id_hd, id_p) DO NOTHING;

-- Update room 102 state to 'Đã đặt'
UPDATE quanly.phong SET trang_thai = 'Đã đặt' WHERE id_p = 102;

-- Reset all sequences to ensure future auto-increments continue correctly
SELECT pg_catalog.setval('hoadon.dichvu_id_dv_seq', 7, true);
SELECT pg_catalog.setval('hoadon.hoadon_id_hd_seq', 9010, true);
SELECT pg_catalog.setval('khachhang.doankhach_id_doan_seq', 1000, true);
SELECT pg_catalog.setval('khachhang.hoivien_id_hv_seq', 2000, true);
SELECT pg_catalog.setval('khachhang.khachhang_id_kh_seq', 10010, true);
SELECT pg_catalog.setval('khachhang.khachhang_treem_id_tre_em_seq', 1000, true);
SELECT pg_catalog.setval('khachhang.muchoivien_id_mhv_seq', 4, true);
SELECT pg_catalog.setval('nhansu.nhanvien_id_nv_seq', 54, true);

SELECT pg_catalog.setval('quanly.chinhanh_id_cn_seq', 10, true);
SELECT pg_catalog.setval('quanly.chusohuu_id_csh_seq', 5, true);
SELECT pg_catalog.setval('quanly.cosovatchat_id_csvc_seq', 7, true);
SELECT pg_catalog.setval('quanly.loaiphong_id_lp_seq', 50, true);
SELECT pg_catalog.setval('quanly.phong_id_p_seq', 1014, true);

-- Restore default session replication role
SET session_replication_role = 'origin';
