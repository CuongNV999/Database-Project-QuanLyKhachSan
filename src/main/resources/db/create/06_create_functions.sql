-- ============================================================
-- File: 06_create_functions.sql
-- Mục đích: Tạo tất cả functions cho CSDL quanlykhachsan
-- Phiên bản: Tương đương sau migration V36
-- ============================================================

SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;

-- ============================================================
-- SCHEMA: khachhang - Trigger Functions
-- ============================================================

-- 1. Trigger function: Kiểm soát tuổi trẻ em
CREATE OR REPLACE FUNCTION khachhang.func_check_child_age()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.tuoi >= 18 THEN
        RAISE EXCEPTION 'RÀNG BUỘC ĐỘ TUỔI: Khách hàng trẻ em phải dưới 18 tuổi. Tuổi truyền vào (%) không hợp lệ!', NEW.tuoi;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Trigger function: Tự động nâng hạng hội viên (phiên bản V19 - có hạng Basic)
CREATE OR REPLACE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien()
RETURNS TRIGGER AS $$
DECLARE
    v_id_mhv INT;
BEGIN
    IF NEW.tong_luu_tru >= 80 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Gold';
    ELSIF NEW.tong_luu_tru >= 40 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Silver';
    ELSIF NEW.tong_luu_tru >= 20 THEN
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Bronze';
    ELSE
        SELECT id_mhv INTO v_id_mhv FROM khachhang.muchoivien WHERE hang = 'Basic';
    END IF;
    
    NEW.id_mhv := v_id_mhv;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- SCHEMA: hoadon - Helper Functions
-- ============================================================

-- 3. Helper: Lấy hạng và mức giảm giá hội viên từ hóa đơn (V24)
CREATE OR REPLACE FUNCTION hoadon.func_lay_hang_va_giam_gia_hoi_vien(
    p_id_hd INT,
    OUT o_hang_hv VARCHAR,
    OUT o_giam_gia_percent NUMERIC
) AS $$
BEGIN
    SELECT COALESCE(mhv.hang, ''), COALESCE(mhv.muc_giam_gia, 0.00)
    INTO o_hang_hv, o_giam_gia_percent
    FROM hoadon.hoadon h
    JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh
    LEFT JOIN khachhang.hoivien hv ON kh.id_hv = hv.id_hv
    LEFT JOIN khachhang.muchoivien mhv ON hv.id_mhv = mhv.id_mhv
    WHERE h.id_hd = p_id_hd;

    o_hang_hv := COALESCE(o_hang_hv, '');
    o_giam_gia_percent := COALESCE(o_giam_gia_percent, 0.00);
END;
$$ LANGUAGE plpgsql;

-- 4. Helper: Tính phụ thu và giảm giá (V24 - giữ lại cho backward compatibility nhưng không dùng trong V25+)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_phu_thu_va_giam_gia(
    p_gia_phong_goc MONEY,
    p_ti_le_checkout_muon NUMERIC,
    p_giam_gia_percent NUMERIC,
    p_phu_thu MONEY,
    p_tien_coc MONEY
)
RETURNS MONEY AS $$
DECLARE
    v_vat MONEY;
    v_phu_vu MONEY;
    v_phu_thu_checkout MONEY;
    v_uu_dai MONEY;
    v_tong_tien MONEY;
BEGIN
    v_vat := p_gia_phong_goc * 0.08;
    v_phu_vu := p_gia_phong_goc * 0.05;
    v_phu_thu_checkout := p_gia_phong_goc * p_ti_le_checkout_muon;
    v_uu_dai := p_gia_phong_goc * (p_giam_gia_percent / 100);

    v_tong_tien := p_gia_phong_goc + v_vat + v_phu_vu + v_phu_thu_checkout + COALESCE(p_phu_thu, 0::money) - v_uu_dai - COALESCE(p_tien_coc, 0::money);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- SCHEMA: hoadon - Tính tỷ lệ phụ thu check-out muộn
-- ============================================================

-- 5. Tính tỷ lệ phụ thu check-out muộn (phiên bản V27 - scale 100% per day overdue)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_ti_le_checkout_muon(
    p_hang_hv VARCHAR,
    p_ngaynhan TIMESTAMP,
    p_so_ngay_luu_tru INT,
    p_ngaytra_thucte TIMESTAMP
)
RETURNS NUMERIC AS $$
DECLARE
    v_ngaytra_dukien TIMESTAMP;
    v_expected_date DATE;
    v_checkout_time TIME;
    v_ti_le NUMERIC := 0.00;
