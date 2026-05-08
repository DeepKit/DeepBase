# DeepFlow 数据库迁移管理

## 概述

本目录管理 DeepFlow 的数据库迁移脚本，确保数据库结构的版本化和可追踪性。

## 目录结构

```
sql/migrations/
├── README.md                    # 本文档
├── migration_tool.py            # 迁移执行工具
├── versions/                    # 迁移脚本目录
│   ├── 0001_initial_schema.sql
│   ├── 0002_add_audit_tables.sql
│   └── ...
├── rollbacks/                   # 回滚脚本目录
│   ├── 0001_rollback.sql
│   ├── 0002_rollback.sql
│   └── ...
└── seeds/                       # 初始数据
    ├── roles.sql
    └── default_config.sql
```

## 命名规范

### 迁移文件

格式: `{序号}_{描述}.sql`

```
0001_initial_schema.sql
0002_add_audit_tables.sql
0003_add_message_bus_tables.sql
0004_add_workflow_state.sql
```

### 回滚文件

格式: `{序号}_rollback.sql`

```
0001_rollback.sql
0002_rollback.sql
```

## 迁移脚本模板

### 创建表

```sql
-- Migration: 0001_initial_schema
-- Description: 初始化基础表结构
-- Author: 鲁班
-- Date: 2024-12-04

-- ========================================
-- 会话表
-- ========================================
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL DEFAULT 'default',
    user_id TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    metadata TEXT  -- JSON
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_status ON sessions(status);
CREATE INDEX IF NOT EXISTS idx_sessions_tenant ON sessions(tenant_id);

-- ========================================
-- 消息表
-- ========================================
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    from_role TEXT NOT NULL,
    to_role TEXT NOT NULL,
    msg_type TEXT NOT NULL,
    payload TEXT NOT NULL,  -- JSON
    state INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (session_id) REFERENCES sessions(id)
);

CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id);
CREATE INDEX IF NOT EXISTS idx_messages_state ON messages(state);

-- ========================================
-- 迁移记录
-- ========================================
INSERT INTO migration_history (version, name, applied_at)
VALUES ('0001', 'initial_schema', datetime('now'));
```

### 修改表

```sql
-- Migration: 0005_add_priority_column
-- Description: 为消息表添加优先级字段
-- Author: 鲁班
-- Date: 2024-12-04

-- 添加字段
ALTER TABLE messages ADD COLUMN priority INTEGER DEFAULT 1;

-- 添加索引
CREATE INDEX IF NOT EXISTS idx_messages_priority ON messages(priority);

-- 记录迁移
INSERT INTO migration_history (version, name, applied_at)
VALUES ('0005', 'add_priority_column', datetime('now'));
```

### 回滚脚本

```sql
-- Rollback: 0005_add_priority_column
-- Description: 回滚优先级字段

-- SQLite 不支持 DROP COLUMN，需要重建表
-- 1. 创建临时表
CREATE TABLE messages_temp AS SELECT
    id, session_id, from_role, to_role, msg_type, payload, state, created_at
FROM messages;

-- 2. 删除原表
DROP TABLE messages;

-- 3. 重命名临时表
ALTER TABLE messages_temp RENAME TO messages;

-- 4. 重建索引
CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id);
CREATE INDEX IF NOT EXISTS idx_messages_state ON messages(state);

-- 5. 删除迁移记录
DELETE FROM migration_history WHERE version = '0005';
```

## 迁移工具

### migration_tool.py

