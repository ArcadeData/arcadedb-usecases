-- Users
INSERT INTO User SET name = 'Alice', handle = 'alice', joinedAt = '2025-01-15 10:00:00', bio = 'Tech blogger and AI enthusiast'
INSERT INTO User SET name = 'Bob', handle = 'bob', joinedAt = '2025-02-20 14:30:00', bio = 'Music producer and photographer'
INSERT INTO User SET name = 'Charlie', handle = 'charlie', joinedAt = '2025-03-10 09:00:00', bio = 'Full-stack developer'
INSERT INTO User SET name = 'Diana', handle = 'diana', joinedAt = '2025-04-05 11:00:00', bio = 'Sports journalist'
INSERT INTO User SET name = 'Eve', handle = 'eve', joinedAt = '2025-05-12 08:00:00', bio = 'Travel photographer'
INSERT INTO User SET name = 'Frank', handle = 'frank', joinedAt = '2025-06-01 16:00:00', bio = 'Indie game developer'
INSERT INTO User SET name = 'Grace', handle = 'grace', joinedAt = '2025-07-20 12:00:00', bio = 'Data scientist'
INSERT INTO User SET name = 'Hank', handle = 'hank', joinedAt = '2025-08-15 10:00:00', bio = 'Casual user'
-- Topics
INSERT INTO Topic SET name = 'Tech', description = 'Technology and software'
INSERT INTO Topic SET name = 'Music', description = 'Music production and culture'
INSERT INTO Topic SET name = 'Sports', description = 'Sports news and analysis'
INSERT INTO Topic SET name = 'Travel', description = 'Travel stories and tips'
-- Groups
INSERT INTO Group SET name = 'Developers', description = 'Software development community', createdAt = '2025-01-01 00:00:00'
INSERT INTO Group SET name = 'Photographers', description = 'Photography enthusiasts', createdAt = '2025-02-01 00:00:00'
INSERT INTO Group SET name = 'Gamers', description = 'Gaming community', createdAt = '2025-03-01 00:00:00'
-- Posts (12 posts across users)
INSERT INTO Post SET title = 'AI Trends in 2026', body = 'A deep dive into the latest AI developments', createdAt = '2026-03-01 09:00:00', category = 'Tech'
INSERT INTO Post SET title = 'Building REST APIs', body = 'Best practices for API design', createdAt = '2026-03-01 10:00:00', category = 'Tech'
INSERT INTO Post SET title = 'Guitar Techniques', body = 'Advanced fingerpicking patterns', createdAt = '2026-03-01 11:00:00', category = 'Music'
INSERT INTO Post SET title = 'Concert Review', body = 'Last night at the jazz festival', createdAt = '2026-03-01 12:00:00', category = 'Music'
INSERT INTO Post SET title = 'Marathon Training', body = 'My 16-week training plan', createdAt = '2026-03-02 08:00:00', category = 'Sports'
INSERT INTO Post SET title = 'Database Performance', body = 'Tuning queries for multi-model databases', createdAt = '2026-03-02 09:00:00', category = 'Tech'
INSERT INTO Post SET title = 'Tokyo Travel Guide', body = 'Hidden gems in Shibuya and Shinjuku', createdAt = '2026-03-02 10:00:00', category = 'Travel'
INSERT INTO Post SET title = 'Game Dev Tips', body = 'Optimizing sprite rendering', createdAt = '2026-03-02 11:00:00', category = 'Tech'
INSERT INTO Post SET title = 'Vinyl Collecting', body = 'Finding rare pressings at local shops', createdAt = '2026-03-03 09:00:00', category = 'Music'
INSERT INTO Post SET title = 'Rock Climbing Basics', body = 'Getting started with bouldering', createdAt = '2026-03-03 10:00:00', category = 'Sports'
INSERT INTO Post SET title = 'Backpacking Europe', body = 'Budget tips for 30 days across 10 countries', createdAt = '2026-03-03 11:00:00', category = 'Travel'
INSERT INTO Post SET title = 'Open Source Databases', body = 'Why multi-model is the future', createdAt = '2026-03-03 12:00:00', category = 'Tech'
-- CREATED edges (User -> Post, authorship)
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Building REST APIs')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Concert Review')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Vinyl Collecting')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Database Performance')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Marathon Training')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Rock Climbing Basics')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'Backpacking Europe')
CREATE EDGE CREATED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'Game Dev Tips')
-- FOLLOWS edges (asymmetric — Alice and Bob are popular)
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM User WHERE handle = 'alice')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM User WHERE handle = 'bob')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM User WHERE handle = 'charlie')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM User WHERE handle = 'charlie')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM User WHERE handle = 'grace')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM User WHERE handle = 'charlie')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM User WHERE handle = 'frank')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM User WHERE handle = 'frank')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM User WHERE handle = 'diana')
CREATE EDGE FOLLOWS FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM User WHERE handle = 'eve')
-- LIKED edges (skewed toward viral post "AI Trends in 2026")
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Concert Review')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Concert Review')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Database Performance')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'Database Performance')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Marathon Training')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'Game Dev Tips')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'Game Dev Tips')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'Backpacking Europe')
CREATE EDGE LIKED FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Post WHERE title = 'Backpacking Europe')
-- SHARED edges (concentrated on viral posts)
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Post WHERE title = 'AI Trends in 2026')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Post WHERE title = 'Guitar Techniques')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Post WHERE title = 'Open Source Databases')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Post WHERE title = 'Tokyo Travel Guide')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Post WHERE title = 'Marathon Training')
CREATE EDGE SHARED FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Post WHERE title = 'Backpacking Europe')
-- TAGGED edges (Post -> Topic, 1-2 topics per post)
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'AI Trends in 2026') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Building REST APIs') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Guitar Techniques') TO (SELECT FROM Topic WHERE name = 'Music')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Concert Review') TO (SELECT FROM Topic WHERE name = 'Music')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Marathon Training') TO (SELECT FROM Topic WHERE name = 'Sports')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Database Performance') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Tokyo Travel Guide') TO (SELECT FROM Topic WHERE name = 'Travel')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Game Dev Tips') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Vinyl Collecting') TO (SELECT FROM Topic WHERE name = 'Music')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Rock Climbing Basics') TO (SELECT FROM Topic WHERE name = 'Sports')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Backpacking Europe') TO (SELECT FROM Topic WHERE name = 'Travel')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Open Source Databases') TO (SELECT FROM Topic WHERE name = 'Tech')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Game Dev Tips') TO (SELECT FROM Topic WHERE name = 'Music')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Rock Climbing Basics') TO (SELECT FROM Topic WHERE name = 'Travel')
CREATE EDGE TAGGED FROM (SELECT FROM Post WHERE title = 'Concert Review') TO (SELECT FROM Topic WHERE name = 'Travel')
-- MEMBER_OF edges (User -> Group, Developers has mutual-follow cluster)
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'alice') TO (SELECT FROM Group WHERE name = 'Developers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Group WHERE name = 'Developers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Group WHERE name = 'Developers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Group WHERE name = 'Developers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'bob') TO (SELECT FROM Group WHERE name = 'Photographers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'eve') TO (SELECT FROM Group WHERE name = 'Photographers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Group WHERE name = 'Photographers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'frank') TO (SELECT FROM Group WHERE name = 'Gamers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'hank') TO (SELECT FROM Group WHERE name = 'Gamers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'charlie') TO (SELECT FROM Group WHERE name = 'Gamers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'grace') TO (SELECT FROM Group WHERE name = 'Gamers')
CREATE EDGE MEMBER_OF FROM (SELECT FROM User WHERE handle = 'diana') TO (SELECT FROM Group WHERE name = 'Gamers')
-- EngagementMetric time-series (3 snapshots per post: hour 1, 2, 3)
-- AI Trends in 2026 (viral — rapid growth)
INSERT INTO EngagementMetric SET postRid = 'ai-trends-2026', recordedAt = '2026-03-01 10:00:00', likes = 5, shares = 2, comments = 3
INSERT INTO EngagementMetric SET postRid = 'ai-trends-2026', recordedAt = '2026-03-01 11:00:00', likes = 15, shares = 8, comments = 10
INSERT INTO EngagementMetric SET postRid = 'ai-trends-2026', recordedAt = '2026-03-01 12:00:00', likes = 30, shares = 15, comments = 20
-- Building REST APIs (steady)
INSERT INTO EngagementMetric SET postRid = 'building-rest-apis', recordedAt = '2026-03-01 11:00:00', likes = 3, shares = 1, comments = 2
INSERT INTO EngagementMetric SET postRid = 'building-rest-apis', recordedAt = '2026-03-01 12:00:00', likes = 5, shares = 2, comments = 3
INSERT INTO EngagementMetric SET postRid = 'building-rest-apis', recordedAt = '2026-03-01 13:00:00', likes = 7, shares = 2, comments = 4
-- Guitar Techniques (moderate growth)
INSERT INTO EngagementMetric SET postRid = 'guitar-techniques', recordedAt = '2026-03-01 12:00:00', likes = 4, shares = 2, comments = 1
INSERT INTO EngagementMetric SET postRid = 'guitar-techniques', recordedAt = '2026-03-01 13:00:00', likes = 8, shares = 4, comments = 3
INSERT INTO EngagementMetric SET postRid = 'guitar-techniques', recordedAt = '2026-03-01 14:00:00', likes = 12, shares = 6, comments = 5
-- Concert Review (peaks early then plateaus)
INSERT INTO EngagementMetric SET postRid = 'concert-review', recordedAt = '2026-03-01 13:00:00', likes = 8, shares = 1, comments = 5
INSERT INTO EngagementMetric SET postRid = 'concert-review', recordedAt = '2026-03-01 14:00:00', likes = 10, shares = 1, comments = 6
INSERT INTO EngagementMetric SET postRid = 'concert-review', recordedAt = '2026-03-01 15:00:00', likes = 11, shares = 1, comments = 6
-- Marathon Training (slow and steady)
INSERT INTO EngagementMetric SET postRid = 'marathon-training', recordedAt = '2026-03-02 09:00:00', likes = 2, shares = 1, comments = 1
INSERT INTO EngagementMetric SET postRid = 'marathon-training', recordedAt = '2026-03-02 10:00:00', likes = 4, shares = 2, comments = 2
INSERT INTO EngagementMetric SET postRid = 'marathon-training', recordedAt = '2026-03-02 11:00:00', likes = 6, shares = 3, comments = 3
-- Database Performance (moderate)
INSERT INTO EngagementMetric SET postRid = 'database-performance', recordedAt = '2026-03-02 10:00:00', likes = 3, shares = 1, comments = 2
INSERT INTO EngagementMetric SET postRid = 'database-performance', recordedAt = '2026-03-02 11:00:00', likes = 6, shares = 2, comments = 4
INSERT INTO EngagementMetric SET postRid = 'database-performance', recordedAt = '2026-03-02 12:00:00', likes = 8, shares = 3, comments = 5
-- Tokyo Travel Guide (moderate growth)
INSERT INTO EngagementMetric SET postRid = 'tokyo-travel-guide', recordedAt = '2026-03-02 11:00:00', likes = 5, shares = 2, comments = 3
INSERT INTO EngagementMetric SET postRid = 'tokyo-travel-guide', recordedAt = '2026-03-02 12:00:00', likes = 9, shares = 4, comments = 5
INSERT INTO EngagementMetric SET postRid = 'tokyo-travel-guide', recordedAt = '2026-03-02 13:00:00', likes = 12, shares = 5, comments = 7
-- Game Dev Tips (niche but engaged)
INSERT INTO EngagementMetric SET postRid = 'game-dev-tips', recordedAt = '2026-03-02 12:00:00', likes = 2, shares = 0, comments = 3
INSERT INTO EngagementMetric SET postRid = 'game-dev-tips', recordedAt = '2026-03-02 13:00:00', likes = 4, shares = 1, comments = 5
INSERT INTO EngagementMetric SET postRid = 'game-dev-tips', recordedAt = '2026-03-02 14:00:00', likes = 5, shares = 1, comments = 7
-- Vinyl Collecting (low engagement)
INSERT INTO EngagementMetric SET postRid = 'vinyl-collecting', recordedAt = '2026-03-03 10:00:00', likes = 2, shares = 0, comments = 1
INSERT INTO EngagementMetric SET postRid = 'vinyl-collecting', recordedAt = '2026-03-03 11:00:00', likes = 3, shares = 1, comments = 1
INSERT INTO EngagementMetric SET postRid = 'vinyl-collecting', recordedAt = '2026-03-03 12:00:00', likes = 4, shares = 1, comments = 2
-- Rock Climbing Basics (moderate)
INSERT INTO EngagementMetric SET postRid = 'rock-climbing-basics', recordedAt = '2026-03-03 11:00:00', likes = 3, shares = 1, comments = 2
INSERT INTO EngagementMetric SET postRid = 'rock-climbing-basics', recordedAt = '2026-03-03 12:00:00', likes = 5, shares = 2, comments = 3
INSERT INTO EngagementMetric SET postRid = 'rock-climbing-basics', recordedAt = '2026-03-03 13:00:00', likes = 7, shares = 2, comments = 4
-- Backpacking Europe (grows steadily)
INSERT INTO EngagementMetric SET postRid = 'backpacking-europe', recordedAt = '2026-03-03 12:00:00', likes = 4, shares = 2, comments = 2
INSERT INTO EngagementMetric SET postRid = 'backpacking-europe', recordedAt = '2026-03-03 13:00:00', likes = 8, shares = 4, comments = 4
INSERT INTO EngagementMetric SET postRid = 'backpacking-europe', recordedAt = '2026-03-03 14:00:00', likes = 13, shares = 6, comments = 6
-- Open Source Databases (strong engagement)
INSERT INTO EngagementMetric SET postRid = 'open-source-databases', recordedAt = '2026-03-03 13:00:00', likes = 6, shares = 3, comments = 4
INSERT INTO EngagementMetric SET postRid = 'open-source-databases', recordedAt = '2026-03-03 14:00:00', likes = 12, shares = 5, comments = 7
INSERT INTO EngagementMetric SET postRid = 'open-source-databases', recordedAt = '2026-03-03 15:00:00', likes = 18, shares = 8, comments = 10
