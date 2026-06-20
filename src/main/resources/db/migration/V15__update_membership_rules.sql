-- Migration: V15 - Cập nhật quy định hội viên và bổ sung các hàm nghiệp vụ homestay
-- ---------------------------------------------------------------------------------

-- 1. Cập nhật các mức hội viên trong bảng muchoivien
-- Mức 1: Bronze (Tích lũy >= 20 đêm, giảm 5% giá phòng)
UPDATE khachhang.muchoivien 
SET hang = 'Bronze', dieu_kien = 'Lưu trú tối thiểu 20 đêm', muc_giam_gia = 5.00 
WHERE id_mhv = 1;

-- Mức 2: Gold (Tích lũy >= 40 đêm, giảm 15% giá phòng, check-out muộn đến 16:00 miễn phí)
UPDATE khachhang.muchoivien 
SET hang = 'Gold', dieu_kien = 'Lưu trú tối thiểu 40 đêm', muc_giam_gia = 15.00 
WHERE id_mhv = 2;

-- Mức 3: Diamond (Tích lũy >= 80 đêm, giảm 30% giá phòng, check-out muộn đến 18:00 miễn phí)
-- Nếu chưa có dòng id_mhv = 3 thì chèn mới, nếu có rồi thì cập nhật thành Diamond
INSERT INTO khachhang.muchoivien (id_mhv, hang, dieu_kien, muc_giam_gia)
VALUES (3, 'Diamond', 'Lưu trú tối thiểu 80 đêm', 30.00)
ON CONFLICT (id_mhv) DO UPDATE 
SET hang = 'Diamond', dieu_kien = 'Lưu trú tối thiểu 80 đêm', muc_giam_gia = 30.00;

-- Đồng bộ seq cho muchoivien_id_mhv_seq
SELECT pg_catalog.setval('khachhang.muchoivien_id_mhv_seq', 3, true);


-- 2. Hàm trigger tự động nâng hạng hội viên theo số đêm lưu trú (diem_tich_luy đóng vai trò là số đêm tích lũy)
CREATE OR REPLACE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien()
RETURNS TRIGGER AS $$
DECLARE
    v_id_mhv INT;
BEGIN
    -- Kiểm tra số đêm tích lũy để thăng hạng
    IF NEW.diem_tich_luy >= 80 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Diamond';
    ELSIF NEW.diem_tich_luy >= 40 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Gold';
    ELSIF NEW.diem_tich_luy >= 20 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Bronze';
    ELSE
        v_id_mhv := NULL; -- Chưa đạt mốc hội viên cơ bản
    END IF;
    
    NEW.id_mhv := v_id_mhv;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 3. Hàm trigger tự động cộng số đêm lưu trú khi hóa đơn chuyển sang 'Đã thanh toán'
CREATE OR REPLACE FUNCTION hoadon.func_cap_nhat_diem_tich_luy()
RETURNS TRIGGER AS $$
DECLARE
    v_id_hv INT;
    v_tong_so_dem INT := 0;
BEGIN
    -- Chỉ kích hoạt khi hóa đơn chuyển trạng thái sang "Đã thanh toán"
    IF NEW.trang_thai = 'Đã thanh toán' AND (OLD.trang_thai IS NULL OR OLD.trang_thai != 'Đã thanh toán') THEN
        -- Tìm xem khách hàng thanh toán có thẻ hội viên không
        SELECT id_hv INTO v_id_hv
        FROM khachhang.khachhang
        WHERE id_kh = NEW.id_kh;

        -- Nếu là hội viên thì bắt đầu cộng dồn đêm
        IF v_id_hv IS NOT NULL THEN
            -- Tính tổng số đêm thuê phòng trong hóa đơn này
            SELECT COALESCE(SUM(EXTRACT(DAY FROM (ngaytra - ngaynhan))::INT), 0)
            INTO v_tong_so_dem
            FROM hoadon.hoadon_thue_phong
            WHERE id_hd = NEW.id_hd;

            -- Đảm bảo mỗi lượt đặt tính tối thiểu 1 đêm
            IF v_tong_so_dem <= 0 THEN
                v_tong_so_dem := 1;
            END IF;

            -- Cộng dồn số đêm lưu trú vào điểm tích lũy
            UPDATE khachhang.hoivien
            SET diem_tich_luy = diem_tich_luy + v_tong_so_dem
            WHERE id_hv = v_id_hv;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- 4. Hàm tính tỷ lệ phụ thu check-out muộn dựa trên hạng hội viên
