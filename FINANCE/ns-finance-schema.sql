-- =====================================================================
--  NS FINANCE — database schema
--  NAVI SHIPPING OPC  ·  Finance and Accounting Portal
--  MySQL 8.0 / MariaDB 10.5 or later
--
--  Mirrors the data model of ns-finance-portal.html so records created
--  offline can be imported, and the portal can run against a server.
--  Money is DECIMAL(15,2) — never FLOAT. Dates are DATE, not strings.
-- =====================================================================

SET NAMES utf8mb4;
SET time_zone = '+08:00';                      -- Asia/Manila

CREATE DATABASE IF NOT EXISTS ns_finance
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ns_finance;

-- ---------------------------------------------------------------------
-- 1.  COMPANY SETTINGS AND DOCUMENT NUMBERING
-- ---------------------------------------------------------------------

CREATE TABLE settings (
  skey            VARCHAR(60)   NOT NULL PRIMARY KEY,
  sval            TEXT          NULL,
  updated_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Series restart each January: NS/INV-2026-0001 → NS/INV-2027-0001
CREATE TABLE counters (
  prefix          VARCHAR(12)   NOT NULL,       -- INV, BILL, EXP, COE, PV, CR, JV, CH, HS, PR, PRJ, VOY
  year            SMALLINT      NOT NULL,
  last_no         INT           NOT NULL DEFAULT 0,
  PRIMARY KEY (prefix, year)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2.  MASTER DATA
-- ---------------------------------------------------------------------

CREATE TABLE vessels (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  name            VARCHAR(120)  NOT NULL,
  type            VARCHAR(40)   NULL,           -- LCT, Tugboat, Passenger, Cargo, Dredger…
  status          VARCHAR(20)   NOT NULL DEFAULT 'Active',
  basis           VARCHAR(60)   NULL,           -- Owned / CSMA / Chartered in …
  owner_id        CHAR(24)      NULL,           -- principal, see clients
  marina_no       VARCHAR(40)   NULL,           -- official number
  call_sign       VARCHAR(20)   NULL,
  flag            VARCHAR(40)   NULL,
  homeport        VARCHAR(80)   NULL,
  year_built      SMALLINT      NULL,
  builder         VARCHAR(120)  NULL,
  grt             DECIMAL(12,2) NULL,
  nrt             DECIMAL(12,2) NULL,
  kw              DECIMAL(12,2) NULL,
  loa             DECIMAL(8,2)  NULL,
  breadth         DECIMAL(8,2)  NULL,
  depth           DECIMAL(8,2)  NULL,
  draft           DECIMAL(8,2)  NULL,
  engine          VARCHAR(160)  NULL,
  klass           VARCHAR(80)   NULL,           -- classification society
  last_dd         VARCHAR(40)   NULL,           -- last drydocking
  cargo_cap       VARCHAR(80)   NULL,
  fuel_cons       VARCHAR(80)   NULL,
  speed           VARCHAR(40)   NULL,
  csma_date       DATE          NULL,
  mgmt_fee        DECIMAL(15,2) NULL,
  crew_fee        DECIMAL(15,2) NULL,
  remarks         TEXT          NULL,
  KEY ix_vessel_owner (owner_id)
) ENGINE=InnoDB;

CREATE TABLE clients (                          -- principals, owners, charterers
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  name            VARCHAR(160)  NOT NULL,
  kind            VARCHAR(60)   NULL,           -- Principal (ship management) / Charterer …
  contact         VARCHAR(120)  NULL,
  email           VARCHAR(160)  NULL,
  phone           VARCHAR(60)   NULL,
  tin             VARCHAR(30)   NULL,
  address         TEXT          NULL,
  terms           SMALLINT      NOT NULL DEFAULT 30,
  remarks         TEXT          NULL,
  UNIQUE KEY ux_client_name (name)
) ENGINE=InnoDB;

ALTER TABLE vessels
  ADD CONSTRAINT fk_vessel_owner FOREIGN KEY (owner_id) REFERENCES clients(id)
  ON DELETE SET NULL;

CREATE TABLE vendors (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  name            VARCHAR(160)  NOT NULL,
  cat             VARCHAR(60)   NULL,
  contact         VARCHAR(120)  NULL,
  email           VARCHAR(160)  NULL,
  phone           VARCHAR(60)   NULL,
  tin             VARCHAR(30)   NULL,
  address         TEXT          NULL,
  terms           SMALLINT      NOT NULL DEFAULT 30,
  ewt_rate        DECIMAL(5,2)  NULL,           -- 2% services, 5% rental
  remarks         TEXT          NULL,
  UNIQUE KEY ux_vendor_name (name)
) ENGINE=InnoDB;

CREATE TABLE coa (                              -- chart of accounts
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  code            VARCHAR(20)   NOT NULL,
  name            VARCHAR(160)  NOT NULL,
  type            VARCHAR(30)   NOT NULL,       -- Asset/Liability/Equity/Income/Expense
  remarks         TEXT          NULL,
  UNIQUE KEY ux_coa_code (code)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3.  PEOPLE — crew and shore staff
--     CCN for seafarers, SCN for shore staff; the number never changes
--     when a seafarer signs a further contract.
-- ---------------------------------------------------------------------

CREATE TABLE employees (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  ccn             VARCHAR(10)   NULL,           -- digits only, e.g. 00028
  emp_no          VARCHAR(20)   NULL,
  last_name       VARCHAR(80)   NOT NULL,
  first_name      VARCHAR(80)   NOT NULL,
  middle_name     VARCHAR(80)   NULL,
  full_name       VARCHAR(200)  NOT NULL,       -- LAST, FIRST MIDDLE — as printed
  kind            VARCHAR(30)   NOT NULL DEFAULT 'Crew (seafarer)',
  position        VARCHAR(80)   NULL,
  vessel_id       CHAR(24)      NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Active',
  address         TEXT          NULL,

  pay_basis       VARCHAR(20)   NOT NULL DEFAULT 'Monthly rate',
  basic           DECIMAL(15,2) NOT NULL DEFAULT 0,
  ot_fixed        DECIMAL(15,2) NOT NULL DEFAULT 0,
  allowance       DECIMAL(15,2) NOT NULL DEFAULT 0,
  night_diff      DECIMAL(15,2) NOT NULL DEFAULT 0,
  thirteenth_mo   DECIMAL(15,2) NOT NULL DEFAULT 0,
  leave_pay_mo    DECIMAL(15,2) NOT NULL DEFAULT 0,
  daily_rate      DECIMAL(15,2) NOT NULL DEFAULT 0,
  std_days        DECIMAL(5,2)  NOT NULL DEFAULT 26,
  leave_credits   DECIMAL(5,2)  NOT NULL DEFAULT 15,
  allot_pct       DECIMAL(5,2)  NOT NULL DEFAULT 0,
  tax_exempt      TINYINT(1)    NOT NULL DEFAULT 0,

  tin             VARCHAR(30)   NULL,
  sss_no          VARCHAR(30)   NULL,
  philhealth_no   VARCHAR(30)   NULL,
  pagibig_no      VARCHAR(30)   NULL,

  sirb_no         VARCHAR(30)   NULL,           -- seaman's book — prints in the Acknowledgment
  sirb_issued     DATE          NULL,
  sirb_place      VARCHAR(80)   NULL,
  sirb_expiry     DATE          NULL,

  hired           DATE          NULL,
  contract_end    DATE          NULL,
  ext_end         DATE          NULL,           -- extension end; the effective end date

  allottee        VARCHAR(160)  NULL,
  allottee_rel    VARCHAR(60)   NULL,

  bank1_bank      VARCHAR(120)  NULL,           -- own account
  bank1_branch    VARCHAR(120)  NULL,
  bank1_name      VARCHAR(160)  NULL,
  bank1_acct      VARCHAR(60)   NULL,
  bank2_bank      VARCHAR(120)  NULL,           -- other / spouse / parent
  bank2_branch    VARCHAR(120)  NULL,
  bank2_name      VARCHAR(160)  NULL,
  bank2_acct      VARCHAR(60)   NULL,

  remarks         TEXT          NULL,
  created_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY ux_emp_ccn (ccn, kind),
  KEY ix_emp_vessel (vessel_id),
  KEY ix_emp_name (last_name, first_name),
  CONSTRAINT fk_emp_vessel FOREIGN KEY (vessel_id) REFERENCES vessels(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- notarised contract scan and other 201-file documents
CREATE TABLE employee_files (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  employee_id     CHAR(24)      NOT NULL,
  doc_type        VARCHAR(60)   NOT NULL,       -- Notarised contract, Allotment, Attachment A…
  contract_no     VARCHAR(30)   NULL,
  file_name       VARCHAR(255)  NULL,
  file_path       VARCHAR(500)  NULL,           -- stored on disk, not in the database
  file_size       INT           NULL,
  mime_type       VARCHAR(80)   NULL,
  uploaded_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY ix_empfile (employee_id),
  CONSTRAINT fk_empfile FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE wage_scale (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  vessel_id       CHAR(24)      NULL,
  position        VARCHAR(80)   NOT NULL,
  licence         VARCHAR(40)   NULL,           -- minimum licence required
  basic           DECIMAL(15,2) NOT NULL DEFAULT 0,
  ot_fixed        DECIMAL(15,2) NOT NULL DEFAULT 0,
  allowance       DECIMAL(15,2) NOT NULL DEFAULT 0,
  others          DECIMAL(15,2) NOT NULL DEFAULT 0,
  night_diff      DECIMAL(15,2) NOT NULL DEFAULT 0,
  leave_pay       DECIMAL(15,2) NOT NULL DEFAULT 0,
  thirteenth      DECIMAL(15,2) NOT NULL DEFAULT 0,
  effective       DATE          NULL,
  remarks         TEXT          NULL,
  UNIQUE KEY ux_scale (vessel_id, position),
  CONSTRAINT fk_scale_vessel FOREIGN KEY (vessel_id) REFERENCES vessels(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- contract register — its own series, independent of the CCN
CREATE TABLE contracts (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  contract_no     VARCHAR(30)   NOT NULL,       -- NS-COE-2026-00001
  ccn             VARCHAR(10)   NULL,
  employee_id     CHAR(24)      NULL,
  crew_name       VARCHAR(200)  NULL,
  position        VARCHAR(80)   NULL,
  vessel_id       CHAR(24)      NULL,
  date_from       DATE          NULL,
  date_to         DATE          NULL,
  duration_text   VARCHAR(160)  NULL,
  gross_monthly   DECIMAL(15,2) NULL,
  issued          DATE          NULL,
  notarised       DATE          NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Issued',  -- Issued/Notarised/Void
  void_reason     VARCHAR(255)  NULL,
  void_date       DATE          NULL,
  UNIQUE KEY ux_contract_no (contract_no),
  KEY ix_contract_ccn (ccn),
  CONSTRAINT fk_contract_emp FOREIGN KEY (employee_id) REFERENCES employees(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4.  PAYROLL — semi-monthly cut-offs
--     1st–15th carries the whole month's SSS, PhilHealth, Pag-IBIG and tax.
--     16th–30th carries reimbursements.
-- ---------------------------------------------------------------------

CREATE TABLE payrolls (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  ref_no          VARCHAR(30)   NOT NULL,
  period          VARCHAR(10)   NOT NULL,       -- 2026-09
  cutoff          ENUM('1-15','16-30') NOT NULL DEFAULT '1-15',
  kind            VARCHAR(30)   NOT NULL,       -- Crew (seafarer) / Shore staff
  vessel_id       CHAR(24)      NULL,           -- null = fleet-wide
  scope           VARCHAR(80)   NULL,
  pay_date        DATE          NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Draft',
  remarks         TEXT          NULL,
  UNIQUE KEY ux_payroll_ref (ref_no),
  KEY ix_payroll_period (period, cutoff)
) ENGINE=InnoDB;

CREATE TABLE payroll_lines (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  payroll_id      CHAR(24)      NOT NULL,
  employee_id     CHAR(24)      NOT NULL,
  vessel_id       CHAR(24)      NULL,
  -- monthly scale figures; the cut-off pays half
  basic           DECIMAL(15,2) NOT NULL DEFAULT 0,
  ot_fixed        DECIMAL(15,2) NOT NULL DEFAULT 0,
  allowance       DECIMAL(15,2) NOT NULL DEFAULT 0,
  night_diff      DECIMAL(15,2) NOT NULL DEFAULT 0,
  -- deductions keyed on this cut-off
  dental          DECIMAL(15,2) NOT NULL DEFAULT 0,
  cash_advance    DECIMAL(15,2) NOT NULL DEFAULT 0,
  other_ded       DECIMAL(15,2) NOT NULL DEFAULT 0,
  no_tax          TINYINT(1)    NOT NULL DEFAULT 0,   -- withholding switched off for this line
  -- reimbursements, second cut-off only
  reim_medical    DECIMAL(15,2) NOT NULL DEFAULT 0,
  reim_travel     DECIMAL(15,2) NOT NULL DEFAULT 0,
  reim_other      DECIMAL(15,2) NOT NULL DEFAULT 0,
  remarks         VARCHAR(255)  NULL,
  KEY ix_line_payroll (payroll_id),
  KEY ix_line_emp (employee_id),
  CONSTRAINT fk_line_payroll FOREIGN KEY (payroll_id) REFERENCES payrolls(id) ON DELETE CASCADE,
  CONSTRAINT fk_line_emp FOREIGN KEY (employee_id) REFERENCES employees(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5.  COMMERCIAL — charters, hire statements, voyages
-- ---------------------------------------------------------------------

CREATE TABLE charters (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  ref_no          VARCHAR(30)   NOT NULL,
  type            VARCHAR(40)   NOT NULL,       -- Time / Voyage / Bareboat / COA
  vessel_name     VARCHAR(160)  NULL,           -- typed, may be outside the fleet
  owner_name      VARCHAR(160)  NULL,
  owner_address   TEXT          NULL,
  charterer_name  VARCHAR(160)  NULL,
  charterer_addr  TEXT          NULL,
  form            VARCHAR(60)   NULL,           -- charter party form
  cp_date         DATE          NULL,
  date_from       DATE          NULL,
  date_to         DATE          NULL,
  rate            DECIMAL(15,2) NULL,
  rate_basis      VARCHAR(40)   NULL,           -- per day / per MT / lumpsum
  addcom_pct      DECIMAL(5,2)  NULL,
  broker_pct      DECIMAL(5,2)  NULL,
  demurrage_rate  DECIMAL(15,2) NULL,
  despatch_rate   DECIMAL(15,2) NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'On hire',
  remarks         TEXT          NULL,
  UNIQUE KEY ux_charter_ref (ref_no)
) ENGINE=InnoDB;

CREATE TABLE hire_statements (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  ref_no          VARCHAR(30)   NOT NULL,
  charter_id      CHAR(24)      NOT NULL,
  period          VARCHAR(20)   NULL,
  date_from       DATE          NULL,
  date_to         DATE          NULL,
  qty             DECIMAL(12,2) NOT NULL DEFAULT 0,    -- days or quantity on hire
  off_hire        DECIMAL(12,2) NOT NULL DEFAULT 0,
  demurrage_days  DECIMAL(12,2) NOT NULL DEFAULT 0,
  despatch        DECIMAL(15,2) NOT NULL DEFAULT 0,
  additions       DECIMAL(15,2) NOT NULL DEFAULT 0,
  deductions      DECIMAL(15,2) NOT NULL DEFAULT 0,
  vatable         TINYINT(1)    NOT NULL DEFAULT 1,    -- 12% applied unless agreed otherwise
  status          VARCHAR(20)   NOT NULL DEFAULT 'Draft',
  remarks         TEXT          NULL,
  UNIQUE KEY ux_hire_ref (ref_no),
  CONSTRAINT fk_hire_charter FOREIGN KEY (charter_id) REFERENCES charters(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE voyages (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  ref_no          VARCHAR(30)   NOT NULL,
  vessel_name     VARCHAR(160)  NULL,
  charter_ref     VARCHAR(60)   NULL,
  charterer_name  VARCHAR(160)  NULL,
  agent           VARCHAR(160)  NULL,
  port_from       VARCHAR(120)  NULL,
  port_to         VARCHAR(120)  NULL,
  sailed          DATE          NULL,
  arrived         DATE          NULL,
  cargo           VARCHAR(160)  NULL,
  quantity        DECIMAL(15,3) NULL,
  freight         DECIMAL(15,2) NOT NULL DEFAULT 0,
  bunker_cost     DECIMAL(15,2) NOT NULL DEFAULT 0,
  port_cost       DECIMAL(15,2) NOT NULL DEFAULT 0,
  other_cost      DECIMAL(15,2) NOT NULL DEFAULT 0,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Open',
  remarks         TEXT          NULL,
  UNIQUE KEY ux_voyage_ref (ref_no)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6.  MONEY IN AND OUT
-- ---------------------------------------------------------------------

CREATE TABLE invoices (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  invoice_no      VARCHAR(30)   NOT NULL,       -- NS/INV-2026-0001
  inv_date        DATE          NOT NULL,
  due_date        DATE          NULL,
  client_id       CHAR(24)      NULL,
  vessel_id       CHAR(24)      NULL,
  kind            VARCHAR(60)   NULL,           -- Management fee / Charter hire / Reimbursable…
  description     TEXT          NULL,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  vatable         TINYINT(1)    NOT NULL DEFAULT 1,
  ewt_pct         DECIMAL(5,2)  NOT NULL DEFAULT 0,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Open',
  remarks         TEXT          NULL,
  UNIQUE KEY ux_invoice_no (invoice_no),
  KEY ix_inv_client (client_id),
  KEY ix_inv_date (inv_date),
  CONSTRAINT fk_inv_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL,
  CONSTRAINT fk_inv_vessel FOREIGN KEY (vessel_id) REFERENCES vessels(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE bills (                            -- supplier payables
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  bill_no         VARCHAR(30)   NOT NULL,       -- NS/BILL-2026-0001
  bill_date       DATE          NOT NULL,
  due_date        DATE          NULL,
  vendor_id       CHAR(24)      NULL,
  vessel_id       CHAR(24)      NULL,
  category        VARCHAR(60)   NULL,           -- Vessel Time Charter, Bareboat Charter, Spares…
  description     TEXT          NULL,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  vatable         TINYINT(1)    NOT NULL DEFAULT 1,
  ewt_pct         DECIMAL(5,2)  NOT NULL DEFAULT 0,
  owner_account   TINYINT(1)    NOT NULL DEFAULT 0,   -- charged to the principal's funds
  owner_id        CHAR(24)      NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Open',
  remarks         TEXT          NULL,
  UNIQUE KEY ux_bill_no (bill_no),
  KEY ix_bill_vendor (vendor_id),
  KEY ix_bill_date (bill_date),
  CONSTRAINT fk_bill_vendor FOREIGN KEY (vendor_id) REFERENCES vendors(id) ON DELETE SET NULL,
  CONSTRAINT fk_bill_vessel FOREIGN KEY (vessel_id) REFERENCES vessels(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- daily expenses and revolving fund
CREATE TABLE expenses (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  ref_no          VARCHAR(30)   NOT NULL,       -- NS/EXP-2026-0001
  exp_date        DATE          NOT NULL,
  fund_id         CHAR(24)      NULL,           -- bank / cash account it was paid from
  or_no           VARCHAR(40)   NULL,
  payee           VARCHAR(160)  NULL,
  category        VARCHAR(80)   NULL,           -- PPA, PCG, BOQ, provisions…
  requested_by    VARCHAR(120)  NULL,
  description     TEXT          NULL,
  -- cost centre
  charge_type     VARCHAR(40)   NULL,           -- Vessel / Shore office / Principal / Project / Voyage / Charterer
  charge_ref      CHAR(24)      NULL,
  -- whose money bears it
  account_charged VARCHAR(60)   NULL,           -- Principal's revolving fund / Advanced by NAVI / NAVI own account…
  account_ref     CHAR(24)      NULL,           -- the party charged, where recoverable
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  vat             DECIMAL(15,2) NOT NULL DEFAULT 0,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Recorded',
  UNIQUE KEY ux_exp_ref (ref_no),
  KEY ix_exp_date (exp_date),
  KEY ix_exp_charge (charge_type, charge_ref),
  KEY ix_exp_account (account_ref)
) ENGINE=InnoDB;

CREATE TABLE banks (                            -- bank and cash accounts, incl. revolving funds
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  name            VARCHAR(160)  NOT NULL,
  kind            VARCHAR(40)   NULL,           -- Current / Savings / Petty cash / Revolving fund
  bank_name       VARCHAR(160)  NULL,
  branch          VARCHAR(160)  NULL,
  account_no      VARCHAR(60)   NULL,
  currency        CHAR(3)       NOT NULL DEFAULT 'PHP',
  opening_bal     DECIMAL(15,2) NOT NULL DEFAULT 0,
  remarks         TEXT          NULL
) ENGINE=InnoDB;

CREATE TABLE cash_tx (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  ref_no          VARCHAR(30)   NULL,
  tx_date         DATE          NOT NULL,
  kind            VARCHAR(20)   NOT NULL,       -- Receipt / Payment / Transfer
  bank_id         CHAR(24)      NOT NULL,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  invoice_id      CHAR(24)      NULL,
  bill_id         CHAR(24)      NULL,
  expense_id      CHAR(24)      NULL,
  vessel_id       CHAR(24)      NULL,
  description     VARCHAR(255)  NULL,
  KEY ix_cash_date (tx_date),
  KEY ix_cash_bank (bank_id),
  CONSTRAINT fk_cash_bank FOREIGN KEY (bank_id) REFERENCES banks(id),
  CONSTRAINT fk_cash_exp FOREIGN KEY (expense_id) REFERENCES expenses(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- principal / owner trust accounts
CREATE TABLE owner_tx (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  client_id       CHAR(24)      NOT NULL,
  tx_date         DATE          NOT NULL,
  kind            VARCHAR(40)   NOT NULL,       -- Funding received / Refund to principal
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  bank_id         CHAR(24)      NULL,
  description     VARCHAR(255)  NULL,
  KEY ix_ownertx_client (client_id),
  CONSTRAINT fk_ownertx_client FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7.  BUDGETS, ASSETS, INSURANCE, PROJECTS, JOURNALS, FILINGS
-- ---------------------------------------------------------------------

CREATE TABLE budgets (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  vessel_id       CHAR(24)      NOT NULL,
  year            SMALLINT      NOT NULL,
  head            VARCHAR(80)   NOT NULL,       -- Crew wages, Charter hire, Survey and inspection…
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  UNIQUE KEY ux_budget (vessel_id, year, head),
  CONSTRAINT fk_budget_vessel FOREIGN KEY (vessel_id) REFERENCES vessels(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE assets (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  name            VARCHAR(160)  NOT NULL,
  category        VARCHAR(60)   NULL,
  vessel_id       CHAR(24)      NULL,
  acquired        DATE          NULL,
  cost            DECIMAL(15,2) NOT NULL DEFAULT 0,
  salvage         DECIMAL(15,2) NOT NULL DEFAULT 0,
  life_years      DECIMAL(5,2)  NOT NULL DEFAULT 5,
  status          VARCHAR(20)   NOT NULL DEFAULT 'In use',
  remarks         TEXT          NULL,
  CONSTRAINT fk_asset_vessel FOREIGN KEY (vessel_id) REFERENCES vessels(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE insurance (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  policy_no       VARCHAR(60)   NOT NULL,
  cover           VARCHAR(60)   NULL,           -- H&M, P&I, TPL, crew accident…
  vessel_id       CHAR(24)      NULL,
  insurer_id      CHAR(24)      NULL,
  date_from       DATE          NULL,
  date_to         DATE          NULL,
  sum_insured     DECIMAL(15,2) NOT NULL DEFAULT 0,
  premium         DECIMAL(15,2) NOT NULL DEFAULT 0,
  deductible      DECIMAL(15,2) NOT NULL DEFAULT 0,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Active',
  file_name       VARCHAR(255)  NULL,           -- uploaded policy document
  file_path       VARCHAR(500)  NULL,
  remarks         TEXT          NULL,
  KEY ix_ins_expiry (date_to),
  CONSTRAINT fk_ins_vessel FOREIGN KEY (vessel_id) REFERENCES vessels(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE projects (                          -- drydock and repair
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  ref_no          VARCHAR(30)   NOT NULL,
  title           VARCHAR(200)  NOT NULL,
  vessel_id       CHAR(24)      NULL,
  yard            VARCHAR(160)  NULL,
  date_from       DATE          NULL,
  date_to         DATE          NULL,
  budget          DECIMAL(15,2) NOT NULL DEFAULT 0,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Planned',
  remarks         TEXT          NULL,
  UNIQUE KEY ux_project_ref (ref_no),
  CONSTRAINT fk_proj_vessel FOREIGN KEY (vessel_id) REFERENCES vessels(id) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE journals (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  ref_no          VARCHAR(30)   NOT NULL,
  jv_date         DATE          NOT NULL,
  memo            VARCHAR(255)  NULL,
  UNIQUE KEY ux_jv_ref (ref_no)
) ENGINE=InnoDB;

CREATE TABLE journal_lines (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  journal_id      CHAR(24)      NOT NULL,
  coa_id          CHAR(24)      NULL,
  vessel_id       CHAR(24)      NULL,
  debit           DECIMAL(15,2) NOT NULL DEFAULT 0,
  credit          DECIMAL(15,2) NOT NULL DEFAULT 0,
  memo            VARCHAR(255)  NULL,
  KEY ix_jl_journal (journal_id),
  CONSTRAINT fk_jl_journal FOREIGN KEY (journal_id) REFERENCES journals(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE filings (                           -- BIR, SSS, PhilHealth, Pag-IBIG returns
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  form            VARCHAR(40)   NOT NULL,        -- 1601-C, 2550Q, R-5, RF-1, MCRF
  period          VARCHAR(20)   NOT NULL,
  due_date        DATE          NULL,
  filed_date      DATE          NULL,
  amount          DECIMAL(15,2) NOT NULL DEFAULT 0,
  reference       VARCHAR(80)   NULL,
  status          VARCHAR(20)   NOT NULL DEFAULT 'Due',
  remarks         TEXT          NULL,
  KEY ix_filing_due (due_date)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8.  USERS AND AUDIT
--     Bank and cash edits are gated by the management approval code.
-- ---------------------------------------------------------------------

CREATE TABLE users (
  id              CHAR(24)      NOT NULL PRIMARY KEY,
  username        VARCHAR(60)   NOT NULL,
  full_name       VARCHAR(160)  NOT NULL,
  email           VARCHAR(160)  NULL,
  pass_hash       VARCHAR(255)  NOT NULL,       -- password_hash(), never plain text
  role            ENUM('admin','accountant','clerk','viewer') NOT NULL DEFAULT 'clerk',
  active          TINYINT(1)    NOT NULL DEFAULT 1,
  last_login      DATETIME      NULL,
  created_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY ux_user (username)
) ENGINE=InnoDB;

CREATE TABLE audit_log (
  id              BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
  at              TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  user_id         CHAR(24)      NULL,
  username        VARCHAR(60)   NULL,
  action          VARCHAR(40)   NOT NULL,       -- create / update / delete / approve / print
  table_name      VARCHAR(40)   NOT NULL,
  record_id       CHAR(24)      NULL,
  before_json     JSON          NULL,
  after_json      JSON          NULL,
  ip              VARCHAR(45)   NULL,
  KEY ix_audit_at (at),
  KEY ix_audit_rec (table_name, record_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9.  VIEWS — the figures the portal reports
-- ---------------------------------------------------------------------

-- principal trust balance: funding received less disbursements.
-- A negative balance is the amount to bill that principal.
CREATE OR REPLACE VIEW v_principal_balance AS
SELECT c.id AS client_id, c.name,
       COALESCE(f.funded,0)   AS funded,
       COALESCE(d.disbursed,0) + COALESCE(e.disbursed,0) AS disbursed,
       COALESCE(f.funded,0) - COALESCE(d.disbursed,0) - COALESCE(e.disbursed,0) AS balance
FROM clients c
LEFT JOIN (SELECT client_id,
                  SUM(CASE WHEN kind='Funding received' THEN amount
                           WHEN kind='Refund to principal' THEN -amount ELSE 0 END) AS funded
           FROM owner_tx GROUP BY client_id) f ON f.client_id=c.id
LEFT JOIN (SELECT owner_id, SUM(amount) AS disbursed
           FROM bills WHERE owner_account=1 GROUP BY owner_id) d ON d.owner_id=c.id
LEFT JOIN (SELECT account_ref, SUM(amount+vat) AS disbursed
           FROM expenses WHERE account_ref IS NOT NULL GROUP BY account_ref) e ON e.account_ref=c.id;

-- bank and revolving fund balances
CREATE OR REPLACE VIEW v_bank_balance AS
SELECT b.id AS bank_id, b.name, b.kind,
       b.opening_bal
       + COALESCE(SUM(CASE WHEN t.kind='Receipt' THEN t.amount
                           WHEN t.kind='Payment' THEN -t.amount ELSE 0 END),0) AS balance
FROM banks b LEFT JOIN cash_tx t ON t.bank_id=b.id
GROUP BY b.id, b.name, b.kind, b.opening_bal;

-- ---------------------------------------------------------------------
-- 10. SEED — company settings, numbering and statutory rates
--     Rates as at September 2026; update when a circular changes them.
-- ---------------------------------------------------------------------

INSERT INTO settings (skey, sval) VALUES
 ('company',       'NAVI SHIPPING OPC'),
 ('address',       '18 Leo St., Veraville Homes 1, Almanza Uno, Las Piñas City, NCR 1750, Philippines'),
 ('phone',         '+63 927 621 2975 / +63 2 8894 3101'),
 ('email',         'operations@navishipping.com.ph'),
 ('web',           'www.navishipping.com.ph'),
 ('vat',           '12'),
 ('ewt_service',   '2'),
 ('ewt_rental',    '5'),
 ('sss_total',     '15'),      -- total contribution rate, per cent of MSC
 ('sss_ee_share',  '5'),       -- employee share
 ('sss_msc_min',   '5000'),
 ('sss_msc_max',   '35000'),
 ('ec_low',        '10'),      -- EC below 15,000 MSC
 ('ec_high',       '30'),
 ('ph_rate',       '5'),       -- PhilHealth, shared equally
 ('ph_floor',      '10000'),
 ('ph_ceil',       '100000'),
 ('pagibig_cap',   '10000'),
 ('pagibig_ee',    '2'),
 ('pagibig_er',    '2'),
 ('bonus_exempt',  '90000'),   -- 13th month and benefits, tax-exempt ceiling
 ('contract_pages','8'),
 ('ccn_last',      '53'),      -- last crew control number issued
 ('scn_start',     '3')        -- shore series begins at the third person
ON DUPLICATE KEY UPDATE sval=VALUES(sval);

INSERT INTO counters (prefix, year, last_no) VALUES
 ('INV',  2026, 0), ('BILL', 2026, 0), ('EXP', 2026, 0), ('COE', 2026, 0),
 ('PV',   2026, 0), ('CR',   2026, 0), ('JV',  2026, 0), ('CH',  2026, 0),
 ('HS',   2026, 0), ('PR',   2026, 0), ('PRJ', 2026, 0), ('VOY', 2026, 0)
ON DUPLICATE KEY UPDATE last_no=VALUES(last_no);

-- The first administrator. Replace the hash with one from
-- password_hash('your password', PASSWORD_DEFAULT) before going live.
INSERT INTO users (id, username, full_name, email, pass_hash, role) VALUES
 ('usr0000000000000000admin','admin','System Administrator','operations@navishipping.com.ph',
  '$2y$12$REPLACE.THIS.WITH.A.REAL.BCRYPT.HASH.000000000000000000000','admin')
ON DUPLICATE KEY UPDATE username=VALUES(username);
