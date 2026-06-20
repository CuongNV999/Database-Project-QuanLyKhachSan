-- Migration: V16 - Thêm cột tách nhỏ phụ thu và cập nhật/bổ sung các hàm nghiệp vụ
-- ---------------------------------------------------------------------------------

-- 1. Thêm cột phụ thu tiêu hao và phụ thu hỏng hóc vào hoadon_thue_phong để dễ báo cáo doanh thu dòng tiền chi tiết
ALTER TABLE hoadon.hoadon_thue_phong ADD COLUMN phu_thu_tieu_hao MONEY DEFAULT 0::numeric::money;
ALTER TABLE hoadon.hoadon_thue_phong ADD COLUMN phu_thu_hong_hoc MONEY DEFAULT 0::numeric::money;

-- 2. Cập nhật hàm thanh toán hóa đơn để dùng CURRENT_TIMESTAMP và quản lý chuyển đổi trạng thái phòng tốt hơn
CREATE OR REPLACE FUNCTION hoadon.func_thanh_toan_hoa_don(
    p_id_hd INT,
    p_phuongthuc VARCHAR(100)
)
RETURNS MONEY AS $$
DECLARE
    v_tong_thanh_toan MONEY;
    r RECORD;
BEGIN
    -- Cập nhật ngày thanh toán thành TIMESTAMP thực tế hiện tại trước khi tính tiền
    UPDATE hoadon.hoadon
    SET ngaythanhtoan = CURRENT_TIMESTAMP
    WHERE id_hd = p_id_hd;

    -- Tính tổng tiền cuối cùng của hóa đơn
    v_tong_thanh_toan := hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);

    -- Đánh dấu trạng thái hóa đơn là Đã thanh toán
    UPDATE hoadon.hoadon
    SET trang_thai = 'Đã thanh toán',
        phuongthuc = p_phuongthuc
    WHERE id_hd = p_id_hd;

    -- Giải phóng các phòng liên quan
    FOR r IN 
        SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
    LOOP
        UPDATE quanly.phong
        SET trang_thai = 'Đang dọn dẹp'
        WHERE id_p = r.id_p AND trang_thai NOT IN ('Đang dọn dẹp', 'Đang sửa');
    END LOOP;

    RETURN v_tong_thanh_toan;
END;
$$ LANGUAGE plpgsql;

-- 3. Tạo hàm thực hiện check-out từng phòng trong hóa đơn
CREATE OR REPLACE FUNCTION hoadon.func_check_out_phong(
    p_id_hd INT,
    p_id_p INT,
    p_phu_thu_tieu_hao MONEY DEFAULT 0::money,
    p_phu_thu_hong_hoc MONEY DEFAULT 0::money
)
RETURNS MONEY AS $$
DECLARE
    v_tong_tien_phong MONEY;
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM hoadon.hoadon_thue_phong 
        WHERE id_hd = p_id_hd AND id_p = p_id_p
    ) THEN
        RAISE EXCEPTION 'Phòng % không có trong hóa đơn %!', p_id_p, p_id_hd;
    END IF;

    -- Đổi trạng thái phòng
    IF p_phu_thu_hong_hoc > 0::money THEN
        UPDATE quanly.phong
        SET trang_thai = 'Đang sửa'
        WHERE id_p = p_id_p;
    ELSE
        UPDATE quanly.phong
        SET trang_thai = 'Đang dọn dẹp'
        WHERE id_p = p_id_p;
    END IF;

    -- Cộng dồn phụ thu chi tiết vào hóa đơn đặt phòng
    UPDATE hoadon.hoadon_thue_phong
    SET phu_thu_tieu_hao = COALESCE(phu_thu_tieu_hao, 0::money) + p_phu_thu_tieu_hao,
        phu_thu_hong_hoc = COALESCE(phu_thu_hong_hoc, 0::money) + p_phu_thu_hong_hoc,
        phu_thu = COALESCE(phu_thu, 0::money) + p_phu_thu_tieu_hao + p_phu_thu_hong_hoc
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    -- Tính lại tổng tiền của riêng phòng này
    v_tong_tien_phong := hoadon.func_tinh_tien_phong(p_id_hd, p_id_p);

    UPDATE hoadon.hoadon_thue_phong
    SET tong_tien = v_tong_tien_phong
    WHERE id_hd = p_id_hd AND id_p = p_id_p;

    -- Tính và trả về tổng hóa đơn
    RETURN hoadon.func_tinh_tong_tien_hoa_don(p_id_hd);
END;
$$ LANGUAGE plpgsql;

-- 4. Cập nhật hàm tìm và đặt phòng nhanh để hỗ trợ bộ lọc nâng cao (diện tích, view, đối tượng)
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
    v_tong_tien_phong MONEY;
