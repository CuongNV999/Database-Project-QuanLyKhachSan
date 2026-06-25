-- ============================================================
-- File: 07_create_triggers.sql
-- Mục đích: Tạo tất cả triggers cho CSDL quanlykhachsan
-- Phiên bản: Tương đương sau migration V36
-- ============================================================

SET search_path TO "$user", public, quanly, nhansu, khachhang, hoadon;

-- ============================================================
-- SCHEMA: khachhang
-- ============================================================

-- 1. Trigger kiểm soát tuổi trẻ em
CREATE OR REPLACE TRIGGER trg_kiem_tra_tuoi_tre_em
BEFORE INSERT OR UPDATE ON khachhang.khachhang_treem
FOR EACH ROW
EXECUTE FUNCTION khachhang.func_check_child_age();

-- 2. Trigger tự động nâng hạng hội viên khi cập nhật tổng lưu trú
CREATE OR REPLACE TRIGGER trg_tu_dong_nang_hang_hoivien
BEFORE UPDATE OF tong_luu_tru ON khachhang.hoivien
FOR EACH ROW
EXECUTE FUNCTION khachhang.func_tu_dong_nang_hang_hoi_vien();


-- ============================================================
-- SCHEMA: hoadon
-- ============================================================

-- 3. Trigger tích điểm (số đêm) khi thanh toán hóa đơn
CREATE OR REPLACE TRIGGER trg_sau_khi_thanh_toan_hoadon
AFTER UPDATE OF trang_thai ON hoadon.hoadon
FOR EACH ROW
EXECUTE FUNCTION hoadon.func_cap_nhat_diem_tich_luy();

-- 4. Trigger tự cập nhật trạng thái phòng khi thêm/xóa chi tiết thuê phòng
CREATE OR REPLACE TRIGGER trg_dat_phong_auto_update_status
AFTER INSERT OR DELETE ON hoadon.hoadon_thue_phong
FOR EACH ROW
EXECUTE FUNCTION hoadon.func_dat_phong_auto_update_status();

-- 5. Trigger ngăn chặn đặt trùng phòng (kiểm tra giao thoa lịch)
CREATE OR REPLACE TRIGGER trg_truoc_khi_dat_phong
BEFORE INSERT OR UPDATE ON hoadon.hoadon_thue_phong
FOR EACH ROW
EXECUTE FUNCTION hoadon.func_check_booking_overlap();

-- 6. Trigger khóa hóa đơn đã thanh toán (không cho sửa/xóa chi tiết thuê phòng)
CREATE OR REPLACE TRIGGER trg_khoa_chi_tiet_hoa_don_da_thanh_toan
BEFORE UPDATE OR DELETE ON hoadon.hoadon_thue_phong
FOR EACH ROW
EXECUTE FUNCTION hoadon.func_prevent_paid_invoice_edit();
