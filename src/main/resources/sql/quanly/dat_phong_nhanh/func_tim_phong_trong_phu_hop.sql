-- Helper Function: Tìm phòng trống của chi nhánh và loại phòng phù hợp các tiêu chí bộ lọc
-- Đầu vào:
--   p_id_cn: Mã chi nhánh homestay
--   p_chat_luong: Chất lượng (tiêu chuẩn, cao cấp)
--   p_loai_giuong: Loại giường (đơn, đôi)
--   p_dien_tich: Diện tích phòng (nhỏ, vừa, lớn - mặc định NULL để chọn bất kỳ)
--   p_view: Tầm nhìn (biển, núi, thành phố - mặc định NULL để chọn bất kỳ)
--   p_doi_tuong: Đối tượng sử dụng (cá nhân, cặp đôi, gia đình, nhóm - mặc định NULL để chọn bất kỳ)
--   p_ngaynhan: Ngày nhận phòng dự kiến
--   p_ngaytra: Ngày trả phòng dự kiến
-- Trả về: o_id_p (Mã phòng phù hợp hoặc NULL), o_gia_tien (Giá phòng niêm yết của phòng đó)

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
          -- Kiểm tra trùng lịch với bất kỳ đặt phòng nào khác của phòng này chưa hủy
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
