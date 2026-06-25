-- Update room sizes: replace 'Large' with specific values ('45m2' for Suite, '50m2' for others like Deluxe, Family, or Dorm)
UPDATE quanly.loaiphong 
SET dien_tich = '45m2' 
WHERE dien_tich = 'Large' AND chat_luong = 'Suite';

UPDATE quanly.loaiphong 
SET dien_tich = '50m2' 
WHERE dien_tich = 'Large' AND chat_luong != 'Suite';
