DROP TABLE IF EXISTS client;
CREATE TABLE client (
    id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    agent                 TEXT NOT NULL,
    agent_device          TEXT NOT NULL DEFAULT '',
    agent_os              TEXT NOT NULL DEFAULT '',
    agent_browser         TEXT NOT NULL DEFAULT '',
    agent_browser_version TEXT NOT NULL DEFAULT '',
    agent_engine          TEXT NOT NULL DEFAULT '',
    ip                    TEXT NOT NULL,
    app_id                TEXT NOT NULL,
    client_id             TEXT NOT NULL,
    joined_at             INTEGER NOT NULL,
    last_seen             INTEGER NOT NULL,
    active                CHAR(1) NOT NULL default 0
);

DROP TABLE IF EXISTS task;
CREATE TABLE task (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    test_id     INTEGER NOT NULL,
    created_at  INTEGER NOT NULL,
    started_at  INTEGER,
    finished_at INTEGER,
    state       CHAR(10) NOT NULL default 'pending'
);

DROP TABLE IF EXISTS client_task;
CREATE TABLE client_task (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id     INTEGER NOT NULL,
    client_id   INTEGER NOT NULL,
    created_at  INTEGER NOT NULL,
    started_at  INTEGER,
    finished_at INTEGER,
    state       CHAR(10) NOT NULL default 'pending'
);
DROP TABLE IF EXISTS client_task_result;
CREATE TABLE client_task_result (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    client_task_id  INTEGER NOT NULL,
    result          TEXT NOT NULL DEFAULT ''
);
DROP TABLE IF EXISTS test;
CREATE TABLE test (
    id INTEGER PRIMARY KEY AUTOINCREMENT
);
