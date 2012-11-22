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

DROP TABLE IF EXISTS run;
CREATE TABLE run (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id     INTEGER NOT NULL,
    created_at  INTEGER NOT NULL,
    started_at  INTEGER,
    finished_at INTEGER,
    state       CHAR(10) NOT NULL default 'pending'
);

DROP TABLE IF EXISTS job;
CREATE TABLE job (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id      INTEGER NOT NULL,
    client_id   INTEGER NOT NULL,
    created_at  INTEGER NOT NULL,
    started_at  INTEGER,
    finished_at INTEGER,
    state       CHAR(10) NOT NULL default 'pending'
);
DROP TABLE IF EXISTS job_result;
CREATE TABLE job_result (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    epoch           INTEGER NOT NULL,
    job_id          INTEGER NOT NULL,
    state           TEXT NOT NULL,
    count           INTEGER NOT NULL,
    test_name       TEXT NOT NULL,
    result          TEXT NOT NULL DEFAULT ''
);
DROP TABLE IF EXISTS task;
CREATE TABLE task (
    id INTEGER PRIMARY KEY AUTOINCREMENT
);
