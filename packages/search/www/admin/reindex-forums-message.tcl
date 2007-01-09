ad_page_contract {
    Reindex FORUMS_MESSAGE

    @author openacs@dirkgomez.de
} {
} -properties {
}                                                                                                                           
db_dml delete_forums_message_from_index {delete from site_wide_index where object_id in (select object_id from acs_objects where object_type='forums_message')}
db_dml reindex_forums_message {
    insert into search_observer_queue (object_id, event) select object_id, 'INSERT' from acs_objects where object_type in ('forums_message')}

ad_returnredirect ./index