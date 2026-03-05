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
-- SensorReading time-series data (2-hour window, 10-min intervals)
-- Timestamps are epoch milliseconds for 2026-02-20 (ts column is LONG)
-- 10:00 = 1771581600000, +10min = +600000
-- s-A (HQ-1): gradual warming 22.1 -> 24.5
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-A', location = 'hq', temperature = 22.1, humidity = 55.0, pressure = 1013.2
INSERT INTO SensorReading SET ts = 1771582200000, sensor_id = 's-A', location = 'hq', temperature = 22.2, humidity = 55.1, pressure = 1013.2
INSERT INTO SensorReading SET ts = 1771582800000, sensor_id = 's-A', location = 'hq', temperature = 22.3, humidity = 55.2, pressure = 1013.1
INSERT INTO SensorReading SET ts = 1771583400000, sensor_id = 's-A', location = 'hq', temperature = 22.5, humidity = 55.5, pressure = 1013.0
INSERT INTO SensorReading SET ts = 1771584000000, sensor_id = 's-A', location = 'hq', temperature = 22.8, humidity = 55.7, pressure = 1013.0
INSERT INTO SensorReading SET ts = 1771584600000, sensor_id = 's-A', location = 'hq', temperature = 23.0, humidity = 56.0, pressure = 1012.9
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-A', location = 'hq', temperature = 23.2, humidity = 56.3, pressure = 1012.8
INSERT INTO SensorReading SET ts = 1771585800000, sensor_id = 's-A', location = 'hq', temperature = 23.5, humidity = 56.6, pressure = 1012.8
INSERT INTO SensorReading SET ts = 1771586400000, sensor_id = 's-A', location = 'hq', temperature = 23.8, humidity = 57.0, pressure = 1012.7
INSERT INTO SensorReading SET ts = 1771587000000, sensor_id = 's-A', location = 'hq', temperature = 24.1, humidity = 57.5, pressure = 1012.6
INSERT INTO SensorReading SET ts = 1771587600000, sensor_id = 's-A', location = 'hq', temperature = 24.3, humidity = 57.8, pressure = 1012.5
INSERT INTO SensorReading SET ts = 1771588200000, sensor_id = 's-A', location = 'hq', temperature = 24.5, humidity = 58.0, pressure = 1012.5
-- s-B (HQ-1): similar to s-A, slightly lower 21.8 -> 23.8
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-B', location = 'hq', temperature = 21.8, humidity = 54.0, pressure = 1013.3
INSERT INTO SensorReading SET ts = 1771582200000, sensor_id = 's-B', location = 'hq', temperature = 21.9, humidity = 54.1, pressure = 1013.3
INSERT INTO SensorReading SET ts = 1771582800000, sensor_id = 's-B', location = 'hq', temperature = 22.0, humidity = 54.3, pressure = 1013.2
INSERT INTO SensorReading SET ts = 1771583400000, sensor_id = 's-B', location = 'hq', temperature = 22.0, humidity = 54.5, pressure = 1013.1
INSERT INTO SensorReading SET ts = 1771584000000, sensor_id = 's-B', location = 'hq', temperature = 22.3, humidity = 54.7, pressure = 1013.1
INSERT INTO SensorReading SET ts = 1771584600000, sensor_id = 's-B', location = 'hq', temperature = 22.5, humidity = 55.0, pressure = 1013.0
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-B', location = 'hq', temperature = 22.5, humidity = 55.0, pressure = 1012.9
INSERT INTO SensorReading SET ts = 1771585800000, sensor_id = 's-B', location = 'hq', temperature = 22.8, humidity = 55.3, pressure = 1012.9
INSERT INTO SensorReading SET ts = 1771586400000, sensor_id = 's-B', location = 'hq', temperature = 23.1, humidity = 55.6, pressure = 1012.8
INSERT INTO SensorReading SET ts = 1771587000000, sensor_id = 's-B', location = 'hq', temperature = 23.3, humidity = 55.8, pressure = 1012.7
INSERT INTO SensorReading SET ts = 1771587600000, sensor_id = 's-B', location = 'hq', temperature = 23.5, humidity = 56.0, pressure = 1012.7
INSERT INTO SensorReading SET ts = 1771588200000, sensor_id = 's-B', location = 'hq', temperature = 23.8, humidity = 56.3, pressure = 1012.6
-- s-C (HQ-2): deliberate gap between 10:20 and 11:00 for interpolation query
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-C', location = 'hq', temperature = 23.0, humidity = 58.0, pressure = 1013.0
INSERT INTO SensorReading SET ts = 1771582200000, sensor_id = 's-C', location = 'hq', temperature = 23.1, humidity = 58.1, pressure = 1013.0
INSERT INTO SensorReading SET ts = 1771582800000, sensor_id = 's-C', location = 'hq', temperature = 23.2, humidity = 58.2, pressure = 1012.9
-- gap: no readings at 10:30, 10:40, 10:50
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-C', location = 'hq', temperature = 25.0, humidity = 60.0, pressure = 1012.5
INSERT INTO SensorReading SET ts = 1771585800000, sensor_id = 's-C', location = 'hq', temperature = 25.2, humidity = 60.3, pressure = 1012.4
INSERT INTO SensorReading SET ts = 1771586400000, sensor_id = 's-C', location = 'hq', temperature = 25.3, humidity = 60.5, pressure = 1012.4
INSERT INTO SensorReading SET ts = 1771587000000, sensor_id = 's-C', location = 'hq', temperature = 25.5, humidity = 61.0, pressure = 1012.3
INSERT INTO SensorReading SET ts = 1771587600000, sensor_id = 's-C', location = 'hq', temperature = 25.8, humidity = 61.3, pressure = 1012.2
INSERT INTO SensorReading SET ts = 1771588200000, sensor_id = 's-C', location = 'hq', temperature = 26.0, humidity = 61.5, pressure = 1012.2
-- s-D (DC-1): cooler, stable 19.0 -> 20.0
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-D', location = 'dc', temperature = 19.0, humidity = 45.0, pressure = 1014.0
INSERT INTO SensorReading SET ts = 1771582200000, sensor_id = 's-D', location = 'dc', temperature = 19.0, humidity = 45.1, pressure = 1014.0
INSERT INTO SensorReading SET ts = 1771582800000, sensor_id = 's-D', location = 'dc', temperature = 19.1, humidity = 45.2, pressure = 1014.0
INSERT INTO SensorReading SET ts = 1771583400000, sensor_id = 's-D', location = 'dc', temperature = 19.2, humidity = 45.5, pressure = 1013.9
INSERT INTO SensorReading SET ts = 1771584000000, sensor_id = 's-D', location = 'dc', temperature = 19.3, humidity = 45.6, pressure = 1013.9
INSERT INTO SensorReading SET ts = 1771584600000, sensor_id = 's-D', location = 'dc', temperature = 19.4, humidity = 45.7, pressure = 1013.9
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-D', location = 'dc', temperature = 19.5, humidity = 46.0, pressure = 1013.8
INSERT INTO SensorReading SET ts = 1771585800000, sensor_id = 's-D', location = 'dc', temperature = 19.6, humidity = 46.1, pressure = 1013.8
INSERT INTO SensorReading SET ts = 1771586400000, sensor_id = 's-D', location = 'dc', temperature = 19.7, humidity = 46.3, pressure = 1013.8
INSERT INTO SensorReading SET ts = 1771587000000, sensor_id = 's-D', location = 'dc', temperature = 19.8, humidity = 46.5, pressure = 1013.7
INSERT INTO SensorReading SET ts = 1771587600000, sensor_id = 's-D', location = 'dc', temperature = 19.9, humidity = 46.6, pressure = 1013.7
INSERT INTO SensorReading SET ts = 1771588200000, sensor_id = 's-D', location = 'dc', temperature = 20.0, humidity = 46.8, pressure = 1013.7
-- s-E (DC-1): coolest, 18.5 -> 19.5
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-E', location = 'dc', temperature = 18.5, humidity = 44.0, pressure = 1014.1
INSERT INTO SensorReading SET ts = 1771582200000, sensor_id = 's-E', location = 'dc', temperature = 18.5, humidity = 44.0, pressure = 1014.1
INSERT INTO SensorReading SET ts = 1771582800000, sensor_id = 's-E', location = 'dc', temperature = 18.6, humidity = 44.1, pressure = 1014.1
INSERT INTO SensorReading SET ts = 1771583400000, sensor_id = 's-E', location = 'dc', temperature = 18.7, humidity = 44.2, pressure = 1014.0
INSERT INTO SensorReading SET ts = 1771584000000, sensor_id = 's-E', location = 'dc', temperature = 18.7, humidity = 44.3, pressure = 1014.0
INSERT INTO SensorReading SET ts = 1771584600000, sensor_id = 's-E', location = 'dc', temperature = 18.8, humidity = 44.3, pressure = 1014.0
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-E', location = 'dc', temperature = 18.8, humidity = 44.5, pressure = 1014.0
INSERT INTO SensorReading SET ts = 1771585800000, sensor_id = 's-E', location = 'dc', temperature = 18.9, humidity = 44.5, pressure = 1013.9
INSERT INTO SensorReading SET ts = 1771586400000, sensor_id = 's-E', location = 'dc', temperature = 19.0, humidity = 44.6, pressure = 1013.9
INSERT INTO SensorReading SET ts = 1771587000000, sensor_id = 's-E', location = 'dc', temperature = 19.1, humidity = 44.8, pressure = 1013.9
INSERT INTO SensorReading SET ts = 1771587600000, sensor_id = 's-E', location = 'dc', temperature = 19.3, humidity = 44.9, pressure = 1013.8
INSERT INTO SensorReading SET ts = 1771588200000, sensor_id = 's-E', location = 'dc', temperature = 19.5, humidity = 45.0, pressure = 1013.8
-- s-F (DC-2): 20.0 -> 21.5
INSERT INTO SensorReading SET ts = 1771581600000, sensor_id = 's-F', location = 'dc', temperature = 20.0, humidity = 48.0, pressure = 1013.5
INSERT INTO SensorReading SET ts = 1771582200000, sensor_id = 's-F', location = 'dc', temperature = 20.1, humidity = 48.1, pressure = 1013.5
INSERT INTO SensorReading SET ts = 1771582800000, sensor_id = 's-F', location = 'dc', temperature = 20.1, humidity = 48.2, pressure = 1013.5
INSERT INTO SensorReading SET ts = 1771583400000, sensor_id = 's-F', location = 'dc', temperature = 20.2, humidity = 48.3, pressure = 1013.4
INSERT INTO SensorReading SET ts = 1771584000000, sensor_id = 's-F', location = 'dc', temperature = 20.4, humidity = 48.4, pressure = 1013.4
INSERT INTO SensorReading SET ts = 1771584600000, sensor_id = 's-F', location = 'dc', temperature = 20.5, humidity = 48.5, pressure = 1013.3
INSERT INTO SensorReading SET ts = 1771585200000, sensor_id = 's-F', location = 'dc', temperature = 20.5, humidity = 48.5, pressure = 1013.3
INSERT INTO SensorReading SET ts = 1771585800000, sensor_id = 's-F', location = 'dc', temperature = 20.7, humidity = 48.7, pressure = 1013.2
INSERT INTO SensorReading SET ts = 1771586400000, sensor_id = 's-F', location = 'dc', temperature = 20.9, humidity = 48.9, pressure = 1013.2
INSERT INTO SensorReading SET ts = 1771587000000, sensor_id = 's-F', location = 'dc', temperature = 21.0, humidity = 49.0, pressure = 1013.1
INSERT INTO SensorReading SET ts = 1771587600000, sensor_id = 's-F', location = 'dc', temperature = 21.2, humidity = 49.2, pressure = 1013.1
INSERT INTO SensorReading SET ts = 1771588200000, sensor_id = 's-F', location = 'dc', temperature = 21.5, humidity = 49.5, pressure = 1013.0
-- ServiceMetrics time-series data (same 2-hour window, 5-min intervals)
-- api-gateway on srv-1: high traffic, steady growth
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 15000, error_count = 12, latency_ms = 45.2
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 15500, error_count = 8, latency_ms = 42.1
INSERT INTO ServiceMetrics SET ts = 1771582200000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 16200, error_count = 15, latency_ms = 48.7
INSERT INTO ServiceMetrics SET ts = 1771582500000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 16800, error_count = 10, latency_ms = 44.5
INSERT INTO ServiceMetrics SET ts = 1771582800000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 17100, error_count = 9, latency_ms = 43.2
INSERT INTO ServiceMetrics SET ts = 1771583100000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 17500, error_count = 11, latency_ms = 46.1
INSERT INTO ServiceMetrics SET ts = 1771583400000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 18000, error_count = 14, latency_ms = 47.8
INSERT INTO ServiceMetrics SET ts = 1771583700000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 18200, error_count = 7, latency_ms = 41.0
INSERT INTO ServiceMetrics SET ts = 1771584000000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 18500, error_count = 13, latency_ms = 46.5
INSERT INTO ServiceMetrics SET ts = 1771584300000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 19000, error_count = 16, latency_ms = 50.2
INSERT INTO ServiceMetrics SET ts = 1771584600000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 19200, error_count = 10, latency_ms = 44.8
INSERT INTO ServiceMetrics SET ts = 1771584900000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 19500, error_count = 12, latency_ms = 45.5
INSERT INTO ServiceMetrics SET ts = 1771585200000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 20000, error_count = 18, latency_ms = 52.0
INSERT INTO ServiceMetrics SET ts = 1771585500000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 20500, error_count = 11, latency_ms = 47.3
INSERT INTO ServiceMetrics SET ts = 1771585800000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 20800, error_count = 9, latency_ms = 43.9
INSERT INTO ServiceMetrics SET ts = 1771586100000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 21000, error_count = 14, latency_ms = 48.1
INSERT INTO ServiceMetrics SET ts = 1771586400000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 21500, error_count = 10, latency_ms = 44.0
INSERT INTO ServiceMetrics SET ts = 1771586700000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 21800, error_count = 8, latency_ms = 42.5
INSERT INTO ServiceMetrics SET ts = 1771587000000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 22000, error_count = 15, latency_ms = 49.0
INSERT INTO ServiceMetrics SET ts = 1771587300000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 22200, error_count = 12, latency_ms = 46.0
INSERT INTO ServiceMetrics SET ts = 1771587600000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 22500, error_count = 9, latency_ms = 43.5
INSERT INTO ServiceMetrics SET ts = 1771587900000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 22800, error_count = 11, latency_ms = 45.0
INSERT INTO ServiceMetrics SET ts = 1771588200000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 23000, error_count = 13, latency_ms = 47.0
INSERT INTO ServiceMetrics SET ts = 1771588500000, service_id = 'api-gateway', server_id = 'srv-1', request_count = 23500, error_count = 10, latency_ms = 44.2
-- auth-service on srv-1: moderate traffic
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8000, error_count = 3, latency_ms = 22.0
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8200, error_count = 2, latency_ms = 21.5
INSERT INTO ServiceMetrics SET ts = 1771582200000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8100, error_count = 4, latency_ms = 23.0
INSERT INTO ServiceMetrics SET ts = 1771582500000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8400, error_count = 2, latency_ms = 21.0
INSERT INTO ServiceMetrics SET ts = 1771582800000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8500, error_count = 3, latency_ms = 22.5
INSERT INTO ServiceMetrics SET ts = 1771583100000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8600, error_count = 1, latency_ms = 20.8
INSERT INTO ServiceMetrics SET ts = 1771583400000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8800, error_count = 3, latency_ms = 22.2
INSERT INTO ServiceMetrics SET ts = 1771583700000, service_id = 'auth-service', server_id = 'srv-1', request_count = 8900, error_count = 2, latency_ms = 21.0
INSERT INTO ServiceMetrics SET ts = 1771584000000, service_id = 'auth-service', server_id = 'srv-1', request_count = 9000, error_count = 4, latency_ms = 23.5
INSERT INTO ServiceMetrics SET ts = 1771584300000, service_id = 'auth-service', server_id = 'srv-1', request_count = 9200, error_count = 2, latency_ms = 21.8
INSERT INTO ServiceMetrics SET ts = 1771584600000, service_id = 'auth-service', server_id = 'srv-1', request_count = 9300, error_count = 3, latency_ms = 22.0
INSERT INTO ServiceMetrics SET ts = 1771584900000, service_id = 'auth-service', server_id = 'srv-1', request_count = 9500, error_count = 1, latency_ms = 20.5
INSERT INTO ServiceMetrics SET ts = 1771585200000, service_id = 'auth-service', server_id = 'srv-1', request_count = 9500, error_count = 5, latency_ms = 24.0
INSERT INTO ServiceMetrics SET ts = 1771585800000, service_id = 'auth-service', server_id = 'srv-1', request_count = 9800, error_count = 2, latency_ms = 21.5
INSERT INTO ServiceMetrics SET ts = 1771586400000, service_id = 'auth-service', server_id = 'srv-1', request_count = 10000, error_count = 3, latency_ms = 22.8
INSERT INTO ServiceMetrics SET ts = 1771587000000, service_id = 'auth-service', server_id = 'srv-1', request_count = 10200, error_count = 2, latency_ms = 21.2
INSERT INTO ServiceMetrics SET ts = 1771587600000, service_id = 'auth-service', server_id = 'srv-1', request_count = 10500, error_count = 1, latency_ms = 20.5
INSERT INTO ServiceMetrics SET ts = 1771588200000, service_id = 'auth-service', server_id = 'srv-1', request_count = 10800, error_count = 3, latency_ms = 22.0
-- user-service on srv-2: moderate traffic
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'user-service', server_id = 'srv-2', request_count = 5000, error_count = 5, latency_ms = 35.0
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'user-service', server_id = 'srv-2', request_count = 5200, error_count = 4, latency_ms = 33.8
INSERT INTO ServiceMetrics SET ts = 1771582200000, service_id = 'user-service', server_id = 'srv-2', request_count = 5100, error_count = 6, latency_ms = 36.5
INSERT INTO ServiceMetrics SET ts = 1771582500000, service_id = 'user-service', server_id = 'srv-2', request_count = 5300, error_count = 3, latency_ms = 32.0
INSERT INTO ServiceMetrics SET ts = 1771582800000, service_id = 'user-service', server_id = 'srv-2', request_count = 5400, error_count = 5, latency_ms = 34.5
INSERT INTO ServiceMetrics SET ts = 1771583100000, service_id = 'user-service', server_id = 'srv-2', request_count = 5500, error_count = 4, latency_ms = 33.2
INSERT INTO ServiceMetrics SET ts = 1771583400000, service_id = 'user-service', server_id = 'srv-2', request_count = 5600, error_count = 6, latency_ms = 36.0
INSERT INTO ServiceMetrics SET ts = 1771583700000, service_id = 'user-service', server_id = 'srv-2', request_count = 5700, error_count = 3, latency_ms = 32.5
INSERT INTO ServiceMetrics SET ts = 1771584000000, service_id = 'user-service', server_id = 'srv-2', request_count = 5800, error_count = 5, latency_ms = 35.2
INSERT INTO ServiceMetrics SET ts = 1771584300000, service_id = 'user-service', server_id = 'srv-2', request_count = 5900, error_count = 4, latency_ms = 33.8
INSERT INTO ServiceMetrics SET ts = 1771584600000, service_id = 'user-service', server_id = 'srv-2', request_count = 6000, error_count = 7, latency_ms = 37.0
INSERT INTO ServiceMetrics SET ts = 1771584900000, service_id = 'user-service', server_id = 'srv-2', request_count = 6100, error_count = 3, latency_ms = 32.0
INSERT INTO ServiceMetrics SET ts = 1771585200000, service_id = 'user-service', server_id = 'srv-2', request_count = 6200, error_count = 5, latency_ms = 35.5
INSERT INTO ServiceMetrics SET ts = 1771585800000, service_id = 'user-service', server_id = 'srv-2', request_count = 6400, error_count = 4, latency_ms = 34.0
INSERT INTO ServiceMetrics SET ts = 1771586400000, service_id = 'user-service', server_id = 'srv-2', request_count = 6600, error_count = 6, latency_ms = 36.8
INSERT INTO ServiceMetrics SET ts = 1771587000000, service_id = 'user-service', server_id = 'srv-2', request_count = 6800, error_count = 4, latency_ms = 33.5
INSERT INTO ServiceMetrics SET ts = 1771587600000, service_id = 'user-service', server_id = 'srv-2', request_count = 7000, error_count = 5, latency_ms = 35.0
INSERT INTO ServiceMetrics SET ts = 1771588200000, service_id = 'user-service', server_id = 'srv-2', request_count = 7200, error_count = 3, latency_ms = 32.5
-- payment-service on srv-2: lower traffic, rising errors and latency
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2000, error_count = 25, latency_ms = 120.5
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2100, error_count = 30, latency_ms = 135.2
INSERT INTO ServiceMetrics SET ts = 1771582200000, service_id = 'payment-service', server_id = 'srv-2', request_count = 1800, error_count = 45, latency_ms = 180.0
INSERT INTO ServiceMetrics SET ts = 1771582500000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2200, error_count = 28, latency_ms = 125.0
INSERT INTO ServiceMetrics SET ts = 1771582800000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2300, error_count = 35, latency_ms = 145.0
INSERT INTO ServiceMetrics SET ts = 1771583100000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2100, error_count = 40, latency_ms = 160.5
INSERT INTO ServiceMetrics SET ts = 1771583400000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2400, error_count = 32, latency_ms = 138.0
INSERT INTO ServiceMetrics SET ts = 1771583700000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2500, error_count = 38, latency_ms = 155.0
INSERT INTO ServiceMetrics SET ts = 1771584000000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2300, error_count = 42, latency_ms = 170.0
INSERT INTO ServiceMetrics SET ts = 1771584300000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2600, error_count = 35, latency_ms = 142.5
INSERT INTO ServiceMetrics SET ts = 1771584600000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2700, error_count = 48, latency_ms = 185.0
INSERT INTO ServiceMetrics SET ts = 1771584900000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2500, error_count = 50, latency_ms = 195.0
INSERT INTO ServiceMetrics SET ts = 1771585200000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2800, error_count = 40, latency_ms = 158.0
INSERT INTO ServiceMetrics SET ts = 1771585800000, service_id = 'payment-service', server_id = 'srv-2', request_count = 2900, error_count = 35, latency_ms = 140.0
INSERT INTO ServiceMetrics SET ts = 1771586400000, service_id = 'payment-service', server_id = 'srv-2', request_count = 3000, error_count = 30, latency_ms = 130.0
INSERT INTO ServiceMetrics SET ts = 1771587000000, service_id = 'payment-service', server_id = 'srv-2', request_count = 3100, error_count = 28, latency_ms = 125.0
INSERT INTO ServiceMetrics SET ts = 1771587600000, service_id = 'payment-service', server_id = 'srv-2', request_count = 3200, error_count = 25, latency_ms = 118.0
INSERT INTO ServiceMetrics SET ts = 1771588200000, service_id = 'payment-service', server_id = 'srv-2', request_count = 3300, error_count = 22, latency_ms = 110.0
-- notification-service on srv-3: low traffic, stable
INSERT INTO ServiceMetrics SET ts = 1771581600000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3000, error_count = 1, latency_ms = 15.0
INSERT INTO ServiceMetrics SET ts = 1771581900000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3100, error_count = 0, latency_ms = 14.5
INSERT INTO ServiceMetrics SET ts = 1771582200000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3050, error_count = 1, latency_ms = 15.2
INSERT INTO ServiceMetrics SET ts = 1771582500000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3200, error_count = 0, latency_ms = 14.0
INSERT INTO ServiceMetrics SET ts = 1771582800000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3150, error_count = 1, latency_ms = 15.5
INSERT INTO ServiceMetrics SET ts = 1771583100000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3300, error_count = 0, latency_ms = 14.2
INSERT INTO ServiceMetrics SET ts = 1771583400000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3250, error_count = 2, latency_ms = 16.0
INSERT INTO ServiceMetrics SET ts = 1771583700000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3400, error_count = 0, latency_ms = 13.8
INSERT INTO ServiceMetrics SET ts = 1771584000000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3350, error_count = 1, latency_ms = 15.0
INSERT INTO ServiceMetrics SET ts = 1771584300000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3500, error_count = 0, latency_ms = 14.5
INSERT INTO ServiceMetrics SET ts = 1771584600000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3450, error_count = 1, latency_ms = 15.8
INSERT INTO ServiceMetrics SET ts = 1771584900000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3600, error_count = 0, latency_ms = 14.0
INSERT INTO ServiceMetrics SET ts = 1771585200000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3550, error_count = 1, latency_ms = 15.2
INSERT INTO ServiceMetrics SET ts = 1771585800000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3700, error_count = 0, latency_ms = 14.2
INSERT INTO ServiceMetrics SET ts = 1771586400000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3800, error_count = 1, latency_ms = 15.0
INSERT INTO ServiceMetrics SET ts = 1771587000000, service_id = 'notification-service', server_id = 'srv-3', request_count = 3900, error_count = 0, latency_ms = 14.5
INSERT INTO ServiceMetrics SET ts = 1771587600000, service_id = 'notification-service', server_id = 'srv-3', request_count = 4000, error_count = 1, latency_ms = 15.5
INSERT INTO ServiceMetrics SET ts = 1771588200000, service_id = 'notification-service', server_id = 'srv-3', request_count = 4100, error_count = 0, latency_ms = 14.0