BEGIN
    SELECT p.id_p, lp.gia_tien INTO v_id_p, v_gia_tien
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

    IF v_id_p IS NULL THEN
        RAISE EXCEPTION 'Không có phòng trống nào thuộc chi nhánh % với chất lượng %, giường %, diện tích %, view %, đối tượng % từ % đến %!', 
            p_id_cn, p_chat_luong, p_loai_giuong, COALESCE(p_dien_tich, 'Bất kỳ'), COALESCE(p_view, 'Bất kỳ'), COALESCE(p_doi_tuong, 'Bất kỳ'), p_ngaynhan, p_ngaytra;
    END IF;

    INSERT INTO hoadon.hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv)
    VALUES ('Đã đặt', CURRENT_DATE, 'Tiền mặt', p_id_kh, p_id_nv)
    RETURNING id_hd INTO v_id_hd;

    INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, tien_coc, phu_thu, tong_tien)
    VALUES (v_id_hd, v_id_p, p_ngaynhan, p_ngaytra, p_tien_coc, p_phu_thu, 0::money);

    v_tong_tien_phong := hoadon.func_tinh_tien_phong(v_id_hd, v_id_p);

    UPDATE hoadon.hoadon_thue_phong
    SET tong_tien = v_tong_tien_phong
    WHERE id_hd = v_id_hd AND id_p = v_id_p;

    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;

-- 5. Báo cáo dòng tiền chi tiết cho Admin
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
    SELECT COALESCE(SUM(hoadon.func_tinh_tong_tien_hoa_don(h.id_hd)), 0::money)
    INTO v_tong_doanh_thu
    FROM hoadon.hoadon h
    JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv
    WHERE h.trang_thai = 'Đã thanh toán'
      AND (p_id_cn = -1 OR nv.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay;

    SELECT COALESCE(SUM(htp.tien_coc), 0::money)
    INTO v_tien_coc_online
    FROM hoadon.hoadon h
    JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE h.trang_thai IN ('Đã đặt', 'Đã cọc')
      AND (p_id_cn = -1 OR lp.id_cn = p_id_cn)
      AND htp.ngaynhan >= CURRENT_TIMESTAMP;

    SELECT COALESCE(SUM(htp.phu_thu_tieu_hao), 0::money), COALESCE(SUM(htp.phu_thu_hong_hoc), 0::money)
    INTO v_tieu_hao, v_hong_hoc
    FROM hoadon.hoadon h
    JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd
    JOIN quanly.phong p ON htp.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE h.trang_thai = 'Đã thanh toán'
      AND (p_id_cn = -1 OR lp.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay;

    RETURN QUERY SELECT v_tong_doanh_thu, v_tien_coc_online, v_tieu_hao, v_hong_hoc;
END;
$$ LANGUAGE plpgsql;

-- 6. Báo cáo xếp hạng doanh thu theo loại phòng
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
        COALESCE(SUM(htp.tong_tien), 0::money) AS tong_doanh_thu
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

-- 7. Báo cáo đánh giá hỏng hóc bảo trì thiết bị
CREATE OR REPLACE FUNCTION quanly.func_thong_ke_tan_suat_hong_hoc(p_id_cn INT)
RETURNS TABLE (
    ten_csvc VARCHAR(255),
    mo_ta TEXT,
    loai_csvc VARCHAR(50),
    so_lan_bao_tri INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cvc.ten_csvc::VARCHAR(255),
        cvc.mo_ta,
        cvc.loai_csvc::VARCHAR(50),
        COUNT(bt.id_bao_tri)::INT AS so_lan_bao_tri
    FROM quanly.cosovatchat_duoc_baotri bt
    JOIN quanly.cosovatchat cvc ON bt.id_csvc = cvc.id_csvc
    JOIN quanly.phong_trangbi_csvc ptb ON cvc.id_csvc = ptb.id_csvc
    JOIN quanly.phong p ON ptb.id_p = p.id_p
    JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
    WHERE (p_id_cn = -1 OR lp.id_cn = p_id_cn)
    GROUP BY cvc.id_csvc, cvc.ten_csvc, cvc.mo_ta, cvc.loai_csvc
    ORDER BY so_lan_bao_tri DESC;
END;
$$ LANGUAGE plpgsql;

-- 8. Cập nhật lại hoadon.func_tinh_tong_tien_hoa_don để bỏ qua cập nhật dữ liệu với hóa đơn đã thanh toán (tránh vi phạm trigger bảo mật)
CREATE OR REPLACE FUNCTION hoadon.func_tinh_tong_tien_hoa_don(p_id_hd INT)
RETURNS MONEY AS $$
DECLARE
    v_tien_phong MONEY := 0::money;
    v_tien_dich_vu MONEY := 0::money;
    v_tong_tien MONEY := 0::money;
    v_trang_thai VARCHAR(50);
    r RECORD;
BEGIN
    SELECT trang_thai INTO v_trang_thai FROM hoadon.hoadon WHERE id_hd = p_id_hd;

    IF COALESCE(v_trang_thai, '') != 'Đã thanh toán' THEN
        FOR r IN 
            SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = p_id_hd
        LOOP
            UPDATE hoadon.hoadon_thue_phong
            SET tong_tien = hoadon.func_tinh_tien_phong(p_id_hd, r.id_p)
            WHERE id_hd = p_id_hd AND id_p = r.id_p;
        END LOOP;
    END IF;

    SELECT COALESCE(SUM(tong_tien), 0::money)
    INTO v_tien_phong
    FROM hoadon.hoadon_thue_phong
    WHERE id_hd = p_id_hd;

    SELECT COALESCE(SUM(hsd.so_luong * dv.gia), 0::money)
    INTO v_tien_dich_vu
    FROM hoadon.hoadon_sudung_dichvu hsd
    JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv
    WHERE hsd.id_hd = p_id_hd;

    v_tong_tien := v_tien_phong + v_tien_dich_vu;

    RETURN v_tong_tien;
END;
$$ LANGUAGE plpgsql;
