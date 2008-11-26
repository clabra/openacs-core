ad_page_contract {
    Convert the current subsite to one of its descendent subsite types.

    @author Steffen Tiedemann Christensen (steffen@christensen.name)
    @creation-date 2003-09-26
}

auth::require_login

set page_title "Convert Subsite To Descendent Type"

set context [list $page_title]

set subsite_package_options [subsite::util::get_package_descendent_options [ad_conn package_key]]

if { [llength $subsite_package_options] == 0 } {
    return .
    ad_script_abort
}

ad_form -name subsite -cancel_url . -form {
    {package_key:text(select)
        {label "Subsite Package"}
        {help_text "Choose the new subsite package type"}
        {options $subsite_package_options}
    }
} -on_submit {
    if { $package_key ne [ad_conn package_key] } {
        subsite::util::convert_type -new_package_key $package_key
    }
    ad_returnredirect .
    ad_script_abort
}
