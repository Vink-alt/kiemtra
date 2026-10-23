-- ==============================================================================
-- FLEET MANAGEMENT SYSTEM - POSTGRESQL INITIALIZATION SCHEMA & SEED DATA
-- Database: fleetdb
-- ==============================================================================

-- Drop tables if exists in reverse dependency order
DROP TABLE IF EXISTS fuel_logs CASCADE;
DROP TABLE IF EXISTS maintenance_records CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
DROP TABLE IF EXISTS drivers CASCADE;
DROP TABLE IF EXISTS vehicles CASCADE;
DROP TABLE IF EXISTS vehicle_types CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- 1. USERS TABLE
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(20) NOT NULL CHECK (role IN ('driver', 'dispatcher', 'admin')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 2. VEHICLE TYPES TABLE
CREATE TABLE vehicle_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    sort_order INT DEFAULT 0
);

-- 3. VEHICLES TABLE
CREATE TABLE vehicles (
    id SERIAL PRIMARY KEY,
    plate_number VARCHAR(20) UNIQUE NOT NULL,
    vehicle_type_id INT NOT NULL REFERENCES vehicle_types(id) ON DELETE RESTRICT,
    make VARCHAR(50) NOT NULL,
    model VARCHAR(50) NOT NULL,
    year INT CHECK (year >= 1990),
    vin VARCHAR(50) UNIQUE NULL,
    fuel_type VARCHAR(20) NOT NULL CHECK (fuel_type IN ('gasoline', 'diesel', 'electric', 'hybrid')),
    seats INT CHECK (seats > 0),
    odometer_km INT CHECK (odometer_km >= 0),
    status VARCHAR(20) NOT NULL CHECK (status IN ('available', 'in_use', 'maintenance', 'retired')),
    insurance_expiry DATE NOT NULL,
    registration_expiry DATE NOT NULL,
    next_service_km INT NOT NULL,
    image_path VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- 4. DRIVERS TABLE
CREATE TABLE drivers (
    id SERIAL PRIMARY KEY,
    user_id INT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    license_number VARCHAR(50) UNIQUE NOT NULL,
    license_class VARCHAR(10) NOT NULL,
    license_expiry DATE NOT NULL,
    phone VARCHAR(20)
);

-- 5. TRIPS TABLE
CREATE TABLE trips (
    id SERIAL PRIMARY KEY,
    trip_code VARCHAR(50) UNIQUE NOT NULL,
    vehicle_id INT NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    driver_id INT NOT NULL REFERENCES drivers(id) ON DELETE RESTRICT,
    created_by INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    purpose TEXT,
    origin VARCHAR(255) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    planned_start TIMESTAMPTZ NOT NULL,
    planned_end TIMESTAMPTZ NOT NULL CHECK (planned_end > planned_start),
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    start_odometer INT,
    end_odometer INT CHECK (end_odometer >= start_odometer),
    distance_km INT,
    cancel_reason TEXT
);

-- 6. MAINTENANCE RECORDS TABLE
CREATE TABLE maintenance_records (
    id SERIAL PRIMARY KEY,
    vehicle_id INT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('routine', 'repair', 'inspection', 'tire')),
    description TEXT NOT NULL,
    cost NUMERIC(12, 0) CHECK (cost >= 0),
    odometer_km INT NOT NULL,
    serviced_at DATE NOT NULL,
    next_due_km INT NULL,
    performed_by INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT
);

-- 7. FUEL LOGS TABLE
CREATE TABLE fuel_logs (
    id SERIAL PRIMARY KEY,
    vehicle_id INT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    trip_id INT NULL REFERENCES trips(id) ON DELETE SET NULL,
    filled_at TIMESTAMPTZ NOT NULL,
    liters NUMERIC(8, 2) CHECK (liters > 0),
    price_per_liter NUMERIC(10, 0) CHECK (price_per_liter >= 0),
    total_cost NUMERIC(12, 0) NOT NULL,
    odometer_km INT NOT NULL,
    station VARCHAR(255),
    recorded_by INT NOT NULL REFERENCES users(id) ON DELETE RESTRICT
);

-- INDEXES FOR PERFORMANCE AND TRANSACTION CONCURRENCY
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_vehicles_status ON vehicles(status);
CREATE INDEX idx_vehicles_type ON vehicles(vehicle_type_id);
CREATE INDEX idx_vehicles_plate ON vehicles(plate_number);
CREATE INDEX idx_drivers_expiry ON drivers(license_expiry);
CREATE INDEX idx_trips_vehicle_status ON trips(vehicle_id, status);
CREATE INDEX idx_trips_driver_status ON trips(driver_id, status);
CREATE INDEX idx_trips_dates ON trips(planned_start, planned_end);
CREATE INDEX idx_maintenance_vehicle ON maintenance_records(vehicle_id);
CREATE INDEX idx_fuel_vehicle ON fuel_logs(vehicle_id);

