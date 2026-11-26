-- Ensure the audit table is read-only to authenticated users; inserts come only from the private trigger.
revoke all on public.audit_logs from authenticated;
grant select on public.audit_logs to authenticated;
