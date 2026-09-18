-- ============================================================
-- NAVI Crewing System — readable views of navi_records
-- Shows each crew member / vessel / document as normal columns
-- (the app itself still saves into navi_records; these are read-only views).
-- Paste into Supabase Dashboard -> SQL Editor -> New query -> Run
-- Safe to run more than once.
-- ============================================================

create or replace view crew_list with (security_invoker = on) as
select
  id,
  data->>'crewControlNo'       as crew_control_no,
  data->>'crewName'            as crew_name,
  data->>'vessel'              as vessel,
  data->>'position'            as position,
  data->>'status'              as status,
  data->>'contractType'        as contract_type,
  data->>'dob'                 as dob,
  data->>'nationality'         as nationality,
  data->>'contactNo'           as contact_no,
  data->>'address'             as address,
  data->>'passportNo'          as passport_no,
  data->>'sirbNo'              as sirb_no,
  data->>'sirbExpiry'          as sirb_expiry,
  data->>'licenseHold'         as license_hold,
  data->>'licenseRequired'     as license_required,
  data->>'embarkDate'          as embark_date,
  data->>'embarkPort'          as embark_port,
  data->>'coeEnd'              as coe_end,
  data->>'extEnd'              as ext_end,
  data->>'actualDisembarkDate' as actual_disembark_date,
  data->>'disembarkPort'       as disembark_port,
  data->>'nextOfKin'           as next_of_kin,
  data->>'nextOfKinContact'    as next_of_kin_contact,
  data->>'relieverName'        as reliever_name,
  data->>'relieverContact'     as reliever_contact,
  data->>'relieverLicense'     as reliever_license,
  data->>'relieverStatus'      as reliever_status,
  data->>'nfr'                 as nfr,
  data->>'nfrReason'           as nfr_reason,
  data->>'illness'             as illness,
  data->>'illnessNotes'        as illness_notes,
  data->>'incidentCount'       as incident_count,
  data->>'accidentCount'       as accident_count,
  data->>'remarks'             as remarks,
  jsonb_array_length(coalesce(data->'serviceHistory', '[]'::jsonb)) as service_records,
  data->>'hasPhoto'            as has_photo,
  updated_at
from navi_records
where collection = 'crew'
order by pos;

create or replace view vessel_list with (security_invoker = on) as
select
  id,
  data->>'name'           as name,
  data->>'vesselType'     as vessel_type,
  data->>'homePort'       as home_port,
  data->>'marinaRegNo'    as marina_reg_no,
  data->>'grt'            as grt,
  data->>'nrt'            as nrt,
  data->>'loa'            as loa,
  data->>'breadth'        as breadth,
  data->>'depth'          as depth,
  data->>'dwt'            as dwt,
  data->>'engineKW'       as engine_kw,
  data->>'certNo'         as safe_manning_cert_no,
  data->>'certIssueDate'  as cert_issue_date,
  data->>'certExpiryDate' as cert_expiry_date,
  data->>'hasCertFile'    as has_cert_file,
  data->>'notes'          as notes,
  updated_at
from navi_records
where collection = 'vessels'
order by pos;

create or replace view document_list with (security_invoker = on) as
select
  id,
  data->>'holder'     as holder,
  data->>'crewId'     as crew_id,
  data->>'vessel'     as vessel,
  data->>'title'      as title,
  data->>'category'   as category,
  data->>'issueDate'  as issue_date,
  data->>'expiryDate' as expiry_date,
  data->>'hasFile'    as has_file,
  data->>'fileName'   as file_name,
  data->>'notes'      as notes,
  updated_at
from navi_records
where collection = 'documents'
order by pos;
