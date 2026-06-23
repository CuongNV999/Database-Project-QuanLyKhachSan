--Thêm hội viên mới
--Tham số: id_kh

CREATE OR REPLACE FUNCTION khachhang.func_them_hoi_vien(p_id_kh INT)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_hv INT;
BEGIN
    -- Kiểm tra xem khách hàng đã có hội viên chưa
    IF EXISTS (
        SELECT 1 FROM khachhang.hoivien WHERE id_kh = p_id_kh
    ) THEN
        RAISE EXCEPTION 'Khách hàng đã là hội viên!';
    END IF;

    -- Thêm hội viên với hạng Basic
    INSERT INTO khachhang.hoivien ( tong_luu_tru, id_mhv)
    VALUES ( 0, 4);


    --Cập nhật hội viên cho khách hàng
    UPDATE khachhang.khachhang SET id_hv = v_id_hv WHERE id_kh = p_id_kh;
END;
$$;
