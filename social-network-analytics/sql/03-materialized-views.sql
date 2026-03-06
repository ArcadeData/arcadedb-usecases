-- TrendingPosts: PERIODIC refresh every 1 minute
-- Aggregates engagement metrics into a trending score per post
CREATE MATERIALIZED VIEW TrendingPosts AS SELECT postRid, sum(likes) AS totalLikes, sum(shares) AS totalShares, sum(comments) AS totalComments, sum(likes) + sum(shares) * 2 + sum(comments) * 3 AS score FROM EngagementMetric GROUP BY postRid REFRESH EVERY 1 MINUTE
-- UserPostCounts: INCREMENTAL refresh (updates after each commit)
-- Counts posts per user by counting outgoing CREATED edges
CREATE MATERIALIZED VIEW UserPostCounts AS SELECT @out.handle AS handle, @out.name AS userName, count(*) AS postCount FROM CREATED GROUP BY @out.handle, @out.name REFRESH INCREMENTAL
-- InfluenceScores: MANUAL refresh (on demand)
-- Computes follower count per user (engagement correlation done at query time)
CREATE MATERIALIZED VIEW InfluenceScores AS SELECT @in.name AS userName, @in.handle AS handle, count(*) AS followers FROM FOLLOWS GROUP BY @in.name, @in.handle REFRESH MANUAL
