package com.homestay;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import org.flywaydb.core.Flyway;

public class App {
    public static void main(String[] args) throws Exception {

        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            System.err.println("PostgreSQL JDBC Driver not found.");
            return;
        }

        String url = "jdbc:postgresql://localhost:5432/quanlykhachsan";
        String user = "postgres";
        String password = "admin";

        // 1. Khởi chạy Flyway migrations tự động
        try {
            System.out.println("Đang khởi chạy Flyway database migration...");
            Flyway flyway = Flyway.configure()
                .dataSource(url, user, password)
                .baselineOnMigrate(true) // Đặt baseline nếu DB đã có bảng từ trước
                .load();
            flyway.migrate();
            System.out.println("Flyway migration hoàn tất thành công!");
        } catch (Exception e) {
            System.err.println("Flyway migration thất bại: " + e.getMessage());
            e.printStackTrace();
            return;
        }

        // 2. Kết nối JDBC thực hiện truy vấn nghiệp vụ mẫu
        try (Connection conn = DriverManager.getConnection(url, user, password)) {
            System.out.println("\nKết nối cơ sở dữ liệu thành công!");

            // Demo A: Truy vấn từ View mới tạo (v_doanh_thu_chi_nhanh)
            try (PreparedStatement pstmt = conn.prepareStatement("SELECT * FROM v_doanh_thu_chi_nhanh LIMIT 5");
                 ResultSet rs = pstmt.executeQuery()) {
                System.out.println("\n--- DOANH THU CÁC CHI NHÁNH (Lấy từ View) ---");
                while (rs.next()) {
                    System.out.printf("Chi nhánh: %s | Tổng doanh thu phòng: %,.0f VND | Số hóa đơn: %d\n",
                            rs.getString("ten_cn"),
                            rs.getDouble("tong_doanh_thu_thue_phong"),
                            rs.getInt("so_hoa_don"));
                }
            }

            // Demo B: Tải câu truy vấn động từ file tim_phong_trong.sql thông qua SQLHelper
            String timPhongSql = SQLHelper.readQuery("quanly/tim_phong_trong.sql");
            try (PreparedStatement pstmt = conn.prepareStatement(timPhongSql)) {
                // Đặt tham số cho chi nhánh 1, khoảng thời gian: 15/06/2026 14:00 đến 20/06/2026 12:00
                pstmt.setInt(1, 1);
                pstmt.setTimestamp(2, Timestamp.valueOf("2026-06-20 12:00:00"));
                pstmt.setTimestamp(3, Timestamp.valueOf("2026-06-15 14:00:00"));

                try (ResultSet rs = pstmt.executeQuery()) {
                    System.out.println("\n--- TOP 5 PHÒNG CÒN TRỐNG TẠI CHI NHÁNH 1 (Từ 15/06/2026 đến 20/06/2026) ---");
                    int printedCount = 0;
                    while (rs.next() && printedCount < 5) {
                        System.out.printf("Phòng: %s | Chất lượng: %s | Giường: %s | Giá: %,.0f VND\n",
                                rs.getString("ten_phong"),
                                rs.getString("chat_luong"),
                                rs.getString("loai_giuong"),
                                rs.getDouble("gia_tien"));
                        printedCount++;
                    }
                }
            }

        } catch (SQLException e) {
            System.err.println("Kết nối cơ sở dữ liệu thất bại: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
