create or replace function content_revision__new (varchar,varchar,timestamptz,varchar,varchar,text,integer,integer,timestamptz,integer,varchar,integer,integer)
returns integer as '
declare
  new__title                  alias for $1;  
  new__description            alias for $2;  -- default null  
  new__publish_date           alias for $3;  -- default now()
  new__mime_type              alias for $4;  -- default ''text/plain''
  new__nls_language           alias for $5;  -- default null
  new__text                   alias for $6;  -- default '' ''
  new__item_id                alias for $7;  
  new__revision_id            alias for $8;  -- default null
  new__creation_date          alias for $9;  -- default now()
  new__creation_user          alias for $10; -- default null
  new__creation_ip            alias for $11; -- default null
  new__content_length         alias for $12; -- default null
  new__package_id             alias for $13; -- default null  
  v_revision_id               integer;       
  v_package_id                acs_objects.package_id%TYPE;
  v_content_type              acs_object_types.object_type%TYPE;
  v_storage_type              cr_items.storage_type%TYPE;
  v_length                    cr_revisions.content_length%TYPE;
begin


  LOCK TABLE acs_objects IN SHARE ROW EXCLUSIVE MODE;

  v_content_type := content_item__get_content_type(new__item_id);

  if new__package_id is null then
    v_package_id := acs_object__package_id(new__item_id);
  else
    v_package_id := new__package_id;
  end if;

  v_revision_id := acs_object__new(
      new__revision_id,
      v_content_type, 
      new__creation_date, 
      new__creation_user, 
      new__creation_ip, 
      new__item_id,
      ''t'',
      new__title,
      v_package_id
  );

  select storage_type into v_storage_type
    from cr_items
   where item_id = new__item_id;

  if v_storage_type = ''text'' then 
     v_length := length(new__text);
  else
     v_length := coalesce(new__content_length,0);
  end if;

  -- text data is stored directly in cr_revisions using text datatype.

  insert into cr_revisions (
    revision_id, title, description, mime_type, publish_date,
    nls_language, content, item_id, content_length
  ) values (
    v_revision_id, new__title, new__description,
     new__mime_type, 
    new__publish_date, new__nls_language, 
    new__text, new__item_id, v_length
  );

  return v_revision_id;
 
end;' language 'plpgsql';

create or replace function content_item__new (
  cr_items.name%TYPE,
  cr_items.parent_id%TYPE,
  acs_objects.object_id%TYPE,
  cr_items.locale%TYPE,
  acs_objects.creation_date%TYPE,
  acs_objects.creation_user%TYPE,
  acs_objects.context_id%TYPE,
  acs_objects.creation_ip%TYPE,
  acs_object_types.object_type%TYPE,
  acs_object_types.object_type%TYPE, 
  cr_revisions.title%TYPE,
  cr_revisions.description%TYPE,
  cr_revisions.mime_type%TYPE,
  cr_revisions.nls_language%TYPE,
  varchar,
  cr_revisions.content%TYPE,
  cr_child_rels.relation_tag%TYPE,
  boolean,
  cr_items.storage_type%TYPE,
  acs_objects.package_id%TYPE
) returns integer as '
declare
  new__name       alias for $1;
  new__parent_id  alias for $2;
  new__item_id    alias for $3;
  new__locale     alias for $4;
  new__creation_date alias for $5;
  new__creation_user alias for $6;
  new__context_id    alias for $7;
  new__creation_ip   alias for $8;
  new__item_subtype  alias for $9;
  new__content_type  alias for $10;
  new__title         alias for $11;
  new__description   alias for $12;
  new__mime_type     alias for $13;
  new__nls_language  alias for $14;
  new__text          alias for $15;
  new__data          alias for $16;
  new__relation_tag  alias for $17;
  new__is_live       alias for $18;
  new__storage_type  alias for $19;
  new__package_id    alias for $20;
  v_parent_id      cr_items.parent_id%TYPE;
  v_parent_type    acs_objects.object_type%TYPE;
  v_item_id        cr_items.item_id%TYPE;
  v_title          cr_revisions.title%TYPE;
  v_revision_id    cr_revisions.revision_id%TYPE;
  v_rel_id         acs_objects.object_id%TYPE;
  v_rel_tag        cr_child_rels.relation_tag%TYPE;
  v_context_id     acs_objects.context_id%TYPE;
  v_storage_type   cr_items.storage_type%TYPE;
