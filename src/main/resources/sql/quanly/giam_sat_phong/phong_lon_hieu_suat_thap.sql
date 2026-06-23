-- Query: Danh sách phòng diện tích lớn nhưng ít khách đặt hoặc hiệu suất sử dụng thấp (< mức sàn)
-- Tham số truyền vào (định dạng JDBC template ?):
-- 1. tu_ngay (Ngày bắt đầu khoảng thời gian, kiểu DATE/TIMESTAMP)
-- 2. den_ngay (Ngày kết thúc khoảng thời gian, kiểu DATE/TIMESTAMP)
-- 3. muc_it_khach (Ngưỡng số lượt đặt tối thiểu để coi là ít khách, kiểu INTEGER, ví dụ: 2)
-- 4. muc_san_hieu_suat (Mức sàn hiệu suất sử dụng %, kiểu NUMERIC, ví dụ: 40.0)

WITH params AS (
    SELECT 
        ?::date AS tu_ngay,
        ?::date AS den_ngay,
        ?::integer AS muc_it_khach,
        ?::numeric AS muc_san_hieu_suat
),
date_series AS (
    -- Tạo danh sách các ngày trong khoảng thời gian được chọn
    SELECT generate_series(tu_ngay::timestamp, (den_ngay - INTERVAL '1 day')::timestamp, '1 day'::interval)::date AS booked_day
    FROM params
),
room_booked_days AS (
    -- Tính tổng số đêm được thuê và số lượt đặt của từng phòng trong khoảng thời gian
    SELECT 
        htp.id_p,
        COUNT(DISTINCT h.id_hd) AS so_luot_dat,
        COUNT(DISTINCT ds.booked_day) AS tong_so_dem_thue
    FROM hoadon_thue_phong htp
    JOIN hoadon h ON htp.id_hd = h.id_hd
    CROSS JOIN date_series ds
    WHERE h.trang_thai != 'Đã hủy'
      AND ds.booked_day >= htp.ngaynhan::date
      AND ds.booked_day < htp.ngaytra::date
    GROUP BY htp.id_p
SELECT 
    p.id_p,
    p.dia_chi AS ten_phong,
    cn.ten_cn,
    lp.id_cn AS id_cn,
    lp.chat_luong,
    lp.loai_giuong,
    lp.view,
    lp.dien_tich,
    COALESCE(rb.so_luot_dat, 0) AS so_luot_dat,
    COALESCE(rb.tong_so_dem_thue, 0) AS tong_so_dem_thue,
    -- Số đêm phòng trống thực tế có thể phục vụ = Tổng số đêm
    (SELECT COUNT(*) FROM date_series) AS tong_so_dem_co_the_phuc_vu,
    -- Hiệu suất sử dụng phòng (%)
    ROUND(
        COALESCE(
            (rb.tong_so_dem_thue::numeric / NULLIF((SELECT COUNT(*) FROM date_series), 0)) * 100,
            0
        ), 
        2
    ) AS hieu_suat
FROM quanly.phong p
JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp
JOIN quanly.chinhanh cn ON lp.id_cn = cn.id_cn
CROSS JOIN params pr
LEFT JOIN room_booked_days rb ON p.id_p = rb.id_p
WHERE lp.dien_tich IN ('45m2', '50m2')
  AND (
      COALESCE(rb.so_luot_dat, 0) < pr.muc_it_khach
      OR
      COALESCE(
          (rb.tong_so_dem_thue::numeric / NULLIF((SELECT COUNT(*) FROM date_series), 0)) * 100,
          0
      ) < pr.muc_san_hieu_suat
  )
ORDER BY hieu_suat ASC, so_luot_dat ASC;

