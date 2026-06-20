-- Migration: V20 - Loại bỏ bảng truongdoan và thêm id_truong_doan vào bảng doankhach
-- ----------------------------------------------------------------------------------

-- 1. Thêm cột id_truong_doan vào bảng doankhach
ALTER TABLE khachhang.doankhach ADD COLUMN id_truong_doan INTEGER;

-- UPDATE khachhang.doankhach dk
-- SET id_truong_doan = td.id_kh
-- FROM khachhang.truongdoan td
-- WHERE dk.id_doan = td.id_doan;

-- 3. Tạo ràng buộc khóa ngoại tham chiếu đến bảng khachhang(id_kh) với tùy chọn ON DELETE SET NULL
ALTER TABLE khachhang.doankhach
ADD CONSTRAINT fk_doankhach_truongdoan FOREIGN KEY (id_truong_doan)
REFERENCES khachhang.khachhang(id_kh) ON DELETE SET NULL;

-- 4. Xóa bảng truongdoan
DROP TABLE IF EXISTS khachhang.truongdoan CASCADE;
