<?php

declare(strict_types=1);

/**
 * Incremental MySQL upgrades for admin / telemetry / remote config.
 *
 * @return list<string>
 */
return [
    "ALTER TABLE users ADD COLUMN email VARCHAR(255) NULL UNIQUE AFTER id",
    "ALTER TABLE users ADD COLUMN password_hash VARCHAR(255) NULL AFTER email",
    "ALTER TABLE users ADD COLUMN updated_at DATETIME NULL AFTER created_at",
    "ALTER TABLE users ADD COLUMN is_admin TINYINT(1) NOT NULL DEFAULT 0",
    "ALTER TABLE users ADD COLUMN is_banned TINYINT(1) NOT NULL DEFAULT 0",
    "ALTER TABLE users ADD COLUMN premium_until DATETIME NULL",
    "ALTER TABLE users ADD COLUMN premium_note TEXT NULL",
    "ALTER TABLE users ADD COLUMN last_seen_at DATETIME NULL",
    "ALTER TABLE users ADD COLUMN last_data_at DATETIME NULL",
    "ALTER TABLE users ADD COLUMN app_version VARCHAR(32) NULL",
    "ALTER TABLE users ADD COLUMN ios_version VARCHAR(32) NULL",
    "ALTER TABLE users ADD COLUMN device_model VARCHAR(128) NULL",
    "ALTER TABLE users ADD COLUMN notes TEXT NULL",
    "ALTER TABLE trips ADD COLUMN require_join_approval TINYINT(1) NOT NULL DEFAULT 1 AFTER owner_id",
    "ALTER TABLE trip_members ADD COLUMN display_name VARCHAR(100) NULL",
    "ALTER TABLE trip_members ADD COLUMN is_manual TINYINT(1) NOT NULL DEFAULT 0",
    "ALTER TABLE trip_members DROP FOREIGN KEY fk_members_user",
    "ALTER TABLE trip_members MODIFY user_id INT NULL",
    "ALTER TABLE trip_members ADD CONSTRAINT fk_members_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE",
    "ALTER TABLE expenses ADD COLUMN category_id VARCHAR(64) NULL",
    "ALTER TABLE expenses ADD COLUMN category_name VARCHAR(100) NULL",
    "ALTER TABLE expenses ADD COLUMN is_settled TINYINT(1) NOT NULL DEFAULT 0",
    "ALTER TABLE expenses ADD COLUMN settled_at DATETIME NULL",
    "CREATE TABLE IF NOT EXISTS trip_settlements (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        trip_id INT UNSIGNED NOT NULL,
        settled_by_user_id INT UNSIGNED NOT NULL,
        note TEXT NULL,
        snapshot LONGTEXT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

    "CREATE TABLE IF NOT EXISTS sync_documents (
        user_id INT UNSIGNED NOT NULL,
        doc_type VARCHAR(64) NOT NULL,
        payload LONGTEXT NOT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (user_id, doc_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

    "CREATE TABLE IF NOT EXISTS trip_join_requests (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        trip_id INT UNSIGNED NOT NULL,
        user_id INT UNSIGNED NOT NULL,
        status VARCHAR(16) NOT NULL DEFAULT 'pending',
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        resolved_at DATETIME NULL,
        UNIQUE KEY uq_trip_user (trip_id, user_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

    "CREATE TABLE IF NOT EXISTS trip_shortcuts (
        user_id INT UNSIGNED NOT NULL,
        trip_id INT UNSIGNED NOT NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (user_id, trip_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

    "CREATE TABLE IF NOT EXISTS devices (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        device_uuid VARCHAR(64) NOT NULL UNIQUE,
        user_id INT UNSIGNED NULL,
        is_guest TINYINT(1) NOT NULL DEFAULT 1,
        first_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_data_at DATETIME NULL,
        app_version VARCHAR(32) NULL,
        ios_version VARCHAR(32) NULL,
        device_model VARCHAR(128) NULL,
        locale VARCHAR(32) NULL,
        timezone VARCHAR(64) NULL,
        push_token VARCHAR(255) NULL,
        notes TEXT NULL,
        INDEX idx_devices_user (user_id),
        INDEX idx_devices_last_seen (last_seen_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

    "CREATE TABLE IF NOT EXISTS app_config (
        config_key VARCHAR(64) PRIMARY KEY,
        config_value TEXT NOT NULL,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_by INT UNSIGNED NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

    "CREATE TABLE IF NOT EXISTS admin_audit_log (
        id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        admin_user_id INT UNSIGNED NOT NULL,
        action VARCHAR(64) NOT NULL,
        target_type VARCHAR(64) NULL,
        target_id VARCHAR(64) NULL,
        details TEXT NULL,
        ip_address VARCHAR(64) NULL,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_audit_created (created_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
];
