-- ============================================================
-- NS FINANCE — readable views of fin_records
-- One view per kind of record, each field in its own column, and
-- vessel / principal / supplier IDs shown as names.
-- The portal still saves into fin_records; these views are read-only
-- and always up to date. Access follows the same fin_staff rules.
--
-- Paste into the NS - FINANCE project -> SQL Editor -> New query -> Run
-- Safe to run more than once.
-- ============================================================

-- name of a vessel / client / supplier / bank / account from its id
create or replace function fin_name(coll text, rec_id text) returns text
language sql stable security invoker set search_path = public as $$
  select coalesce(data->>'name', data->>'code') from fin_records
  where collection = coll and id = rec_id limit 1;
$$;

-- ---------- overview ----------
create or replace view fin_summary with (security_invoker = on) as
select collection, count(*) as records, max(updated_at) as last_change
from fin_records group by collection order by collection;

-- ---------- master data ----------
create or replace view fin_vessels with (security_invoker = on) as
select id,
  data->>'name' as name, data->>'type' as type, data->>'status' as status,
  data->>'basis' as engagement_basis, fin_name('clients', data->>'owner') as principal,
  data->>'marina' as official_no, data->>'callSign' as call_sign, data->>'flag' as flag,
  data->>'homeport' as port_of_registry, data->>'grt' as grt, data->>'nrt' as nrt,
  data->>'kw' as engine_kw, data->>'loa' as loa_m, data->>'breadth' as breadth_m, data->>'depth' as depth_m,
  data->>'yearBuilt' as year_built, data->>'builder' as builder, data->>'klass' as class,
  data->>'csma' as csma_date, data->>'mgmtFee' as mgmt_fee_monthly, data->>'crewFee' as crew_fee_monthly,
  data->>'remarks' as remarks, updated_at
from fin_records where collection = 'vessels' order by pos;

create or replace view fin_clients with (security_invoker = on) as
select id,
  data->>'name' as name, data->>'kind' as relationship, data->>'contact' as contact_person,
  data->>'email' as email, data->>'phone' as phone, data->>'tin' as tin,
  data->>'terms' as terms_days, data->>'address' as address, updated_at
from fin_records where collection = 'clients' order by data->>'name';

create or replace view fin_vendors with (security_invoker = on) as
select id,
  data->>'name' as name, data->>'cat' as category, data->>'contact' as contact_person,
  data->>'phone' as phone, data->>'email' as email, data->>'tin' as tin,
  data->>'vatReg' as vat_registered, data->>'terms' as terms_days, updated_at
from fin_records where collection = 'vendors' order by data->>'name';

create or replace view fin_employees with (security_invoker = on) as
select id,
  data->>'empNo' as emp_no, data->>'ccn' as ccn, data->>'name' as name, data->>'kind' as kind,
  data->>'position' as position, fin_name('vessels', data->>'vessel') as vessel,
  data->>'status' as status, data->>'payBasis' as pay_basis, data->>'basic' as basic_monthly,
  data->>'dailyRate' as daily_rate, data->>'allow' as allowance, data->>'otFixed' as ot_fixed,
  data->>'hired' as hired, data->>'contractEnd' as contract_end,
  data->>'tin' as tin, data->>'sss' as sss_no, data->>'phil' as philhealth_no, data->>'pag' as pagibig_no,
  data->>'bank' as payout_bank, jsonb_array_length(coalesce(data->'docs','[]'::jsonb)) as files_on_record,
  data->>'remarks' as remarks, updated_at
from fin_records where collection = 'employees' order by data->>'name';

create or replace view fin_chart_of_accounts with (security_invoker = on) as
select id, data->>'code' as code, data->>'name' as name, data->>'type' as type, updated_at
from fin_records where collection = 'coa' order by data->>'code';

create or replace view fin_wage_scale with (security_invoker = on) as
select id,
  coalesce(fin_name('vessels', data->>'vessel'), 'All vessels') as vessel,
  data->>'position' as position, data->>'licence' as licence, data->>'basic' as basic,
  data->>'otFixed' as ot_fixed, data->>'allowance' as allowance, data->>'nightDiff' as night_diff,
  data->>'leavePay' as leave_pay, data->>'thirteenth' as thirteenth_month, data->>'others' as others,
  data->>'effective' as effective, updated_at
