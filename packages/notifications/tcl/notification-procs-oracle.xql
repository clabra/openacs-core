<?xml version="1.0"?>
<queryset>
   <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

<fullquery name="notification::delete.delete_notification">
<querytext>
declare begin
  notification.delete(:notification_id);
end;
</querytext>
</fullquery>

</queryset>
