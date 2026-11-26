-- Explicit deny-all policy documents the intended absence of direct Data API access.
-- The invitation workflow is exposed only through the guarded RPC functions.
drop policy if exists agency_invitations_deny_direct_access on public.agency_invitations;
create policy agency_invitations_deny_direct_access
on public.agency_invitations
for all
to authenticated
using (false)
with check (false);
