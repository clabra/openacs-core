<?xml version="1.0"?>
<queryset>
<rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="dbqd.acs-subsite.www.permissions.revoke-2.revoke">
  <querytext>
	select acs_permission__revoke_permission(:object_id, :party_id, :privilege)
  </querytext>
</fullquery>

</queryset>
