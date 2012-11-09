DROP TABLE IF EXISTS client;
CREATE TABLE client (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    agent     TEXT NOT NULL,
    ip        TEXT NOT NULL,
    joined_at INTEGER NOT NULL,
    active    CHAR(1) NOT NULL default 0
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
    state       CHAR(10) NOT NULL default 'pending',
    result      TEXT
);
