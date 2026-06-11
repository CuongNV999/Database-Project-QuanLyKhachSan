-- Migration: V9 - Add more important transactional and reporting functions

-- 1. Create hoadon.func_them_dich_vu_vao_hoa_don
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
    FROM hoadon
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
    FROM dichvu
    WHERE id_dv = p_id_dv;

    IF v_gia_dv IS NULL THEN
        RAISE EXCEPTION 'Dịch vụ không tồn tại (Mã DV: %)!', p_id_dv;
    END IF;

    -- 4. Thêm hoặc cập nhật số lượng
    SELECT COUNT(*) INTO v_exist_count
    FROM hoadon_sudung_dichvu
    WHERE id_hd = p_id_hd AND id_dv = p_id_dv;

    IF v_exist_count > 0 THEN
        UPDATE hoadon_sudung_dichvu
        SET so_luong = so_luong + p_so_luong
        WHERE id_hd = p_id_hd AND id_dv = p_id_dv;
    ELSE
        INSERT INTO hoadon_sudung_dichvu (id_hd, id_dv, so_luong)
        VALUES (p_id_hd, p_id_dv, p_so_luong);
    END IF;

    -- 5. Trả về tổng tiền cho dịch vụ này
    SELECT (so_luong * v_gia_dv) INTO v_tong_tien_dv
    FROM hoadon_sudung_dichvu
    WHERE id_hd = p_id_hd AND id_dv = p_id_dv;

    RETURN v_tong_tien_dv;
END;
$$ LANGUAGE plpgsql;


-- 2. Create khachhang.func_tu_dong_nang_hang_hoi_vien
CREATE OR REPLACE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien()
RETURNS TRIGGER AS $$
BEGIN
    -- Xác định hạng hội viên dựa trên điểm tích lũy:
    -- < 100 điểm: Hạng NULL
    -- Từ 100 đến 299 điểm: Bronze
    -- Từ 300 đến 799 điểm: Silver
    -- Từ 800 điểm trở lên: Gold
    IF NEW.diem_tich_luy >= 800 THEN
        NEW.hang := 'Gold';
    ELSIF NEW.diem_tich_luy >= 300 THEN
        NEW.hang := 'Silver';
    ELSIF NEW.diem_tich_luy >= 100 THEN
        NEW.hang := 'Bronze';
    ELSE
        NEW.hang := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Register loyalty rank trigger
DROP TRIGGER IF EXISTS trg_tu_dong_nang_hang_hoivien ON khachhang.hoivien;
CREATE TRIGGER trg_tu_dong_nang_hang_hoivien
BEFORE UPDATE OF diem_tich_luy ON khachhang.hoivien
FOR EACH ROW
EXECUTE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien();


-- 3. Create hoadon.func_huy_dat_phong
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
    FROM hoadon
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
        SELECT id_p FROM hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE phong
        SET trang_thai = 'Còn trống'
        WHERE id_p = r.id_p;
    END LOOP;

    -- 3. Cập nhật trạng thái hóa đơn sang 'Đã hủy'
    UPDATE hoadon
    SET trang_thai = 'Đã hủy'
    WHERE id_hd = p_id_hd;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


-- 4. Create quanly.func_tim_va_dat_phong_nhanh
CREATE OR REPLACE FUNCTION quanly.func_tim_va_dat_phong_nhanh(
    p_id_kh INT,
    p_id_nv INT,
    p_id_cn INT,
    p_chat_luong VARCHAR(100),
    p_loai_giuong VARCHAR(100),
    p_ngaynhan TIMESTAMP,
    p_ngaytra TIMESTAMP,
    p_tien_coc MONEY DEFAULT 0::money,
    p_phu_thu MONEY DEFAULT 0::money
)
RETURNS INT AS $$
DECLARE
    v_id_p INT;
    v_id_hd INT;
    v_gia_tien MONEY;
    v_tong_tien_phong MONEY;
BEGIN
    -- 1. Tìm phòng trống của chi nhánh và loại phòng phù hợp không trùng lịch
    SELECT p.id_p, lp.gia_tien INTO v_id_p, v_gia_tien
    FROM phong p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND lp.chat_luong = p_chat_luong
      AND lp.loai_giuong = p_loai_giuong
      AND p.trang_thai = 'Còn trống'
      AND NOT EXISTS (
          -- Kiểm tra trùng lịch với bất kỳ đặt phòng nào chưa hủy
          SELECT 1 
          FROM hoadon_thue_phong htp
          JOIN hoadon h ON htp.id_hd = h.id_hd
          WHERE htp.id_p = p.id_p
            AND h.trang_thai != 'Đã hủy'
            AND htp.ngaynhan < p_ngaytra
            AND htp.ngaytra > p_ngaynhan
      )
    LIMIT 1;

    IF v_id_p IS NULL THEN
        RAISE EXCEPTION 'Không có phòng trống nào thuộc chi nhánh % với chất lượng %, loại giường % trong khoảng thời gian từ % đến %!', 
            p_id_cn, p_chat_luong, p_loai_giuong, p_ngaynhan, p_ngaytra;
    END IF;

    -- 2. Tạo hóa đơn mới
    INSERT INTO hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, 'Tiền mặt', p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;

    -- 3. Đăng ký thuê phòng
    INSERT INTO hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, tien_coc, phu_thu, tong_tien)
    VALUES (v_id_hd, v_id_p, p_ngaynhan, p_ngaytra, p_tien_coc, p_phu_thu, 0::money);

    -- 4. Tính toán tổng tiền thực tế
    v_tong_tien_phong := hoadon.func_tinh_tien_phong(v_id_hd, v_id_p);

    -- 5. Cập nhật lại tổng tiền trong chi tiết thuê phòng
    UPDATE hoadon_thue_phong
    SET tong_tien = v_tong_tien_phong
    WHERE id_hd = v_id_hd AND id_p = v_id_p;

    -- 6. Trả về ID hóa đơn mới
    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;


