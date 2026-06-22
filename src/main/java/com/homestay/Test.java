package com.homestay;

import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

public class Test {
    public static void main(String[] args) {
        try {
            DriverManagerDataSource dataSource = new DriverManagerDataSource();
            dataSource.setDriverClassName("org.postgresql.Driver");
            dataSource.setUrl("jdbc:postgresql://localhost:5432/quanlykhachsan");
            dataSource.setUsername("postgres");
            dataSource.setPassword("admin");

            JdbcTemplate jdbcTemplate = new JdbcTemplate(dataSource);
            String sql = "SELECT hoadon.func_tinh_tong_tien_hoa_don(?)::numeric AS tong_tien";
            
            int[] testInvoices = {7121, 1, 2, 5};
            for (int id : testInvoices) {
                List<Map<String, Object>> result = jdbcTemplate.queryForList(sql, id);
                System.out.println("Tổng tiền hóa đơn " + id + " (số tiền trả sau thực tế): " + result.get(0).get("tong_tien") + " VND");
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