BEGIN
    -- Tính ngày trả dự kiến từ ngày nhận + số ngày lưu trú
    v_ngaytra_dukien := p_ngaynhan + COALESCE(p_so_ngay_luu_tru, 1) * INTERVAL '1 day';

    -- Nếu chưa check-out hoặc check-out trước/đúng giờ hẹn dự kiến, không tính phí check-out muộn
    IF p_ngaytra_thucte IS NULL OR p_ngaytra_thucte <= v_ngaytra_dukien THEN
        RETURN 0.00;
    END IF;

    v_expected_date := v_ngaytra_dukien::date;
    v_checkout_time := p_ngaytra_thucte::time;

    -- Nếu check-out sau ngày dự kiến, phụ thu 100% cho mỗi ngày trễ hạn (1.00 * n ngày)
    IF p_ngaytra_thucte::date > v_expected_date THEN
        RETURN (p_ngaytra_thucte::date - v_expected_date)::NUMERIC;
    END IF;

    -- Kiểm tra điều kiện phụ thu theo từng hạng hội viên
    IF p_hang_hv IS NULL OR p_hang_hv = '' OR p_hang_hv = 'Basic' OR p_hang_hv = 'Bronze' THEN
        -- Khách lẻ vãng lai hoặc hạng Basic / Bronze:
        IF v_checkout_time <= TIME '14:00:00' THEN
            v_ti_le := 0.00;
        ELSIF v_checkout_time <= TIME '16:00:00' THEN
            v_ti_le := 0.30;
        ELSIF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.50;
        ELSE
            v_ti_le := 1.00;
        END IF;
    ELSIF p_hang_hv = 'Silver' THEN
        -- Hội viên hạng Silver:
        IF v_checkout_time <= TIME '16:00:00' THEN
            v_ti_le := 0.00;
        ELSIF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.20;
        ELSE
            v_ti_le := 1.00;
        END IF;
    ELSIF p_hang_hv = 'Gold' THEN
        -- Hội viên hạng Gold:
        IF v_checkout_time <= TIME '18:00:00' THEN
            v_ti_le := 0.00;
        ELSE
            v_ti_le := 1.00;
        END IF;
    END IF;

    RETURN v_ti_le;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- SCHEMA: hoadon - Tính tiền phòng và hóa đơn
-- ============================================================

-- 6. Tính tiền phòng chi tiết cho 1 phòng trong hóa đơn (phiên bản V36 - dùng bảng phu_thu_phong)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_phong(id_hd_input INT, id_p_input INT)
RETURNS MONEY AS $$
DECLARE
    v_ngaynhan TIMESTAMP;
    v_ngaytra TIMESTAMP;
    v_so_ngay_luu_tru INT;
    v_ngaythanhtoan TIMESTAMP;
    v_gia_tien MONEY;
    v_phu_thu_tieu_hao MONEY;
    v_phu_thu_hong_hoc MONEY;
    v_so_ngay INT;
    v_hang_hv VARCHAR(50);
    v_giam_gia_percent NUMERIC(5,2) := 0.00;
    v_ti_le_checkout_muon NUMERIC := 0.00;
    v_ngaytra_thucte TIMESTAMP;
    v_tong_tien MONEY;
BEGIN
    -- 1. Lấy thông tin ngày nhận, ngày trả, số ngày lưu trú, và ngày thanh toán thực tế
    SELECT htp.ngaynhan, htp.ngaytra, htp.so_ngay_luu_tru, h.ngaythanhtoan
    INTO v_ngaynhan, v_ngaytra, v_so_ngay_luu_tru, v_ngaythanhtoan
    FROM hoadon.hoadon_thue_phong htp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE htp.id_hd = id_hd_input AND htp.id_p = id_p_input;

    -- 2. Lấy thông tin các phụ thu từ bảng phu_thu_phong
    SELECT COALESCE(SUM(so_tien), 0::money) INTO v_phu_thu_tieu_hao FROM hoadon.phu_thu_phong WHERE id_hd = id_hd_input AND id_p = id_p_input AND loai_phu_thu = 'Tiêu hao';
    SELECT COALESCE(SUM(so_tien), 0::money) INTO v_phu_thu_hong_hoc FROM hoadon.phu_thu_phong WHERE id_hd = id_hd_input AND id_p = id_p_input AND loai_phu_thu = 'Hỏng hóc';

    -- 3. Lấy giá phòng niêm yết của loại phòng này
    SELECT lp.gia_tien
    INTO v_gia_tien
    FROM quanly.phong p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE p.id_p = id_p_input;

    -- 4. Tính số đêm lưu trú (sử dụng cột so_ngay_luu_tru, tối thiểu 1 đêm)
    v_so_ngay := COALESCE(v_so_ngay_luu_tru, 1);
    IF v_so_ngay <= 0 THEN
        v_so_ngay := 1;
    END IF;

    -- 5. Lấy thông tin hạng và giảm giá hội viên từ helper function
    SELECT * INTO v_hang_hv, v_giam_gia_percent 
    FROM hoadon.func_lay_hang_va_giam_gia_hoi_vien(id_hd_input);

    -- 6. Xác định thời gian checkout thực tế để tính phụ thu check-out muộn
    v_ngaytra_thucte := v_ngaytra;
    IF v_ngaythanhtoan IS NULL AND CURRENT_TIMESTAMP > (v_ngaynhan + v_so_ngay * INTERVAL '1 day') THEN
        v_ngaytra_thucte := CURRENT_TIMESTAMP;
    END IF;

    -- 7. Tính phụ thu check-out muộn
    v_ti_le_checkout_muon := hoadon.func_tinh_ti_le_checkout_muon(
        v_hang_hv, 
        v_ngaynhan,
        v_so_ngay,
        v_ngaytra_thucte
    );

    -- 8. Tính toán tổng chi phí phòng
    v_tong_tien := (v_so_ngay * COALESCE(v_gia_tien, 0::money) + v_phu_thu_hong_hoc + v_phu_thu_tieu_hao) * (1.00 + v_ti_le_checkout_muon);
    
    IF v_tong_tien < 0::money THEN
        v_tong_tien := 0::money;
    END IF;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;

