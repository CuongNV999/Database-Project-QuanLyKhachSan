package com.homestay;

import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.jdbc.core.JdbcTemplate;
import java.sql.Timestamp;
import java.util.List;
import java.util.Map;

@SpringBootApplication
public class App {

    public static void main(String[] args) {
        SpringApplication.run(App.class, args);
    }

    @Bean
    public CommandLineRunner demo(JdbcTemplate jdbcTemplate) {
        return args -> {
            System.out.println("\n========================================================");
            System.out.println("KHỞI CHẠY BÁO CÁO NGHIỆP VỤ DEMO (SPRING BOOT & JDBC)");
            System.out.println("========================================================");

            // Demo A: Truy vấn từ View mới tạo (v_doanh_thu_chi_nhanh)
            try {
                String sqlView = "SELECT * FROM v_doanh_thu_chi_nhanh LIMIT 5";
                List<Map<String, Object>> branchRevenues = jdbcTemplate.queryForList(sqlView);

                System.out.println("\n--- DOANH THU CÁC CHI NHÁNH (Lấy từ View) ---");
                for (Map<String, Object> row : branchRevenues) {
                    System.out.printf("Chi nhánh: %s | Tổng doanh thu phòng: %,.0f VND | Số hóa đơn: %d\n",
                            row.get("ten_cn"),
                            ((Number) row.get("tong_doanh_thu_thue_phong")).doubleValue(),
                            ((Number) row.get("so_hoa_don")).intValue());
                }
            } catch (Exception e) {
                System.err.println("Truy vấn View doanh thu chi nhánh thất bại: " + e.getMessage());
            }

            // Demo B: Tải câu truy vấn động từ file tim_phong_trong.sql thông qua SQLHelper
            try {
                String timPhongSql = SQLHelper.readQuery("quanly/tim_phong_trong.sql");
                System.out.println("\n--- TOP 5 PHÒNG CÒN TRỐNG TẠI CHI NHÁNH 1 (Từ 15/06/2026 đến 20/06/2026) ---");
                
                // Đặt tham số cho chi nhánh 1, khoảng thời gian: 15/06/2026 14:00 đến 20/06/2026 12:00
                List<Map<String, Object>> availableRooms = jdbcTemplate.queryForList(
                        timPhongSql,
                        1,
                        Timestamp.valueOf("2026-06-20 12:00:00"),
                        Timestamp.valueOf("2026-06-15 14:00:00")
                );

                int printedCount = 0;
                for (Map<String, Object> row : availableRooms) {
                    if (printedCount >= 5) break;
                    System.out.printf("Phòng: %s | Chất lượng: %s | Giường: %s | Giá: %,.0f VND\n",
                            row.get("ten_phong"),
                            row.get("chat_luong"),
                            row.get("loai_giuong"),
                            ((Number) row.get("gia_tien")).doubleValue());
                    printedCount++;
                }
            } catch (Exception e) {
                System.err.println("Truy vấn tìm phòng trống thất bại: " + e.getMessage());
                e.printStackTrace();
            }
            System.out.println("========================================================\n");
        };
    }
}