```python
#!/usr/bin/env python3
"""
DeepFlow 数据库迁移工具

使用方法：
    python migration_tool.py migrate           # 执行所有未应用的迁移
    python migration_tool.py rollback 0005     # 回滚到指定版本
    python migration_tool.py status            # 查看迁移状态
    python migration_tool.py create <name>     # 创建新迁移脚本
"""

import os
import sys
import sqlite3
import argparse
from pathlib import Path
from datetime import datetime


class MigrationTool:
    def __init__(self, db_path: str, migrations_dir: str = "./versions"):
        self.db_path = db_path
        self.migrations_dir = Path(migrations_dir)
        self.rollbacks_dir = Path("./rollbacks")
        self.conn = None
    
    def connect(self):
        self.conn = sqlite3.connect(self.db_path)
        self._ensure_migration_table()
    
    def close(self):
        if self.conn:
            self.conn.close()
    
    def _ensure_migration_table(self):
        """确保迁移历史表存在"""
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS migration_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                version TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                applied_at TEXT NOT NULL,
                checksum TEXT
            )
        """)
        self.conn.commit()
    
    def get_applied_migrations(self) -> list:
        """获取已应用的迁移"""
        cursor = self.conn.execute(
            "SELECT version FROM migration_history ORDER BY version"
        )
        return [row[0] for row in cursor.fetchall()]
    
    def get_pending_migrations(self) -> list:
        """获取待应用的迁移"""
        applied = set(self.get_applied_migrations())
        all_migrations = sorted(self.migrations_dir.glob("*.sql"))
        
        pending = []
        for path in all_migrations:
            version = path.stem.split("_")[0]
            if version not in applied:
                pending.append(path)
        
        return pending
    
    def migrate(self):
        """执行所有未应用的迁移"""
        pending = self.get_pending_migrations()
        
        if not pending:
            print("No pending migrations.")
            return
        
        print(f"Found {len(pending)} pending migrations:")
        for path in pending:
            print(f"  - {path.name}")
        
        for path in pending:
            self._apply_migration(path)
        
        print(f"\n✅ Applied {len(pending)} migrations successfully.")
    
    def _apply_migration(self, path: Path):
        """应用单个迁移"""
        print(f"\nApplying: {path.name}")
        
        with open(path, 'r', encoding='utf-8') as f:
            sql = f.read()
        
        try:
            self.conn.executescript(sql)
            self.conn.commit()
            print(f"  ✓ {path.name} applied successfully")
        except Exception as e:
            self.conn.rollback()
            print(f"  ✗ {path.name} failed: {e}")
            raise
    
    def rollback(self, target_version: str):
        """回滚到指定版本"""
        applied = self.get_applied_migrations()
        
        if target_version not in applied:
            print(f"Version {target_version} not found in applied migrations.")
            return
        
        # 找出需要回滚的迁移
        to_rollback = []
        for version in reversed(applied):
            if version <= target_version:
                break
            to_rollback.append(version)
        
        if not to_rollback:
            print("Nothing to rollback.")
            return
        
        print(f"Will rollback {len(to_rollback)} migrations:")
        for version in to_rollback:
            print(f"  - {version}")
        
        for version in to_rollback:
            self._apply_rollback(version)
        
        print(f"\n✅ Rolled back to version {target_version}.")
    
    def _apply_rollback(self, version: str):
        """应用回滚脚本"""
        rollback_path = self.rollbacks_dir / f"{version}_rollback.sql"
        
        if not rollback_path.exists():
            print(f"  ⚠ No rollback script for {version}")
            return
        
        print(f"\nRolling back: {version}")
        
        with open(rollback_path, 'r', encoding='utf-8') as f:
            sql = f.read()
        
        try:
            self.conn.executescript(sql)
            self.conn.commit()
            print(f"  ✓ {version} rolled back successfully")
        except Exception as e:
            self.conn.rollback()
            print(f"  ✗ {version} rollback failed: {e}")
            raise
    
    def status(self):
        """显示迁移状态"""
        applied = self.get_applied_migrations()
        pending = self.get_pending_migrations()
        
        print("Migration Status:")
        print(f"  Database: {self.db_path}")
        print(f"  Applied:  {len(applied)}")
        print(f"  Pending:  {len(pending)}")
        
        if applied:
            print("\nApplied migrations:")
            cursor = self.conn.execute(
                "SELECT version, name, applied_at FROM migration_history ORDER BY version"
            )
            for row in cursor.fetchall():
                print(f"  ✓ {row[0]} - {row[1]} ({row[2]})")
        
        if pending:
            print("\nPending migrations:")
            for path in pending:
                print(f"  ○ {path.name}")
    
    def create(self, name: str):
        """创建新迁移脚本"""
        # 获取下一个版本号
        existing = sorted(self.migrations_dir.glob("*.sql"))
        if existing:
            last_version = int(existing[-1].stem.split("_")[0])
            next_version = last_version + 1
        else:
            next_version = 1
        
        version_str = f"{next_version:04d}"
        filename = f"{version_str}_{name}.sql"
        rollback_filename = f"{version_str}_rollback.sql"
        
        # 创建迁移脚本
        migration_path = self.migrations_dir / filename
        with open(migration_path, 'w', encoding='utf-8') as f:
            f.write(f"""-- Migration: {version_str}_{name}
-- Description: TODO: 添加描述
-- Author: {os.getenv('USER', 'unknown')}
-- Date: {datetime.now().strftime('%Y-%m-%d')}

-- TODO: 添加迁移 SQL

-- 记录迁移
INSERT INTO migration_history (version, name, applied_at)
VALUES ('{version_str}', '{name}', datetime('now'));
""")
        
        # 创建回滚脚本
        rollback_path = self.rollbacks_dir / rollback_filename
        self.rollbacks_dir.mkdir(exist_ok=True)
        with open(rollback_path, 'w', encoding='utf-8') as f:
            f.write(f"""-- Rollback: {version_str}_{name}
-- Description: TODO: 添加回滚描述

-- TODO: 添加回滚 SQL

-- 删除迁移记录
DELETE FROM migration_history WHERE version = '{version_str}';
""")
        
        print(f"Created migration: {migration_path}")
        print(f"Created rollback:  {rollback_path}")


def main():
    parser = argparse.ArgumentParser(description="DeepFlow Database Migration Tool")
    parser.add_argument("command", choices=["migrate", "rollback", "status", "create"])
    parser.add_argument("arg", nargs="?", help="Version for rollback or name for create")
    parser.add_argument("--db", default="DeepFlow.db", help="Database path")
    parser.add_argument("--migrations", default="./versions", help="Migrations directory")
    
    args = parser.parse_args()
    
    tool = MigrationTool(args.db, args.migrations)
    tool.connect()
    
    try:
        if args.command == "migrate":
            tool.migrate()
        elif args.command == "rollback":
            if not args.arg:
                print("Error: rollback requires a target version")
                sys.exit(1)
            tool.rollback(args.arg)
        elif args.command == "status":
            tool.status()
        elif args.command == "create":
            if not args.arg:
                print("Error: create requires a name")
                sys.exit(1)
            tool.create(args.arg)
    finally:
        tool.close()


if __name__ == "__main__":
    main()
```

