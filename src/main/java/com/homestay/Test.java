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
            String TiLeCheckoutMuon = SQLHelper.readQuery("quanly/kiem_tra_phong_qua_han_checkout.sql");
            List<Map<String, Object>> result = jdbcTemplate.queryForList(TiLeCheckoutMuon);
            System.out.println(result);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