-- ==============================================================================
-- SEED DATA
-- ==============================================================================

-- 1. SEED USERS
-- Password Hashes:
-- admin: FleetAdmin@2026! -> $2b$10$ZKBfP8OBdQ8arvDciYbUG.zPiuYZGyoIAieV1gj6oL0r4Qexhtsre
-- dieuphoi: FleetDisp@2026! -> $2b$10$1utGIZMOuFr4HWui/pxRTuXFyK34.L4nl4YIWUIxnLrCXbtK9VmVy
-- taixe: FleetDriver@2026! -> $2b$10$xGsAVTrXvNzb5os16J3reuhKJ4IL4qjJ3NDgRkb2DaTgppU.QEUEq

INSERT INTO users (username, email, password_hash, full_name, phone, role, is_active) VALUES
('admin', 'admin@fleet.local', '$2b$10$ZKBfP8OBdQ8arvDciYbUG.zPiuYZGyoIAieV1gj6oL0r4Qexhtsre', 'Nguyễn Quản Trị', '0901234567', 'admin', true),
('dieuphoi01', 'dieuphoi01@fleet.local', '$2b$10$1utGIZMOuFr4HWui/pxRTuXFyK34.L4nl4YIWUIxnLrCXbtK9VmVy', 'Trần Điều Phối 01', '0912345678', 'dispatcher', true),
('dieuphoi02', 'dieuphoi02@fleet.local', '$2b$10$1utGIZMOuFr4HWui/pxRTuXFyK34.L4nl4YIWUIxnLrCXbtK9VmVy', 'Lê Điều Phối 02', '0923456789', 'dispatcher', true),
('taixe01', 'taixe01@fleet.local', '$2b$10$xGsAVTrXvNzb5os16J3reuhKJ4IL4qjJ3NDgRkb2DaTgppU.QEUEq', 'Phạm Văn Tài 01', '0934567890', 'driver', true),
('taixe02', 'taixe02@fleet.local', '$2b$10$xGsAVTrXvNzb5os16J3reuhKJ4IL4qjJ3NDgRkb2DaTgppU.QEUEq', 'Hoàng Văn Lái 02', '0945678901', 'driver', true),
('taixe03', 'taixe03@fleet.local', '$2b$10$xGsAVTrXvNzb5os16J3reuhKJ4IL4qjJ3NDgRkb2DaTgppU.QEUEq', 'Đặng Quốc Xế 03', '0956789012', 'driver', true),
('taixe04', 'taixe04@fleet.local', '$2b$10$xGsAVTrXvNzb5os16J3reuhKJ4IL4qjJ3NDgRkb2DaTgppU.QEUEq', 'Vũ Thành Lộ 04', '0967890123', 'driver', true);

-- 2. SEED DRIVERS (taixe01 expires in 20 days -> WARNING)
INSERT INTO drivers (user_id, license_number, license_class, license_expiry, phone) VALUES
((SELECT id FROM users WHERE username = 'taixe01'), 'GPLX-010203040', 'B2', CURRENT_DATE + INTERVAL '20 days', '0934567890'),
((SELECT id FROM users WHERE username = 'taixe02'), 'GPLX-020304050', 'C', CURRENT_DATE + INTERVAL '365 days', '0945678901'),
((SELECT id FROM users WHERE username = 'taixe03'), 'GPLX-030405060', 'D', CURRENT_DATE + INTERVAL '720 days', '0956789012'),
((SELECT id FROM users WHERE username = 'taixe04'), 'GPLX-040506070', 'E', CURRENT_DATE + INTERVAL '500 days', '0967890123');

-- 3. SEED VEHICLE TYPES
INSERT INTO vehicle_types (name, sort_order) VALUES
('Xe con (Sedan/Hatchback)', 1),
('SUV / MPV', 2),
('Xe bán tải (Pickup)', 3),
('Xe tải nhẹ', 4),
('Xe khách 16 chỗ', 5);

