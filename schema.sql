DROP TABLE IF EXISTS client;
CREATE TABLE client (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    agent     TEXT NOT NULL,
    ip        TEXT NOT NULL,
    joined_at INTEGER NOT NULL,
    active    CHAR(1) NOT NULL default 0
);
