-- Function: Báo cáo chi tiết dòng tiền (Doanh thu thực tế, tiền cọc phòng online chưa check-in, phụ thu tiêu hao và hỏng hóc)
-- Đầu vào:
--   p_id_cn: Mã chi nhánh cần xem (-1 nếu xem toàn bộ chi nhánh)
--   p_tu_ngay: Thời gian bắt đầu
--   p_den_ngay: Thời gian kết thúc
-- Trả về: Bảng kết quả gồm 4 cột tài chính

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
    -- 1. Tổng doanh thu thực tế (tổng tiền các hóa đơn đã thanh toán có ngày thanh toán trong kỳ)
    -- Bao gồm cả tiền thuê phòng và tiền sử dụng dịch vụ phát sinh
    SELECT COALESCE(SUM(hoadon.func_tinh_tong_tien_hoa_don(h.id_hd)), 0::money)
    INTO v_tong_doanh_thu
    FROM hoadon.hoadon h
    JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv
    WHERE h.trang_thai = 'Đã thanh toán'
      AND (p_id_cn = -1 OR nv.id_cn = p_id_cn)
      AND h.ngaythanhtoan >= p_tu_ngay
      AND h.ngaythanhtoan <= p_den_ngay;

    -- 2. Tiền cọc 50% từ các phòng online chưa check-in
    -- Xác định là hóa đơn trạng thái 'Đã đặt' hoặc 'Đã cọc' và ngày nhận phòng dự kiến >= thời gian hiện tại
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

    -- 4. Tổng tiền đền bù hỏng hóc thực tế thu được
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
