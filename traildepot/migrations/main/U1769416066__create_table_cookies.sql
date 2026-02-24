CREATE TABLE "cookies" (
    'id' BLOB PRIMARY KEY CHECK (is_uuid_v7(id)) DEFAULT (uuid_v7()) NOT NULL,
    'user' BLOB NOT NULL UNIQUE REFERENCES '_user'('id'),
    'cookies' INTEGER NOT NULL DEFAULT 0
) STRICT;
