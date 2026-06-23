package com.homestay.controller;

import com.homestay.SQLHelper;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;

import org.springframework.lang.NonNull;
import java.sql.Timestamp;
import java.util.List;
import java.util.Map;
import java.util.HashMap;

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

    @NonNull
    private String wrapWithBranchFilter(@NonNull String sql) {
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

        if (!password.equals("123")) {
            return Map.of("success", false, "message", "Sai mật khẩu!");
        }

        Map<String, Object> res = null;

        if (username.equals("admin")) {
            res = Map.of("success", true, "role", "Administrator", "branchId", -1, "branchName", "Tất cả chi nhánh",
                    "fullName", "Quản trị viên Hệ thống");
        } else if (username.startsWith("nv") && username.contains("_cn")) {
            try {
                String nvStr = username.substring(2, username.indexOf("_cn"));
                String cnStr = username.substring(username.indexOf("_cn") + 3);
                int idNv = Integer.parseInt(nvStr);
                int idCn = Integer.parseInt(cnStr);

                List<Map<String, Object>> list = jdbcTemplate.queryForList(
                    "SELECT nv.ten_nv, nv.chuc_vu, nv.id_cn, cn.ten_cn FROM nhansu.nhanvien nv " +
                    "JOIN quanly.chinhanh cn ON nv.id_cn = cn.id_cn " +
                    "WHERE nv.id_cn = ? AND nv.chuc_vu <> 'Quản lý' " +
                    "ORDER BY nv.id_nv LIMIT 1 OFFSET ?", idCn, idNv - 1);

                if (!list.isEmpty()) {
                    Map<String, Object> emp = list.get(0);
                    String tenNv = (String) emp.get("ten_nv");
                    String chucVu = (String) emp.get("chuc_vu");
                    String tenCn = (String) emp.get("ten_cn");
                    String role = chucVu.equals("Quản lý") ? "Quản lý" : "Nhân viên";

                    res = Map.of("success", true, "role", role, "branchId", idCn, "branchName", tenCn, "fullName", tenNv);
                }
            } catch (Exception e) {
                // ignore
            }
        } else if (username.startsWith("ql_cn")) {
            try {
                String cnStr = username.substring(5);
                int idCn = Integer.parseInt(cnStr);

                List<Map<String, Object>> list = jdbcTemplate.queryForList(
                    "SELECT nv.ten_nv, nv.chuc_vu, nv.id_cn, cn.ten_cn FROM nhansu.nhanvien nv " +
                    "JOIN quanly.chinhanh cn ON nv.id_cn = cn.id_cn " +
                    "WHERE nv.id_cn = ? AND nv.chuc_vu = 'Quản lý' LIMIT 1", idCn);

                if (!list.isEmpty()) {
                    Map<String, Object> emp = list.get(0);
                    String tenNv = (String) emp.get("ten_nv");
                    String tenCn = (String) emp.get("ten_cn");

                    res = Map.of("success", true, "role", "Quản lý", "branchId", idCn, "branchName", tenCn, "fullName", tenNv);
                }
            } catch (Exception e) {
                // ignore
            }
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

        return Map.of("success", false, "message", "Sai tên tài khoản hoặc tài khoản không tồn tại!");
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
            return jdbcTemplate.queryForList("SELECT id_cn, ten_cn FROM quanly.chinhanh WHERE id_cn = ? ORDER BY id_cn",
                    branchId);
        }
        return jdbcTemplate.queryForList("SELECT id_cn, ten_cn FROM quanly.chinhanh ORDER BY id_cn");
    }

    @GetMapping("/customers")
    public List<Map<String, Object>> getCustomers(
            @RequestParam(required = false) String query,
            HttpSession session) {
        checkBranchAccess(session);
        if (query != null && !query.trim().isEmpty()) {
            String sql = "SELECT id_kh, ho_ten, cccd, passport, la_knn FROM khachhang.khachhang WHERE ho_ten ILIKE ? OR cccd ILIKE ? OR passport ILIKE ? ORDER BY id_kh LIMIT 100";
            String searchPattern = "%" + query.trim() + "%";
            return jdbcTemplate.queryForList(sql, searchPattern, searchPattern, searchPattern);
        }
        return jdbcTemplate.queryForList("SELECT id_kh, ho_ten, cccd, passport, la_knn FROM khachhang.khachhang ORDER BY id_kh LIMIT 100");
    }

    @GetMapping("/employees")
    public List<Map<String, Object>> getEmployees(HttpSession session) {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            return jdbcTemplate.queryForList(
                    "SELECT id_nv, ten_nv FROM nhansu.nhanvien WHERE id_cn = ? ORDER BY id_nv LIMIT 100", branchId);
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
                            "WHERE lp.id_cn = ? ORDER BY p.id_p",
                    branchId);
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
                            "WHERE nv.id_cn = ? ORDER BY h.id_hd DESC LIMIT 100",
                    branchId);
        }
        return jdbcTemplate.queryForList(
                "SELECT id_hd, trang_thai, ngaylap, id_kh FROM hoadon.hoadon ORDER BY id_hd DESC LIMIT 100");
    }

    @GetMapping("/facilities")
    public List<Map<String, Object>> getFacilities(HttpSession session) {
        checkBranchAccess(session);
        return jdbcTemplate.queryForList(
            "SELECT id_csvc, ten_csvc, loai_csvc, gia_den_bu::numeric AS gia_den_bu FROM quanly.cosovatchat ORDER BY id_csvc"
        );
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

    @GetMapping("/doanh-thu-theo-ngay")
    public List<Map<String, Object>> getDoanhThuTheoNgay(
            @RequestParam String tuNgay,
            @RequestParam String denNgay,
            @RequestParam(defaultValue = "-1") int idCn,
            HttpSession session) {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            idCn = branchId;
        }

        String sql;
        if (idCn > 0) {
            sql = "SELECT h.ngaythanhtoan AS ngay, " +
                  "SUM(hoadon.func_tinh_tong_chi_phi(h.id_hd)::numeric) AS doanh_thu, " +
                  "COUNT(DISTINCT h.id_hd) AS so_luot_checkout " +
                  "FROM hoadon.hoadon h " +
                  "JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv " +
                  "WHERE h.trang_thai = 'Đã thanh toán' " +
                  "AND h.ngaythanhtoan BETWEEN ?::date AND ?::date " +
                  "AND nv.id_cn = ? " +
                  "GROUP BY h.ngaythanhtoan " +
                  "ORDER BY h.ngaythanhtoan";
            return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(tuNgay), java.sql.Date.valueOf(denNgay), idCn);
        } else {
            sql = "SELECT h.ngaythanhtoan AS ngay, " +
                  "SUM(hoadon.func_tinh_tong_chi_phi(h.id_hd)::numeric) AS doanh_thu, " +
                  "COUNT(DISTINCT h.id_hd) AS so_luot_checkout " +
                  "FROM hoadon.hoadon h " +
                  "JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv " +
                  "WHERE h.trang_thai = 'Đã thanh toán' " +
                  "AND h.ngaythanhtoan BETWEEN ?::date AND ?::date " +
                  "GROUP BY h.ngaythanhtoan " +
                  "ORDER BY h.ngaythanhtoan";
            return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(tuNgay), java.sql.Date.valueOf(denNgay));
        }
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
        String timPhongSql = SQLHelper.readQuery("quanly/giam_sat_phong/tim_phong_trong.sql");
        return jdbcTemplate.queryForList(
                timPhongSql,
                chiNhanhId,
                Timestamp.valueOf(checkOut),
                Timestamp.valueOf(checkIn));
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

    @GetMapping("/phong-detail/{id}")
    public Map<String, Object> getPhongDetail(@PathVariable int id, HttpSession session) {
        // 1. Get room basic info
        String roomSql = "SELECT p.id_p, cn.ten_cn, p.dia_chi, lp.chat_luong, lp.loai_giuong, lp.view, lp.dien_tich, lp.gia_tien::numeric AS gia_tien, p.trang_thai " +
                "FROM quanly.phong p " +
                "LEFT JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp " +
                "LEFT JOIN quanly.chinhanh cn ON lp.id_cn = cn.id_cn " +
                "WHERE p.id_p = ?";
        List<Map<String, Object>> roomList = jdbcTemplate.queryForList(roomSql, id);
        if (roomList.isEmpty()) {
            return Map.of("success", false, "message", "Phòng không tồn tại!");
        }
        Map<String, Object> room = new HashMap<>(roomList.get(0));

        // 2. Check branch access
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            String checkBranchSql = "SELECT COUNT(*) FROM quanly.phong p JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp WHERE p.id_p = ? AND lp.id_cn = ?";
            Integer count = jdbcTemplate.queryForObject(checkBranchSql, Integer.class, id, branchId);
            if (count == null || count == 0) {
                return Map.of("success", false, "message", "Bạn không có quyền xem thông tin phòng này!");
            }
        }

        // 3. Compute room utilization efficiency over last 30 days
        String effSql = "WITH date_series AS ( " +
                "    SELECT generate_series(CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE - INTERVAL '1 day', '1 day'::interval)::date AS booked_day " +
                "), " +
                "booked_days AS ( " +
                "    SELECT COUNT(DISTINCT ds.booked_day) AS total_booked " +
                "    FROM hoadon.hoadon_thue_phong htp " +
                "    JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd " +
                "    CROSS JOIN date_series ds " +
                "    WHERE htp.id_p = ? " +
                "      AND h.trang_thai != 'Đã hủy' " +
                "      AND ds.booked_day >= htp.ngaynhan::date " +
                "      AND ds.booked_day < htp.ngaytra::date " +
                ") " +
                "SELECT ROUND((total_booked::numeric / 30.0) * 100, 2) AS hieu_suat " +
                "FROM booked_days";
        Double hieuSuat = jdbcTemplate.queryForObject(effSql, Double.class, id);
        room.put("hieu_suat", hieuSuat != null ? hieuSuat : 0.00);

        // 4. If status is "Đã đặt", get booking customer & employee info
        if ("Đã đặt".equals(room.get("trang_thai"))) {
            String bookingSql = "SELECT h.id_hd, kh.id_kh, kh.ho_ten AS ten_kh, kh.sdt AS sdt_kh, nv.id_nv, nv.ten_nv, htp.ngaynhan, htp.ngaytra " +
                    "FROM hoadon.hoadon_thue_phong htp " +
                    "JOIN hoadon.hoadon h ON htp.id_hd = h.id_hd " +
                    "LEFT JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh " +
                    "LEFT JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv " +
                    "WHERE htp.id_p = ? " +
                    "  AND h.trang_thai = 'Đã đặt' " +
                    "ORDER BY htp.ngaynhan DESC " +
                    "LIMIT 1";
            List<Map<String, Object>> bookings = jdbcTemplate.queryForList(bookingSql, id);
            if (!bookings.isEmpty()) {
                room.put("booking", bookings.get(0));
            }
        }

        return Map.of("success", true, "data", room);
    }

    private void checkManagerAccess(HttpSession session) {
        checkBranchAccess(session);
        String role = (String) session.getAttribute("role");
        if (!"Quản lý".equals(role)) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Bạn không có quyền thực hiện thao tác này!");
        }
    }

    @GetMapping("/management/customers")
    public Map<String, Object> getManagementCustomers(
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "15") int size,
            @RequestParam(required = false) String search,
            HttpSession session) {
        checkManagerAccess(session);

        String countSql = "SELECT COUNT(*) FROM khachhang.khachhang kh WHERE 1=1";
        String dataSql = "SELECT kh.id_kh, kh.ho_ten, kh.cccd, kh.sdt, kh.dia_chi, kh.quoc_tich, kh.passport, kh.visa, kh.la_knn, " +
                "       hv.hang AS hang_hoi_vien, hv.tong_luu_tru " +
                "FROM khachhang.khachhang kh " +
                "LEFT JOIN ( " +
                "    SELECT h.id_hv, mhv.hang, h.tong_luu_tru " +
                "    FROM khachhang.hoivien h " +
                "    JOIN khachhang.muchoivien mhv ON h.id_mhv = mhv.id_mhv " +
                ") hv ON kh.id_hv = hv.id_hv " +
                "WHERE 1=1";

        boolean hasSearch = search != null && !search.trim().isEmpty();
        int totalElements = 0;
        List<Map<String, Object>> content;

        if (hasSearch) {
            String filter = "%" + search.trim().toLowerCase() + "%";
            String searchFilter = " AND (LOWER(kh.ho_ten) LIKE ? OR LOWER(kh.sdt) LIKE ? OR LOWER(kh.cccd) LIKE ? OR LOWER(kh.passport) LIKE ?)";
            countSql += searchFilter;
            dataSql += searchFilter;

            totalElements = jdbcTemplate.queryForObject(countSql, Integer.class, filter, filter, filter, filter);

            dataSql += " ORDER BY kh.id_kh LIMIT ? OFFSET ?";
            int offset = (page - 1) * size;
            content = jdbcTemplate.queryForList(dataSql, filter, filter, filter, filter, size, offset);
        } else {
            totalElements = jdbcTemplate.queryForObject(countSql, Integer.class);

            dataSql += " ORDER BY kh.id_kh LIMIT ? OFFSET ?";
            int offset = (page - 1) * size;
            content = jdbcTemplate.queryForList(dataSql, size, offset);
        }

        int totalPages = (int) Math.ceil((double) totalElements / size);

        Map<String, Object> response = new HashMap<>();
        response.put("content", content);
        response.put("totalPages", totalPages);
        response.put("totalElements", totalElements);
        response.put("page", page);
        response.put("size", size);

        return response;
    }

    @GetMapping("/management/customers/{id}/history")
    public List<Map<String, Object>> getCustomerBookingHistory(@PathVariable int id, HttpSession session) {
        checkManagerAccess(session);
        String sql = "SELECT h.id_hd, h.ngaylap, h.trang_thai, htp.id_p, p.dia_chi AS ten_phong, cn.ten_cn, htp.ngaynhan, htp.ngaytra " +
                "FROM hoadon.hoadon h " +
                "JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd " +
                "JOIN quanly.phong p ON htp.id_p = p.id_p " +
                "JOIN quanly.chinhanh cn ON p.id_cn = cn.id_cn " +
                "WHERE h.id_kh = ? " +
                "ORDER BY h.id_hd DESC";
        return jdbcTemplate.queryForList(sql, id);
    }

    @GetMapping("/management/employees")
    public List<Map<String, Object>> getManagementEmployees(HttpSession session) {
        checkManagerAccess(session);
        Integer branchId = (Integer) session.getAttribute("branchId");
        if (branchId > 0) {
            String sql = "SELECT nv.id_nv, nv.ten_nv, nv.chuc_vu, nv.luong::numeric AS luong, cn.ten_cn, nv.id_cn " +
                    "FROM nhansu.nhanvien nv " +
                    "JOIN quanly.chinhanh cn ON nv.id_cn = cn.id_cn " +
                    "WHERE nv.id_cn = ? " +
                    "ORDER BY nv.id_nv";
            return jdbcTemplate.queryForList(sql, branchId);
        } else {
            String sql = "SELECT nv.id_nv, nv.ten_nv, nv.chuc_vu, nv.luong::numeric AS luong, cn.ten_cn, nv.id_cn " +
                    "FROM nhansu.nhanvien nv " +
                    "JOIN quanly.chinhanh cn ON nv.id_cn = cn.id_cn " +
                    "ORDER BY nv.id_nv";
            return jdbcTemplate.queryForList(sql);
        }
    }

    @PostMapping("/management/employees")
    @Transactional
    public Map<String, Object> addEmployee(@RequestBody Map<String, Object> body, HttpSession session) {
        checkManagerAccess(session);
        try {
            String tenNv = (String) body.get("tenNv");
            String chucVu = (String) body.get("chucVu");
            int idCn = ((Number) body.get("idCn")).intValue();
            double luong = ((Number) body.get("luong")).doubleValue();

            if (tenNv == null || tenNv.trim().isEmpty() || chucVu == null || chucVu.trim().isEmpty()) {
                return Map.of("success", false, "message", "Thông tin nhân viên không hợp lệ!");
            }

            Integer branchId = (Integer) session.getAttribute("branchId");
            if (branchId > 0 && idCn != branchId) {
                return Map.of("success", false, "message", "Bạn không có quyền thêm nhân viên vào chi nhánh khác!");
            }

            String sql = "INSERT INTO nhansu.nhanvien (ten_nv, chuc_vu, id_cn, luong) VALUES (?, ?, ?, ?::numeric::money)";
            jdbcTemplate.update(sql, tenNv.trim(), chucVu.trim(), idCn, luong);

            return Map.of("success", true, "message", "Thêm nhân viên thành công!");
        } catch (Exception e) {
            return Map.of("success", false, "message", "Lỗi thêm nhân viên: " + e.getMessage());
        }
    }

    @GetMapping("/chua-don-dep")
    public List<Map<String, Object>> getChuaDonDep(@RequestParam(defaultValue = "1") int chiNhanhId,
            HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            chiNhanhId = branchId;
        }
        String sql = SQLHelper.readQuery("quanly/giam_sat_phong/danh_sach_phong_chua_don_dep.sql");
        return jdbcTemplate.queryForList(sql, chiNhanhId);
    }

    @GetMapping("/sap-checkin")
    public List<Map<String, Object>> getSapCheckin(
            @RequestParam(defaultValue = "2026-06-15") String date,
            HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        String sql = SQLHelper.readQuery("quanly/giam_sat_phong/danh_sach_phong_sap_checkin.sql");
        if (branchId > 0) {
            sql = wrapWithBranchFilter(sql);
            return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(date), branchId);
        }
        return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(date));
    }

    @GetMapping("/qua-han-checkout")
    public List<Map<String, Object>> getQuaHanCheckout(HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        String sql = SQLHelper.readQuery("quanly/giam_sat_phong/kiem_tra_phong_qua_han_checkout.sql");
        if (branchId > 0) {
            sql = wrapWithBranchFilter(sql);
            return jdbcTemplate.queryForList(sql, branchId);
        }
        return jdbcTemplate.queryForList(sql);
    }

    @GetMapping("/huu-hao-csvc")
    public List<Map<String, Object>> getHuuHaoCsvc(HttpSession session) throws Exception {
        Integer branchId = checkBranchAccess(session);
        String sql = SQLHelper.readQuery("quanly/giam_sat_phong/bao_cao_huu_hao_csvc.sql");
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
        String sql = SQLHelper.readQuery("quanly/giam_sat_phong/phong_lon_hieu_suat_thap.sql");
        if (branchId > 0) {
            sql = wrapWithBranchFilter(sql);
            return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(tuNgay), java.sql.Date.valueOf(denNgay),
                    mucItKhach, mucSanHieuSuat, branchId);
        }
        return jdbcTemplate.queryForList(sql, java.sql.Date.valueOf(tuNgay), java.sql.Date.valueOf(denNgay), mucItKhach,
                mucSanHieuSuat);
    }

    // -------------------------------------------------------------
    // C. Database Actions / Transactions Calling Functions
    // -------------------------------------------------------------

    @PostMapping("/tim-va-dat-phong-nhanh")
    @Transactional
    public Map<String, Object> timVaDatPhongNhanh(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            Integer branchId = checkBranchAccess(session);
            Integer idKh = null;
            if (body.get("idKh") != null) {
                idKh = ((Number) body.get("idKh")).intValue();
            } else if (body.get("newCustName") != null) {
                String newCustName = (String) body.get("newCustName");
                if (newCustName != null && !newCustName.trim().isEmpty()) {
                    String cccd = (String) body.get("cccd");
                    String sdt = (String) body.get("sdt");
                    String diaChi = (String) body.get("diaChi");
                    String quocTich = (String) body.get("quocTich");
                    String passport = (String) body.get("passport");
                    String visa = (String) body.get("visa");
                    Boolean laKnn = (Boolean) body.get("laKnn");
                    if (laKnn == null) laKnn = false;

                    // Check if customer already exists based on CCCD (Vietnamese) or Passport (Foreigner)
                    if (!laKnn && cccd != null && !cccd.trim().isEmpty()) {
                        List<Integer> list = jdbcTemplate.queryForList(
                            "SELECT id_kh FROM khachhang.khachhang WHERE cccd = ? LIMIT 1", Integer.class, cccd.trim());
                        if (!list.isEmpty()) {
                            idKh = list.get(0);
                        }
                    } else if (laKnn && passport != null && !passport.trim().isEmpty()) {
                        List<Integer> list = jdbcTemplate.queryForList(
                            "SELECT id_kh FROM khachhang.khachhang WHERE passport = ? LIMIT 1", Integer.class, passport.trim());
                        if (!list.isEmpty()) {
                            idKh = list.get(0);
                        }
                    }

                    if (idKh == null) {
                        String insertSql = "INSERT INTO khachhang.khachhang (ho_ten, cccd, sdt, dia_chi, quoc_tich, passport, visa, la_knn) " +
                                           "VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id_kh";
                        idKh = jdbcTemplate.queryForObject(insertSql, Integer.class, 
                                newCustName.trim(), 
                                (cccd == null || cccd.trim().isEmpty()) ? null : cccd.trim(),
                                (sdt == null || sdt.trim().isEmpty()) ? null : sdt.trim(),
                                (diaChi == null || diaChi.trim().isEmpty()) ? null : diaChi.trim(),
                                (quocTich == null || quocTich.trim().isEmpty()) ? "Việt Nam" : quocTich.trim(),
                                (passport == null || passport.trim().isEmpty()) ? null : passport.trim(),
                                (visa == null || visa.trim().isEmpty()) ? null : visa.trim(),
                                laKnn
                        );
                    }
                }
            }

            if (idKh == null) {
                return Map.of("success", false, "message",
                        "Đặt phòng thất bại: Vui lòng chọn hoặc nhập tên khách hàng!");
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
                    return Map.of("success", false, "message",
                            "Đặt phòng thất bại: Nhân viên thực hiện không thuộc chi nhánh của bạn!");
                }
            }

            Integer idHd = null;
            Integer idP = null;
            if (body.get("idP") != null) {
                idP = ((Number) body.get("idP")).intValue();
            }

            if (idP != null) {
                // Verify room belongs to the branch
                Integer countRoom = jdbcTemplate.queryForObject(
                        "SELECT COUNT(*) FROM quanly.phong p JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp WHERE p.id_p = ? AND lp.id_cn = ?",
                        Integer.class, idP, idCn);
                if (countRoom == null || countRoom == 0) {
                    return Map.of("success", false, "message",
                            "Đặt phòng thất bại: Phòng không thuộc chi nhánh đã chọn!");
                }

                // 1. Create invoice in hoadon.hoadon
                jdbcTemplate.update("INSERT INTO hoadon.hoadon (trang_thai, ngaylap, phuongthuc, id_kh, id_nv) VALUES ('Đã đặt', CURRENT_DATE, 'Tiền mặt', ?, ?)", idKh, idNv);
                idHd = jdbcTemplate.queryForObject("SELECT currval('hoadon.hoadon_id_hd_seq')", Integer.class);

                // 2. Calculate nights
                long diff = Timestamp.valueOf(ngayTra).getTime() - Timestamp.valueOf(ngayNhan).getTime();
                int soNgay = (int) (diff / (1000 * 60 * 60 * 24));
                if (soNgay <= 0) soNgay = 1;

                // 3. Insert into hoadon.hoadon_thue_phong
                jdbcTemplate.update("INSERT INTO hoadon.hoadon_thue_phong (id_hd, id_p, ngaynhan, ngaytra, so_ngay_luu_tru, phu_thu_tieu_hao) VALUES (?, ?, ?::timestamp, ?::timestamp, ?, ?::numeric::money)",
                        idHd, idP, ngayNhan, ngayTra, soNgay, phuThu);
            } else {
                String sql = "SELECT quanly.func_tim_va_dat_phong_nhanh(?, ?, ?, ?, ?, ?::timestamp, ?::timestamp, ?::numeric::money, ?::numeric::money) AS id_hd";
                idHd = jdbcTemplate.queryForObject(sql, Integer.class,
                        idKh, idNv, idCn, chatLuong, loaiGiuong,
                        Timestamp.valueOf(ngayNhan), Timestamp.valueOf(ngayTra),
                        tienCoc, phuThu);
            }

            // Log booking history
            if (idHd != null) {
                try {
                    String customerName = jdbcTemplate.queryForObject("SELECT ho_ten FROM khachhang.khachhang WHERE id_kh = ?", String.class, idKh);
                    String employeeName = jdbcTemplate.queryForObject("SELECT ten_nv FROM nhansu.nhanvien WHERE id_nv = ?", String.class, idNv);
                    List<Integer> roomIds = jdbcTemplate.queryForList("SELECT id_p FROM hoadon.hoadon_thue_phong WHERE id_hd = ?", Integer.class, idHd);
                    for (Integer roomId : roomIds) {
                        jdbcTemplate.update(
                            "INSERT INTO hoadon.lich_su_thao_tac (thao_tac, id_hd, id_kh, ho_ten_kh, id_nv, ten_nv, id_p) VALUES (?, ?, ?, ?, ?, ?, ?)",
                            "Đặt phòng", idHd, idKh, customerName, idNv, employeeName, roomId
                        );
                    }
                } catch (Exception ex) {
                    // Ignore history logging errors to not block transaction
                    System.err.println("Failed to log booking history: " + ex.getMessage());
                }
            }

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
                    return Map.of("success", false, "message",
                            "Hủy đặt phòng thất bại: Hóa đơn không thuộc chi nhánh của bạn!");
                }
            }

            // Get customer and employee details to log the cancellation BEFORE calling the function
            List<Map<String, Object>> invoiceInfo = jdbcTemplate.queryForList(
                "SELECT h.id_kh, kh.ho_ten, h.id_nv, nv.ten_nv, htp.id_p " +
                "FROM hoadon.hoadon h " +
                "JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd " +
                "LEFT JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh " +
                "LEFT JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv " +
                "WHERE h.id_hd = ?", idHd
            );

            String sql = "SELECT hoadon.func_huy_dat_phong(?)";
            Boolean result = jdbcTemplate.queryForObject(sql, Boolean.class, idHd);
            if (Boolean.TRUE.equals(result)) {
                // Log cancellation history
                try {
                    for (Map<String, Object> info : invoiceInfo) {
                        Integer idKhVal = (Integer) info.get("id_kh");
                        String hoTen = (String) info.get("ho_ten");
                        Integer idNvVal = (Integer) info.get("id_nv");
                        String tenNv = (String) info.get("ten_nv");
                        Integer idP = (Integer) info.get("id_p");
                        
                        jdbcTemplate.update(
                            "INSERT INTO hoadon.lich_su_thao_tac (thao_tac, id_hd, id_kh, ho_ten_kh, id_nv, ten_nv, id_p) VALUES (?, ?, ?, ?, ?, ?, ?)",
                            "Hủy đặt phòng", idHd, idKhVal, hoTen, idNvVal, tenNv, idP
                        );
                    }
                } catch (Exception ex) {
                    System.err.println("Failed to log cancellation history: " + ex.getMessage());
                }

                return Map.of("success", true, "message", "Hủy đặt phòng thành công!");
            } else {
                return Map.of("success", false, "message",
                        "Hủy đặt phòng thất bại (hóa đơn không tồn tại hoặc đã thanh toán)!");
            }
        } catch (Exception e) {
            return Map.of("success", false, "message", "Lỗi: " + e.getMessage());
        }
    }

    @GetMapping("/lich-su-thao-tac")
    public List<Map<String, Object>> getLichSuThaoTac(HttpSession session) {
        Integer branchId = checkBranchAccess(session);
        if (branchId > 0) {
            String sql = "SELECT ls.*, to_char(ls.thoi_gian, 'YYYY-MM-DD HH24:MI:SS') as thoi_gian_str " +
                         "FROM hoadon.lich_su_thao_tac ls " +
                         "JOIN nhansu.nhanvien nv ON ls.id_nv = nv.id_nv " +
                         "WHERE nv.id_cn = ? " +
                         "ORDER BY ls.id_ls DESC LIMIT 200";
            return jdbcTemplate.queryForList(sql, branchId);
        }
        String sql = "SELECT ls.*, to_char(ls.thoi_gian, 'YYYY-MM-DD HH24:MI:SS') as thoi_gian_str " +
                     "FROM hoadon.lich_su_thao_tac ls " +
                     "ORDER BY ls.id_ls DESC LIMIT 200";
        return jdbcTemplate.queryForList(sql);
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
                    return Map.of("success", false, "message",
                            "Thanh toán thất bại: Hóa đơn không thuộc chi nhánh của bạn!");
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
                    return Map.of("success", false, "message",
                            "Chuyển phòng thất bại: Phòng không thuộc chi nhánh của bạn!");
                }
            }

            String sql = "SELECT hoadon.func_chuyen_phong(?, ?, ?)";
            Boolean result = jdbcTemplate.queryForObject(sql, Boolean.class, idHd, idPIdCu, idPIdMoi);
            if (Boolean.TRUE.equals(result)) {
                return Map.of("success", true, "message", "Chuyển phòng thành công!");
            } else {
                return Map.of("success", false, "message",
                        "Chuyển phòng thất bại (phòng mới không trống hoặc phòng cũ không thuộc hóa đơn này)!");
            }
        } catch (Exception e) {
            return Map.of("success", false, "message", "Lỗi: " + e.getMessage());
        }
    }

    @GetMapping("/invoice-billing/{id}")
    public Map<String, Object> getInvoiceBilling(@PathVariable int id, HttpSession session) {
        try {
            checkBranchAccess(session);
            Double tongChiPhi = jdbcTemplate.queryForObject("SELECT hoadon.func_tinh_tong_chi_phi(?)::numeric", Double.class, id);
            Double tienCoc = jdbcTemplate.queryForObject("SELECT hoadon.func_tinh_tien_coc(?)::numeric", Double.class, id);
            Double traSau = jdbcTemplate.queryForObject("SELECT hoadon.func_tinh_so_tien_tra_sau(?)::numeric", Double.class, id);
            Double giamGiaPercent = 0.0;
            try {
                Map<String, Object> hvDetails = jdbcTemplate.queryForMap(
                    "SELECT o_giam_gia_percent FROM hoadon.func_lay_hang_va_giam_gia_hoi_vien(?)", id
                );
                if (hvDetails.get("o_giam_gia_percent") != null) {
                    giamGiaPercent = ((Number) hvDetails.get("o_giam_gia_percent")).doubleValue();
                }
            } catch (Exception ignored) {}
            return Map.of(
                "success", true,
                "tongChiPhi", tongChiPhi != null ? tongChiPhi : 0.0,
                "tienCoc", tienCoc != null ? tienCoc : 0.0,
                "traSau", traSau != null ? traSau : 0.0,
                "giamGiaPercent", giamGiaPercent
            );
        } catch (Exception e) {
            return Map.of("success", false, "message", "Lỗi: " + e.getMessage());
        }
    }

    @GetMapping("/invoice-rooms/{id}")
    public List<Map<String, Object>> getInvoiceRooms(@PathVariable int id, HttpSession session) {
        checkBranchAccess(session);
        return jdbcTemplate.queryForList(
            "SELECT htp.id_p, p.dia_chi, htp.ngaynhan, htp.ngaytra, htp.so_ngay_luu_tru, " +
            "COALESCE(htp.phu_thu_tieu_hao::numeric, 0) AS phu_thu_tieu_hao, " +
            "COALESCE(htp.phu_thu_hong_hoc::numeric, 0) AS phu_thu_hong_hoc, " +
            "lp.gia_tien::numeric AS gia_tien, lp.chat_luong, lp.loai_giuong " +
            "FROM hoadon.hoadon_thue_phong htp " +
            "JOIN quanly.phong p ON htp.id_p = p.id_p " +
            "JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp " +
            "WHERE htp.id_hd = ?",
            id
        );
    }

    @PostMapping("/check-out-phong")
    public Map<String, Object> checkOutPhong(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            Integer branchId = checkBranchAccess(session);
            int idHd = ((Number) body.get("idHd")).intValue();
            int idP = ((Number) body.get("idP")).intValue();
            double phuThuTieuHao = ((Number) body.getOrDefault("phuThuTieuHao", 0)).doubleValue();
            double phuThuHongHoc = ((Number) body.getOrDefault("phuThuHongHoc", 0)).doubleValue();

            if (branchId > 0) {
                // Verify room belongs to the branch
                Integer count = jdbcTemplate.queryForObject(
                        "SELECT COUNT(*) FROM quanly.phong p JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp WHERE p.id_p = ? AND lp.id_cn = ?",
                        Integer.class, idP, branchId);
                if (count == null || count == 0) {
                    return Map.of("success", false, "message",
                            "Check-out thất bại: Phòng không thuộc chi nhánh của bạn!");
                }
            }

            String sql = "SELECT hoadon.func_check_out_phong(?, ?, ?::numeric::money, ?::numeric::money)::numeric AS tong_tien";
            Double tongTien = jdbcTemplate.queryForObject(sql, Double.class, idHd, idP, phuThuTieuHao, phuThuHongHoc);
            return Map.of("success", true, "message", "Check-out phòng thành công!", "tong_tien", tongTien);
        } catch (Exception e) {
            return Map.of("success", false, "message", "Lỗi: " + e.getMessage());
        }
    }

    @PostMapping("/check-out-va-thanh-toan")
    @Transactional
    public Map<String, Object> checkOutVaThanhToan(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            Integer branchId = checkBranchAccess(session);
            int idHd = ((Number) body.get("idHd")).intValue();
            String phuongThuc = (String) body.get("phuongThuc");
            List<Map<String, Object>> rooms = (List<Map<String, Object>>) body.get("rooms");

            if (branchId > 0) {
                // Verify invoice belongs to the branch
                Integer count = jdbcTemplate.queryForObject(
                        "SELECT COUNT(*) FROM hoadon.hoadon h JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv WHERE h.id_hd = ? AND nv.id_cn = ?",
                        Integer.class, idHd, branchId);
                if (count == null || count == 0) {
                    return Map.of("success", false, "message",
                            "Check-out và thanh toán thất bại: Hóa đơn không thuộc chi nhánh của bạn!");
                }
            }

            // Get customer and employee details to log the checkout
            List<Map<String, Object>> invoiceInfo = jdbcTemplate.queryForList(
                "SELECT h.id_kh, kh.ho_ten, h.id_nv, nv.ten_nv, htp.id_p " +
                "FROM hoadon.hoadon h " +
                "JOIN hoadon.hoadon_thue_phong htp ON h.id_hd = htp.id_hd " +
                "LEFT JOIN khachhang.khachhang kh ON h.id_kh = kh.id_kh " +
                "LEFT JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv " +
                "WHERE h.id_hd = ?", idHd
            );

            // 1. Loop through each room and check it out with its surcharges
            for (Map<String, Object> room : rooms) {
                int idP = ((Number) room.get("idP")).intValue();
                double phuThuTieuHao = ((Number) room.getOrDefault("phuThuTieuHao", 0)).doubleValue();
                double phuThuHongHoc = ((Number) room.getOrDefault("phuThuHongHoc", 0)).doubleValue();

                if (branchId > 0) {
                    // Verify room belongs to the branch
                    Integer count = jdbcTemplate.queryForObject(
                            "SELECT COUNT(*) FROM quanly.phong p JOIN quanly.loaiphong lp ON p.id_lp = lp.id_lp WHERE p.id_p = ? AND lp.id_cn = ?",
                            Integer.class, idP, branchId);
                    if (count == null || count == 0) {
                        throw new RuntimeException("Phòng #" + idP + " không thuộc chi nhánh của bạn!");
                    }
                }

                String checkOutSql = "SELECT hoadon.func_check_out_phong(?, ?, ?::numeric::money, ?::numeric::money)::numeric AS tong_tien";
                jdbcTemplate.queryForObject(checkOutSql, Double.class, idHd, idP, phuThuTieuHao, phuThuHongHoc);
            }

            // 2. Perform invoice payment
            String paySql = "SELECT hoadon.func_thanh_toan_hoa_don(?, ?)::numeric AS tong_tien";
            Double tongTien = jdbcTemplate.queryForObject(paySql, Double.class, idHd, phuongThuc);

            // 3. Log checkout/payment history
            try {
                for (Map<String, Object> info : invoiceInfo) {
                    Integer idKhVal = (Integer) info.get("id_kh");
                    String hoTen = (String) info.get("ho_ten");
                    Integer idNvVal = (Integer) info.get("id_nv");
                    String tenNv = (String) info.get("ten_nv");
                    Integer idP = (Integer) info.get("id_p");
                    
                    jdbcTemplate.update(
                        "INSERT INTO hoadon.lich_su_thao_tac (thao_tac, id_hd, id_kh, ho_ten_kh, id_nv, ten_nv, id_p) VALUES (?, ?, ?, ?, ?, ?, ?)",
                        "Thanh toán (Check-out)", idHd, idKhVal, hoTen, idNvVal, tenNv, idP
                    );
                }
            } catch (Exception ex) {
                System.err.println("Failed to log checkout history: " + ex.getMessage());
            }

            return Map.of("success", true, "message", "Check-out và thanh toán hóa đơn thành công!", "tong_tien", tongTien);
        } catch (Exception e) {
            return Map.of("success", false, "message", "Lỗi: " + e.getMessage());
        }
    }

    @GetMapping("/services")
    public List<Map<String, Object>> getServices(HttpSession session) {
        checkBranchAccess(session);
        return jdbcTemplate.queryForList("SELECT id_dv, ten_dv, gia::numeric AS gia, loai_dv FROM hoadon.dichvu ORDER BY id_dv");
    }

    @GetMapping("/invoice-services/{id}")
    public List<Map<String, Object>> getInvoiceServices(@PathVariable int id, HttpSession session) {
        checkBranchAccess(session);
        return jdbcTemplate.queryForList(
            "SELECT hsd.id_dv, dv.ten_dv, dv.loai_dv, dv.gia::numeric AS gia, hsd.so_luong " +
            "FROM hoadon.hoadon_sudung_dichvu hsd " +
            "JOIN hoadon.dichvu dv ON hsd.id_dv = dv.id_dv " +
            "WHERE hsd.id_hd = ? ORDER BY dv.id_dv", id
        );
    }

    @PostMapping("/them-dich-vu")
    public Map<String, Object> themDichVu(@RequestBody Map<String, Object> body, HttpSession session) {
        try {
            Integer branchId = checkBranchAccess(session);
            int idHd = ((Number) body.get("idHd")).intValue();
            int idDv = ((Number) body.get("idDv")).intValue();
            int soLuong = ((Number) body.get("soLuong")).intValue();

            if (branchId > 0) {
                // Verify invoice belongs to the branch
                Integer count = jdbcTemplate.queryForObject(
                        "SELECT COUNT(*) FROM hoadon.hoadon h JOIN nhansu.nhanvien nv ON h.id_nv = nv.id_nv WHERE h.id_hd = ? AND nv.id_cn = ?",
                        Integer.class, idHd, branchId);
                if (count == null || count == 0) {
                    return Map.of("success", false, "message",
                            "Thêm dịch vụ thất bại: Hóa đơn không thuộc chi nhánh của bạn!");
                }
            }

            String sql = "SELECT hoadon.func_them_dich_vu_vao_hoa_don(?, ?, ?)::numeric AS tong_tien_dv";
            jdbcTemplate.queryForObject(sql, Double.class, idHd, idDv, soLuong);
            return Map.of("success", true, "message", "Thêm dịch vụ vào hóa đơn thành công!");
        } catch (Exception e) {
            return Map.of("success", false, "message", "Lỗi: " + e.getMessage());
        }
    }
}

