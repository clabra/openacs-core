<?xml version="1.0"?>

<queryset>
   <rdbms><type>postgresql</type><version>7.1</version></rdbms>

<fullquery name="relation_add.select_rel_violation">      
      <querytext>
      
	    select rel_constraint__violation(:rel_id) 
	
      </querytext>
</fullquery>

 
<fullquery name="relation_remove.relation_delete">      
      <querytext>
      select ${package_name}__delete(:rel_id)
      </querytext>
</fullquery>

 
<fullquery name="relation_segment_has_dependant.others_depend_p">      
      <querytext>
      
	    select case when exists
	             (select 1 from rc_violations_by_removing_rel r where r.rel_id = :rel_id)
	           then 1 else 0 end
	      
    
      </querytext>
</fullquery>

 
<fullquery name="relation_type_is_valid_to_group_p.rel_type_valid_p">      
      <querytext>
      
	    select case when exists
	             (select 1 from rc_valid_rel_types r 
                      where r.group_id = :group_id 
                        and r.rel_type = :rel_type)
	           then 1 else 0 end
	      
    
      </querytext>
</fullquery>

 
<fullquery name="relation_types_valid_to_group_multirow.select_sub_rel_types">      
      <querytext>    
	select
		pretty_name, object_type, level, indent,
		case when valid_types.rel_type = null then 0 else 1 end as valid_p
	from 
		(select
			t.pretty_name, t.object_type, tree_level(t.tree_sortkey) as level,
		        lpad('&nbsp;', (tree_level(t.tree_sortkey) - 1) * 4) as indent,
	        	t.tree_sortkey as sortkey
		from
			acs_object_types t
		where tree_sortkey like (select tree_sortkey || '%' 
					from acs_object_types where object_type = :start_with)) types left join
		(select
			rel_type
		from
			rc_valid_rel_types
		where
			group_id= :group_id) valid_types
	on (types.object_type = valid_types.rel_type)
	order by sortkey
		

	
      </querytext>
</fullquery>

 
</queryset>
