-- ============================================================
-- NS FLEET — readable views of fleet_records
-- One view per kind of record, each field in its own column, and
-- vessel IDs shown as vessel names.
-- The fleet system still saves into fleet_records; these views are
-- read-only and always up to date. Access follows the fleet_staff rules.
--
-- Paste into the NS FLEET project -> SQL Editor -> New query -> Run
-- (run supabase-fleet-setup.sql first). Safe to run more than once.
-- ============================================================

-- name of a record (vessel, audit, ...) from its id
create or replace function fleet_name(coll text, rec_id text) returns text
language sql stable security invoker set search_path = public as $$
  select coalesce(data->>'name', data->>'refNo', data->>'code') from fleet_records
  where collection = coll and id = rec_id limit 1;
$$;

-- ---------- overview ----------
create or replace view fleet_summary with (security_invoker = on) as
select collection, count(*) as records, max(updated_at) as last_change
from fleet_records group by collection order by collection;

-- ---------- fleet operations ----------
create or replace view fleet_vessels with (security_invoker = on) as
select id,
  data->>'name' as name, data->>'type' as type, data->>'mgmt' as management_basis,
  data->>'status' as status, data->>'owner' as registered_owner, data->>'homePort' as home_port,
  data->>'marinaReg' as marina_reg_no, data->>'officialNo' as official_no, data->>'callSign' as call_sign,
  data->>'built' as year_built, data->>'builder' as builder, data->>'flag' as flag,
  data->>'grt' as grt, data->>'nrt' as nrt, data->>'dwt' as dwt, data->>'loa' as loa_m,
  data->>'breadth' as breadth_m, data->>'depth' as depth_m, data->>'draft' as draft_m,
  data->>'engineMake' as main_engine, data->>'enginePower' as engine_kw, data->>'engineHP' as engine_hp,
  data->>'gensets' as generators, data->>'tradeArea' as trading_area, data->>'manning' as safe_manning,
  data->>'charterer' as present_charterer, data->>'remarks' as remarks, updated_at
from fleet_records where collection = 'vessels' order by data->>'name';

create or replace view fleet_daily_reports with (security_invoker = on) as
select id,
  data->>'refNo' as report_no, data->>'date' as date, fleet_name('vessels', data->>'vessel') as vessel,
  data->>'reportType' as report_type, data->>'status' as status, data->>'location' as position,
  data->>'activity' as activity, data->>'cargo' as cargo, data->>'runHours' as me_running_hours,
  data->>'fuelROB' as fuel_rob_l, data->>'luboilROB' as lube_rob_l, data->>'waterROB' as water_rob_l,
  data->>'crewOnboard' as crew_on_board, data->>'weather' as weather, data->>'reportedBy' as reported_by,
  data->>'remarks' as remarks, updated_at
from fleet_records where collection = 'dailyreports' order by data->>'date' desc;

-- ---------- crew ----------
create or replace view fleet_crew with (security_invoker = on) as
select id,
  data->>'ccn' as ccn, data->>'name' as name, data->>'rank' as rank,
  fleet_name('vessels', data->>'vessel') as vessel, data->>'status' as status,
  data->>'contact' as contact, data->>'dob' as date_of_birth, data->>'signOn' as sign_on,
  data->>'contractEnd' as contract_end, data->>'reliever' as reliever,
  data->>'sirbNo' as sirb_no, data->>'sirbExp' as sirb_expiry, data->>'licenseNo' as licence_no,
  data->>'licenseExp' as licence_expiry, data->>'medicalExp' as medical_expiry, data->>'sidExp' as sid_expiry,
  data->>'emgName' as emergency_contact, data->>'emgRel' as emergency_relationship,
  data->>'emgContact' as emergency_number, data->>'address' as address, data->>'remarks' as remarks, updated_at
from fleet_records where collection = 'crew' order by data->>'name';

create or replace view fleet_crew_changes with (security_invoker = on) as
select id,
  data->>'refNo' as ref_no, data->>'date' as date, fleet_name('vessels', data->>'vessel') as vessel,
  data->>'crewName' as seafarer, data->>'rank' as rank, data->>'movement' as movement,
  data->>'port' as port, data->>'relieverFor' as reliever_for, data->>'remarks' as remarks, updated_at
