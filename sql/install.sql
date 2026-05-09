CREATE TABLE IF NOT EXISTS `ug_garages` (
  `id` varchar(64) NOT NULL,
  `label` varchar(100) NOT NULL,
  `type` enum('public','job') NOT NULL DEFAULT 'public',
  `job` varchar(64) DEFAULT NULL,
  `vehicle_type` varchar(16) NOT NULL DEFAULT 'car',
  `coords` longtext NOT NULL,
  `store` longtext NULL,
  `spawn` longtext NOT NULL,
  `blip` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` varchar(80) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Recommended columns for ESX owned_vehicles if missing:
-- ALTER TABLE `owned_vehicles` ADD COLUMN `garage` varchar(64) DEFAULT NULL;
-- ALTER TABLE `owned_vehicles` ADD COLUMN `stored` tinyint(1) NOT NULL DEFAULT 1;

-- QBCore usually already has `garage` and `state` in player_vehicles.

-- Für bestehende Installationen, falls die Tabelle schon existiert:
-- ALTER TABLE `ug_garages` ADD COLUMN `store` longtext NULL AFTER `coords`;
-- ALTER TABLE `ug_garages` ADD COLUMN `vehicle_type` varchar(16) NOT NULL DEFAULT 'car' AFTER `job`;
-- UPDATE `ug_garages` SET `store` = `coords` WHERE `store` IS NULL OR `store` = '';
-- UPDATE `ug_garages` SET `vehicle_type` = 'car' WHERE `vehicle_type` IS NULL OR `vehicle_type` = '';

CREATE TABLE IF NOT EXISTS `ug_job_vehicles` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `garage_id` varchar(64) NOT NULL,
  `model` varchar(80) NOT NULL,
  `label` varchar(100) NOT NULL,
  `primary_r` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `primary_g` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `primary_b` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `secondary_r` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `secondary_g` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `secondary_b` tinyint(3) unsigned NOT NULL DEFAULT 255,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `garage_id` (`garage_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- Version 17 nutzt keine ug_active_job_vehicles Tabelle mehr.
-- Falls du von v16 kommst, kannst du die alte Tabelle optional entfernen:
-- DROP TABLE IF EXISTS `ug_active_job_vehicles`;
