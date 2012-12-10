PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;

DROP TABLE IF EXISTS `resume`;
CREATE TABLE `resume` (
 `id` INTEGER PRIMARY KEY AUTOINCREMENT,
 `pauseid` varchar(40) NOT NULL default '',
 `name` varchar(255) NOT NULL default '',
 `views` INTEGER NOT NULL DEFAULT 0,
 `updated` INTERGER NOT NULL DEFAULT 0,
 UNIQUE(`pauseid`)
);

COMMIT;
