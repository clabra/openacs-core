<?xml version="1.0"?>

<queryset>
   <rdbms><type>oracle</type><version>8.1.6</version></rdbms>

<fullquery name="sec_update_user_session_info.update_last_visit">      
      <querytext>
      
        update users
        set second_to_last_visit = last_visit,
            last_visit = sysdate,
            n_sessions = n_sessions + 1
        where user_id = :user_id
    
      </querytext>
</fullquery>

 
<fullquery name="ad_maybe_redirect_for_registration.sql_test_1">      
      <querytext>
      select test_sql('select 1 from dual where 1=[DoubleApos $value]') from dual
      </querytext>
</fullquery>

 
<fullquery name="ad_maybe_redirect_for_registration.sql_test_2">      
      <querytext>
      select test_sql('select 1 from dual where 1=[DoubleApos "'$value'"]') from dual
      </querytext>
</fullquery>

 
<fullquery name="populate_secret_tokens_db.insert_random_token">      
      <querytext>
      
	    insert /*+ APPEND */ into secret_tokens(token_id, token, token_timestamp)
	    values(sec_security_token_id_seq.nextval, :random_token, sysdate)
	
      </querytext>
</fullquery>

 
<fullquery name="populate_secret_tokens_cache.get_secret_tokens">      
      <querytext>
      
	    select * from (
	    select token_id, token
	    from secret_tokens
	    sample(15)
	    ) where rownum < :num_tokens
	
      </querytext>
</fullquery>
 
</queryset>