from fin_records where collection = 'wagescale' order by 2, data->>'position';

-- ---------- commercial ----------
create or replace view fin_charters with (security_invoker = on) as
select id,
  data->>'no' as ref_no, data->>'type' as type, data->>'vessel' as vessel,
  data->>'ownerName' as owner, data->>'charterer' as charterer, data->>'status' as status,
  data->>'cpDate' as cp_date, data->>'from' as delivery, data->>'to' as redelivery,
  data->>'form' as cp_form, data->>'rate' as rate, data->>'basis' as rate_basis,
  data->>'route' as trade_route, data->>'remarks' as remarks, updated_at
from fin_records where collection = 'charters' order by pos;

create or replace view fin_hire_statements with (security_invoker = on) as
select id,
  data->>'no' as ref_no, data->>'period' as period, data->>'from' as period_from, data->>'to' as period_to,
  (select c.data->>'no' from fin_records c where c.collection = 'charters' and c.id = r.data->>'charter') as charter_ref,
  (select c.data->>'vessel' from fin_records c where c.collection = 'charters' and c.id = r.data->>'charter') as vessel,
  data->>'status' as status, updated_at
from fin_records r where collection = 'hires' order by pos;

create or replace view fin_voyages with (security_invoker = on) as
select id,
  data->>'no' as ref_no, data->>'vessel' as vessel, data->>'charterer' as charterer,
  data->>'from' as port_from, data->>'to' as port_to, data->>'sailed' as sailed, data->>'arrived' as arrived,
  data->>'cargo' as cargo, data->>'qty' as quantity, data->>'freight' as freight,
  data->>'fuelLtr' as fuel_litres, data->>'fuelCost' as fuel_cost, data->>'portDues' as port_dues,
  data->>'status' as status, updated_at
from fin_records where collection = 'voyages' order by pos;

-- ---------- money in and out ----------
create or replace view fin_invoices with (security_invoker = on) as
select id,
  data->>'no' as invoice_no, data->>'date' as date, data->>'due' as due,
  fin_name('clients', data->>'client') as client, fin_name('vessels', data->>'vessel') as vessel,
  data->>'kind' as kind, data->>'desc' as description, data->>'amount' as amount,
  data->>'vatable' as vatable, data->>'ewt' as ewt_pct, data->>'status' as status, updated_at
from fin_records where collection = 'invoices' order by data->>'date' desc;

create or replace view fin_bills with (security_invoker = on) as
select id,
  data->>'no' as bill_no, data->>'date' as date, data->>'due' as due,
  fin_name('vendors', data->>'vendor') as supplier, fin_name('vessels', data->>'vessel') as vessel,
  data->>'cat' as category, data->>'siNo' as supplier_invoice_no, data->>'poNo' as po_no,
  data->>'desc' as description, data->>'amount' as amount, data->>'vatable' as vatable,
  data->>'ewt' as ewt_pct, data->>'ownerAcct' as charged_to_principal, data->>'status' as status, updated_at
from fin_records where collection = 'bills' order by data->>'date' desc;

create or replace view fin_expenses with (security_invoker = on) as
select id,
  data->>'no' as ref_no, data->>'date' as date, fin_name('banks', data->>'fund') as paid_from,
  data->>'orNo' as or_no, data->>'payee' as paid_to, data->>'cat' as category,
  data->>'by' as requested_by, data->>'desc' as particulars,
  data->>'chargeType' as charge_to, data->>'acct' as account_charged,
  data->>'amount' as amount, data->>'vat' as vat, data->>'status' as status, updated_at
from fin_records where collection = 'expenses' order by data->>'date' desc;

create or replace view fin_banks with (security_invoker = on) as
select id,
  data->>'name' as name, data->>'bank' as bank, data->>'acctNo' as account_no, data->>'kind' as type,
  data->>'opening' as opening_balance, fin_name('clients', data->>'client') as held_for_principal, updated_at