## 使用指南

### 1. 初始化数据库

```bash
# 执行所有迁移
python migration_tool.py migrate --db ../data/DeepFlow.db

# 查看状态
python migration_tool.py status --db ../data/DeepFlow.db
```

### 2. 创建新迁移

```bash
# 创建迁移脚本
python migration_tool.py create add_workflow_tables

# 编辑生成的文件
# versions/0006_add_workflow_tables.sql
# rollbacks/0006_rollback.sql
```

### 3. 回滚迁移

```bash
# 回滚到指定版本
python migration_tool.py rollback 0003 --db ../data/DeepFlow.db
```

## 最佳实践

### 1. 迁移原则

- **向前兼容**: 新迁移不应破坏现有功能
- **原子性**: 每个迁移应该是独立的、完整的
- **可逆性**: 每个迁移都应有对应的回滚脚本
- **幂等性**: 迁移脚本应使用 `IF NOT EXISTS` 等条件语句

### 2. 审查流程

```
1. 开发者创建迁移脚本
2. 代码审查：
   - 检查 SQL 语法
   - 检查索引设计
   - 检查回滚脚本
3. 在测试环境验证
4. 合并到主分支
5. CI 自动执行迁移
```

### 3. 生产部署

```bash
# 1. 备份数据库
sqlite3 DeepFlow.db ".backup DeepFlow_backup_$(date +%Y%m%d).db"

# 2. 执行迁移
python migration_tool.py migrate --db DeepFlow.db

# 3. 验证
python migration_tool.py status --db DeepFlow.db
```

## 注意事项

### SQLite 限制

SQLite 不支持以下操作：
- `ALTER TABLE ... DROP COLUMN` (需重建表)
- `ALTER TABLE ... RENAME COLUMN` (3.25.0+ 支持)
- `ALTER TABLE ... ADD CONSTRAINT`

对于这些操作，需要：
1. 创建新表
2. 复制数据
3. 删除旧表
4. 重命名新表

### 并发迁移

- 确保同一时间只有一个迁移进程运行
- 建议使用文件锁或数据库锁

### 数据迁移

对于涉及数据转换的迁移：
1. 先添加新字段
2. 运行数据迁移脚本
3. 删除旧字段

## 初始迁移脚本

### 0001_initial_schema.sql

参见 `versions/0001_initial_schema.sql`

## 相关文档

- `04.01.Data-DeepFlow数据模型-v1.0.md` - 数据模型设计
- `06.14.Dev-DeepFlow-IPC通信详细设计-v1.0.md` - 消息表设计
- `03.16.Arch-DeepFlow-消息总线可靠性设计-v1.0.md` - 消息持久化