-- 5. Create quanly.func_bao_cao_doanh_thu_va_hieu_suat_chi_nhanh
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
    -- 1. Đếm tổng số phòng của chi nhánh này
    SELECT COUNT(*) INTO v_tong_so_phong
    FROM phong p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn;

    -- 2. Tính số ngày trong tháng đó
    v_ngay_trong_thang := EXTRACT(DAY FROM (DATE_TRUNC('month', MAKE_DATE(p_nam, p_thang, 1)) + INTERVAL '1 month' - INTERVAL '1 day'))::INT;

    -- 3. Tính doanh thu phòng và dịch vụ cho chi nhánh trong tháng/năm đó từ các hóa đơn đã thanh toán
    SELECT COALESCE(SUM(htp.tong_tien), 0::money), COUNT(DISTINCT h.id_hd)
    INTO v_tong_doanh_thu, v_so_hd
    FROM hoadon h
    JOIN hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN phong p ON htp.id_p = p.id_p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai = 'Đã thanh toán'
      AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
      AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

    -- Tính thêm doanh thu dịch vụ cho các hóa đơn thuộc chi nhánh trong tháng/năm đó
    DECLARE
        v_tien_dv MONEY := 0::money;
    BEGIN
        SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
        INTO v_tien_dv
        FROM hoadon h
        JOIN hoadon_sudung_dichvu hsd ON h.id_hd = hsd.id_hd
        JOIN dichvu dv ON hsd.id_dv = dv.id_dv
        WHERE EXISTS (
            SELECT 1 FROM hoadon_thue_phong htp
            JOIN phong p ON htp.id_p = p.id_p
            JOIN loaiphong lp ON p.id_lp = lp.id_lp
            WHERE htp.id_hd = h.id_hd AND lp.id_cn = p_id_cn
        )
        AND h.trang_thai = 'Đã thanh toán'
        AND EXTRACT(MONTH FROM h.ngaythanhtoan) = p_thang
        AND EXTRACT(YEAR FROM h.ngaythanhtoan) = p_nam;

        v_tong_doanh_thu := v_tong_doanh_thu + v_tien_dv;
    END;

    -- 4. Tính số lượt phòng đã được thuê trong tháng
    SELECT COUNT(*) INTO v_so_phong_thue
    FROM hoadon_thue_phong htp
    JOIN phong p ON htp.id_p = p.id_p
    JOIN loaiphong lp ON p.id_lp = lp.id_lp
    JOIN hoadon h ON htp.id_hd = h.id_hd
    WHERE lp.id_cn = p_id_cn
      AND h.trang_thai != 'Đã hủy'
      AND (
          (EXTRACT(MONTH FROM htp.ngaynhan) = p_thang AND EXTRACT(YEAR FROM htp.ngaynhan) = p_nam)
          OR
          (EXTRACT(MONTH FROM htp.ngaytra) = p_thang AND EXTRACT(YEAR FROM htp.ngaytra) = p_nam)
      );

    -- 5. Tính hiệu suất phòng (%)
    DECLARE
        v_tong_so_ngay_thue INT := 0;
    BEGIN
        SELECT COALESCE(SUM(
            EXTRACT(DAY FROM (
                LEAST(htp.ngaytra, MAKE_DATE(p_nam, p_thang, v_ngay_trong_thang) + TIME '23:59:59') - 
                GREATEST(htp.ngaynhan, MAKE_DATE(p_nam, p_thang, 1))
            ))::INT
        ), 0) INTO v_tong_so_ngay_thue
        FROM hoadon_thue_phong htp
        JOIN phong p ON htp.id_p = p.id_p
        JOIN loaiphong lp ON p.id_lp = lp.id_lp
        JOIN hoadon h ON htp.id_hd = h.id_hd
        WHERE lp.id_cn = p_id_cn
          AND h.trang_thai != 'Đã hủy'
          AND htp.ngaynhan <= (MAKE_DATE(p_nam, p_thang, v_ngay_trong_thang) + TIME '23:59:59')
          AND htp.ngaytra >= MAKE_DATE(p_nam, p_thang, 1);

        IF v_tong_so_ngay_thue < 0 THEN
            v_tong_so_ngay_thue := 0;
        END IF;

        IF v_tong_so_phong > 0 AND v_ngay_trong_thang > 0 THEN
            v_hieu_suat := (v_tong_so_ngay_thue::numeric / (v_tong_so_phong * v_ngay_trong_thang)) * 100;
            IF v_hieu_suat > 100.00 THEN
                v_hieu_suat := 100.00;
            END IF;
        ELSE
            v_hieu_suat := 0.00;
        END IF;
    END;

    RETURN QUERY SELECT v_tong_doanh_thu, v_so_hd, v_so_phong_thue, v_hieu_suat;
END;
$$ LANGUAGE plpgsql;
