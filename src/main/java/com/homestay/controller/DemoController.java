package com.homestay.controller;

import com.homestay.SQLHelper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

import java.sql.Timestamp;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/demo")
@CrossOrigin(origins = "*") // Allow frontend requests from any origin
public class DemoController {

    private final JdbcTemplate jdbcTemplate;

    @Autowired
    public DemoController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    private Integer checkBranchAccess(HttpSession session) {
        Integer branchId = (Integer) session.getAttribute("branchId");
        if (branchId == null) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Vui lòng đăng nhập trước!");
        }
        return branchId;
    }

    private String wrapWithBranchFilter(String sql) {
        String cleanSql = sql.trim();
        if (cleanSql.endsWith(";")) {
            cleanSql = cleanSql.substring(0, cleanSql.length() - 1);
        }
        return "SELECT * FROM (" + cleanSql + ") sub WHERE sub.id_cn = ?";
    }

    @PostMapping("/login")
    public Map<String, Object> login(@RequestBody Map<String, Object> body, HttpServletRequest request) {
        String username = (String) body.get("username");
        String password = (String) body.get("password");

        if (username == null || password == null) {
            return Map.of("success", false, "message", "Tên đăng nhập và mật khẩu không được trống!");
        }

        Map<String, Object> res = null;

        // Mock application logins with branch mapping (NOT database roles)
        if (username.equals("nv1_cn1") && password.equals("123")) {
            res = Map.of("success", true, "role", "Nhân viên", "branchId", 1, "branchName", "Salazar, Page and Martinez Homestay", "fullName", "Nguyen Van A");
        } else if (username.equals("ql_cn1") && password.equals("123")) {
            res = Map.of("success", true, "role", "Quản lý", "branchId", 1, "branchName", "Salazar, Page and Martinez Homestay", "fullName", "Tran Thi B");
        } else if (username.equals("nv2_cn2") && password.equals("123")) {
            res = Map.of("success", true, "role", "Nhân viên", "branchId", 2, "branchName", "Schultz-Osborne Homestay", "fullName", "Le Van C");
        } else if (username.equals("ql_cn2") && password.equals("123")) {
            res = Map.of("success", true, "role", "Quản lý", "branchId", 2, "branchName", "Schultz-Osborne Homestay", "fullName", "Pham Thi D");
        } else if (username.equals("admin") && password.equals("123")) {
            res = Map.of("success", true, "role", "Administrator", "branchId", -1, "branchName", "Tất cả chi nhánh", "fullName", "Quản trị viên Hệ thống");
        }

        if (res != null) {
            HttpSession session = request.getSession(true);
            session.setAttribute("username", username);
            session.setAttribute("role", res.get("role"));
            session.setAttribute("branchId", res.get("branchId"));
            session.setAttribute("fullName", res.get("fullName"));
            session.setAttribute("branchName", res.get("branchName"));
            return res;
        }

        return Map.of("success", false, "message", "Sai tên tài khoản hoặc mật khẩu!");
    }

    @PostMapping("/logout")
    public Map<String, Object> logout(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session != null) {
            session.invalidate();
        }
        return Map.of("success", true);
    }

    // -------------------------------------------------------------
    // A. Helper Lists for Dropdowns on UI
    // -------------------------------------------------------------

    @GetMapping("/branches")
    public List<Map<String, Object>> getBranches(HttpSession session) {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            return jdbcTemplate.queryForList("SELECT id_cn, ten_cn FROM quanly.chinhanh WHERE id_cn = ? ORDER BY id_cn", branchId);
        }
        return jdbcTemplate.queryForList("SELECT id_cn, ten_cn FROM quanly.chinhanh ORDER BY id_cn");
    }

    @GetMapping("/customers")
    public List<Map<String, Object>> getCustomers(HttpSession session) {
        checkBranchAccess(session);
        return jdbcTemplate.queryForList("SELECT id_kh, ho_ten FROM khachhang.khachhang ORDER BY id_kh LIMIT 100");
    }

    @GetMapping("/employees")
    public List<Map<String, Object>> getEmployees(HttpSession session) {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            return jdbcTemplate.queryForList("SELECT id_nv, ten_nv FROM nhansu.nhanvien WHERE id_cn = ? ORDER BY id_nv LIMIT 100", branchId);
        }
        return jdbcTemplate.queryForList("SELECT id_nv, ten_nv FROM nhansu.nhanvien ORDER BY id_nv LIMIT 100");
    }

    @GetMapping("/rooms")
    public List<Map<String, Object>> getRooms(HttpSession session) {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            return jdbcTemplate.queryForList(
                "SELECT p.id_p, p.dia_chi, p.trang_thai FROM quanly.phong p " +
                "JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp " +
                "WHERE lp.id_cn = ? ORDER BY p.id_p", branchId);
        }
        return jdbcTemplate.queryForList("SELECT id_p, dia_chi, trang_thai FROM quanly.phong ORDER BY id_p");
    }

    @GetMapping("/invoices")
    public List<Map<String, Object>> getInvoices(HttpSession session) {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            return jdbcTemplate.queryForList(
                "SELECT h.id_hd, h.trang_thai, h.ngaylap, h.id_kh FROM hoadon.hoadon h " +
                "JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv " +
                "WHERE nv.id_cn = ? ORDER BY h.id_hd DESC LIMIT 100", branchId);
        }
        return jdbcTemplate.queryForList("SELECT id_hd, trang_thai, ngaylap, id_kh FROM hoadon.hoadon ORDER BY id_hd DESC LIMIT 100");
    }

    // -------------------------------------------------------------
    // B. View-based APIs and SQL Reports
    // -------------------------------------------------------------

    @GetMapping("/doanh-thu-chi-nhanh")
    public List<Map<String, Object>> getDoanhThuChiNhanh(HttpSession session) {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            return jdbcTemplate.queryForList("SELECT * FROM v_doanh_thu_chi_nhanh WHERE id_cn = ?", branchId);
        }
        return jdbcTemplate.queryForList("SELECT * FROM v_doanh_thu_chi_nhanh");
    }

    @GetMapping("/phong-trong")
    public List<Map<String, Object>> getPhongTrong(
            @RequestParam(defaultValue = "1") int chiNhanhId,
            @RequestParam(defaultValue = "2026-06-15 14:00:00") String checkIn,
            @RequestParam(defaultValue = "2026-06-20 12:00:00") String checkOut,
            HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            chiNhanhId = branchId;
        }
        String timPhongSql = SQLHelper.readQuery("quanly/tim_phong_trong.sql");
        return jdbcTemplate.queryForList(
                timPhongSql,
                chiNhanhId,
                Timestamp.valueOf(checkOut),
                Timestamp.valueOf(checkIn)
        );
    }

    @GetMapping("/phong-status-detail")
    public List<Map<String, Object>> getPhongStatusDetail(HttpSession session) {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            String sql = "SELECT v.* FROM v_phong_status_detail v " +
                         "JOIN quanly.phong p ON v.id_p = p.id_p " +
                         "JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp " +
                         "WHERE lp.id_cn = ? ORDER BY v.id_p";
            return jdbcTemplate.queryForList(sql, branchId);
        }
        String sql = "SELECT * FROM v_phong_status_detail ORDER BY id_p";
        return jdbcTemplate.queryForList(sql);
    }

    @GetMapping("/chua-don-dep")
    public List<Map<String, Object>> getChuaDonDep(@RequestParam(defaultValue = "1") int chiNhanhId, HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            chiNhanhId = branchId;
        }
        String sql = SQLHelper.readQuery("quanly/danh_sach_phong_chua_don_dep.sql");
        return jdbcTemplate.queryForList(sql, chiNhanhId);
    }

    @GetMapping("/sap-checkin")
    public List<Map<String, Object>> getSapCheckin(
            @RequestParam(defaultValue = "2026-06-15") String date,
            HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        String sql = SQLHelper.readQuery("quanly/danh_sach_phong_sap_checkin.sql");
        if (branchId > 0) {
            sql = wrapWithBranchFilter(sql);
            return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(date), branchId);
        }
        return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(date));
    }

    @GetMapping("/qua-han-checkout")
    public List<Map<String, Object>> getQuaHanCheckout(HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        String sql = SQLHelper.readQuery("quanly/kiem_tra_phong_qua_han_checkout.sql");
        if (branchId > 0) {
            sql = wrapWithBranchFilter(sql);
            return jdbcTemplate.queryForList(sql, branchId);
        }
        return jdbcTemplate.queryForList(sql);
    }

    @GetMapping("/huu-hao-csvc")
    public List<Map<String, Object>> getHuuHaoCsvc(HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        String sql = SQLHelper.readQuery("quanly/bao_cao_huu_hao_csvc.sql");
        if (branchId > 0) {
            sql = wrapWithBranchFilter(sql);
            return jdbcTemplate.queryForList(sql, branchId);
        }
        return jdbcTemplate.queryForList(sql);
    }

    @GetMapping("/phong-lon-hieu-suat-thap")
    public List<Map<String, Object>> getPhongLonHieuSuatThap(
            @RequestParam(defaultValue = "2026-06-01") String tuNgay,
            @RequestParam(defaultValue = "2026-06-30") String denNgay,
            @RequestParam(defaultValue = "3") int mucItKhach,
            @RequestParam(defaultValue = "40.0") double mucSanHieuSuat,
            HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        String sql = SQLHelper.readQuery("quanly/phong_lon_hieu_suat_thap.sql");
        if (branchId > 0) {
            sql = wrapWithBranchFilter(sql);
            return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(tuNgay), java.sql.Date.valueOf(denNgay), mucItKhach, mucSanHieuSuat, branchId);
        }
        return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(tuNgay), java.sql.Date.valueOf(denNgay), mucItKhach, mucSanHieuSuat);
    }

    // -------------------------------------------------------------
    // C. Database Actions / Transactions Calling Functions
    // -------------------------------------------------------------

    @PostMapping("/tim-va-dat-phong-nhanh")
    public Map<String, Object> timVaDatPhongNhanh(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            Integer branchId = checkBranchAccess(session);
            Integer idKh = null;
            if (body.get("idKh") != null) {
                idKh = ((Number) body.get("idKh")).intValue();
            } else if (body.get("newCustName") != null) {
                String newCustName = (String) body.get("newCustName");
                if (newCustName != null && !newCustName.trim().isEmpty()) {
                    String insertSql = "INSERT INTO khachhang.khachhang (ho_ten) VALUES (?) RETURNING id_kh";
                    idKh = jdbcTemplate.queryForObject(insertSql, Integer.class, newCustName.trim());
                }
            }

            if (idKh == null) {
                return Map.of("success", false, "message", "Đặt phòng thất bại: Vui lòng chọn hoặc nhập tên khách hàng!");
            }
            int idNv = ((Number) body.get("idNv")).intValue();
            int idCn = ((Number) body.get("idCn")).intValue();
            String chatLuong = (String) body.get("chatLuong");
            String loaiGiuong = (String) body.get("loaiGiuong");
            String ngayNhan = (String) body.get("ngayNhan");
            String ngayTra = (String) body.get("ngayTra");
            double tienCoc = ((Number) body.getOrDefault("tienCoc", 0)).doubleValue();
            double phuThu = ((Number) body.getOrDefault("phuThu", 0)).doubleValue();

            if (branchId > 0) {
                idCn = branchId;
                // Verify employee is from this branch
                Integer count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM nhansu.nhanvien WHERE id_nv = ? AND id_cn = ?",
                    Integer.class, idNv, branchId);
                if (count == null || count == 0) {
                    return Map.of("success", false, "message", "Đặt phòng thất bại: Nhân viên thực hiện không thuộc chi nhánh của bạn!");
                }
            }

            String sql = "SELECT quanly.func_tim_va_dat_phong_nhanh(?, ?, ?, ?, ?, ?::timestamp, ?::timestamp, ?::numeric::money, ?::numeric::money) AS id_hd";
            Integer idHd = jdbcTemplate.queryForObject(sql, Integer.class, 
                    idKh, idNv, idCn, chatLuong, loaiGiuong, 
                    Timestamp.valueOf(ngayNhan), Timestamp.valueOf(ngayTra), 
                    tienCoc, phuThu);
            return Map.of("success", true, "message", "Đặt phòng nhanh thành công!", "id_hd", idHd);
        } catch (Exception e) {
            return Map.of("success", false, "message", "Đặt phòng thất bại: " + e.getMessage());
        }
    }

    @PostMapping("/huy-dat-phong")
    public Map<String, Object> huyDatPhong(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            Integer branchId = checkBranchAccess(session);
            int idHd = ((Number) body.get("idHd")).intValue();

            if (branchId > 0) {
                // Verify invoice belongs to the branch
                Integer count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM hoadon.hoadon h JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv WHERE h.id_hd = ? AND nv.id_cn = ?",
                    Integer.class, idHd, branchId);
                if (count == null || count == 0) {
                    return Map.of("success", false, "message", "Hủy đặt phòng thất bại: Hóa đơn không thuộc chi nhánh của bạn!");
                }
            }

            String sql = "SELECT hoadon.func_huy_dat_phong(?)";
            Boolean result = jdbcTemplate.queryForObject(sql, Boolean.class, idHd);
            if (Boolean.TRUE.equals(result)) {
                return Map.of("success", true, "message", "Hủy đặt phòng thành công!");
            } else {
                return Map.of("success", false, "message", "Hủy đặt phòng thất bại (hóa đơn không tồn tại hoặc đã thanh toán)!");
            }
        } catch (Exception e) {
            return Map.of("success", false, "message", "Lỗi: " + e.getMessage());
        }
    }

    @PostMapping("/thanh-toan-hoa-don")
    public Map<String, Object> thanhToanHoaDon(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            Integer branchId = checkBranchAccess(session);
            int idHd = ((Number) body.get("idHd")).intValue();
            String phuongThuc = (String) body.get("phuongThuc");

            if (branchId > 0) {
                // Verify invoice belongs to the branch
                Integer count = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM hoadon.hoadon h JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv WHERE h.id_hd = ? AND nv.id_cn = ?",
                    Integer.class, idHd, branchId);
                if (count == null || count == 0) {
                    return Map.of("success", false, "message", "Thanh toán thất bại: Hóa đơn không thuộc chi nhánh của bạn!");
                }
            }

            String sql = "SELECT hoadon.func_thanh_toan_hoa_don(?, ?)::numeric AS tong_tien";
            Double tongTien = jdbcTemplate.queryForObject(sql, Double.class, idHd, phuongThuc);
            return Map.of("success", true, "message", "Thanh toán hóa đơn thành công!", "tong_tien", tongTien);
        } catch (Exception e) {
            return Map.of("success", false, "message", "Thanh toán thất bại: " + e.getMessage());
        }
    }

    @PostMapping("/chuyen-phong")
    public Map<String, Object> chuyenPhong(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            Integer branchId = checkBranchAccess(session);
            int idHd = ((Number) body.get("idHd")).intValue();
            int idPIdCu = ((Number) body.get("idPIdCu")).intValue();
            int idPIdMoi = ((Number) body.get("idPIdMoi")).intValue();

            if (branchId > 0) {
                // Verify both rooms belong to the branch
                Integer countCu = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM quanly.phong p JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp WHERE p.id_p = ? AND lp.id_cn = ?",
                    Integer.class, idPIdCu, branchId);
                Integer countMoi = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM quanly.phong p JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp WHERE p.id_p = ? AND lp.id_cn = ?",
                    Integer.class, idPIdMoi, branchId);
                if (countCu == null || countCu == 0 || countMoi == null || countMoi == 0) {
                    return Map.of("success", false, "message", "Chuyển phòng thất bại: Phòng không thuộc chi nhánh của bạn!");
                }
            }

            String sql = "SELECT hoadon.func_chuyen_phong(?, ?, ?)";
            Boolean result = jdbcTemplate.queryForObject(sql, Boolean.class, idHd, idPIdCu, idPIdMoi);
            if (Boolean.TRUE.equals(result)) {
                return Map.of("success", true, "message", "Chuyển phòng thành công!");
            } else {
                return Map.of("success", false, "message", "Chuyển phòng thất bại (phòng mới không trống hoặc phòng cũ không thuộc hóa đơn này)!");
            }
        } catch (Exception e) {
            return Map.of("success", false, "message", "Lỗi: " + e.getMessage());
        }
    }
}
