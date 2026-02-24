-- new database migration
INSERT INTO "cookies" ('user', 'cookies') SELECT id, 0 FROM '_user';