-- 4. SEED 16 REALISTIC VEHICLES IN VIETNAM
-- Type 1: Xe con (sedan.svg)
-- Type 2: SUV/MPV (suv.svg)
-- Type 3: Xe ban tai (pickup.svg)
-- Type 4: Xe tai nhe (truck.svg)
-- Type 5: Xe khach 16 cho (van.svg)
INSERT INTO vehicles (plate_number, vehicle_type_id, make, model, year, vin, fuel_type, seats, odometer_km, status, insurance_expiry, registration_expiry, next_service_km, image_path) VALUES
-- Xe 1: Available, bình thường
('30A-123.45', 1, 'Toyota', 'Vios 1.5G', 2022, 'RL4BT9134NL102931', 'gasoline', 5, 28500, 'available', CURRENT_DATE + INTERVAL '180 days', CURRENT_DATE + INTERVAL '180 days', 35000, '/images/vehicles/sedan.svg'),
-- Xe 2: Available, sắp hết hạn đăng kiểm trong 15 ngày!
('30G-678.90', 1, 'Honda', 'City RS', 2021, 'RL4GM2678NL554432', 'gasoline', 5, 41200, 'available', CURRENT_DATE + INTERVAL '90 days', CURRENT_DATE + INTERVAL '15 days', 45000, '/images/vehicles/sedan.svg'),
-- Xe 3: Available, sắp đến hạn bảo dưỡng (còn 200 km <= 500 km)!
('51H-234.56', 1, 'Hyundai', 'Accent AT', 2023, 'KMHCT4134PU891234', 'gasoline', 5, 19800, 'available', CURRENT_DATE + INTERVAL '240 days', CURRENT_DATE + INTERVAL '240 days', 20000, '/images/vehicles/sedan.svg'),
-- Xe 4: In Use (đang chạy chuyến)
('29A-999.88', 1, 'Toyota', 'Camry 2.5Q', 2022, 'JTDKN3DU001099881', 'hybrid', 5, 34500, 'in_use', CURRENT_DATE + INTERVAL '150 days', CURRENT_DATE + INTERVAL '150 days', 40000, '/images/vehicles/sedan.svg'),

-- Xe 5: Available, SUV
('30F-456.78', 2, 'Toyota', 'Fortuner Legender', 2022, 'MHFYB59G200112233', 'diesel', 7, 52000, 'available', CURRENT_DATE + INTERVAL '210 days', CURRENT_DATE + INTERVAL '210 days', 60000, '/images/vehicles/suv.svg'),
-- Xe 6: Available, MPV bán chạy
('51K-888.66', 2, 'Mitsubishi', 'Xpander Cross', 2023, 'MMBJRNC1WP0022334', 'gasoline', 7, 24600, 'available', CURRENT_DATE + INTERVAL '120 days', CURRENT_DATE + INTERVAL '120 days', 30000, '/images/vehicles/suv.svg'),
-- Xe 7: Maintenance (đang bảo dưỡng)
('29B-345.67', 2, 'Ford', 'Everest Titanium', 2021, 'MPBUM50K800334455', 'diesel', 7, 68000, 'maintenance', CURRENT_DATE + INTERVAL '90 days', CURRENT_DATE + INTERVAL '90 days', 70000, '/images/vehicles/suv.svg'),
-- Xe 8: Available, sắp hết hạn bảo hiểm (22 ngày <= 30 ngày)!
('43A-567.89', 2, 'Kia', 'Carnival Signature', 2022, 'KNAGH814DN5566778', 'diesel', 7, 39000, 'available', CURRENT_DATE + INTERVAL '22 days', CURRENT_DATE + INTERVAL '160 days', 45000, '/images/vehicles/suv.svg'),

-- Xe 9: Available, bán tải
('29H-123.99', 3, 'Ford', 'Ranger Wildtrak', 2023, 'MNBUMFF6200778899', 'diesel', 5, 21500, 'available', CURRENT_DATE + INTERVAL '300 days', CURRENT_DATE + INTERVAL '300 days', 30000, '/images/vehicles/pickup.svg'),
-- Xe 10: In Use (đang chở hàng)
('14C-456.12', 3, 'Mitsubishi', 'Triton Athlete', 2022, 'MMBJNKK1WP0099887', 'diesel', 5, 47800, 'in_use', CURRENT_DATE + INTERVAL '130 days', CURRENT_DATE + INTERVAL '130 days', 50000, '/images/vehicles/pickup.svg'),
-- Xe 11: Available, sắp hết hạn đăng kiểm (đã quá hạn 5 ngày -> EXPIRED)
('36C-789.01', 3, 'Isuzu', 'D-Max Hi-Lander', 2020, 'MP1TFSC4EP0011223', 'diesel', 5, 82000, 'available', CURRENT_DATE + INTERVAL '60 days', CURRENT_DATE - INTERVAL '5 days', 85000, '/images/vehicles/pickup.svg'),

