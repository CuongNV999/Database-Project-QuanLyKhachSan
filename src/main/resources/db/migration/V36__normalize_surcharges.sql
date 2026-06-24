-- Migration V36: Normalize Room Surcharges to 3NF

-- 1. Drop dependent objects first
DROP VIEW IF EXISTS hoadon.v_chi_tiet_hoa_don_thue_phong CASCADE;

-- 2. Create the new normalized table for room surcharges
CREATE TABLE IF NOT EXISTS hoadon.phu_thu_phong (
    id_hd INT NOT NULL,
    id_p INT NOT NULL,
    loai_phu_thu VARCHAR(100) NOT NULL, -- 'Tiêu hao' or 'Hỏng hóc'
    so_tien MONEY NOT NULL DEFAULT 0::money,
    PRIMARY KEY (id_hd, id_p, loai_phu_thu),
    FOREIGN KEY (id_hd, id_p) REFERENCES hoadon.hoadon_thue_phong(id_hd, id_p) ON DELETE CASCADE
);

-- 3. Migrate existing surcharge data
INSERT INTO hoadon.phu_thu_phong (id_hd, id_p, loai_phu_thu, so_tien)
SELECT id_hd, id_p, 'Tiêu hao', phu_thu_tieu_hao
FROM hoadon.hoadon_thue_phong
WHERE phu_thu_tieu_hao IS NOT NULL AND phu_thu_tieu_hao > 0::money
ON CONFLICT (id_hd, id_p, loai_phu_thu) DO UPDATE SET so_tien = EXCLUDED.so_tien;

INSERT INTO hoadon.phu_thu_phong (id_hd, id_p, loai_phu_thu, so_tien)
SELECT id_hd, id_p, 'Hỏng hóc', phu_thu_hong_hoc
FROM hoadon.hoadon_thue_phong
WHERE phu_thu_hong_hoc IS NOT NULL AND phu_thu_hong_hoc > 0::money
ON CONFLICT (id_hd, id_p, loai_phu_thu) DO UPDATE SET so_tien = EXCLUDED.so_tien;

-- 4. Drop obsolete surcharge columns from the room rental details table
ALTER TABLE hoadon.hoadon_thue_phong DROP COLUMN IF EXISTS phu_thu_tieu_hao;
ALTER TABLE hoadon.hoadon_thue_phong DROP COLUMN IF EXISTS phu_thu_hong_hoc;

-- 5. Recreate hoadon.v_chi_tiet_hoa_don_thue_phong view
CREATE OR REPLACE VIEW hoadon.v_chi_tiet_hoa_don_thue_phong AS
SELECT 
    htp.id_hd,
    htp.id_p,
    htp.ngaynhan,
    htp.ngaytra,
    htp.so_ngay_luu_tru,
    COALESCE((SELECT SUM(so_tien) FROM hoadon.phu_thu_phong pt WHERE pt.id_hd = htp.id_hd AND pt.id_p = htp.id_p AND pt.loai_phu_thu = 'Tiêu hao'), 0::money) AS phu_thu_tieu_hao,
    COALESCE((SELECT SUM(so_tien) FROM hoadon.phu_thu_phong pt WHERE pt.id_hd = htp.id_hd AND pt.id_p = htp.id_p AND pt.loai_phu_thu = 'Hỏng hóc'), 0::money) AS phu_thu_hong_hoc,
    hoadon.func_tinh_tien_coc(htp.id_hd) AS tong_tien_coc_hoa_don,
    (htp.so_ngay_luu_tru * lp.gia_tien * 0.5) AS tien_coc_phong,
    hoadon.func_tinh_tien_phong(htp.id_hd, htp.id_p) AS tong_tien_phong
FROM hoadon.hoadon_thue_phong htp
JOIN quanly.phong p ON htp.id_p = p.id_p
JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp;

-- 6. Redefine hoadon.func_tinh_tien_phong
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

-- 7. Redefine hoadon.func_check_out_phong
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

    -- 4. Lưu các phụ thu vào bảng mới
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

-- 8. Redefine quanly.func_tim_va_dat_phong_nhanh
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

    -- 4. Lưu phụ thu ban đầu vào bảng mới nếu có
    IF p_phu_thu > 0::money THEN
        INSERT INTO hoadon.phu_thu_phong (id_hd, id_p, loai_phu_thu, so_tien)
        VALUES (v_id_hd, v_id_p, 'Tiêu hao', p_phu_thu);
    END IF;

    -- 5. Trả về ID của hóa đơn mới được lập
    RETURN v_id_hd;
END;
$$ LANGUAGE plpgsql;

-- 9. Redefine quanly.func_bao_cao_tai_chinh
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
