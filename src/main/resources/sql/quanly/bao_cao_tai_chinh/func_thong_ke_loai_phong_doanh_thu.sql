-- Function: Thống kê loại phòng mang lại doanh thu cao nhất để biết xu hướng thị hiếu khách hàng
-- Đầu vào:
--   p_id_cn: Mã chi nhánh cần xem (-1 nếu xem tất cả)
--   p_tu_ngay: Thời gian bắt đầu
--   p_den_ngay: Thời gian kết thúc
-- Trả về: Bảng xếp hạng loại phòng theo tổng doanh thu giảm dần

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
        COALESCE(SUM(hoadon.func_tinh_tien_phong(h.id_hd, htp.id_p)), 0::money) AS tong_doanh_thu
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
