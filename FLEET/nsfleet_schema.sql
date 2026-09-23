-- =====================================================================
--  NS FLEET — NAVI Shipping Fleet Management System
--  Database schema for MySQL 5.7+ / MariaDB 10.3+
--
--  Generated from the application's own field definitions, so every
--  column matches a field in the system exactly.
--
--  Run once:  mysql -u USER -p DATABASE < nsfleet_schema.sql
--  Or import through phpMyAdmin in cPanel.
-- =====================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET time_zone = '+08:00';

-- ---------------------------------------------------------------
-- Vessel register
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `vessels` (
  `id` CHAR(24) NOT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `type` VARCHAR(255) DEFAULT NULL,
  `mgmt` VARCHAR(255) DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `owner` VARCHAR(255) DEFAULT NULL,
  `homePort` VARCHAR(255) DEFAULT NULL,
  `marinaReg` VARCHAR(255) DEFAULT NULL,
  `officialNo` VARCHAR(255) DEFAULT NULL,
  `callSign` VARCHAR(255) DEFAULT NULL,
  `built` VARCHAR(255) DEFAULT NULL,
  `builder` VARCHAR(255) DEFAULT NULL,
  `flag` VARCHAR(255) DEFAULT NULL,
  `grt` DECIMAL(16,3) DEFAULT NULL,
  `nrt` DECIMAL(16,3) DEFAULT NULL,
  `dwt` DECIMAL(16,3) DEFAULT NULL,
  `loa` DECIMAL(16,3) DEFAULT NULL,
  `breadth` DECIMAL(16,3) DEFAULT NULL,
  `depth` DECIMAL(16,3) DEFAULT NULL,
  `draft` DECIMAL(16,3) DEFAULT NULL,
  `engineMake` VARCHAR(255) DEFAULT NULL,
  `enginePower` DECIMAL(16,3) DEFAULT NULL,
  `engineHP` DECIMAL(16,3) DEFAULT NULL,
  `gensets` VARCHAR(255) DEFAULT NULL,
  `tradeArea` VARCHAR(255) DEFAULT NULL,
  `manning` DECIMAL(16,3) DEFAULT NULL,
  `charterer` VARCHAR(255) DEFAULT NULL,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_vessels_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Vessel register';

-- ---------------------------------------------------------------
-- Engine register
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `engines` (
  `id` CHAR(24) NOT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `unit` VARCHAR(255) DEFAULT NULL,
  `maker` VARCHAR(255) DEFAULT NULL,
  `model` VARCHAR(255) DEFAULT NULL,
  `serial` VARCHAR(255) DEFAULT NULL,
  `powerKW` DECIMAL(16,3) DEFAULT NULL,
  `powerHP` DECIMAL(16,3) DEFAULT NULL,
  `rateSea` DECIMAL(16,3) DEFAULT NULL,
  `ratePort` DECIMAL(16,3) DEFAULT NULL,
  `tolerance` DECIMAL(16,3) DEFAULT NULL,
  `runHours` DECIMAL(16,3) DEFAULT NULL,
  `manualRef` VARCHAR(255) DEFAULT NULL,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_engines_vessel` (`vessel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Engine register';

-- ---------------------------------------------------------------
-- Crew roster
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `crew` (
  `id` CHAR(24) NOT NULL,
  `ccn` VARCHAR(255) DEFAULT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `rank` VARCHAR(255) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `contact` VARCHAR(255) DEFAULT NULL,
  `address` TEXT,
  `dob` DATE DEFAULT NULL,
  `signOn` DATE DEFAULT NULL,
  `contractEnd` DATE DEFAULT NULL,
  `reliever` VARCHAR(255) DEFAULT NULL,
  `sirbNo` VARCHAR(255) DEFAULT NULL,
  `sirbExp` DATE DEFAULT NULL,
  `licenseNo` VARCHAR(255) DEFAULT NULL,
  `licenseExp` DATE DEFAULT NULL,
  `medicalExp` DATE DEFAULT NULL,
  `sidExp` DATE DEFAULT NULL,
  `emgName` VARCHAR(255) DEFAULT NULL,
  `emgRel` VARCHAR(255) DEFAULT NULL,
  `emgContact` VARCHAR(255) DEFAULT NULL,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_crew_vessel` (`vessel_id`),
  KEY `ix_crew_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Crew roster';

-- ---------------------------------------------------------------
-- Crew changes
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `crewchange` (
  `id` CHAR(24) NOT NULL,
  `refNo` VARCHAR(255) DEFAULT NULL,
  `date` DATE DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `crewName` VARCHAR(255) DEFAULT NULL,
  `rank` VARCHAR(255) DEFAULT NULL,
  `movement` VARCHAR(255) DEFAULT NULL,
  `port` VARCHAR(255) DEFAULT NULL,
  `relieverFor` VARCHAR(255) DEFAULT NULL,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_crewchange_date` (`date`),
  KEY `ix_crewchange_vessel` (`vessel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Crew changes';

-- ---------------------------------------------------------------
-- Machinery and equipment register
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `components` (
  `id` CHAR(24) NOT NULL,
  `code` VARCHAR(255) DEFAULT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `location` VARCHAR(255) DEFAULT NULL,
  `maker` VARCHAR(255) DEFAULT NULL,
  `model` VARCHAR(255) DEFAULT NULL,
  `serial` VARCHAR(255) DEFAULT NULL,
  `criticality` VARCHAR(255) DEFAULT NULL,
  `runHours` DECIMAL(16,3) DEFAULT NULL,
  `hoursDate` DATE DEFAULT NULL,
  `manualRef` VARCHAR(255) DEFAULT NULL,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_components_vessel` (`vessel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Machinery and equipment register';

-- ---------------------------------------------------------------
-- Planned maintenance jobs
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pmsjobs` (
  `id` CHAR(24) NOT NULL,
  `jobNo` VARCHAR(255) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `component` VARCHAR(255) DEFAULT NULL,
  `job` VARCHAR(255) DEFAULT NULL,
  `basis` VARCHAR(255) DEFAULT NULL,
  `intervalDays` DECIMAL(16,3) DEFAULT NULL,
  `intervalHours` DECIMAL(16,3) DEFAULT NULL,
  `lastDone` DATE DEFAULT NULL,
  `lastHours` DECIMAL(16,3) DEFAULT NULL,
  `dueDate` DATE DEFAULT NULL,
  `dueHours` DECIMAL(16,3) DEFAULT NULL,
  `criticality` VARCHAR(255) DEFAULT NULL,
  `responsible` VARCHAR(255) DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `manualRef` VARCHAR(255) DEFAULT NULL,
  `sparesNeeded` VARCHAR(255) DEFAULT NULL,
  `workDone` TEXT,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_pmsjobs_vessel` (`vessel_id`),
  KEY `ix_pmsjobs_dueDate` (`dueDate`),
  KEY `ix_pmsjobs_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Planned maintenance jobs';

-- ---------------------------------------------------------------
-- Defects and repairs
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `defects` (
  `id` CHAR(24) NOT NULL,
  `refNo` VARCHAR(255) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `equipment` VARCHAR(255) DEFAULT NULL,
  `description` TEXT,
  `reported` DATE DEFAULT NULL,
  `reportedBy` VARCHAR(255) DEFAULT NULL,
  `severity` VARCHAR(255) DEFAULT NULL,
  `affectsClass` VARCHAR(255) DEFAULT NULL,
  `riskControl` TEXT,
  `targetDate` DATE DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `repairBy` VARCHAR(255) DEFAULT NULL,
  `closedDate` DATE DEFAULT NULL,
  `cost` DECIMAL(16,3) DEFAULT NULL,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_defects_vessel` (`vessel_id`),
  KEY `ix_defects_reported` (`reported`),
  KEY `ix_defects_targetDate` (`targetDate`),
  KEY `ix_defects_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Defects and repairs';

-- ---------------------------------------------------------------
-- Requisitions and purchase orders
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `requisitions` (
  `id` CHAR(24) NOT NULL,
  `reqNo` VARCHAR(255) DEFAULT NULL,
  `date` DATE DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `category` VARCHAR(255) DEFAULT NULL,
  `item` TEXT,
  `quantity` DECIMAL(16,3) DEFAULT NULL,
  `unit` VARCHAR(255) DEFAULT NULL,
  `urgency` VARCHAR(255) DEFAULT NULL,
  `linkedJob` VARCHAR(255) DEFAULT NULL,
  `requestedBy` VARCHAR(255) DEFAULT NULL,
  `supplier` VARCHAR(255) DEFAULT NULL,
  `poNo` VARCHAR(255) DEFAULT NULL,
  `estCost` DECIMAL(16,3) DEFAULT NULL,
  `actualCost` DECIMAL(16,3) DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `approvedBy` VARCHAR(255) DEFAULT NULL,
  `deliveryPort` VARCHAR(255) DEFAULT NULL,
  `deliveredDate` DATE DEFAULT NULL,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_requisitions_date` (`date`),
  KEY `ix_requisitions_vessel` (`vessel_id`),
  KEY `ix_requisitions_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Requisitions and purchase orders';

-- ---------------------------------------------------------------
-- Drills and training
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `drills` (
  `id` CHAR(24) NOT NULL,
  `refNo` VARCHAR(255) DEFAULT NULL,
  `date` DATE DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `drill` VARCHAR(255) DEFAULT NULL,
  `scenario` VARCHAR(255) DEFAULT NULL,
  `participants` DECIMAL(16,3) DEFAULT NULL,
  `duration` DECIMAL(16,3) DEFAULT NULL,
  `conductedBy` VARCHAR(255) DEFAULT NULL,
  `equipment` VARCHAR(255) DEFAULT NULL,
  `deficiencies` TEXT,
  `actions` TEXT,
  `nextDue` DATE DEFAULT NULL,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_drills_date` (`date`),
  KEY `ix_drills_vessel` (`vessel_id`),
  KEY `ix_drills_nextDue` (`nextDue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Drills and training';

-- ---------------------------------------------------------------
-- Incidents, near misses and non-conformities
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `incidents` (
  `id` CHAR(24) NOT NULL,
  `refNo` VARCHAR(255) DEFAULT NULL,
  `date` DATE DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `type` VARCHAR(255) DEFAULT NULL,
  `severity` VARCHAR(255) DEFAULT NULL,
  `title` VARCHAR(255) DEFAULT NULL,
  `description` TEXT,
  `immediate` TEXT,
  `rootCause` TEXT,
  `corrective` TEXT,
  `preventive` TEXT,
  `reportedBy` VARCHAR(255) DEFAULT NULL,
  `dpaNotified` VARCHAR(255) DEFAULT NULL,
  `authority` VARCHAR(255) DEFAULT NULL,
  `targetDate` DATE DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `closedDate` DATE DEFAULT NULL,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_incidents_date` (`date`),
  KEY `ix_incidents_vessel` (`vessel_id`),
  KEY `ix_incidents_targetDate` (`targetDate`),
  KEY `ix_incidents_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Incidents, near misses and non-conformities';

-- ---------------------------------------------------------------
-- Audits and inspections
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `audits` (
  `id` CHAR(24) NOT NULL,
  `refNo` VARCHAR(255) DEFAULT NULL,
  `date` DATE DEFAULT NULL,
  `type` VARCHAR(255) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `auditor` VARCHAR(255) DEFAULT NULL,
  `scope` TEXT,
  `ncr` DECIMAL(16,3) DEFAULT NULL,
  `observations` DECIMAL(16,3) DEFAULT NULL,
  `findings` TEXT,
  `correctiveAction` TEXT,
  `targetDate` DATE DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `closedDate` DATE DEFAULT NULL,
  `intervalMonths` DECIMAL(16,3) DEFAULT NULL,
  `nextDue` DATE DEFAULT NULL,
  `file_name` VARCHAR(255) DEFAULT NULL,
  `file_type` VARCHAR(100) DEFAULT NULL,
  `file_data` LONGTEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_audits_date` (`date`),
  KEY `ix_audits_vessel` (`vessel_id`),
  KEY `ix_audits_targetDate` (`targetDate`),
  KEY `ix_audits_status` (`status`),
  KEY `ix_audits_nextDue` (`nextDue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audits and inspections';

-- ---------------------------------------------------------------
-- Audit findings and corrective actions
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `findings` (
  `id` CHAR(24) NOT NULL,
  `refNo` VARCHAR(255) DEFAULT NULL,
  `audit_id` CHAR(24) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `category` VARCHAR(255) DEFAULT NULL,
  `clause` VARCHAR(255) DEFAULT NULL,
  `description` TEXT,
  `objectiveEvidence` TEXT,
  `raisedBy` VARCHAR(255) DEFAULT NULL,
  `immediate` TEXT,
  `rootCause` TEXT,
  `correctiveAction` TEXT,
  `preventiveAction` TEXT,
  `responsible` VARCHAR(255) DEFAULT NULL,
  `targetDate` DATE DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `evidenceOfClosure` TEXT,
  `verifiedBy` VARCHAR(255) DEFAULT NULL,
  `closedDate` DATE DEFAULT NULL,
  `file_name` VARCHAR(255) DEFAULT NULL,
  `file_type` VARCHAR(100) DEFAULT NULL,
  `file_data` LONGTEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_findings_audit` (`audit_id`),
  KEY `ix_findings_vessel` (`vessel_id`),
  KEY `ix_findings_targetDate` (`targetDate`),
  KEY `ix_findings_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Audit findings and corrective actions';

-- ---------------------------------------------------------------
-- Certificates and licences
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `certificates` (
  `id` CHAR(24) NOT NULL,
  `holder` VARCHAR(255) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `name` VARCHAR(255) DEFAULT NULL,
  `certNo` VARCHAR(255) DEFAULT NULL,
  `issuer` VARCHAR(255) DEFAULT NULL,
  `issued` DATE DEFAULT NULL,
  `expiry` DATE DEFAULT NULL,
  `surveyDue` DATE DEFAULT NULL,
  `renewalOwner` VARCHAR(255) DEFAULT NULL,
  `file_name` VARCHAR(255) DEFAULT NULL,
  `file_type` VARCHAR(100) DEFAULT NULL,
  `file_data` LONGTEXT,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_certificates_vessel` (`vessel_id`),
  KEY `ix_certificates_expiry` (`expiry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Certificates and licences';

-- ---------------------------------------------------------------
-- Voyages and employment
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `voyages` (
  `id` CHAR(24) NOT NULL,
  `voyageNo` VARCHAR(255) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `charterType` VARCHAR(255) DEFAULT NULL,
  `charterer` VARCHAR(255) DEFAULT NULL,
  `cargo` VARCHAR(255) DEFAULT NULL,
  `cargoQty` VARCHAR(255) DEFAULT NULL,
  `loadPort` VARCHAR(255) DEFAULT NULL,
  `dischPort` VARCHAR(255) DEFAULT NULL,
  `laycanFrom` DATE DEFAULT NULL,
  `laycanTo` DATE DEFAULT NULL,
  `atd` DATE DEFAULT NULL,
  `atdTime` CHAR(4) DEFAULT NULL,
  `ata` DATE DEFAULT NULL,
  `ataTime` CHAR(4) DEFAULT NULL,
  `elapsed` VARCHAR(255) DEFAULT NULL,
  `stopHours` DECIMAL(16,3) DEFAULT NULL,
  `steamHours` VARCHAR(255) DEFAULT NULL,
  `distance` DECIMAL(16,3) DEFAULT NULL,
  `speed` DECIMAL(16,3) DEFAULT NULL,
  `passageNote` VARCHAR(255) DEFAULT NULL,
  `revenue` DECIMAL(16,3) DEFAULT NULL,
  `fuelCost` DECIMAL(16,3) DEFAULT NULL,
  `portCharges` DECIMAL(16,3) DEFAULT NULL,
  `otherCost` DECIMAL(16,3) DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_voyages_vessel` (`vessel_id`),
  KEY `ix_voyages_atd` (`atd`),
  KEY `ix_voyages_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Voyages and employment';

-- ---------------------------------------------------------------
-- Bunkering records
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `bunkers` (
  `id` CHAR(24) NOT NULL,
  `refNo` VARCHAR(255) DEFAULT NULL,
  `date` DATE DEFAULT NULL,
  `time` CHAR(4) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `grade` VARCHAR(255) DEFAULT NULL,
  `port` VARCHAR(255) DEFAULT NULL,
  `supplier` VARCHAR(255) DEFAULT NULL,
  `bdn` VARCHAR(255) DEFAULT NULL,
  `litres` DECIMAL(16,3) DEFAULT NULL,
  `price` DECIMAL(16,3) DEFAULT NULL,
  `robAfter` DECIMAL(16,3) DEFAULT NULL,
  `receivedBy` VARCHAR(255) DEFAULT NULL,
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_bunkers_date` (`date`),
  KEY `ix_bunkers_vessel` (`vessel_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bunkering records';

-- ---------------------------------------------------------------
-- Daily vessel reports
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `dailyreports` (
  `id` CHAR(24) NOT NULL,
  `refNo` VARCHAR(255) DEFAULT NULL,
  `reportType` VARCHAR(255) DEFAULT NULL,
  `date` DATE DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `status` VARCHAR(255) DEFAULT NULL,
  `location` VARCHAR(255) DEFAULT NULL,
  `activity` VARCHAR(255) DEFAULT NULL,
  `cargo` VARCHAR(255) DEFAULT NULL,
  `runHours` DECIMAL(16,3) DEFAULT NULL,
  `fuelROB` DECIMAL(16,3) DEFAULT NULL,
  `luboilROB` DECIMAL(16,3) DEFAULT NULL,
  `waterROB` DECIMAL(16,3) DEFAULT NULL,
  `crewOnboard` DECIMAL(16,3) DEFAULT NULL,
  `weather` VARCHAR(255) DEFAULT NULL,
  `remarks` TEXT,
  `reportedBy` VARCHAR(255) DEFAULT NULL,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_dailyreports_date` (`date`),
  KEY `ix_dailyreports_vessel` (`vessel_id`),
  KEY `ix_dailyreports_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Daily vessel reports';

-- ---------------------------------------------------------------
-- Daily fuel consumption — header and one row per engine
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `fuellog` (
  `id` CHAR(24) NOT NULL,
  `refNo` VARCHAR(40) DEFAULT NULL,
  `vessel_id` CHAR(24) DEFAULT NULL,
  `date` DATE DEFAULT NULL,
  `time` CHAR(4) DEFAULT NULL,
  `reportType` VARCHAR(60) DEFAULT NULL,
  `voyage` VARCHAR(60) DEFAULT NULL,
  `openingROB` DECIMAL(16,3) DEFAULT NULL COMMENT 'blank means carried from the previous report',
  `robEnd` DECIMAL(16,3) DEFAULT NULL COMMENT 'ROB by sounding',
  `remarks` TEXT,
  `created` DATETIME DEFAULT NULL,
  `updated` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_fuellog_vessel` (`vessel_id`),
  KEY `ix_fuellog_stamp` (`vessel_id`,`date`,`time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Daily fuel consumption reports';

CREATE TABLE IF NOT EXISTS `fuellog_rows` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `fuellog_id` CHAR(24) NOT NULL,
  `unit` VARCHAR(60) NOT NULL COMMENT 'Main engine (P) … Auxiliary engine No.4 (S)',
  `seaHrs` DECIMAL(10,2) DEFAULT NULL,
  `portHrs` DECIMAL(10,2) DEFAULT NULL,
  `used` DECIMAL(16,3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_fuelrows_log` (`fuellog_id`),
  CONSTRAINT `fk_fuelrows_log` FOREIGN KEY (`fuellog_id`) REFERENCES `fuellog` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Consumption per engine';

-- ---------------------------------------------------------------
-- Users, counters and change log
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `users` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(60) NOT NULL,
  `fullname` VARCHAR(120) DEFAULT NULL,
  `position` VARCHAR(120) DEFAULT NULL,
  `email` VARCHAR(160) DEFAULT NULL,
  `pass_hash` VARCHAR(255) NOT NULL,
  `role` ENUM('admin','office','vessel','read') NOT NULL DEFAULT 'office',
  `vessel_id` CHAR(24) DEFAULT NULL COMMENT 'restricts a vessel account to its own ship',
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `last_login` DATETIME DEFAULT NULL,
  `created` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Login accounts';

CREATE TABLE IF NOT EXISTS `counters` (
  `name` VARCHAR(40) NOT NULL,
  `value` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Reference number sequences';

CREATE TABLE IF NOT EXISTS `change_log` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `at` DATETIME NOT NULL,
  `username` VARCHAR(60) DEFAULT NULL,
  `table_name` VARCHAR(40) DEFAULT NULL,
  `record_id` CHAR(24) DEFAULT NULL,
  `action` ENUM('insert','update','delete') DEFAULT NULL,
  `ip` VARCHAR(45) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `ix_log_at` (`at`),
  KEY `ix_log_rec` (`table_name`,`record_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Who changed what, for audit purposes';

-- ---------------------------------------------------------------
-- Views — the standing questions, answerable from any reporting tool
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW `v_certificates_due` AS
SELECT c.`id`, COALESCE(v.`name`,'Company') AS vessel, c.`name` AS certificate, c.`certNo`,
       c.`issuer`, c.`expiry`, DATEDIFF(c.`expiry`, CURDATE()) AS days_left,
       CASE WHEN DATEDIFF(c.`expiry`, CURDATE()) < 0 THEN 'EXPIRED'
            WHEN DATEDIFF(c.`expiry`, CURDATE()) <= 60 THEN 'DUE'
            ELSE 'VALID' END AS standing
FROM `certificates` c LEFT JOIN `vessels` v ON v.`id` = c.`vessel_id`
WHERE c.`expiry` IS NOT NULL;

CREATE OR REPLACE VIEW `v_pms_overdue` AS
SELECT j.`id`, v.`name` AS vessel, j.`jobNo`, j.`component`, j.`job`, j.`criticality`,
       j.`dueDate`, DATEDIFF(CURDATE(), j.`dueDate`) AS days_overdue
FROM `pmsjobs` j LEFT JOIN `vessels` v ON v.`id` = j.`vessel_id`
WHERE j.`dueDate` IS NOT NULL AND j.`dueDate` < CURDATE()
  AND j.`status` NOT IN ('Completed','Postponed (approved)');

CREATE OR REPLACE VIEW `v_findings_open` AS
SELECT f.`id`, f.`refNo`, COALESCE(v.`name`,'Office') AS scope, f.`category`, f.`clause`,
       f.`description`, f.`responsible`, f.`targetDate`, f.`status`,
       a.`refNo` AS audit_ref, a.`date` AS audit_date
FROM `findings` f
LEFT JOIN `vessels` v ON v.`id` = f.`vessel_id`
LEFT JOIN `audits`  a ON a.`id` = f.`audit_id`
WHERE f.`status` <> 'Verified and closed';

CREATE OR REPLACE VIEW `v_fuel_by_engine` AS
SELECT v.`name` AS vessel, r.`unit`,
       COUNT(*) AS entries,
       SUM(r.`seaHrs` + r.`portHrs`) AS hours_run,
       SUM(r.`used`) AS litres_used,
       SUM(COALESCE(r.`seaHrs`,0) * COALESCE(e.`rateSea`,0)
         + COALESCE(r.`portHrs`,0) * COALESCE(e.`ratePort`,0)) AS litres_expected
FROM `fuellog_rows` r
JOIN `fuellog` f ON f.`id` = r.`fuellog_id`
LEFT JOIN `vessels` v ON v.`id` = f.`vessel_id`
LEFT JOIN `engines` e ON e.`vessel_id` = f.`vessel_id` AND e.`unit` = r.`unit`
GROUP BY v.`name`, r.`unit`;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
--  Nothing else needs running. The first time index.php is opened it
--  creates the administrator account from the details in config.php.
-- =====================================================================