from fleet_records where collection = 'crewchange' order by data->>'date' desc;

-- ---------- planned maintenance ----------
create or replace view fleet_components with (security_invoker = on) as
select id,
  data->>'code' as code, data->>'name' as component, fleet_name('vessels', data->>'vessel') as vessel,
  data->>'location' as location, data->>'maker' as maker, data->>'model' as model, data->>'serial' as serial_no,
  data->>'criticality' as criticality, data->>'runHours' as running_hours, data->>'hoursDate' as hours_as_of,
  data->>'manualRef' as manual_ref, data->>'remarks' as remarks, updated_at
from fleet_records where collection = 'components' order by 4, data->>'code';

create or replace view fleet_maintenance_jobs with (security_invoker = on) as
select id,
  data->>'jobNo' as job_no, fleet_name('vessels', data->>'vessel') as vessel, data->>'component' as component,
  data->>'job' as job, data->>'basis' as interval_basis, data->>'intervalDays' as interval_days,
  data->>'intervalHours' as interval_hours, data->>'lastDone' as last_done, data->>'dueDate' as next_due,
  data->>'dueHours' as next_due_hours, data->>'criticality' as criticality, data->>'responsible' as responsible,
  data->>'status' as status, data->>'sparesNeeded' as spares, data->>'workDone' as work_done, updated_at
from fleet_records where collection = 'pmsjobs' order by data->>'dueDate';

create or replace view fleet_defects with (security_invoker = on) as
select id,
  data->>'refNo' as defect_no, fleet_name('vessels', data->>'vessel') as vessel, data->>'equipment' as equipment,
  data->>'description' as description, data->>'reported' as reported, data->>'reportedBy' as reported_by,
  data->>'severity' as severity, data->>'affectsClass' as affects_class, data->>'targetDate' as target_date,
  data->>'status' as status, data->>'repairBy' as repaired_by, data->>'closedDate' as closed,
  data->>'cost' as repair_cost, data->>'remarks' as remarks, updated_at
from fleet_records where collection = 'defects' order by data->>'reported' desc;

-- ---------- procurement ----------
create or replace view fleet_requisitions with (security_invoker = on) as
select id,
  data->>'reqNo' as req_no, data->>'date' as date, fleet_name('vessels', data->>'vessel') as vessel,
  data->>'category' as category, data->>'item' as item, data->>'quantity' as quantity, data->>'unit' as unit,
  data->>'urgency' as urgency, data->>'requestedBy' as requested_by, data->>'supplier' as supplier,
  data->>'poNo' as po_no, data->>'estCost' as est_cost, data->>'actualCost' as actual_cost,
  data->>'status' as status, data->>'approvedBy' as approved_by, data->>'deliveryPort' as delivery_port,
  data->>'deliveredDate' as delivered, updated_at
from fleet_records where collection = 'requisitions' order by data->>'date' desc;

-- ---------- safety and ISM ----------
create or replace view fleet_drills with (security_invoker = on) as
select id,
  data->>'refNo' as record_no, data->>'date' as date, fleet_name('vessels', data->>'vessel') as vessel,
  data->>'drill' as drill, data->>'scenario' as scenario, data->>'participants' as participants,
  data->>'duration' as duration_min, data->>'conductedBy' as conducted_by,
  data->>'deficiencies' as deficiencies, data->>'actions' as actions, data->>'nextDue' as next_due, updated_at
from fleet_records where collection = 'drills' order by data->>'date' desc;

create or replace view fleet_incidents with (security_invoker = on) as
select id,
  data->>'refNo' as report_no, data->>'date' as date, fleet_name('vessels', data->>'vessel') as vessel,
  data->>'type' as type, data->>'severity' as severity, data->>'title' as title,
  data->>'description' as what_happened, data->>'rootCause' as root_cause, data->>'corrective' as corrective_action,
  data->>'dpaNotified' as dpa_notified, data->>'authority' as reported_to, data->>'targetDate' as target_close,
  data->>'status' as status, data->>'closedDate' as closed, updated_at
from fleet_records where collection = 'incidents' order by data->>'date' desc;

