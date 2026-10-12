Dưới đây là mã nguồn của script `commands.sh`, tài liệu `README.md` và mô phỏng chi tiết kết quả chạy toàn bộ các lệnh kiểm tra theo yêu cầu.

---

### 1. Kịch bản thực thi tự động: `commands.sh`

```bash
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

```

---

### 2. Tệp tài liệu hướng dẫn: `README.md`

```markdown
# Báo Cáo Kỹ Thuật: Quản Lý Custom Bridge Network và Named Volume Trong Docker

## 1. Mục tiêu kiến trúc
- Tự động phân giải tên miền nội bộ (Automatic DNS Resolution): Docker mặc định không bật tính năng phân giải DNS qua tên container trên bridge network mặc định (`bridge`). Khi tạo một User-defined Bridge Network (`app-net`), Docker nhúng một DNS server nội bộ tại `127.0.0.11`, cho phép các container gọi nhau trực tiếp qua container name (ví dụ: `db-server`) thay vì phụ thuộc vào địa chỉ IP động.
- Tính bền vững của dữ liệu (Data Persistence): Mặc định vòng đời dữ liệu của container gắn liền với lớp bộ nhớ ghi tạm thời (Writable Container Layer). Khi container bị xóa (`docker rm`), dữ liệu biến mất. Việc sử dụng Named Volume (`db-data`) tách rời lưu trữ ra khỏi vòng đời container, lưu trực tiếp trên host tại `/var/lib/docker/volumes/` và cho phép tái sử dụng an toàn.

---

## 2. Quy trình kiểm tra chi tiết

### Bước 1: Kiểm tra Network và Volume đã tạo
```bash
docker network ls | grep app-net
docker volume ls | grep db-data

```

### Bước 2: Kiểm tra cấu hình và IP của các Container trong Network

```bash
docker network inspect app-net

```

### Bước 3: Kiểm tra cơ chế DNS Resolution nội bộ từ Backend Container

```bash
docker exec -it app-container ping -c 2 db-server

```

### Bước 4: Kiểm chứng tính toàn vẹn dữ liệu (Data Persistence)

* Thêm dữ liệu mẫu vào cơ sở dữ liệu.
* Xóa cưỡng bức container `db-server` bằng lệnh:
```bash
docker rm -f db-server

```


* Khởi chạy một container DB mới nhưng mount cùng volume `db-data`.
* Truy vấn lại dữ liệu để chứng minh tính bền vững.


## 3. Dọn dẹp tài nguyên

```bash
docker rm -f app-container db-server
docker network rm app-net
docker volume rm db-data

```


### 3. Mô phỏng kết quả thực thi các lệnh kiểm tra

#### Lệnh 1: `docker network ls | grep app-net`
```bash
$ docker network ls | grep app-net
e14d187b8912   app-net   bridge    local

```

#### Lệnh 2: `docker volume ls | grep db-data`

```bash
$ docker volume ls | grep db-data
local     db-data

```

#### Lệnh 3: `docker network inspect app-net`

```json
$ docker network inspect app-net
[
    {
        "Name": "app-net",
        "Id": "e14d187b8912fc18104ea2bc02e21b199bb6321245a4eb392f3cbce104d5ff1a",
        "Created": "2026-10-12T19:15:10.120938122+07:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Config": [
                {
                    "Subnet": "172.20.0.0/16",
                    "Gateway": "172.20.0.1"
                }
            ]
        },
        "Containers": {
            "3a15f0d3810a99c924bc01b4c901a18293": {
                "Name": "db-server",
                "EndpointID": "67dc3b118b76c",
                "MacAddress": "02:42:ac:14:00:02",
                "IPv4Address": "172.20.0.2/16",
                "IPv6Address": ""
            },
            "8f29e1c4a0349f8721ea1b203a985d18b2": {
                "Name": "app-container",
                "EndpointID": "9a56d9841bb2a",
                "MacAddress": "02:42:ac:14:00:03",
                "IPv4Address": "172.20.0.3/16",
                "IPv6Address": ""
            }
        }
    }
]

```

#### Lệnh 4: `docker exec -it app-container ping -c 2 db-server`

*(Container tự giải mã `db-server` thành IP nội bộ `172.20.0.2` do DNS server nhúng của Docker quản lý)*

```bash
$ docker exec -it app-container ping -c 2 db-server
PING db-server (172.20.0.2): 56 data bytes
64 bytes from 172.20.0.2: seq=0 ttl=64 time=0.082 ms
64 bytes from 172.20.0.2: seq=1 ttl=64 time=0.076 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.076/0.079/0.082 ms

```

#### Lệnh 5: Xác minh kiểm thử Data Persistence

* Bước ghi dữ liệu ban đầu:

```bash
$ docker exec -i db-server psql -U appuser -d appdb -c "SELECT * FROM users;"
 id | username |         created_at         
----+----------+----------------------------
  1 | alice    | 2026-10-12 12:15:15.234101
  2 | bob      | 2026-10-12 12:15:15.234101
(2 rows)

```

* Bước xóa cứng và tái tạo:

```bash
$ docker rm -f db-server
db-server

$ docker run -d --name db-server --network app-net -e POSTGRES_USER=appuser -e POSTGRES_PASSWORD=secretpassword -e POSTGRES_DB=appdb -v db-data:/var/lib/postgresql/data postgres:15-alpine
5f9cb422a10e8201a0914c0293ebf1293a1049281a0e19482bf0928192a01429

```

* Bước xác minh dữ liệu còn nguyên vẹn sau khi tái tạo:

```bash
$ docker exec -i db-server psql -U appuser -d appdb -c "SELECT * FROM users;"
 id | username |         created_at         
----+----------+----------------------------
  1 | alice    | 2026-10-12 12:15:15.234101
  2 | bob      | 2026-10-12 12:15:15.234101
(2 rows)

```