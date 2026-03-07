-- Customers (6) with 8D vectors
INSERT INTO Customer SET id = 'c1', name = 'Alice Smith', email = 'alice@example.com', phone = '555-0101', status = 'active', prefVector = [0.9, 0.1, 0.2, 0.1, 0.3, 0.8, 0.1, 0.2], recentBehavior = [0.8, 0.2, 0.3, 0.1, 0.4, 0.7, 0.2, 0.3], baselineBehavior = [0.8, 0.2, 0.3, 0.1, 0.4, 0.7, 0.2, 0.3], lifetimeValue = 4500.00;
INSERT INTO Customer SET id = 'c2', name = 'Bob Smith', email = 'bob@example.com', phone = '555-0102', status = 'active', prefVector = [0.8, 0.2, 0.3, 0.1, 0.2, 0.7, 0.2, 0.3], recentBehavior = [0.7, 0.3, 0.2, 0.2, 0.3, 0.6, 0.3, 0.2], baselineBehavior = [0.7, 0.3, 0.2, 0.2, 0.3, 0.6, 0.3, 0.2], lifetimeValue = 3200.00;
INSERT INTO Customer SET id = 'c3', name = 'Carol Johnson', email = 'carol@example.com', phone = '555-0103', status = 'active', prefVector = [0.2, 0.8, 0.1, 0.3, 0.7, 0.2, 0.1, 0.4], recentBehavior = [0.9, 0.1, 0.8, 0.7, 0.1, 0.9, 0.8, 0.1], baselineBehavior = [0.2, 0.8, 0.1, 0.3, 0.7, 0.2, 0.1, 0.4], lifetimeValue = 2800.00;
INSERT INTO Customer SET id = 'c4', name = 'Dave Johnson', email = 'dave@example.com', phone = '555-0104', status = 'churned', prefVector = [0.3, 0.7, 0.2, 0.4, 0.6, 0.3, 0.2, 0.3], recentBehavior = [0.3, 0.7, 0.2, 0.4, 0.6, 0.3, 0.2, 0.3], baselineBehavior = [0.3, 0.7, 0.2, 0.4, 0.6, 0.3, 0.2, 0.3], lifetimeValue = 1500.00;
INSERT INTO Customer SET id = 'c5', name = 'Alicia Smith', email = 'alicia.s@example.com', phone = '555-0101', status = 'active', prefVector = [0.9, 0.1, 0.1, 0.2, 0.3, 0.8, 0.1, 0.1], recentBehavior = [0.8, 0.2, 0.2, 0.1, 0.4, 0.7, 0.1, 0.2], baselineBehavior = [0.8, 0.2, 0.2, 0.1, 0.4, 0.7, 0.1, 0.2], lifetimeValue = 4200.00;
INSERT INTO Customer SET id = 'c6', name = 'Frank Lee', email = 'frank@example.com', phone = '555-0106', status = 'churned', prefVector = [0.1, 0.2, 0.8, 0.7, 0.1, 0.3, 0.6, 0.2], recentBehavior = [0.1, 0.2, 0.8, 0.7, 0.1, 0.3, 0.6, 0.2], baselineBehavior = [0.1, 0.2, 0.8, 0.7, 0.1, 0.3, 0.6, 0.2], lifetimeValue = 800.00;
-- Households (2)
INSERT INTO Household SET id = 'h1', name = 'Smith Family';
INSERT INTO Household SET id = 'h2', name = 'Johnson Family';
-- Products (6) with 8D embeddings
INSERT INTO Product SET id = 'p1', name = 'Laptop Pro', category = 'Electronics', price = 1299.99, embedding = [0.9, 0.1, 0.2, 0.1, 0.3, 0.8, 0.1, 0.2];
INSERT INTO Product SET id = 'p2', name = 'Wireless Earbuds', category = 'Electronics', price = 149.99, embedding = [0.8, 0.2, 0.3, 0.1, 0.2, 0.7, 0.2, 0.3];
INSERT INTO Product SET id = 'p3', name = 'Trail Boots', category = 'Outdoor', price = 189.99, embedding = [0.2, 0.8, 0.1, 0.3, 0.7, 0.2, 0.1, 0.4];
INSERT INTO Product SET id = 'p4', name = 'Camping Tent', category = 'Outdoor', price = 299.99, embedding = [0.1, 0.9, 0.2, 0.2, 0.6, 0.3, 0.1, 0.5];
INSERT INTO Product SET id = 'p5', name = 'Smart Watch', category = 'Electronics', price = 399.99, embedding = [0.7, 0.2, 0.3, 0.2, 0.4, 0.6, 0.2, 0.3];
INSERT INTO Product SET id = 'p6', name = 'Hiking Backpack', category = 'Outdoor', price = 89.99, embedding = [0.2, 0.7, 0.2, 0.3, 0.6, 0.2, 0.2, 0.4];
-- Devices (3)
INSERT INTO Device SET id = 'd1', deviceType = 'mobile', os = 'iOS';
INSERT INTO Device SET id = 'd2', deviceType = 'desktop', os = 'Windows';
INSERT INTO Device SET id = 'd3', deviceType = 'tablet', os = 'Android';
-- Addresses (3)
INSERT INTO Address SET id = 'a1', street = '123 Main St', city = 'Springfield', state = 'IL', zip = '62701';
INSERT INTO Address SET id = 'a2', street = '456 Oak Ave', city = 'Springfield', state = 'IL', zip = '62702';
INSERT INTO Address SET id = 'a3', street = '789 Pine Rd', city = 'Chicago', state = 'IL', zip = '60601';
-- Tickets (3): one open, two closed
INSERT INTO Ticket SET id = 't1', subject = 'Cannot access account', status = 'open', content = 'I have been unable to log into my account since yesterday. I tried resetting my password but the email never arrived.', createdAt = '2026-03-01 10:00:00';
INSERT INTO Ticket SET id = 't2', subject = 'Order delayed', status = 'closed', content = 'My order for the laptop was supposed to arrive last week but tracking shows it is still in transit.', createdAt = '2026-02-15 14:30:00';
INSERT INTO Ticket SET id = 't3', subject = 'Product recommendation', status = 'closed', content = 'Looking for a good hiking backpack recommendation for weekend trips in the mountains.', createdAt = '2026-02-20 09:15:00';
-- Campaigns (2)
INSERT INTO Campaign SET id = 'camp1', name = 'Spring Electronics Sale', channel = 'email';
INSERT INTO Campaign SET id = 'camp2', name = 'Outdoor Adventure Week', channel = 'social';
-- Sessions (3) for identity resolution
INSERT INTO Session SET id = 's1', startedAt = '2026-03-01 08:00:00';
INSERT INTO Session SET id = 's2', startedAt = '2026-03-02 12:00:00';
INSERT INTO Session SET id = 's3', startedAt = '2026-03-03 18:00:00';
-- Identifiers (6) for c1 identity resolution
INSERT INTO Identifier SET id = 'id1', identifierType = 'email', identifierValue = 'alice@example.com';
INSERT INTO Identifier SET id = 'id2', identifierType = 'phone', identifierValue = '555-0101';
INSERT INTO Identifier SET id = 'id3', identifierType = 'cookie', identifierValue = 'cookie_abc123';
INSERT INTO Identifier SET id = 'id4', identifierType = 'loyaltyNumber', identifierValue = 'LYL-90001';
INSERT INTO Identifier SET id = 'id5', identifierType = 'cookie', identifierValue = 'cookie_xyz789';
INSERT INTO Identifier SET id = 'id6', identifierType = 'deviceId', identifierValue = 'device_id_001';
-- Events for journey path analysis (3 conversion paths)
-- Path 1: google ad -> landing-a -> purchase (c1)
INSERT INTO Event SET id = 'e1', eventType = 'ad_click', channel = 'google', page = '', recordedAt = '2026-03-01 09:00:00';
INSERT INTO Event SET id = 'e2', eventType = 'page_view', channel = 'web', page = 'landing-a', recordedAt = '2026-03-01 09:05:00';
INSERT INTO Event SET id = 'e3', eventType = 'purchase', channel = 'web', page = 'checkout', recordedAt = '2026-03-01 09:20:00';
-- Path 2: facebook ad -> landing-b -> purchase (c2)
INSERT INTO Event SET id = 'e4', eventType = 'ad_click', channel = 'facebook', page = '', recordedAt = '2026-03-02 10:00:00';
INSERT INTO Event SET id = 'e5', eventType = 'page_view', channel = 'web', page = 'landing-b', recordedAt = '2026-03-02 10:03:00';
INSERT INTO Event SET id = 'e6', eventType = 'purchase', channel = 'web', page = 'checkout', recordedAt = '2026-03-02 10:25:00';
-- Path 3: google ad -> landing-a -> purchase (c3)
INSERT INTO Event SET id = 'e7', eventType = 'ad_click', channel = 'google', page = '', recordedAt = '2026-03-03 11:00:00';
INSERT INTO Event SET id = 'e8', eventType = 'page_view', channel = 'web', page = 'landing-a', recordedAt = '2026-03-03 11:02:00';
INSERT INTO Event SET id = 'e9', eventType = 'purchase', channel = 'web', page = 'checkout', recordedAt = '2026-03-03 11:30:00';
-- MEMBER_OF edges (household membership)
CREATE EDGE MEMBER_OF FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Household WHERE id = 'h1');
CREATE EDGE MEMBER_OF FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Household WHERE id = 'h1');
CREATE EDGE MEMBER_OF FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Household WHERE id = 'h2');
CREATE EDGE MEMBER_OF FROM (SELECT FROM Customer WHERE id = 'c4') TO (SELECT FROM Household WHERE id = 'h2');
-- PURCHASED edges (with dates)
CREATE EDGE PURCHASED SET purchasedAt = '2026-02-01 10:00:00' FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Product WHERE id = 'p1');
CREATE EDGE PURCHASED SET purchasedAt = '2026-02-10 14:00:00' FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Product WHERE id = 'p2');
CREATE EDGE PURCHASED SET purchasedAt = '2026-02-05 11:00:00' FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Product WHERE id = 'p1');
CREATE EDGE PURCHASED SET purchasedAt = '2026-02-12 16:00:00' FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Product WHERE id = 'p2');
CREATE EDGE PURCHASED SET purchasedAt = '2026-02-20 09:00:00' FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Product WHERE id = 'p5');
CREATE EDGE PURCHASED SET purchasedAt = '2026-01-15 10:00:00' FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Product WHERE id = 'p3');
CREATE EDGE PURCHASED SET purchasedAt = '2026-01-20 11:00:00' FROM (SELECT FROM Customer WHERE id = 'c5') TO (SELECT FROM Product WHERE id = 'p3');
CREATE EDGE PURCHASED SET purchasedAt = '2026-02-01 13:00:00' FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Product WHERE id = 'p4');
CREATE EDGE PURCHASED SET purchasedAt = '2026-02-05 15:00:00' FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Product WHERE id = 'p6');
CREATE EDGE PURCHASED SET purchasedAt = '2026-02-18 10:00:00' FROM (SELECT FROM Customer WHERE id = 'c5') TO (SELECT FROM Product WHERE id = 'p1');
-- LIVES_AT edges
CREATE EDGE LIVES_AT FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Address WHERE id = 'a1');
CREATE EDGE LIVES_AT FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Address WHERE id = 'a1');
CREATE EDGE LIVES_AT FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Address WHERE id = 'a2');
CREATE EDGE LIVES_AT FROM (SELECT FROM Customer WHERE id = 'c4') TO (SELECT FROM Address WHERE id = 'a2');
CREATE EDGE LIVES_AT FROM (SELECT FROM Customer WHERE id = 'c5') TO (SELECT FROM Address WHERE id = 'a1');
CREATE EDGE LIVES_AT FROM (SELECT FROM Customer WHERE id = 'c6') TO (SELECT FROM Address WHERE id = 'a3');
-- USED edges (customer -> device)
CREATE EDGE USED FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Device WHERE id = 'd1');
CREATE EDGE USED FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Device WHERE id = 'd2');
CREATE EDGE USED FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Device WHERE id = 'd2');
CREATE EDGE USED FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Device WHERE id = 'd3');
-- OPENED edges (customer -> ticket)
CREATE EDGE OPENED FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Ticket WHERE id = 't1');
CREATE EDGE OPENED FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Ticket WHERE id = 't2');
CREATE EDGE OPENED FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Ticket WHERE id = 't3');
-- CLICKED edges (customer -> campaign)
CREATE EDGE CLICKED FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Campaign WHERE id = 'camp1');
CREATE EDGE CLICKED FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Campaign WHERE id = 'camp2');
CREATE EDGE CLICKED FROM (SELECT FROM Customer WHERE id = 'c5') TO (SELECT FROM Campaign WHERE id = 'camp1');
-- REFERRED edges (customer -> customer)
CREATE EDGE REFERRED FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Customer WHERE id = 'c4');
CREATE EDGE REFERRED FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Customer WHERE id = 'c3');
-- CONNECTED_TO edges (social connections)
CREATE EDGE CONNECTED_TO FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Customer WHERE id = 'c6');
CREATE EDGE CONNECTED_TO FROM (SELECT FROM Customer WHERE id = 'c5') TO (SELECT FROM Customer WHERE id = 'c4');
-- OBSERVED_IN edges (identifier -> session, for identity resolution)
CREATE EDGE OBSERVED_IN FROM (SELECT FROM Identifier WHERE id = 'id1') TO (SELECT FROM Session WHERE id = 's1');
CREATE EDGE OBSERVED_IN FROM (SELECT FROM Identifier WHERE id = 'id3') TO (SELECT FROM Session WHERE id = 's1');
CREATE EDGE OBSERVED_IN FROM (SELECT FROM Identifier WHERE id = 'id3') TO (SELECT FROM Session WHERE id = 's2');
CREATE EDGE OBSERVED_IN FROM (SELECT FROM Identifier WHERE id = 'id2') TO (SELECT FROM Session WHERE id = 's2');
CREATE EDGE OBSERVED_IN FROM (SELECT FROM Identifier WHERE id = 'id2') TO (SELECT FROM Session WHERE id = 's3');
CREATE EDGE OBSERVED_IN FROM (SELECT FROM Identifier WHERE id = 'id4') TO (SELECT FROM Session WHERE id = 's3');
CREATE EDGE OBSERVED_IN FROM (SELECT FROM Identifier WHERE id = 'id5') TO (SELECT FROM Session WHERE id = 's3');
CREATE EDGE OBSERVED_IN FROM (SELECT FROM Identifier WHERE id = 'id6') TO (SELECT FROM Session WHERE id = 's3');
-- INTERACTED edges (customer -> event)
CREATE EDGE INTERACTED FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Event WHERE id = 'e1');
CREATE EDGE INTERACTED FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Event WHERE id = 'e2');
CREATE EDGE INTERACTED FROM (SELECT FROM Customer WHERE id = 'c1') TO (SELECT FROM Event WHERE id = 'e3');
CREATE EDGE INTERACTED FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Event WHERE id = 'e4');
CREATE EDGE INTERACTED FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Event WHERE id = 'e5');
CREATE EDGE INTERACTED FROM (SELECT FROM Customer WHERE id = 'c2') TO (SELECT FROM Event WHERE id = 'e6');
CREATE EDGE INTERACTED FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Event WHERE id = 'e7');
CREATE EDGE INTERACTED FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Event WHERE id = 'e8');
CREATE EDGE INTERACTED FROM (SELECT FROM Customer WHERE id = 'c3') TO (SELECT FROM Event WHERE id = 'e9');
-- FOLLOWED_BY edges (event chains for journey analysis)
CREATE EDGE FOLLOWED_BY FROM (SELECT FROM Event WHERE id = 'e1') TO (SELECT FROM Event WHERE id = 'e2');
CREATE EDGE FOLLOWED_BY FROM (SELECT FROM Event WHERE id = 'e2') TO (SELECT FROM Event WHERE id = 'e3');
CREATE EDGE FOLLOWED_BY FROM (SELECT FROM Event WHERE id = 'e4') TO (SELECT FROM Event WHERE id = 'e5');
CREATE EDGE FOLLOWED_BY FROM (SELECT FROM Event WHERE id = 'e5') TO (SELECT FROM Event WHERE id = 'e6');
CREATE EDGE FOLLOWED_BY FROM (SELECT FROM Event WHERE id = 'e7') TO (SELECT FROM Event WHERE id = 'e8');
CREATE EDGE FOLLOWED_BY FROM (SELECT FROM Event WHERE id = 'e8') TO (SELECT FROM Event WHERE id = 'e9');
