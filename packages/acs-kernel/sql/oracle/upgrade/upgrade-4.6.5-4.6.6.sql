-- 
-- @author Lars Pind (lars@collaboraid.biz)
-- @creation-date 2003-07-03
-- 
-- Add 'admin_rel' relationship type for administrators of a group
--
-- Make object_id 0 ("Unregistered Visitor") a user, not a person.
--



-- Make object_id 0 ("Unregistered Visitor") a user, not a person.

insert into users (user_id) values (0);
update acs_objects set object_type = 'user' where object_id = 0;


-- Add 'admin_rel' relationship type for administrators of a group

create table admin_rels (
        rel_id          integer constraint admin_rel_rel_id_fk
                        references membership_rels (rel_id)
                        constraint admin_rel_rel_id_pk
                        primary key
);



begin
 acs_rel_type.create_role ('admin', 'Administrator', 'Administrators');

 acs_rel_type.create_type (
   rel_type => 'admin_rel',
   pretty_name => 'Administrator Relation',
   pretty_plural => 'Administrator Relationships',
   supertype => 'membership_rel',
   table_name => 'admin_rels',
   id_column => 'rel_id',
   package_name => 'admin_rel',
   object_type_one => 'group',
   min_n_rels_one => 0, max_n_rels_one => null,
   object_type_two => 'person', role_two => 'admin',
   min_n_rels_two => 0, max_n_rels_two => null
 );

 commit;
end;
/
show errors



create or replace package admin_rel
as

  function new (
    rel_id              in admin_rels.rel_id%TYPE default null,
    rel_type            in acs_rels.rel_type%TYPE default 'admin_rel',
    object_id_one       in acs_rels.object_id_one%TYPE,
    object_id_two       in acs_rels.object_id_two%TYPE,
    member_state        in membership_rels.member_state%TYPE default 'approved',
    creation_user       in acs_objects.creation_user%TYPE default null,
    creation_ip         in acs_objects.creation_ip%TYPE default null
  ) return admin_rels.rel_id%TYPE;

  procedure delete (
    rel_id      in admin_rels.rel_id%TYPE
  );

end admin_rel;
/
show errors



create or replace package body admin_rel
as

  function new (
    rel_id              in admin_rels.rel_id%TYPE default null,
    rel_type            in acs_rels.rel_type%TYPE default 'admin_rel',
    object_id_one       in acs_rels.object_id_one%TYPE,
    object_id_two       in acs_rels.object_id_two%TYPE,
    member_state        in membership_rels.member_state%TYPE default 'approved',
    creation_user       in acs_objects.creation_user%TYPE default null,
    creation_ip         in acs_objects.creation_ip%TYPE default null
  ) return admin_rels.rel_id%TYPE
  is
    v_rel_id integer;
  begin
    v_rel_id := membership_rel.new (
      rel_id => rel_id,
      rel_type => rel_type,
      object_id_one => object_id_one,
      object_id_two => object_id_two,
      member_state => member_state,
      creation_user => creation_user,
      creation_ip => creation_ip
    );

    insert into admin_rels
     (rel_id)
    values
     (v_rel_id);

    return v_rel_id;
  end;

  procedure delete (
    rel_id      in admin_rels.rel_id%TYPE
  )
  is
  begin
    membership_rel.delete(rel_id);
  end;

end admin_rel;
/
show errors