-- Xe 12: Available, tải nhẹ
('29H-888.11', 4, 'Hyundai', 'New Porter H150', 2022, 'KMHWC37KPNU112233', 'diesel', 3, 37500, 'available', CURRENT_DATE + INTERVAL '180 days', CURRENT_DATE + INTERVAL '180 days', 40000, '/images/vehicles/truck.svg'),
-- Xe 13: Maintenance, tải nhẹ
('50H-999.22', 4, 'Kia', 'Frontier K200', 2021, 'KNABM814DN2233445', 'diesel', 3, 59200, 'maintenance', CURRENT_DATE + INTERVAL '110 days', CURRENT_DATE + INTERVAL '110 days', 60000, '/images/vehicles/truck.svg'),
-- Xe 14: Available, sắp đến hạn bảo dưỡng (còn 350 km <= 500 km)!
('89C-333.44', 4, 'Isuzu', 'QKR 270', 2022, 'MP1QKR4EP00445566', 'diesel', 3, 49650, 'available', CURRENT_DATE + INTERVAL '190 days', CURRENT_DATE + INTERVAL '190 days', 50000, '/images/vehicles/truck.svg'),

-- Xe 15: Available, xe khách 16 chỗ
('29B-666.77', 5, 'Ford', 'Transit Luxury', 2022, 'MNBTTFF6200556677', 'diesel', 16, 42000, 'available', CURRENT_DATE + INTERVAL '150 days', CURRENT_DATE + INTERVAL '150 days', 50000, '/images/vehicles/van.svg'),
-- Xe 16: Retired (Đã thanh lý - xe cũ năm 2010)
('30V-9999', 5, 'Toyota', 'Hiace Commuter', 2010, 'JTDSS3DU001009999', 'diesel', 16, 320000, 'retired', CURRENT_DATE - INTERVAL '300 days', CURRENT_DATE - INTERVAL '300 days', 320000, '/images/vehicles/van.svg');

-- 5. SEED TRIPS
INSERT INTO trips (trip_code, vehicle_id, driver_id, created_by, status, purpose, origin, destination, planned_start, planned_end, started_at, ended_at, start_odometer, end_odometer, distance_km, cancel_reason) VALUES
-- Trip 1: Completed
('TRP-20261001-01', 
 (SELECT id FROM vehicles WHERE plate_number = '30A-123.45'),
 (SELECT id FROM drivers WHERE user_id = (SELECT id FROM users WHERE username = 'taixe01')),
 (SELECT id FROM users WHERE username = 'dieuphoi01'),
 'completed', 'Đưa đón ban lãnh đạo dự hội nghị Nội Bài', 'Trụ sở công ty (Hà Nội)', 'Sân bay Quốc tế Nội Bài',
 NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days' + INTERVAL '4 hours',
 NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days' + INTERVAL '3 hours 45 minutes',
 28420, 28500, 80, NULL),

-- Trip 2: In Progress (matching vehicle 29A-999.88 status in_use)
('TRP-20261023-02', 
 (SELECT id FROM vehicles WHERE plate_number = '29A-999.88'),
 (SELECT id FROM drivers WHERE user_id = (SELECT id FROM users WHERE username = 'taixe02')),
 (SELECT id FROM users WHERE username = 'dieuphoi01'),
 'in_progress', 'Đưa đoàn chuyên gia khảo sát cảng Hải Phòng', 'Hà Nội', 'Cảng Đình Vũ (Hải Phòng)',
 NOW() - INTERVAL '2 hours', NOW() + INTERVAL '6 hours',
 NOW() - INTERVAL '2 hours', NULL,
 34500, NULL, NULL, NULL),

-- Trip 3: Planned (future trip)
('TRP-20261025-03', 
 (SELECT id FROM vehicles WHERE plate_number = '51K-888.66'),
 (SELECT id FROM drivers WHERE user_id = (SELECT id FROM users WHERE username = 'taixe03')),
 (SELECT id FROM users WHERE username = 'dieuphoi02'),
 'planned', 'Chở đoàn công tác chi nhánh Bình Dương', 'Chi nhánh TP.HCM', 'KCN VSIP Bình Dương',
 NOW() + INTERVAL '1 day', NOW() + INTERVAL '1 day 5 hours',
 NULL, NULL, NULL, NULL, NULL, NULL),