CREATE OR REPLACE FUNCTION hoadon.func_tinh_ti_le_checkout_muon(
    p_hang_hv VARCHAR,
    p_ngaytra TIMESTAMP,
    p_ngaythanhtoan TIMESTAMP
)
RETURNS NUMERIC AS $$
DECLARE
    v_checkout_time TIME;
    v_ti_le NUMERIC := 0.00;
BEGIN
    -- Nếu chưa check-out hoặc check-out trước/đúng giờ hẹn, không phụ thu
    IF p_ngaythanhtoan IS NULL OR p_ngaythanhtoan <= p_ngaytra THEN
        RETURN 0.00;
    END IF;

    -- Lấy mốc thời gian giờ trong ngày của lúc thanh toán/checkout thực tế
    v_checkout_time := p_ngaythanhtoan::time;

    -- Tính phụ thu theo phân loại hạng của khách
    IF p_hang_hv IS NULL OR p_hang_hv = '' OR p_hang_hv = 'Bronze' THEN
        -- Khách thường hoặc hạng Bronze:
        -- Trước 14:00: miễn phí
        -- 14:00 - 16:00: phụ thu 30% giá phòng
        -- 16:00 - 18:00: phụ thu 50% giá phòng
        -- Sau 18:00: phụ thu 100% (tính thêm 1 ngày)
        IF v_checkout_time <= TIME '14:00:00' THEN
            v_ti_le := 0.00;
        ELSIF v_checkout_time <= TIME '16:00:00' THEN
            v_ti_le := 0.30;
        ELSIF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.50;
        ELSE
            v_ti_le := 1.00;
        END IF;
    ELSIF p_hang_hv = 'Gold' THEN
        -- Hạng Gold:
        -- Trước 16:00: miễn phí
        -- 16:00 - 18:00: phụ thu 20%
        -- Sau 18:00: phụ thu 100%
        IF v_checkout_time <= TIME '16:00:00' THEN
            v_ti_le := 0.00;
        ELSIF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.20;
        ELSE
            v_ti_le := 1.00;
        END IF;
    ELSIF p_hang_hv = 'Diamond' THEN
        -- Hạng Diamond:
        -- Trước 18:00: miễn phí
        -- Sau 18:00: phụ thu 100%
        IF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.00;
        ELSE
            v_ti_le := 1.00;
        END IF;
    END IF;

    RETURN v_ti_le;
END;
$$ LANGUAGE plpgsql;


-- 5. Hàm tính toán tổng tiền của từng phòng thuê (Áp dụng VAT, phí dịch vụ phục vụ, phụ thu check-out muộn và ưu đãi giảm giá phòng hội viên)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_phong(id_hd_input INT, id_p_input INT)
RETURNS MONEY AS $$
DECLARE
    v_ngaynhan TIMESTAMP;
    v_ngaytra TIMESTAMP;
    v_ngaythanhtoan TIMESTAMP;
    v_gia_tien MONEY;
    v_tien_coc MONEY;
    v_phu_thu MONEY; -- Chứa phụ thu vật phẩm tiêu hao, đền bù cố định
    v_so_ngay INT;
    v_gia_phong_goc MONEY;
    v_hang_hv VARCHAR(50);
    v_giam_gia_percent NUMERIC(5,2) := 0.00;
    v_ti_le_checkout_muon NUMERIC := 0.00;
    
    v_vat MONEY;
    v_phu_vu MONEY;
    v_phu_thu_checkout MONEY;
    v_uu_dai MONEY;
    v_tong_tien MONEY;