begin

  -- place the item in the context of the pages folder if no
  -- context specified 
  LOCK TABLE acs_objects IN SHARE ROW EXCLUSIVE MODE;	

  if new__parent_id is null then
    v_parent_id := content_item_globals.c_root_folder_id;
  else
    v_parent_id := new__parent_id;
  end if;

  -- Determine context_id
  if new__context_id is null then
    v_context_id := v_parent_id;
  else
    v_context_id := new__context_id;
  end if;

  -- use the name of the item if no title is supplied
  if new__title is null or new__title = '''' then
    v_title := new__name;
  else
    v_title := new__title;
  end if;

  if v_parent_id = -4 or 
    content_folder__is_folder(v_parent_id) = ''t'' then

    if v_parent_id != -4 and 
      content_folder__is_registered(
        v_parent_id, new__content_type, ''f'') = ''f'' then

      raise EXCEPTION ''-20000: This items content type % is not registered to this folder %'', new__content_type, v_parent_id;
    end if;

  else if v_parent_id != -4 then

     if new__relation_tag is null then
       v_rel_tag := content_item__get_content_type(v_parent_id) 
         || ''-'' || new__content_type;
     else
       v_rel_tag := new__relation_tag;
     end if;

     select object_type into v_parent_type from acs_objects
       where object_id = v_parent_id;

     if NOT FOUND then 
       raise EXCEPTION ''-20000: Invalid parent ID % specified in content_item.new'',  v_parent_id;
     end if;

     if content_item__is_subclass(v_parent_type, ''content_item'') = ''t'' and
        content_item__is_valid_child(v_parent_id, new__content_type, v_rel_tag) = ''f'' then

       raise EXCEPTION ''-20000: This items content type % is not allowed in this container %'', new__content_type, v_parent_id;
     end if;

  end if; end if;

  -- Create the object

  v_item_id := acs_object__new(
      new__item_id,
      new__item_subtype, 
      new__creation_date, 
      new__creation_user, 
      new__creation_ip, 
      v_context_id,
      ''t'',
      v_title,
      new__package_id
  );


  insert into cr_items (
    item_id, name, content_type, parent_id, storage_type
  ) values (
    v_item_id, new__name, new__content_type, v_parent_id, new__storage_type
  );

  -- if the parent is not a folder, insert into cr_child_rels
  if v_parent_id != -4 and
    content_folder__is_folder(v_parent_id) = ''f'' then

    v_rel_id := acs_object__new(
      null,
      ''cr_item_child_rel'',
      now(),
      null,
      null,
      v_parent_id,
      ''t'',
      v_rel_tag || '': '' || v_parent_id || '' - '' || v_item_id,
      new__package_id
    );

    insert into cr_child_rels (
      rel_id, parent_id, child_id, relation_tag, order_n
    ) values (
      v_rel_id, v_parent_id, v_item_id, v_rel_tag, v_item_id
    );

  end if;

  if new__data is not null then

    v_revision_id := content_revision__new(
        v_title,
	new__description,
        now(),
	new__mime_type,
	new__nls_language,
	new__data,
        v_item_id,
        null,
        new__creation_date, 
        new__creation_user, 
        new__creation_ip,
        new__package_id
        );

  elsif new__text is not null or new__title is not null then

    v_revision_id := content_revision__new(
        v_title,
	new__description,
        now(),
	new__mime_type,
        null,
	new__text,
	v_item_id,
        null,
        new__creation_date, 
        new__creation_user, 
        new__creation_ip,
        new__package_id
    );

  end if;

  -- make the revision live if is_live is true
  if new__is_live = ''t'' then
    PERFORM content_item__set_live_revision(v_revision_id);
  end if;

  return v_item_id;

end;' language 'plpgsql';

create or replace function content_item__new (varchar,integer,integer,varchar,timestamptz,integer,integer,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,varchar,integer)
returns integer as '
declare
  new__name                   alias for $1;  
  new__parent_id              alias for $2;  -- default null  
  new__item_id                alias for $3;  -- default null
  new__locale                 alias for $4;  -- default null
  new__creation_date          alias for $5;  -- default now()
  new__creation_user          alias for $6;  -- default null
  new__context_id             alias for $7;  -- default null
  new__creation_ip            alias for $8;  -- default null
  new__item_subtype           alias for $9;  -- default ''content_item''
  new__content_type           alias for $10; -- default ''content_revision''
  new__title                  alias for $11; -- default null
  new__description            alias for $12; -- default null
  new__mime_type              alias for $13; -- default ''text/plain''
  new__nls_language           alias for $14; -- default null
  new__text                   alias for $15; -- default null
  new__storage_type           alias for $16; -- check in (''text'',''file'')
  new__package_id             alias for $17; -- default null
  new__relation_tag           varchar default null;
  new__is_live                boolean default ''f'';

  v_parent_id                 cr_items.parent_id%TYPE;
  v_parent_type               acs_objects.object_type%TYPE;
  v_item_id                   cr_items.item_id%TYPE;
  v_revision_id               cr_revisions.revision_id%TYPE;
  v_title                     cr_revisions.title%TYPE;
  v_rel_id                    acs_objects.object_id%TYPE;
  v_rel_tag                   cr_child_rels.relation_tag%TYPE;
  v_context_id                acs_objects.context_id%TYPE;
begin


  -- place the item in the context of the pages folder if no
  -- context specified 
  LOCK TABLE acs_objects IN SHARE ROW EXCLUSIVE MODE;	

  if new__parent_id is null then
    v_parent_id := content_item_globals.c_root_folder_id;
  else
    v_parent_id := new__parent_id;
  end if;

  -- Determine context_id
  if new__context_id is null then
    v_context_id := v_parent_id;
  else
    v_context_id := new__context_id;
  end if;

  if v_parent_id = -4 or 
    content_folder__is_folder(v_parent_id) = ''t'' then

    if v_parent_id != -4 and 
      content_folder__is_registered(
        v_parent_id, new__content_type, ''f'') = ''f'' then

      raise EXCEPTION ''-20000: This items content type % is not registered to this folder %'', new__content_type, v_parent_id;
    end if;

  else if v_parent_id != -4 then

     select object_type into v_parent_type from acs_objects
       where object_id = v_parent_id;

     if NOT FOUND then 
       raise EXCEPTION ''-20000: Invalid parent ID % specified in content_item.new'',  v_parent_id;
     end if;

     if content_item__is_subclass(v_parent_type, ''content_item'') = ''t'' and
	content_item__is_valid_child(v_parent_id, new__content_type) = ''f'' then

       raise EXCEPTION ''-20000: This items content type % is not allowed in this container %'', new__content_type, v_parent_id;
     end if;

  end if; end if;

  -- Create the object

  v_item_id := acs_object__new(
      new__item_id,
      new__item_subtype, 
      new__creation_date, 
      new__creation_user, 
      new__creation_ip, 
      v_context_id,
      ''t'',
      coalesce(new__title,new__name),
      new__package_id
  );

  insert into cr_items (
    item_id, name, content_type, parent_id, storage_type
  ) values (
    v_item_id, new__name, new__content_type, v_parent_id, new__storage_type
  );

  -- if the parent is not a folder, insert into cr_child_rels
  if v_parent_id != -4 and
    content_folder__is_folder(v_parent_id) = ''f'' and 
    content_item__is_valid_child(v_parent_id, new__content_type) = ''t'' then

    if new__relation_tag is null then
      v_rel_tag := content_item__get_content_type(v_parent_id) 
        || ''-'' || new__content_type;
    else
      v_rel_tag := new__relation_tag;
    end if;

    v_rel_id := acs_object__new(
      null,
      ''cr_item_child_rel'',
      now(),
      null,
      null,
      v_parent_id,
      ''t'',
      v_rel_tag || '': '' || v_parent_id || '' - '' || v_item_id,
      new__package_id
    );

    insert into cr_child_rels (
      rel_id, parent_id, child_id, relation_tag, order_n
    ) values (
      v_rel_id, v_parent_id, v_item_id, v_rel_tag, v_item_id
    );

  end if;

  -- use the name of the item if no title is supplied
  if new__title is null then
    v_title := new__name;
  else
    v_title := new__title;
  end if;

  if new__title is not null or 
     new__text is not null then

    v_revision_id := content_revision__new(
	v_title,
	new__description,
        now(),
	new__mime_type,
        null,
	new__text,
	v_item_id,
        null,
        new__creation_date, 
        new__creation_user, 
        new__creation_ip,
        new__package_id
    );

  end if;

  -- make the revision live if is_live is true
  if new__is_live = ''t'' then
    PERFORM content_item__set_live_revision(v_revision_id);
  end if;

  return v_item_id;
 
end;' language 'plpgsql';

create or replace function content_item__new (varchar,integer,integer,varchar,timestamptz,integer,integer,varchar,varchar,varchar,varchar,varchar,varchar,varchar,integer,integer)
returns integer as '
declare
  new__name                   alias for $1;  
  new__parent_id              alias for $2;  -- default null  
  new__item_id                alias for $3;  -- default null
  new__locale                 alias for $4;  -- default null
  new__creation_date          alias for $5;  -- default now()
  new__creation_user          alias for $6;  -- default null
  new__context_id             alias for $7;  -- default null
  new__creation_ip            alias for $8;  -- default null
  new__item_subtype           alias for $9;  -- default ''content_item''
  new__content_type           alias for $10; -- default ''content_revision''
  new__title                  alias for $11; -- default null
  new__description            alias for $12; -- default null
  new__mime_type              alias for $13; -- default ''text/plain''
  new__nls_language           alias for $14; -- default null
-- changed to integer for blob_id
  new__data                   alias for $15; -- default null
  new__package_id             alias for $16; -- default null
  new__relation_tag           varchar default null;
  new__is_live                boolean default ''f'';

  v_parent_id                 cr_items.parent_id%TYPE;
  v_parent_type               acs_objects.object_type%TYPE;
  v_item_id                   cr_items.item_id%TYPE;
  v_revision_id               cr_revisions.revision_id%TYPE;
  v_title                     cr_revisions.title%TYPE;
  v_rel_id                    acs_objects.object_id%TYPE;
  v_rel_tag                   cr_child_rels.relation_tag%TYPE;
  v_context_id                acs_objects.context_id%TYPE;
begin

  -- place the item in the context of the pages folder if no
  -- context specified 
  LOCK TABLE acs_objects IN SHARE ROW EXCLUSIVE MODE;	

  if new__parent_id is null then
    v_parent_id := content_item_globals.c_root_folder_id;
  else
    v_parent_id := new__parent_id;
  end if;

  -- Determine context_id
  if new__context_id is null then
    v_context_id := v_parent_id;
  else
    v_context_id := new__context_id;
  end if;

  -- use the name of the item if no title is supplied
  if new__title is null or new__title = '''' then
    v_title := new__name;
  else
    v_title := new__title;
  end if;

  if v_parent_id = -4 or 
    content_folder__is_folder(v_parent_id) = ''t'' then

    if v_parent_id != -4 and 
      content_folder__is_registered(
        v_parent_id, new__content_type, ''f'') = ''f'' then

      raise EXCEPTION ''-20000: This items content type % is not registered to this folder %'', new__content_type, v_parent_id;
    end if;

  else if v_parent_id != -4 then

     select object_type into v_parent_type from acs_objects
       where object_id = v_parent_id;

     if NOT FOUND then 
       raise EXCEPTION ''-20000: Invalid parent ID % specified in content_item.new'',  v_parent_id;
     end if;

     if content_item__is_subclass(v_parent_type, ''content_item'') = ''t'' and
	content_item__is_valid_child(v_parent_id, new__content_type) = ''f'' then

       raise EXCEPTION ''-20000: This items content type % is not allowed in this container %'', new__content_type, v_parent_id;
     end if;

  end if; end if;

  -- Create the object

  v_item_id := acs_object__new(
      new__item_id,
      new__item_subtype, 
      new__creation_date, 
      new__creation_user, 
      new__creation_ip, 
      v_context_id,
      ''t'',
      v_title,
      new__package_id
  );

  insert into cr_items (
    item_id, name, content_type, parent_id, storage_type
  ) values (
    v_item_id, new__name, new__content_type, v_parent_id, ''lob''
  );

  -- if the parent is not a folder, insert into cr_child_rels
  if v_parent_id != -4 and
    content_folder__is_folder(v_parent_id) = ''f'' and 
    content_item__is_valid_child(v_parent_id, new__content_type) = ''t'' then

    if new__relation_tag is null or new__relation_tag = '''' then
      v_rel_tag := content_item__get_content_type(v_parent_id) 
        || ''-'' || new__content_type;
    else
      v_rel_tag := new__relation_tag;
    end if;

    v_rel_id := acs_object__new(
      null,
      ''cr_item_child_rel'',
      now(),
      null,
      null,
      v_parent_id,
      ''t'',
      v_rel_tag || '': '' || v_parent_id || '' - '' || v_item_id,
      new__package_id
    );

    insert into cr_child_rels (
      rel_id, parent_id, child_id, relation_tag, order_n
    ) values (
      v_rel_id, v_parent_id, v_item_id, v_rel_tag, v_item_id
    );

  end if;

  -- create the revision if data or title is not null

  if new__data is not null then

    v_revision_id := content_revision__new(
        v_title,
	new__description,
        now(),
	new__mime_type,
	new__nls_language,
	new__data,
        v_item_id,
        null,
        new__creation_date, 
        new__creation_user, 
        new__creation_ip,
        new__package_id
        );

  elsif new__title is not null then

    v_revision_id := content_revision__new(
	v_title,
	new__description,
        now(),
	new__mime_type,
        null,
	null,
	v_item_id,
        null,
        new__creation_date, 
        new__creation_user, 
        new__creation_ip,
        new__package_id
    );

  end if;

  -- make the revision live if is_live is true
  if new__is_live = ''t'' then
    PERFORM content_item__set_live_revision(v_revision_id);
  end if;

  return v_item_id;
 
end;' language 'plpgsql';



create or replace function content_item__new ( integer, varchar, integer, varchar, timestamptz, integer, integer, varchar, boolean, varchar, text, varchar, boolean, varchar,varchar,varchar,integer)
returns integer as '
declare
  new__item_id                alias for $1; --default null
  new__name                   alias for $2;  
  new__parent_id              alias for $3;  -- default null  
  new__title                  alias for $4; -- default null
  new__creation_date	      alias for $5; -- default now()
  new__creation_user	      alias for $6; -- default null
  new__context_id	      alias for $7; -- default null
  new__creation_ip	      alias for $8; -- default null
  new__is_live		      alias for $9; -- default ''f''
  new__mime_type	      alias for $10; 
  new__text		      alias for $11; -- default null
  new__storage_type	      alias for $12; -- check in (''text'', ''file'') 
  new__security_inherit_p     alias for $13; -- default ''t''
  new__storage_area_key       alias for $14; -- default ''CR_FILES''
  new__item_subtype	      alias for $15;
  new__content_type	      alias for $16; 
  new__package_id	      alias for $17; -- default null
  new__description	      varchar default null;
  new__relation_tag           varchar default null;
  new__nls_language	      varchar default null; 
  v_parent_id                 cr_items.parent_id%TYPE;
  v_parent_type               acs_objects.object_type%TYPE;
  v_item_id                   cr_items.item_id%TYPE;
  v_revision_id               cr_revisions.revision_id%TYPE;
  v_title                     cr_revisions.title%TYPE;
  v_rel_id                    acs_objects.object_id%TYPE;
  v_rel_tag                   cr_child_rels.relation_tag%TYPE;
  v_context_id                acs_objects.context_id%TYPE;
begin

  -- place the item in the context of the pages folder if no
  -- context specified 
  LOCK TABLE acs_objects IN SHARE ROW EXCLUSIVE MODE;	

  if new__parent_id is null then
    v_parent_id := content_item_globals.c_root_folder_id;
  else
    v_parent_id := new__parent_id;
  end if;

  -- Determine context_id
  if new__context_id is null then
    v_context_id := v_parent_id;
  else
    v_context_id := new__context_id;
  end if;

  -- use the name of the item if no title is supplied
  if new__title is null or new__title = '''' then
    v_title := new__name;
  else
    v_title := new__title;
  end if;

  if v_parent_id = -4 or 
    content_folder__is_folder(v_parent_id) = ''t'' then

    if v_parent_id != -4 and 
      content_folder__is_registered(
        v_parent_id, new__content_type, ''f'') = ''f'' then

      raise EXCEPTION ''-20000: This items content type % is not registered to this folder %'', new__content_type, v_parent_id;
    end if;

  else if v_parent_id != -4 then

     select object_type into v_parent_type from acs_objects
       where object_id = v_parent_id;

     if NOT FOUND then 
       raise EXCEPTION ''-20000: Invalid parent ID % specified in content_item.new'',  v_parent_id;
     end if;

     if content_item__is_subclass(v_parent_type, ''content_item'') = ''t'' and
	content_item__is_valid_child(v_parent_id, new__content_type) = ''f'' then

       raise EXCEPTION ''-20000: This items content type % is not allowed in this container %'', new__content_type, v_parent_id;
     end if;

  end if; end if;

 
  -- Create the object

  v_item_id := acs_object__new(
      new__item_id,
      new__item_subtype, 
      new__creation_date, 
      new__creation_user, 
      new__creation_ip, 
      v_context_id,
      new__security_inherit_p,
      v_title,
      new__package_id
  );

  insert into cr_items (
    item_id, name, content_type, parent_id, storage_type, storage_area_key
  ) values (
    v_item_id, new__name, new__content_type, v_parent_id, new__storage_type,
    new__storage_area_key
  );

  -- if the parent is not a folder, insert into cr_child_rels
  if v_parent_id != -4 and
    content_folder__is_folder(v_parent_id) = ''f'' and 
    content_item__is_valid_child(v_parent_id, new__content_type) = ''t'' then

    if new__relation_tag is null then
      v_rel_tag := content_item__get_content_type(v_parent_id) 
        || ''-'' || new__content_type;
    else
      v_rel_tag := new__relation_tag;
    end if;

    v_rel_id := acs_object__new(
      null,
      ''cr_item_child_rel'',
      new__creation_date,
      null,
      null,
      v_parent_id,
      ''f'',
      v_rel_tag || '': '' || v_parent_id || '' - '' || v_item_id,
      new__package_id
    );

    insert into cr_child_rels (
      rel_id, parent_id, child_id, relation_tag, order_n
    ) values (
      v_rel_id, v_parent_id, v_item_id, v_rel_tag, v_item_id
    );

  end if;

  if new__title is not null or 
     new__text is not null then

    v_revision_id := content_revision__new(
	v_title,
	new__description,
        now(),
	new__mime_type,
        null,
	new__text,
	v_item_id,
        null,
        new__creation_date, 
        new__creation_user, 
        new__creation_ip,
        new__package_id
    );

  end if;

  -- make the revision live if is_live is true
  if new__is_live = ''t'' then
    PERFORM content_item__set_live_revision(v_revision_id);
  end if;

  return v_item_id;

end;' language 'plpgsql';

