--Thêm hội viên mới
--Tham số: id_kh
--Tính tong_luu_tru bắt đầu từ số đêm của đơn hàng gần nhất đã thanh toán

CREATE OR REPLACE FUNCTION khachhang.func_them_hoi_vien(p_id_kh INT)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_hv INT;
    v_tong_dem INT := 0;
BEGIN
    -- Kiểm tra xem khách hàng đã có hội viên chưa
    IF EXISTS (
        SELECT 1 FROM khachhang.khachhang WHERE id_kh = p_id_kh AND id_hv IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Khách hàng đã là hội viên!';
    END IF;

    -- Tính tổng số đêm lưu trú từ đơn hàng gần nhất (đã thanh toán)
    SELECT COALESCE(SUM(
        GREATEST(EXTRACT(DAY FROM (htp.ngaytra - htp.ngaynhan))::INT, 1)
    ), 0)
    INTO v_tong_dem
    FROM hoadon.hoadon_thue_phong htp
    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd
    WHERE h.id_kh = p_id_kh
      AND h.trang_thai = 'Đã thanh toán'
      AND h.id_hd = (
          SELECT MAX(h2.id_hd) 
          FROM hoadon.hoadon h2 
          WHERE h2.id_kh = p_id_kh AND h2.trang_thai = 'Đã thanh toán'
      );

    -- Thêm hội viên mới với tong_luu_tru = số đêm đơn gần nhất, hạng Basic (id_mhv = 4)
    INSERT INTO khachhang.hoivien (tong_luu_tru, id_mhv)
    VALUES (v_tong_dem, 4)
    RETURNING id_hv INTO v_id_hv;

    -- Cập nhật liên kết hội viên cho khách hàng
    UPDATE khachhang.khachhang SET id_hv = v_id_hv WHERE id_kh = p_id_kh;
END;
$$;