-- Trip 4: Cancelled
('TRP-20261015-04', 
 (SELECT id FROM vehicles WHERE plate_number = '29H-123.99'),
 (SELECT id FROM drivers WHERE user_id = (SELECT id FROM users WHERE username = 'taixe04')),
 (SELECT id FROM users WHERE username = 'dieuphoi02'),
 'cancelled', 'Vận chuyển thiết bị dự phòng Hà Nam', 'Kho tổng Hà Nội', 'KCN Đồng Văn (Hà Nam)',
 NOW() - INTERVAL '5 days', NOW() - INTERVAL '5 days' + INTERVAL '6 hours',
 NULL, NULL, NULL, NULL, NULL, 'Khách hàng thay đổi kế hoạch dời sang tuần sau');

-- 6. SEED MAINTENANCE RECORDS
INSERT INTO maintenance_records (vehicle_id, type, description, cost, odometer_km, serviced_at, next_due_km, performed_by) VALUES
((SELECT id FROM vehicles WHERE plate_number = '30A-123.45'), 'routine', 'Bảo dưỡng định kỳ cấp 25.000 km, thay dầu máy và lọc gió', 1450000, 25000, CURRENT_DATE - INTERVAL '45 days', 35000, (SELECT id FROM users WHERE username = 'admin')),
((SELECT id FROM vehicles WHERE plate_number = '29B-345.67'), 'repair', 'Thay má phanh trước và cân chỉnh độ chụm bánh xe', 4200000, 68000, CURRENT_DATE - INTERVAL '1 day', 70000, (SELECT id FROM users WHERE username = 'dieuphoi01')),
((SELECT id FROM vehicles WHERE plate_number = '50H-999.22'), 'inspection', 'Đại tu hệ thống lái và thay 2 lốp sau', 8500000, 59200, CURRENT_DATE, 60000, (SELECT id FROM users WHERE username = 'dieuphoi02'));

-- 7. SEED FUEL LOGS
INSERT INTO fuel_logs (vehicle_id, trip_id, filled_at, liters, price_per_liter, total_cost, odometer_km, station, recorded_by) VALUES
((SELECT id FROM vehicles WHERE plate_number = '30A-123.45'), 
 (SELECT id FROM trips WHERE trip_code = 'TRP-20261001-01'),
 NOW() - INTERVAL '3 days' + INTERVAL '30 minutes', 
 35.50, 24500, 869750, 28450, 'Petrolimex Cửa hàng 01 - Cầu Giấy',
 (SELECT id FROM users WHERE username = 'taixe01')),
((SELECT id FROM vehicles WHERE plate_number = '51H-234.56'), 
 NULL,
 NOW() - INTERVAL '2 days', 
 40.00, 24200, 968000, 19750, 'Petrolimex 12 - Q1 TP.HCM',
 (SELECT id FROM users WHERE username = 'dieuphoi01')),
((SELECT id FROM vehicles WHERE plate_number = '29H-888.11'), 
 NULL,
 NOW() - INTERVAL '1 day', 
 65.00, 21800, 1417000, 37400, 'PVOIL Phạm Hùng - Hà Nội',
 (SELECT id FROM users WHERE username = 'dieuphoi02'));


-- =============================================================================
-- EXPORTER ROLE FOR PROMETHEUS POSTGRES_EXPORTER
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'exporter') THEN
    CREATE ROLE exporter WITH LOGIN PASSWORD 'FleetExporter@2026!';
    GRANT pg_monitor TO exporter;
  END IF;
END
$$;


-- =============================================================================
-- HARDENING - LEAST PRIVILEGE ROLES & PERMISSIONS (BUOC 6)
-- =============================================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'fleet_admin') THEN
    CREATE ROLE fleet_admin WITH SUPERUSER LOGIN PASSWORD 'FleetAdminPass@2026!';
  END IF;
END
$$;

ALTER DATABASE fleetdb OWNER TO fleet_admin;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' OWNER TO fleet_admin';
    END LOOP;
    FOR r IN (SELECT sequence_name FROM information_schema.sequences WHERE sequence_schema = 'public') LOOP
        EXECUTE 'ALTER SEQUENCE public.' || quote_ident(r.sequence_name) || ' OWNER TO fleet_admin';
    END LOOP;
END
$$;

-- fleet_app is granted only DML (SELECT, INSERT, UPDATE, DELETE)
REVOKE ALL ON SCHEMA public FROM fleet_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO fleet_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO fleet_app;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO fleet_app;
ALTER DEFAULT PRIVILEGES FOR ROLE fleet_admin IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO fleet_app;
ALTER DEFAULT PRIVILEGES FOR ROLE fleet_admin IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO fleet_app;