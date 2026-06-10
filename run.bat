@echo off
title Quan ly Khach san - Homestay Management

:menu
cls
echo =================================================================
echo         HE THONG QUAN LY KHACH SAN - TIEN ICH CHAY NHANH
echo =================================================================
echo  [1] Bien dich va Chay ung dung (mvn compile exec:java)
echo  [2] Khoi phuc / Nap du lieu mau (Import data_seed.sql)
echo  [3] Thoat
echo =================================================================
set /p choice="Nhap lua chon cua ban (1-3): "

if "%choice%"=="1" goto run_app
if "%choice%"=="2" goto import_data
if "%choice%"=="3" goto exit
goto menu

:run_app
echo.
echo =================================================================
echo [INFO] Dang bien dich va chay ung dung...
echo =================================================================
call mvn compile exec:java
echo.
echo Nhan phim bat ky de quay lai Menu...
pause > nul
goto menu

:import_data
echo.
echo =================================================================
echo [WARNING] Chuan bi nap du lieu mau vao PostgreSQL...
echo =================================================================
call psql "postgresql://postgres:admin@localhost:5432/quanlykhachsan" -1 -q -f "src/main/resources/db/data_seed.sql"
echo.
echo [SUCCESS] Da nap du lieu mau thanh cong!
echo Nhan phim bat ky de quay lai Menu...
pause > nul
goto menu

:exit
echo.
echo Tam biet!
timeout /t 2 > nul
exit /b
