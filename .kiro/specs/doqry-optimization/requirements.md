# Requirements Document

## Introduction

优化 UniBase doQry 查询框架，增加慢查询告警、执行计划缓存、查询模板版本管理等功能，提升数据库访问的可观测性和性能。

## Glossary

- **Slow Query**: 执行时间超过阈值的查询
- **Execution Plan**: 数据库查询的执行计划
- **Query Template**: 预定义的 SQL 查询模板
- **Template Version**: 查询模板的版本号
- **Query Metrics**: 查询执行的统计指标（次数、平均耗时、最大耗时等）

## Requirements

### Requirement 1

**User Story:** As a developer, I want slow query detection and alerting, so that I can identify and optimize performance bottlenecks.

#### Acceptance Criteria

1. WHEN a query execution time exceeds the threshold THEN the system SHALL log a warning with query details
2. WHEN configuring slow query detection THEN the system SHALL allow setting threshold per query or globally
3. WHEN a slow query is detected THEN the system SHALL include execution time, parameters, and correlation ID in the log
4. WHEN slow query alerting is enabled THEN the system SHALL support callback notification

### Requirement 2

**User Story:** As a developer, I want query execution plan caching, so that I can reduce query preparation overhead.

#### Acceptance Criteria

1. WHEN a query is executed multiple times THEN the system SHALL reuse the prepared statement
2. WHEN the cache reaches capacity THEN the system SHALL evict least recently used entries
3. WHEN a query template is modified THEN the system SHALL invalidate the cached plan
4. WHEN viewing cache statistics THEN the system SHALL report hit rate, size, and eviction count

### Requirement 3

**User Story:** As a developer, I want query template version management, so that I can safely update queries in production.

#### Acceptance Criteria

1. WHEN a query template is modified THEN the system SHALL increment its version number
2. WHEN a template version changes THEN the system SHALL log the change with old and new SQL
3. WHEN rolling back a template THEN the system SHALL restore the previous version
4. WHEN deploying templates THEN the system SHALL support importing from JSON file

### Requirement 4

**User Story:** As a developer, I want query execution metrics, so that I can monitor database performance.

#### Acceptance Criteria

1. WHEN a query is executed THEN the system SHALL record execution count and duration
2. WHEN viewing metrics THEN the system SHALL display average, min, max, and percentile (p95, p99) execution times
3. WHEN exporting metrics THEN the system SHALL produce Prometheus-compatible format
4. WHEN metrics are collected THEN the system SHALL support time-based aggregation (per minute, hour, day)

### Requirement 5

**User Story:** As a developer, I want query result caching, so that I can reduce database load for frequently accessed data.

#### Acceptance Criteria

1. WHEN a cacheable query is executed THEN the system SHALL check cache before hitting database
2. WHEN configuring cache THEN the system SHALL allow setting TTL per query template
3. WHEN cached data expires THEN the system SHALL automatically refresh on next access
4. WHEN data is modified THEN the system SHALL invalidate related cache entries