BEGIN
    -- Lấy thông tin ngày nhận, ngày trả, tiền đặt cọc, các loại phụ thu khác và ngày thanh toán thực tế
    SELECT htp.ngaynhan, htp.ngaytra, htp.tien_coc, htp.phu_thu, h.ngaythanhtoan
    INTO v_ngaynhan, v_ngaytra, v_tien_coc, v_phu_thu, v_ngaythanhtoan
    FROM hoadon.hoadon_thue_phong htp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE htp.id_hd = id_hd_input AND htp.id_p = id_p_input;

    -- Lấy giá phòng niêm yết của loại phòng này
    SELECT lp.gia_tien
    INTO v_gia_tien
    FROM quanly.phong p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE p.id_p = id_p_input;

    -- Tính số đêm lưu trú (tối thiểu 1 đêm)
    v_so_ngay := EXTRACT(DAY FROM (v_ngaytra - v_ngaynhan))::INT;
    IF v_so_ngay <= 0 THEN
        v_so_ngay := 1;
    END IF;

    v_gia_phong_goc := v_so_ngay * COALESCE(v_gia_tien, 0::money);

    -- Lấy thông tin hạng và giảm giá hội viên của khách hàng lẻ
    SELECT COALESCE(mhv.hang, ''), COALESCE(mhv.muc_giam_gia, 0.00)
    INTO v_hang_hv, v_giam_gia_percent
    FROM hoadon.hoadon h
    JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
    LEFT JOIN khachhang.hoivien hv ON kh.id_hv = hv.id_hv
    LEFT JOIN khachhang.muchoivien mhv ON hv.id_mhv = mhv.id_mhv
    WHERE h.id_hd = id_hd_input;

    v_hang_hv := COALESCE(v_hang_hv, '');
    v_giam_gia_percent := COALESCE(v_giam_gia_percent, 0.00);

    -- Tính phụ thu check-out muộn
    v_ti_le_checkout_muon := hoadon.func_tinh_ti_le_checkout_muon(v_hang_hv, v_ngaytra, COALESCE(v_ngaythanhtoan, CURRENT_TIMESTAMP::timestamp));

    -- Tính toán các chi phí chi tiết theo công thức nghiệp vụ
    v_vat := v_gia_phong_goc * 0.08; -- VAT mặc định 8%
    v_phu_vu := v_gia_phong_goc * 0.05; -- Phí phục vụ homestay 5%
    v_phu_thu_checkout := v_gia_phong_goc * v_ti_le_checkout_muon; -- Phụ thu check-out muộn
    v_uu_dai := v_gia_phong_goc * (v_giam_gia_percent / 100); -- Giảm giá hội viên

    -- Tổng chi phí phòng = Giá gốc + VAT + Phục vụ + Phụ thu checkout + Phụ thu khác (vật dụng) - Giảm giá hội viên - Tiền cọc
    v_tong_tien := v_gia_phong_goc + v_vat + v_phu_vu + v_phu_thu_checkout + COALESCE(v_phu_thu, 0::money) - v_uu_dai - COALESCE(v_tien_coc, 0::money);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;


-- 6. Hàm tính tổng tiền hóa đơn cuối cùng (Cập nhật lại giá phòng rồi cộng tiền phòng và tiền dịch vụ)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tien_phong MONEY := 0::money;
    v_tien_dich_vu MONEY := 0::money;
    v_tong_tien MONEY := 0::money;
    r RECORD;
BEGIN
    -- A. Cập nhật lại giá tiền thực tế của từng phòng trong hóa đơn trước khi tính tổng
    FOR r IN 
        SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE hoadon.hoadon_thue_phong
        SET tong_tien = hoadon.func_tinh_tien_phong(p_id_hd, r.id_p)
        WHERE id_hd = p_id_hd AND id_p = r.id_p;
    END LOOP;

    -- B. Tính tổng tiền thuê phòng đã cập nhật
    SELECT COALESCE(SUM(tong_tien), 0::money)
    INTO v_tien_phong
    FROM hoadon.hoadon_thue_phong
    WHERE id_hd = p_id_hd;

    -- C. Tính tổng tiền sử dụng dịch vụ trong hóa đơn
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tien_dich_vu
    FROM hoadon.hoadon_sudung_dichvu hsd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE hsd.id_hd = p_id_hd;

    -- Tổng hóa đơn = Tổng tiền phòng (đã áp dụng VAT, phí dịch vụ, late checkout, giảm giá thành viên) + Tiền dịch vụ ăn uống giải trí
    v_tong_tien := v_tien_phong + v_tien_dich_vu;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;