from fin_records where collection = 'banks' order by data->>'name';

create or replace view fin_cash_transactions with (security_invoker = on) as
select id,
  data->>'no' as ref_no, data->>'date' as date, data->>'kind' as kind,
  fin_name('banks', data->>'bank') as bank_account, data->>'amount' as amount,
  data->>'desc' as description, updated_at
from fin_records where collection = 'cashtx' order by data->>'date' desc;

create or replace view fin_owner_transactions with (security_invoker = on) as
select id,
  data->>'date' as date, fin_name('clients', data->>'client') as principal, data->>'kind' as kind,
  data->>'amount' as amount, data->>'desc' as description, updated_at
from fin_records where collection = 'ownertx' order by data->>'date' desc;

-- ---------- people ----------
create or replace view fin_payrolls with (security_invoker = on) as
select id,
  data->>'no' as ref_no, data->>'period' as period, data->>'cutoff' as cutoff, data->>'kind' as kind,
  coalesce(fin_name('vessels', data->>'vessel'), data->>'scope', 'All vessels') as vessel,
  jsonb_array_length(coalesce(data->'lines','[]'::jsonb)) as employees_paid,
  data->>'status' as status, updated_at
from fin_records where collection = 'payrolls' order by data->>'period' desc;

create or replace view fin_contracts with (security_invoker = on) as
select id,
  data->>'no' as contract_no, data->>'ccn' as ccn, data->>'name' as crew_name,
  data->>'position' as position, data->>'status' as status, data->>'notarised' as notarised, updated_at
from fin_records where collection = 'contracts' order by data->>'no';

-- ---------- control ----------
create or replace view fin_projects with (security_invoker = on) as
select id,
  data->>'no' as ref_no, data->>'title' as title, fin_name('vessels', data->>'vessel') as vessel,
  data->>'kind' as kind, fin_name('vendors', data->>'yard') as yard, data->>'start' as start_date,
  data->>'end' as end_date, data->>'quoted' as quoted, data->>'status' as status, updated_at
from fin_records where collection = 'projects' order by pos;

create or replace view fin_assets with (security_invoker = on) as
select id,
  data->>'name' as name, fin_name('vessels', data->>'vessel') as vessel, data->>'cat' as category,
  data->>'acquired' as acquired, data->>'cost' as cost, data->>'salvage' as salvage,
  data->>'life' as life_years, data->>'status' as status, updated_at
from fin_records where collection = 'assets' order by data->>'name';

create or replace view fin_insurance with (security_invoker = on) as
select id,
  data->>'policyNo' as policy_no, data->>'kind' as cover, fin_name('vessels', data->>'vessel') as vessel,
  fin_name('vendors', data->>'insurer') as insurer, data->>'from' as valid_from, data->>'to' as valid_to,
  data->>'sumInsured' as sum_insured, data->>'premium' as premium, data->>'deductible' as deductible,
  data->>'status' as status, updated_at
from fin_records where collection = 'insurance' order by data->>'to';

create or replace view fin_budgets with (security_invoker = on) as
select id,
  fin_name('vessels', data->>'vessel') as vessel, data->>'year' as year, data->>'head' as budget_head,
  data->>'amount' as amount, updated_at
from fin_records where collection = 'budgets' order by 2, 3;

create or replace view fin_journals with (security_invoker = on) as
select id,
  data->>'no' as ref_no, data->>'date' as date, fin_name('coa', data->>'dr') as debit_account,
  fin_name('coa', data->>'cr') as credit_account, data->>'amount' as amount, data->>'memo' as memo, updated_at
from fin_records where collection = 'journals' order by data->>'date' desc;

create or replace view fin_filings with (security_invoker = on) as
select id,
  data->>'form' as form, data->>'period' as period, data->>'due' as due, data->>'filed' as filed,
  data->>'amount' as amount, data->>'status' as status, updated_at
from fin_records where collection = 'filings' order by data->>'due';
