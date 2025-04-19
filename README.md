# SSL Hryric+QQE+RSI+Multi Frame m15&H4 EA

Expert Advisor sử dụng nhiều khung thời gian (H4 và M15) với chiến lược dựa trên các chỉ báo SSL Hybrid, QQE MOD và RSI.

## Tính Năng Chính

- **Phân Tích Đa Khung Thời Gian**: Sử dụng H4 để xác định xu hướng chính và M15 để tìm điểm vào lệnh
- **Quản Lý Rủi Ro Nâng Cao**: Tính toán cỡ lệnh dựa trên phần trăm rủi ro, giới hạn lỗ hàng ngày, số lỗ liên tiếp
- **Bộ Lọc Tin Tức**: Tự động tránh giao dịch trong thời gian có tin tức quan trọng
- **Quản Lý Lệnh Thông Minh**: TP1 (1.5R), TP2 (2.5R), trailing stop với SSL
- **Lưu Trữ Trạng Thái**: Lưu trữ và khôi phục trạng thái lệnh sau khi khởi động lại
- **Theo Dõi Hiệu Suất**: Thống kê tự động về hiệu suất giao dịch

## Yêu Cầu

- MetaTrader 5
- Chỉ báo tùy chỉnh: SSL Hybrid và QQE MOD

## Cấu Hình

EA cho phép tùy chỉnh nhiều tham số, bao gồm:
- Cài đặt quản lý rủi ro (phần trăm rủi ro, giới hạn lỗ hàng ngày)
- Tham số chỉ báo (SSL, QQE, RSI, ATR, EMA)
- Quy tắc vào lệnh và thoát lệnh
- Cài đặt bộ lọc tin tức

## Cách Sử Dụng

1. Cài đặt các chỉ báo SSL Hybrid và QQE MOD
2. Đặt EA vào thư mục MQL5/Experts
3. Tải EA lên biểu đồ cặp tiền tệ bất kỳ, khung thời gian M15
4. Cấu hình các tham số theo chiến lược giao dịch của bạn
5. Bật AutoTrading và bắt đầu giao dịch

## Phiên Bản

- v1.03 - Cải tiến quản lý lệnh, khôi phục trạng thái lệnh, theo dõi hiệu suất 