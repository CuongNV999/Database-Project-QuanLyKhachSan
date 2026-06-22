-- Migration: V26 - Update deposit to be 50% of the room cost (so_ngay_luu_tru * price), recreate v_chi_tiet_hoa_don_thue_phong and update func_bao_cao_tai_chinh.

-- ==========================================
-- 1. DROP EXISTING CONFLICTING OBJECTS
-- ==========================================
DROP VIEW IF EXISTS hoadon.v_chi_tiet_hoa_don_thue_phong CASCADE;
DROP FUNCTION IF EXISTS hoadon.func_tinh_tien_coc(INT) CASCADE;
DROP FUNCTION IF EXISTS quanly.func_bao_cao_tai_chinh(INT, TIMESTAMP, TIMESTAMP) CASCADE;

-- ==========================================
-- 2. CREATE REFACTORED FUNCTIONS
-- ==========================================

-- 2.1. Calculate total deposit for the invoice (50% of room cost)
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

-- 2.2. Recreate quanly.func_bao_cao_tai_chinh with 50% deposit calculation
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

    -- 3. Tổng phụ thu vật phẩm tiêu hao thực tế thu được
    -- 4. Tổng tiền đền bù hỏng hóc thực tế thu được
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

-- ==========================================
-- 3. CREATE VIEW
-- ==========================================

-- 3.1. Recreate hoadon.v_chi_tiet_hoa_don_thue_phong with 50% deposit columns
CREATE OR REPLACE VIEW hoadon.v_chi_tiet_hoa_don_thue_phong AS
SELECT 
    htp.id_hd,
    htp.id_p,
    htp.ngaynhan,
    htp.ngaytra,
    htp.so_ngay_luu_tru,
    htp.phu_thu_tieu_hao,
    htp.phu_thu_hong_hoc,
    hoadon.func_tinh_tien_coc(htp.id_hd) AS tong_tien_coc_hoa_don,
    (htp.so_ngay_luu_tru * lp.gia_tien * 0.5) AS tien_coc_phong,
    hoadon.func_tinh_tien_phong(htp.id_hd, htp.id_p) AS tong_tien_phong
FROM hoadon.hoadon_thue_phong htp
JOIN quanly.phong p ON htp.id_p = p.id_p
JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp;
