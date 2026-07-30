<?php

declare(strict_types=1);

/**
 * Incremental SQLite upgrades for admin / telemetry / remote config.
 *
 * @return list<string>
 */
return [
    "ALTER TABLE users ADD COLUMN email VARCHAR(255)",
    "ALTER TABLE users ADD COLUMN password_hash VARCHAR(255)",
    "ALTER TABLE users ADD COLUMN updated_at DATETIME",
    "ALTER TABLE users ADD COLUMN is_admin INTEGER NOT NULL DEFAULT 0",
    "ALTER TABLE users ADD COLUMN is_banned INTEGER NOT NULL DEFAULT 0",
    "ALTER TABLE users ADD COLUMN premium_until DATETIME NULL",
    "ALTER TABLE users ADD COLUMN premium_note TEXT NULL",
    "ALTER TABLE users ADD COLUMN last_seen_at DATETIME NULL",
    "ALTER TABLE users ADD COLUMN last_data_at DATETIME NULL",
    "ALTER TABLE users ADD COLUMN app_version VARCHAR(32) NULL",
    "ALTER TABLE users ADD COLUMN ios_version VARCHAR(32) NULL",
    "ALTER TABLE users ADD COLUMN device_model VARCHAR(128) NULL",
    "ALTER TABLE users ADD COLUMN notes TEXT NULL",

    "ALTER TABLE trips ADD COLUMN require_join_approval INTEGER NOT NULL DEFAULT 1",

    "ALTER TABLE trip_members ADD COLUMN display_name VARCHAR(100)",
    "ALTER TABLE trip_members ADD COLUMN is_manual INTEGER NOT NULL DEFAULT 0",

    "ALTER TABLE expenses ADD COLUMN category_id VARCHAR(64)",
    "ALTER TABLE expenses ADD COLUMN category_name VARCHAR(100)",
    "ALTER TABLE expenses ADD COLUMN is_settled INTEGER NOT NULL DEFAULT 0",
    "ALTER TABLE expenses ADD COLUMN settled_at DATETIME",

    "CREATE TABLE IF NOT EXISTS trip_settlements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        settled_by_user_id INTEGER NOT NULL,
        note TEXT NULL,
        snapshot TEXT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    )",

    "CREATE TABLE IF NOT EXISTS sync_documents (
        user_id INTEGER NOT NULL,
        doc_type VARCHAR(64) NOT NULL,
        payload TEXT NOT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (user_id, doc_type)
    )",

    "CREATE TABLE IF NOT EXISTS trip_join_requests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        status VARCHAR(16) NOT NULL DEFAULT 'pending',
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        resolved_at DATETIME NULL,
        UNIQUE (trip_id, user_id)
    )",

    "CREATE TABLE IF NOT EXISTS trip_shortcuts (
        user_id INTEGER NOT NULL,
        trip_id INTEGER NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (user_id, trip_id)
    )",

    "CREATE TABLE IF NOT EXISTS devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_uuid VARCHAR(64) NOT NULL UNIQUE,
        user_id INTEGER NULL,
        is_guest INTEGER NOT NULL DEFAULT 1,
        first_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_data_at DATETIME NULL,
        app_version VARCHAR(32) NULL,
        ios_version VARCHAR(32) NULL,
        device_model VARCHAR(128) NULL,
        locale VARCHAR(32) NULL,
        timezone VARCHAR(64) NULL,
        push_token VARCHAR(255) NULL,
        notes TEXT NULL
    )",

    "CREATE TABLE IF NOT EXISTS app_config (
        config_key VARCHAR(64) PRIMARY KEY,
        config_value TEXT NOT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_by INTEGER NULL
    )",

    "CREATE TABLE IF NOT EXISTS admin_audit_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        admin_user_id INTEGER NOT NULL,
        action VARCHAR(64) NOT NULL,
        target_type VARCHAR(64) NULL,
        target_id VARCHAR(64) NULL,
        details TEXT NULL,
        ip_address VARCHAR(64) NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    )",

    "CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id)",
    "CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices(last_seen_at)",
    "CREATE INDEX IF NOT EXISTS idx_users_last_seen ON users(last_seen_at)",
    "CREATE INDEX IF NOT EXISTS idx_users_premium ON users(premium_until)",
    "CREATE INDEX IF NOT EXISTS idx_audit_created ON admin_audit_log(created_at)",
];
