-- Buildings
INSERT INTO Building SET name = 'HQ'
INSERT INTO Building SET name = 'Data Center'
-- Floors
INSERT INTO Floor SET name = 'HQ-1', level = 1
INSERT INTO Floor SET name = 'HQ-2', level = 2
INSERT INTO Floor SET name = 'DC-1', level = 1
INSERT INTO Floor SET name = 'DC-2', level = 2
-- Sensors
INSERT INTO Sensor SET name = 'Temp Sensor A', sensor_id = 's-A'
INSERT INTO Sensor SET name = 'Temp Sensor B', sensor_id = 's-B'
INSERT INTO Sensor SET name = 'Temp Sensor C', sensor_id = 's-C'
INSERT INTO Sensor SET name = 'Temp Sensor D', sensor_id = 's-D'
INSERT INTO Sensor SET name = 'Temp Sensor E', sensor_id = 's-E'
INSERT INTO Sensor SET name = 'Temp Sensor F', sensor_id = 's-F'
-- Servers
INSERT INTO Server SET name = 'Web Server 1', server_id = 'srv-1'
INSERT INTO Server SET name = 'App Server 2', server_id = 'srv-2'
INSERT INTO Server SET name = 'DB Server 3', server_id = 'srv-3'
-- Services
INSERT INTO Service SET name = 'api-gateway', service_id = 'api-gateway'
INSERT INTO Service SET name = 'auth-service', service_id = 'auth-service'
INSERT INTO Service SET name = 'user-service', service_id = 'user-service'
INSERT INTO Service SET name = 'payment-service', service_id = 'payment-service'
INSERT INTO Service SET name = 'notification-service', service_id = 'notification-service'
-- HAS_FLOOR edges (Building -> Floor)
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'HQ') TO (SELECT FROM Floor WHERE name = 'HQ-1')
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'HQ') TO (SELECT FROM Floor WHERE name = 'HQ-2')
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'Data Center') TO (SELECT FROM Floor WHERE name = 'DC-1')
CREATE EDGE HAS_FLOOR FROM (SELECT FROM Building WHERE name = 'Data Center') TO (SELECT FROM Floor WHERE name = 'DC-2')
-- INSTALLED_IN edges (Sensor -> Floor)
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-A') TO (SELECT FROM Floor WHERE name = 'HQ-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-B') TO (SELECT FROM Floor WHERE name = 'HQ-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-C') TO (SELECT FROM Floor WHERE name = 'HQ-2')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-D') TO (SELECT FROM Floor WHERE name = 'DC-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-E') TO (SELECT FROM Floor WHERE name = 'DC-1')
CREATE EDGE INSTALLED_IN FROM (SELECT FROM Sensor WHERE sensor_id = 's-F') TO (SELECT FROM Floor WHERE name = 'DC-2')
-- RUNS_ON edges (Service -> Server)
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'api-gateway') TO (SELECT FROM Server WHERE server_id = 'srv-1')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'auth-service') TO (SELECT FROM Server WHERE server_id = 'srv-1')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'user-service') TO (SELECT FROM Server WHERE server_id = 'srv-2')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'payment-service') TO (SELECT FROM Server WHERE server_id = 'srv-2')
CREATE EDGE RUNS_ON FROM (SELECT FROM Service WHERE service_id = 'notification-service') TO (SELECT FROM Server WHERE server_id = 'srv-3')
-- DEPENDS_ON edges (Service -> Service)
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'api-gateway') TO (SELECT FROM Service WHERE service_id = 'auth-service')
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'api-gateway') TO (SELECT FROM Service WHERE service_id = 'user-service')
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'user-service') TO (SELECT FROM Service WHERE service_id = 'payment-service')
CREATE EDGE DEPENDS_ON FROM (SELECT FROM Service WHERE service_id = 'payment-service') TO (SELECT FROM Service WHERE service_id = 'notification-service')
-- SensorReading time-series data (2-hour window, 10-15 min intervals)
-- Timestamps are epoch milliseconds for 2026-02-20 (ts column is LONG)
-- 10:00 = 1771581600000, 10:05 = 1771581900000, 10:10 = 1771582200000
-- 10:15 = 1771582500000, 10:30 = 1771583400000, 10:45 = 1771584300000
-- 11:00 = 1771585200000, 11:15 = 1771586100000, 11:30 = 1771587000000
-- s-A (HQ-1): regular readings
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-A', location = 'hq', temperature = 22.1, humidity = 55.0, pressure = 1013.2
INSERT INTO SensorReading SET ts = 1771582500000, sensor_id = 's-A', location = 'hq', temperature = 22.3, humidity = 55.2, pressure = 1013.1
INSERT INTO SensorReading SET ts = 1771583400000, sensor_id = 's-A', location = 'hq', temperature = 22.5, humidity = 55.5, pressure = 1013.0
INSERT INTO SensorReading SET ts = 1771584300000, sensor_id = 's-A', location = 'hq', temperature = 23.0, humidity = 56.0, pressure = 1012.9
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-A', location = 'hq', temperature = 23.2, humidity = 56.3, pressure = 1012.8
INSERT INTO SensorReading SET ts = 1771586100000, sensor_id = 's-A', location = 'hq', temperature = 23.8, humidity = 57.0, pressure = 1012.7
INSERT INTO SensorReading SET ts = 1771587000000, sensor_id = 's-A', location = 'hq', temperature = 24.1, humidity = 57.5, pressure = 1012.6
-- s-B (HQ-1)
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-B', location = 'hq', temperature = 21.8, humidity = 54.0, pressure = 1013.3
INSERT INTO SensorReading SET ts = 1771583400000, sensor_id = 's-B', location = 'hq', temperature = 22.0, humidity = 54.5, pressure = 1013.1
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-B', location = 'hq', temperature = 22.5, humidity = 55.0, pressure = 1012.9
-- s-C (HQ-2): deliberate gap between 10:15 and 11:00 for interpolation query
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-C', location = 'hq', temperature = 23.0, humidity = 58.0, pressure = 1013.0
INSERT INTO SensorReading SET ts = 1771582500000, sensor_id = 's-C', location = 'hq', temperature = 23.2, humidity = 58.2, pressure = 1012.9
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-C', location = 'hq', temperature = 25.0, humidity = 60.0, pressure = 1012.5
INSERT INTO SensorReading SET ts = 1771587000000, sensor_id = 's-C', location = 'hq', temperature = 25.5, humidity = 61.0, pressure = 1012.3
-- s-D (DC-1)
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-D', location = 'dc', temperature = 19.0, humidity = 45.0, pressure = 1014.0
INSERT INTO SensorReading SET ts = 1771583400000, sensor_id = 's-D', location = 'dc', temperature = 19.2, humidity = 45.5, pressure = 1013.9
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-D', location = 'dc', temperature = 19.5, humidity = 46.0, pressure = 1013.8
-- s-E (DC-1)
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-E', location = 'dc', temperature = 18.5, humidity = 44.0, pressure = 1014.1
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-E', location = 'dc', temperature = 18.8, humidity = 44.5, pressure = 1014.0
-- s-F (DC-2)
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-F', location = 'dc', temperature = 20.0, humidity = 48.0, pressure = 1013.5
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-F', location = 'dc', temperature = 20.5, humidity = 48.5, pressure = 1013.3
-- ServiceMetrics time-series data (same 2-hour window)
-- api-gateway on srv-1: high traffic
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 15000, error_count = 12, latency_ms = 45.2
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 15500, error_count = 8, latency_ms = 42.1
INSERT INTO ServiceMetrics SET ts = 1771582200000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 16200, error_count = 15, latency_ms = 48.7
-- auth-service on srv-1
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8000, error_count = 3, latency_ms = 22.0
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8200, error_count = 2, latency_ms = 21.5
-- user-service on srv-2
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'user-service', server_id = 'srv-2', request_count = 5000, error_count = 5, latency_ms = 35.0
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'user-service', server_id = 'srv-2', request_count = 5200, error_count = 4, latency_ms = 33.8
INSERT INTO ServiceMetrics SET ts = 1771582200000, service_id = 'user-service', server_id = 'srv-2', request_count = 5100, error_count = 6, latency_ms = 36.5
-- payment-service on srv-2: some errors
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2000, error_count = 25, latency_ms = 120.5
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2100, error_count = 30, latency_ms = 135.2
INSERT INTO ServiceMetrics SET ts = 1771582200000, service_id = 'payment-service', server_id = 'srv-2', request_count = 1800, error_count = 45, latency_ms = 180.0
-- notification-service on srv-3
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3000, error_count = 1, latency_ms = 15.0
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3100, error_count = 0, latency_ms = 14.5