create or replace view fleet_audits with (security_invoker = on) as
select id,
  data->>'refNo' as ref_no, data->>'date' as date, data->>'type' as type,
  coalesce(fleet_name('vessels', data->>'vessel'), 'Office') as vessel, data->>'auditor' as auditor,
  data->>'ncr' as non_conformities, data->>'observations' as observations, data->>'targetDate' as target_close,
  data->>'status' as status, data->>'closedDate' as closed, data->>'nextDue' as next_audit_due, updated_at
from fleet_records where collection = 'audits' order by data->>'date' desc;

create or replace view fleet_findings with (security_invoker = on) as
select id,
  data->>'refNo' as finding_no, fleet_name('audits', data->>'audit') as audit,
  coalesce(fleet_name('vessels', data->>'vessel'), 'Office') as vessel, data->>'category' as category,
  data->>'clause' as reference, data->>'description' as finding, data->>'responsible' as responsible,
  data->>'targetDate' as target_close, data->>'status' as status, data->>'verifiedBy' as verified_by,
  data->>'closedDate' as closed, updated_at
from fleet_records where collection = 'findings' order by data->>'targetDate';

-- ---------- certificates ----------
create or replace view fleet_certificates with (security_invoker = on) as
select id,
  data->>'holder' as held_by, coalesce(fleet_name('vessels', data->>'vessel'), 'Company') as vessel,
  data->>'name' as certificate, data->>'certNo' as cert_no, data->>'issuer' as issued_by,
  data->>'issued' as issued, data->>'expiry' as expiry, data->>'surveyDue' as survey_due,
  data->>'renewalOwner' as renewal_by, (data->'file') is not null as has_scan,
  data->>'remarks' as remarks, updated_at
from fleet_records where collection = 'certificates' order by data->>'expiry';

-- ---------- voyages ----------
create or replace view fleet_voyages with (security_invoker = on) as
select id,
  data->>'voyageNo' as voyage_no, fleet_name('vessels', data->>'vessel') as vessel,
  data->>'charterType' as employment, data->>'charterer' as charterer, data->>'cargo' as cargo,
  data->>'cargoQty' as cargo_qty, data->>'loadPort' as load_port, data->>'dischPort' as discharge_port,
  data->>'atd' as departed, data->>'ata' as arrived, data->>'steamHours' as steaming_hours,
  data->>'distance' as distance_nm, data->>'speed' as speed_kn, data->>'revenue' as revenue,
  data->>'fuelCost' as fuel_cost, data->>'portCharges' as port_charges, data->>'otherCost' as other_cost,
  data->>'status' as status, updated_at
from fleet_records where collection = 'voyages' order by data->>'atd' desc;

-- ---------- fuel ----------
create or replace view fleet_bunkers with (security_invoker = on) as
select id,
  data->>'refNo' as ref_no, data->>'date' as date, data->>'time' as time,
  fleet_name('vessels', data->>'vessel') as vessel, data->>'grade' as grade, data->>'port' as port,
  data->>'supplier' as supplier, data->>'bdn' as bdn_no, data->>'litres' as litres,
  data->>'price' as price_per_litre, data->>'robAfter' as rob_after, data->>'receivedBy' as received_by, updated_at
from fleet_records where collection = 'bunkers' order by data->>'date' desc;

create or replace view fleet_engines with (security_invoker = on) as
select id,
  fleet_name('vessels', data->>'vessel') as vessel, data->>'unit' as engine, data->>'maker' as maker,
  data->>'model' as model, data->>'serial' as serial_no, data->>'powerKW' as power_kw, data->>'powerHP' as power_hp,
  data->>'rateSea' as rate_sea_lph, data->>'ratePort' as rate_port_lph, data->>'tolerance' as tolerance_pct,
  data->>'runHours' as running_hours, updated_at
from fleet_records where collection = 'engines' order by 2, data->>'unit';

create or replace view fleet_fuel_log with (security_invoker = on) as
select id,
  data->>'refNo' as ref_no, data->>'date' as date, fleet_name('vessels', data->>'vessel') as vessel,
  data->>'voyage' as voyage, jsonb_array_length(coalesce(data->'rows','[]'::jsonb)) as engines_reported, updated_at
from fleet_records where collection = 'fuellog' order by data->>'date' desc;
