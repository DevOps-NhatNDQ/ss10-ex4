#!/bin/bash
set -e

echo "=== 1. TẠO CUSTOM BRIDGE NETWORK VÀ NAMED VOLUME ==="
docker network create --driver bridge app-net
docker volume create db-data

echo "=== 2. KHỞI CHẠY POSTGRESQL CONTAINER (db-server) ==="
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secretpassword \
  -e POSTGRES_DB=appdb \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine

# Chờ 5 giây để PostgreSQL hoàn tất khởi tạo ban đầu
echo "Đang đợi PostgreSQL sẵn sàng..."
sleep 5

echo "=== 3. KHỞI CHẠY BACKEND CONTAINER (app-container) ==="
# Sử dụng image node:18-alpine có sẵn ping/curl hoặc backend image đã build ở Bài 2/3
docker run -d \
  --name app-container \
  --network app-net \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_USER=appuser \
  -e DB_PASS=secretpassword \
  -e DB_NAME=appdb \
  node:18-alpine \
  sh -c "while true; do sleep 3600; done"

echo "=== 4. TEST DATA PERSISTENCE - TẠO DỮ LIỆU BAN ĐẦU ==="
docker exec -i db-server psql -U appuser -d appdb << 'EOF'
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (username) VALUES ('alice'), ('bob');
SELECT * FROM users;
EOF

echo "=== 5. TEST DATA PERSISTENCE - XÓA CỨNG CONTAINER DB ==="
docker rm -f db-server

echo "=== 6. TEST DATA PERSISTENCE - TÁI TẠO CONTAINER DB MỚI DÙNG LẠI VOLUME ==="
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=secretpassword \
  -e POSTGRES_DB=appdb \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine

echo "Đang đợi container DB mới khởi động..."
sleep 5

echo "=== 7. XÁC MINH DỮ LIỆU KHÔNG BỊ MẤT ==="
docker exec -i db-server psql -U appuser -d appdb -c "SELECT * FROM users;"