-- 7. Tính tổng tiền tất cả phòng trong hóa đơn (V25)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_phong(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_tien_phong MONEY := 0::money;
    r RECORD;
BEGIN
    FOR r IN 
        SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        v_tong_tien_phong := v_tong_tien_phong + hoadon.func_tinh_tien_phong(p_id_hd, r.id_p);
    END LOOP;
    
    RETURN v_tong_tien_phong;
END;
$$ LANGUAGE plpgsql;

-- 8. Tính tổng tiền dịch vụ trong hóa đơn (V25)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_dich_vu(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_tien_dv MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tong_tien_dv
    FROM hoadon.hoadon_sudung_dichvu hsd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE hsd.id_hd = p_id_hd;
    
    RETURN v_tong_tien_dv;
END;
$$ LANGUAGE plpgsql;

-- 9. Tính tiền cọc (50% giá phòng) (V26)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tien_coc(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tien_coc MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(htp.so_ngay_luu_tru * lp.gia_tien * 0.5), 0::money)
    INTO v_tien_coc
    FROM hoadon.hoadon_thue_phong htp
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE htp.id_hd = p_id_hd;
    
    RETURN v_tien_coc;
END;
$$ LANGUAGE plpgsql;

-- 10. Tính tổng chi phí hóa đơn (V25)
-- Tổng chi phí = Tổng tiền phòng + (Tổng tiền phòng x VAT) + Tổng tiền Dịch vụ - (Tổng tiền phòng x Ưu đãi)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_chi_phi(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_tien_phong MONEY := 0::money;
    v_tong_tien_dv MONEY := 0::money;
    v_vat MONEY := 0::money;
    v_uu_dai MONEY := 0::money;
    v_giam_gia_percent NUMERIC(5,2) := 0.00;
    v_hang_hv VARCHAR(50);
    v_tong_chi_phi MONEY := 0::money;
BEGIN
    v_tong_tien_phong := hoadon.func_tinh_tong_tien_phong(p_id_hd);
    v_tong_tien_dv := hoadon.func_tinh_tong_tien_dich_vu(p_id_hd);

    SELECT * INTO v_hang_hv, v_giam_gia_percent 
    FROM hoadon.func_lay_hang_va_giam_gia_hoi_vien(p_id_hd);

    v_vat := v_tong_tien_phong * 0.08; -- VAT 8%
    v_uu_dai := v_tong_tien_phong * (v_giam_gia_percent / 100.0); -- Ưu đãi

    v_tong_chi_phi := v_tong_tien_phong + v_vat + v_tong_tien_dv - v_uu_dai;
    
    IF v_tong_chi_phi < 0::money THEN
        v_tong_chi_phi := 0::money;
    END IF;

    RETURN v_tong_chi_phi;
END;
$$ LANGUAGE plpgsql;

-- 11. Tính số tiền trả sau (V25)
-- Số tiền trả sau = Tổng chi phí - Tiền cọc
CREATE OR REPLACE FUNCTION hoadon.func_tinh_so_tien_tra_sau(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tong_chi_phi MONEY := 0::money;
    v_tien_coc MONEY := 0::money;
    v_tra_sau MONEY := 0::money;
BEGIN
    v_tong_chi_phi := hoadon.func_tinh_tong_chi_phi(p_id_hd);
    v_tien_coc := hoadon.func_tinh_tien_coc(p_id_hd);
    
    v_tra_sau := v_tong_chi_phi - v_tien_coc;
    
    IF v_tra_sau < 0::money THEN
        v_tra_sau := 0::money;
    END IF;

    RETURN v_tra_sau;
END;
$$ LANGUAGE plpgsql;

-- 12. Tính tổng tiền hóa đơn (wrapper cho JDBC backward compatibility) (V25)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)
RETURNS MONEY AS $$
BEGIN
    RETURN hoadon.func_tinh_so_tien_tra_sau(p_id_hd);
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- SCHEMA: hoadon - Trigger Functions
-- ============================================================

-- 13. Trigger function: Tự động cập nhật số đêm lưu trú khi thanh toán (V17)
CREATE OR REPLACE FUNCTION hoadon.func_cap_nhat_diem_tich_luy()
RETURNS TRIGGER AS $$
DECLARE
    v_id_hv INT;
    v_tong_so_dem INT := 0;
BEGIN
    IF NEW.trang_thai = 'Đã thanh toán' AND (OLD.trang_thai IS NULL OR OLD.trang_thai != 'Đã thanh toán') THEN
        SELECT id_hv INTO v_id_hv FROM khachhang.khachhang WHERE id_kh = NEW.id_kh;
        IF v_id_hv IS NOT NULL THEN
            SELECT COALESCE(SUM(EXTRACT(DAY FROM (ngaytra - ngaynhan))::INT), 0)
            INTO v_tong_so_dem
            FROM hoadon.hoadon_thue_phong
            WHERE id_hd = NEW.id_hd;
            
            IF v_tong_so_dem <= 0 THEN
                v_tong_so_dem := 1;
            END IF;
            
            UPDATE khachhang.hoivien
            SET tong_luu_tru = tong_luu_tru + v_tong_so_dem
            WHERE id_hv = v_id_hv;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 14. Trigger function: Tự động cập nhật trạng thái phòng khi đặt/xóa phòng (V8)
CREATE OR REPLACE FUNCTION hoadon.func_dat_phong_auto_update_status()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE quanly.phong
        SET trang_thai = 'Đã đặt'
        WHERE id_p = NEW.id_p;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE quanly.phong
        SET trang_thai = 'Còn trống'
        WHERE id_p = OLD.id_p;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 15. Trigger function: Kiểm tra trùng lịch đặt phòng (V8)
CREATE OR REPLACE FUNCTION hoadon.func_check_booking_overlap()
RETURNS TRIGGER AS $$
DECLARE
    v_overlap_count INT;
BEGIN
    -- A. Đảm bảo ngày nhận phải trước ngày trả
    IF NEW.ngaynhan >= NEW.ngaytra THEN
        RAISE EXCEPTION 'Ngày nhận phòng (%) phải đứng trước ngày trả phòng (%)!', NEW.ngaynhan, NEW.ngaytra;
    END IF;

    -- B. Đảm bảo phòng không bị trùng lịch thuê với giao dịch khác chưa bị hủy
    SELECT COUNT(*) INTO v_overlap_count
    FROM hoadon.hoadon_thue_phong htp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE htp.id_p = NEW.id_p
      AND h.trang_thai != 'Đã hủy'
      -- Nếu là cập nhật, bỏ qua kiểm tra chính dòng đang sửa
      AND (TG_OP = 'INSERT' OR (htp.id_hd != NEW.id_hd OR htp.id_p != NEW.id_p))
      -- Điều kiện giao thoa ngày nhận/trả
      AND htp.ngaynhan < NEW.ngaytra
      AND htp.ngaytra > NEW.ngaynhan;

    IF v_overlap_count > 0 THEN
        RAISE EXCEPTION 'LỖI ĐẶT PHÒNG: Phòng (ID: %) đã được thuê/đặt bởi hóa đơn khác trong khoảng thời gian từ % đến %!', 
            NEW.id_p, NEW.ngaynhan, NEW.ngaytra;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 16. Trigger function: Khóa hóa đơn đã thanh toán (V8)
CREATE OR REPLACE FUNCTION hoadon.func_prevent_paid_invoice_edit()
RETURNS TRIGGER AS $$
DECLARE
    v_trang_thai VARCHAR(100);
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
        SELECT trang_thai INTO v_trang_thai
        FROM hoadon.hoadon
        WHERE id_hd = OLD.id_hd;

        IF v_trang_thai = 'Đã thanh toán' THEN
            RAISE EXCEPTION 'BẢO MẬT GIAO DỊCH: Không thể chỉnh sửa hoặc xóa chi tiết thuê phòng của hóa đơn đã thanh toán (Mã HĐ: %)!', OLD.id_hd;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- SCHEMA: hoadon - Nghiệp vụ chính (Main Business Functions)
-- ============================================================

-- 17. Tạo hóa đơn nhanh (V7)
CREATE OR REPLACE FUNCTION hoadon.func_them_hoa_don_nhanh(
    p_id_kh INT,
    p_id_nv INT,
    p_phuongthuc VARCHAR(100)
)
RETURNS INT AS $$
DECLARE
    v_id_hd INT;
BEGIN
    INSERT INTO hoadon.hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, p_phuongthuc, p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;
    
    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;

-- 18. Thêm dịch vụ vào hóa đơn (V9)
CREATE OR REPLACE FUNCTION hoadon.func_them_dich_vu_vao_hoa_don(
    p_id_hd INT,
    p_id_dv INT,
    p_so_luong INT
)
RETURNS MONEY AS $$
DECLARE
    v_trang_thai VARCHAR(100);
    v_gia_dv MONEY;
    v_exist_count INT;
    v_tong_tien_dv MONEY;
BEGIN
    -- 1. Kiểm tra trạng thái hóa đơn
    SELECT trang_thai INTO v_trang_thai
    FROM hoadon.hoadon
    WHERE id_hd = p_id_hd;

    IF v_trang_thai IS NULL THEN
        RAISE EXCEPTION 'Hóa đơn không tồn tại (Mã HĐ: %)!', p_id_hd;
    ELSIF v_trang_thai = 'Đã thanh toán' OR v_trang_thai = 'Đã hủy' THEN
        RAISE EXCEPTION 'Không thể thêm dịch vụ vào hóa đơn ở trạng thái %!', v_trang_thai;
    END IF;

    -- 2. Kiểm tra số lượng hợp lệ
    IF p_so_luong <= 0 THEN
        RAISE EXCEPTION 'Số lượng dịch vụ phải lớn hơn 0!';
    END IF;

    -- 3. Lấy giá dịch vụ
    SELECT gia INTO v_gia_dv
    FROM hoadon.dichvu
    WHERE id_dv = p_id_dv;

    IF v_gia_dv IS NULL THEN
        RAISE EXCEPTION 'Dịch vụ không tồn tại (Mã DV: %)!', p_id_dv;
    END IF;

    -- 4. Thêm hoặc cập nhật số lượng
    SELECT COUNT(*) INTO v_exist_count
    FROM hoadon.hoadon_sudung_dichvu
    WHERE id_hd = p_id_hd AND id_dv = p_id_dv;

    IF v_exist_count > 0 THEN
        UPDATE hoadon.hoadon_sudung_dichvu
        SET so_luong = so_luong + p_so_luong
        WHERE id_hd = p_id_hd AND id_dv = p_id_dv;
    ELSE
        INSERT INTO hoadon.hoadon_sudung_dichvu (id_hd, id_dv, so_luong)
        VALUES (p_id_hd, p_id_dv, p_so_luong);
    END IF;

    -- 5. Trả về tổng tiền cho dịch vụ này
    SELECT (so_luong * v_gia_dv) INTO v_tong_tien_dv
    FROM hoadon.hoadon_sudung_dichvu
    WHERE id_hd = p_id_hd AND id_dv = p_id_dv;

    RETURN v_tong_tien_dv;
END;
$$ LANGUAGE plpgsql;

-- 19. Check-out phòng (phiên bản V36 - dùng bảng phu_thu_phong)
CREATE OR REPLACE FUNCTION hoadon.func_check_out_phong(
    p_id_hd INT,
    p_id_p INT,
    p_phu_thu_tieu_hao MONEY DEFAULT 0::money,
    p_phu_thu_hong_hoc MONEY DEFAULT 0::money
)
RETURNS MONEY AS $$
BEGIN
    -- 1. Kiểm tra sự tồn tại của phòng trong hóa đơn
    IF NOT EXISTS (
        SELECT 1 
        FROM hoadon.hoadon_thue_phong 
        WHERE id_hd = p_id_hd AND id_p = p_id_p
    ) THEN
        RAISE EXCEPTION 'Phòng % không có trong hóa đơn %!', p_id_p, p_id_hd;
    END IF;

    -- 2. Cập nhật trạng thái phòng sang 'Còn trống'
    UPDATE quanly.phong
    SET trang_thai = 'Còn trống'
    WHERE id_p = p_id_p;

    -- 3. Cập nhật thời gian trả thực tế thành hiện tại
    UPDATE hoadon.hoadon_thue_phong
    SET ngaytra = CURRENT_TIMESTAMP
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    -- 4. Lưu các phụ thu vào bảng phu_thu_phong
    IF p_phu_thu_tieu_hao > 0::money THEN
        IF EXISTS (SELECT 1 FROM hoadon.phu_thu_phong WHERE id_hd = p_id_hd AND id_p = p_id_p AND loai_phu_thu = 'Tiêu hao') THEN
            UPDATE hoadon.phu_thu_phong
            SET so_tien = so_tien + p_phu_thu_tieu_hao
            WHERE id_hd = p_id_hd AND id_p = p_id_p AND loai_phu_thu = 'Tiêu hao';
        ELSE
            INSERT INTO hoadon.phu_thu_phong (id_hd, id_p, loai_phu_thu, so_tien)
            VALUES (p_id_hd, p_id_p, 'Tiêu hao', p_phu_thu_tieu_hao);
        END IF;
    END IF;

    IF p_phu_thu_hong_hoc > 0::money THEN
        IF EXISTS (SELECT 1 FROM hoadon.phu_thu_phong WHERE id_hd = p_id_hd AND id_p = p_id_p AND loai_phu_thu = 'Hỏng hóc') THEN
            UPDATE hoadon.phu_thu_phong
            SET so_tien = so_tien + p_phu_thu_hong_hoc
            WHERE id_hd = p_id_hd AND id_p = p_id_p AND loai_phu_thu = 'Hỏng hóc';
        ELSE
            INSERT INTO hoadon.phu_thu_phong (id_hd, id_p, loai_phu_thu, so_tien)
            VALUES (p_id_hd, p_id_p, 'Hỏng hóc', p_phu_thu_hong_hoc);
        END IF;
    END IF;

    -- 5. Tính toán và trả về tổng số tiền trả sau của toàn bộ hóa đơn hiện tại
    RETURN hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);
END;
$$ LANGUAGE plpgsql;

-- 20. Thanh toán hóa đơn (phiên bản V29 - phòng chuyển sang 'Còn trống')
CREATE OR REPLACE FUNCTION hoadon.func_thanh_toan_hoa_don(
    p_id_hd INT,
    p_phuongthuc VARCHAR(100)
)
RETURNS MONEY AS $$
DECLARE
    v_tong_thanh_toan MONEY;
    r RECORD;
BEGIN
    -- 1. Cập nhật ngày thanh toán
    UPDATE hoadon.hoadon
    SET ngaythanhtoan = CURRENT_TIMESTAMP
    WHERE id_hd = p_id_hd;

    -- 2. Tính tổng tiền cuối cùng
    v_tong_thanh_toan := hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);

    -- 3. Cập nhật trạng thái hóa đơn
    UPDATE hoadon.hoadon
    SET trang_thai = 'Đã thanh toán',
        phuongthuc = p_phuongthuc
    WHERE id_hd = p_id_hd;

    -- 4. Giải phóng phòng
    FOR r IN 
        SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE quanly.phong
        SET trang_thai = 'Còn trống'
        WHERE id_p = r.id_p AND trang_thai != 'Còn trống';
    END LOOP;

    RETURN v_tong_thanh_toan;
END;
$$ LANGUAGE plpgsql;

-- 21. Chuyển phòng (phiên bản V29 - phòng cũ chuyển sang 'Còn trống')
CREATE OR REPLACE FUNCTION hoadon.func_chuyen_phong(
    p_id_hd INT,
    p_id_p_cu INT,
    p_id_p_moi INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_trang_thai_moi VARCHAR(100);
    v_exists BOOLEAN;
BEGIN
    -- 1. Kiểm tra phòng mới có trống không
    SELECT trang_thai INTO v_trang_thai_moi
    FROM quanly.phong
    WHERE id_p = p_id_p_moi;

    IF v_trang_thai_moi != 'Còn trống' THEN
        RAISE NOTICE 'Phòng mới (ID: %) không ở trạng thái trống! Không thể chuyển.', p_id_p_moi;
        RETURN FALSE;
    END IF;

    -- 2. Kiểm tra phòng cũ có trong hóa đơn không
    SELECT EXISTS(
        SELECT 1 FROM hoadon.hoadon_thue_phong 
        WHERE id_hd = p_id_hd AND id_p = p_id_p_cu
    ) INTO v_exists;

    IF NOT v_exists THEN
        RAISE NOTICE 'Phòng cũ (ID: %) không được đăng ký trong hóa đơn (ID: %)!', p_id_p_cu, p_id_hd;
        RETURN FALSE;
    END IF;

    -- 3. Cập nhật phòng mới vào hóa đơn
    UPDATE hoadon.hoadon_thue_phong
    SET id_p = p_id_p_moi
    WHERE id_hd = p_id_hd AND id_p = p_id_p_cu;

    -- 4. Cập nhật trạng thái phòng cũ
    UPDATE quanly.phong
    SET trang_thai = 'Còn trống'
    WHERE id_p = p_id_p_cu;

    -- 5. Cập nhật trạng thái phòng mới
    UPDATE quanly.phong
    SET trang_thai = 'Đã đặt'
    WHERE id_p = p_id_p_moi;

    RAISE NOTICE 'Chuyển phòng thành công từ % sang % cho hóa đơn %.', p_id_p_cu, p_id_p_moi, p_id_hd;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 22. Hủy đặt phòng (V9)
CREATE OR REPLACE FUNCTION hoadon.func_huy_dat_phong(
    p_id_hd INT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_trang_thai VARCHAR(100);
    r RECORD;
BEGIN
    -- 1. Kiểm tra trạng thái hóa đơn
    SELECT trang_thai INTO v_trang_thai
    FROM hoadon.hoadon
    WHERE id_hd = p_id_hd;

    IF v_trang_thai IS NULL THEN
        RAISE NOTICE 'Hóa đơn không tồn tại (Mã HĐ: %)!', p_id_hd;
        RETURN FALSE;
    ELSIF v_trang_thai = 'Đã thanh toán' THEN
        RAISE NOTICE 'Hóa đơn đã được thanh toán, không thể hủy!';
        RETURN FALSE;
    ELSIF v_trang_thai = 'Đã hủy' THEN
        RAISE NOTICE 'Hóa đơn đã được hủy trước đó!';
        RETURN TRUE;
    END IF;

    -- 2. Cập nhật trạng thái phòng sang 'Còn trống'
    FOR r IN 
        SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE quanly.phong
        SET trang_thai = 'Còn trống'
        WHERE id_p = r.id_p;
    END LOOP;

    -- 3. Cập nhật trạng thái hóa đơn sang 'Đã hủy'
    UPDATE hoadon.hoadon
    SET trang_thai = 'Đã hủy'
    WHERE id_hd = p_id_hd;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- SCHEMA: quanly - Helper Functions
-- ============================================================

-- 23. Helper: Tìm phòng trống phù hợp (V24)
CREATE OR REPLACE FUNCTION quanly.func_tim_phong_trong_phu_hop(
    p_id_cn INT,
    p_chat_luong VARCHAR(100),
    p_loai_giuong VARCHAR(100),
    p_dien_tich VARCHAR(50),
    p_view VARCHAR(100),
    p_doi_tuong VARCHAR(100),
    p_ngaynhan TIMESTAMP,
    p_ngaytra TIMESTAMP,
    OUT o_id_p INT,
    OUT o_gia_tien MONEY
) AS $$
BEGIN
    SELECT p.id_p, lp.gia_tien INTO o_id_p, o_gia_tien
    FROM quanly.phong p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND lp.chat_luong = p_chat_luong
      AND lp.loai_giuong = p_loai_giuong
      AND (p_dien_tich IS NULL OR lp.dien_tich = p_dien_tich)
      AND (p_view IS NULL OR lp.view = p_view)
      AND (p_doi_tuong IS NULL OR lp.doi_tuong = p_doi_tuong)
      AND p.trang_thai = 'Còn trống'
      AND NOT EXISTS (
          SELECT 1 
          FROM hoadon.hoadon_thue_phong htp
          JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
          WHERE htp.id_p = p.id_p
            AND h.trang_thai != 'Đã hủy'
            AND htp.ngaynhan < p_ngaytra
            AND htp.ngaytra > p_ngaynhan
      )
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- 24. Helper: Số ngày trong tháng (V24)
CREATE OR REPLACE FUNCTION quanly.func_lay_so_ngay_trong_thang(p_thang INT, p_nam INT)
RETURNS INT AS $$
BEGIN
    RETURN EXTRACT(DAY FROM (DATE_TRUNC('month', MAKE_DATE(p_nam, p_thang, 1)) + INTERVAL '1 month' - INTERVAL '1 day'))::INT;
END;
$$ LANGUAGE plpgsql;

-- 25. Helper: Doanh thu dịch vụ chi nhánh (V24)
CREATE OR REPLACE FUNCTION quanly.func_tinh_doanh_thu_dich_vu_chi_nhanh(
    p_id_cn INT,
    p_thang INT,
    p_nam INT
)
RETURNS MONEY AS $$
DECLARE
    v_tien_dv MONEY := 0::money;
BEGIN
    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tien_dv
    FROM hoadon.hoadon h
    JOIN hoadon.hoadon_sudung_dichvu hsd ON h.id_hd = hsd.id_hd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE EXISTS (
        SELECT 1 FROM hoadon.hoadon_thue_phong htp
        JOIN quanly.phong p ON htp.id_p = p.id_p
        JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
        WHERE htp.id_hd = h.id_hd AND lp.id_cn = p_id_cn
    )
    AND h.trang_thai = 'Đã thanh toán'
    AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
    AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

    RETURN v_tien_dv;
END;
$$ LANGUAGE plpgsql;

-- 26. Helper: Hiệu suất phòng (V24)
CREATE OR REPLACE FUNCTION quanly.func_tinh_hieu_suat_phong(
    p_id_cn INT,
    p_thang INT,
    p_nam INT,
    p_ngay_trong_thang INT,
    p_tong_so_phong INT
)
RETURNS NUMERIC(5,2) AS $$
DECLARE
    v_tong_so_ngay_thue INT := 0;
    v_hieu_suat NUMERIC(5,2) := 0.00;
BEGIN
    SELECT COALESCE(SUM(
        EXTRACT(DAY FROM (
            LEAST(htp.ngaytra, MAKE_DATE(p_nam, p_thang, p_ngay_trong_thang) + TIME '23:59:59') - 
            GREATEST(htp.ngaynhan, MAKE_DATE(p_nam, p_thang, 1))
        ))::INT
    ), 0) INTO v_tong_so_ngay_thue
    FROM hoadon.hoadon_thue_phong htp
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai != 'Đã hủy'
      AND htp.ngaynhan <= (MAKE_DATE(p_nam, p_thang, p_ngay_trong_thang) + TIME '23:59:59')
      AND htp.ngaytra >= MAKE_DATE(p_nam, p_thang, 1);

    IF v_tong_so_ngay_thue < 0 THEN
        v_tong_so_ngay_thue := 0;
    END IF;

    IF p_tong_so_phong > 0 AND p_ngay_trong_thang > 0 THEN
        v_hieu_suat := (v_tong_so_ngay_thue::numeric / (p_tong_so_phong * p_ngay_trong_thang)) * 100;
        IF v_hieu_suat > 100.00 THEN
            v_hieu_suat := 100.00;
        END IF;
    ELSE
        v_hieu_suat := 0.00;
    END IF;

    RETURN v_hieu_suat;
END;
$$ LANGUAGE plpgsql;


-- ============================================================
-- SCHEMA: quanly - Nghiệp vụ chính (Main Business Functions)
-- ============================================================

-- 27. Tìm và đặt phòng nhanh (phiên bản V36 - dùng bảng phu_thu_phong)
CREATE OR REPLACE FUNCTION quanly.func_tim_va_dat_phong_nhanh(
    p_id_kh INT,
    p_id_nv INT,
    p_id_cn INT,
    p_chat_luong VARCHAR(100),
    p_loai_giuong VARCHAR(100),
    p_ngaynhan TIMESTAMP,
    p_ngaytra TIMESTAMP,
    p_tien_coc MONEY DEFAULT 0::money,
    p_phu_thu MONEY DEFAULT 0::money,
    p_dien_tich VARCHAR(50) DEFAULT NULL,
    p_view VARCHAR(100) DEFAULT NULL,
    p_doi_tuong VARCHAR(100) DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    v_id_p INT;
    v_id_hd INT;
    v_gia_tien MONEY;
    v_so_ngay_luu_tru INT;
BEGIN
    -- 1. Tìm phòng trống bằng helper function
    SELECT * INTO v_id_p, v_gia_tien
    FROM quanly.func_tim_phong_trong_phu_hop(
        p_id_cn, p_chat_luong, p_loai_giuong,
        p_dien_tich, p_view, p_doi_tuong,
        p_ngaynhan, p_ngaytra
    );

    IF v_id_p IS NULL THEN
        RAISE EXCEPTION 'Không có phòng trống nào thuộc chi nhánh % với chất lượng %, giường %, diện tích %, view %, đối tượng % từ % đến %!', 
            p_id_cn, p_chat_luong, p_loai_giuong, COALESCE(p_dien_tich, 'Bất kỳ'), COALESCE(p_view, 'Bất kỳ'), COALESCE(p_doi_tuong, 'Bất kỳ'), p_ngaynhan, p_ngaytra;
    END IF;

    -- 2. Tạo hóa đơn mới ở trạng thái "Đã đặt"
    INSERT INTO hoadon.hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, 'Tiền mặt', p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;

    -- Tính toán số ngày lưu trú từ dự kiến ban đầu
    v_so_ngay_luu_tru := EXTRACT(DAY FROM (p_ngaytra - p_ngaynhan))::INT;
    IF v_so_ngay_luu_tru <= 0 THEN
        v_so_ngay_luu_tru := 1;
    END IF;

    -- 3. Tạo bản ghi chi tiết thuê phòng
    INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, so_ngay_luu_tru)
    VALUES (v_id_hd, v_id_p, p_ngaynhan, p_ngaytra, v_so_ngay_luu_tru);

    -- 4. Lưu phụ thu ban đầu vào bảng phu_thu_phong nếu có
    IF p_phu_thu > 0::money THEN
        INSERT INTO hoadon.phu_thu_phong (id_hd, id_p, loai_phu_thu, so_tien)
        VALUES (v_id_hd, v_id_p, 'Tiêu hao', p_phu_thu);
    END IF;

    -- 5. Trả về ID của hóa đơn mới được lập
    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;

-- 28. Báo cáo doanh thu và hiệu suất chi nhánh (V24)
CREATE OR REPLACE FUNCTION quanly.func_bao_cao_doanh_thu_va_hieu_suat_chi_nhanh(
    p_id_cn INT,
    p_thang INT,
    p_nam INT
)
RETURNS TABLE (
    tong_doanh_thu MONEY,
    so_hoa_don_thanh_toan INT,
    so_luot_phong_thue INT,
    hieu_suat_phong_percent NUMERIC(5,2)
) AS $$
DECLARE
    v_tong_doanh_thu MONEY := 0::money;
    v_so_hd INT := 0;
    v_so_phong_thue INT := 0;
    v_tong_so_phong INT := 0;
    v_ngay_trong_thang INT;
    v_hieu_suat NUMERIC(5,2) := 0.00;
BEGIN
    SELECT COUNT(*) INTO v_tong_so_phong
    FROM quanly.phong p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn;

    v_ngay_trong_thang := quanly.func_lay_so_ngay_trong_thang(p_thang, p_nam);

    SELECT COALESCE(SUM(hoadon.func_tinh_tien_phong(htp.id_hd, htp.id_p)), 0::money), COUNT(DISTINCT h.id_hd)
    INTO v_tong_doanh_thu, v_so_hd
    FROM hoadon.hoadon h
    JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai = 'Đã thanh toán'
      AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
      AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

    v_tong_doanh_thu := v_tong_doanh_thu + quanly.func_tinh_doanh_thu_dich_vu_chi_nhanh(p_id_cn, p_thang, p_nam);

    SELECT COUNT(*) INTO v_so_phong_thue
    FROM hoadon.hoadon_thue_phong htp
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai != 'Đã hủy'
      AND (
          (EXTRACT(MONTH FROM htp.ngaynhan) = p_thang AND EXTRACT(YEAR FROM htp.ngaynhan) = p_nam)
          OR
          (EXTRACT(MONTH FROM htp.ngaytra) = p_thang AND EXTRACT(YEAR FROM htp.ngaytra) = p_nam)
      );

    v_hieu_suat := quanly.func_tinh_hieu_suat_phong(p_id_cn, p_thang, p_nam, v_ngay_trong_thang, v_tong_so_phong);

    RETURN QUERY SELECT v_tong_doanh_thu, v_so_hd, v_so_phong_thue, v_hieu_suat;
END;
$$ LANGUAGE plpgsql;

-- 29. Báo cáo tài chính (phiên bản V36 - dùng bảng phu_thu_phong)
CREATE OR REPLACE FUNCTION quanly.func_bao_cao_tai_chinh(
    p_id_cn INT,
    p_tu_ngay TIMESTAMP,
    p_den_ngay TIMESTAMP
)
RETURNS TABLE (
    tong_doanh_thu_thuc_te MONEY,
    tien_coc_phong_online MONEY,
    tong_phu_thu_tieu_hao MONEY,
    tong_den_bu_hong_hoc MONEY
) AS $$
DECLARE
    v_tong_doanh_thu MONEY := 0::money;
    v_tien_coc_online MONEY := 0::money;
    v_tieu_hao MONEY := 0::money;
    v_hong_hoc MONEY := 0::money;
BEGIN
    -- 1. Tổng doanh thu thực tế
    SELECT COALESCE(SUM(hoadon.func_tinh_tong_tien_hoa_don(h.id_hd)), 0::money)
    INTO v_tong_doanh_thu
    FROM hoadon.hoadon h
    JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv
    WHERE h.trang_thai = 'Đã thanh toán'
      AND (p_id_cn = -1 OR nv.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay;

    -- 2. Tiền cọc 50% từ các phòng online chưa check-in
    SELECT COALESCE(SUM(htp.so_ngay_luu_tru * lp.gia_tien * 0.5), 0::money)
    INTO v_tien_coc_online
    FROM hoadon.hoadon h
    JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE h.trang_thai IN ('Đã đặt', 'Đã cọc')
      AND (p_id_cn = -1 OR lp.id_cn = p_id_cn)
      AND htp.ngaynhan >= CURRENT_TIMESTAMP;

    -- 3. Tổng phụ thu vật phẩm tiêu hao thực tế
    SELECT COALESCE(SUM(so_tien), 0::money)
    INTO v_tieu_hao
    FROM hoadon.hoadon h
    JOIN hoadon.phu_thu_phong pt ON h.id_hd = pt.id_hd
    JOIN quanly.phong p ON pt.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE h.trang_thai = 'Đã thanh toán'
      AND pt.loai_phu_thu = 'Tiêu hao'
      AND (p_id_cn = -1 OR lp.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay;

    -- 4. Tổng tiền đền bù hỏng hóc thực tế
    SELECT COALESCE(SUM(so_tien), 0::money)
    INTO v_hong_hoc
    FROM hoadon.hoadon h
    JOIN hoadon.phu_thu_phong pt ON h.id_hd = pt.id_hd
    JOIN quanly.phong p ON pt.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE h.trang_thai = 'Đã thanh toán'
      AND pt.loai_phu_thu = 'Hỏng hóc'
      AND (p_id_cn = -1 OR lp.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay;

    RETURN QUERY SELECT v_tong_doanh_thu, v_tien_coc_online, v_tieu_hao, v_hong_hoc;
END;
$$ LANGUAGE plpgsql;

-- 30. Thống kê loại phòng doanh thu (V24)
CREATE OR REPLACE FUNCTION quanly.func_thong_ke_loai_phong_doanh_thu(
    p_id_cn INT,
    p_tu_ngay TIMESTAMP,
    p_den_ngay TIMESTAMP
)
RETURNS TABLE (
    ten_loai_phong VARCHAR(255),
    tong_doanh_thu MONEY
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (lp.chat_luong || ' - ' || lp.loai_giuong)::VARCHAR(255) AS ten_loai_phong,
        COALESCE(SUM(hoadon.func_tinh_tien_phong(htp.id_hd, htp.id_p)), 0::money) AS tong_doanh_thu
    FROM hoadon.hoadon_thue_phong htp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE h.trang_thai = 'Đã thanh toán'
      AND (p_id_cn = -1 OR lp.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay
    GROUP BY lp.chat_luong, lp.loai_giuong
    ORDER BY tong_doanh_thu DESC;
END;
$$ LANGUAGE plpgsql;
