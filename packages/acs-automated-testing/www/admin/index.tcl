ad_page_contract {
  @cvs-id $Id$
} {
  {quiet 0}
  {by_package_key ""}
  {by_category:aa_test_category ""}
  {view_by:aa_test_view_by "package"}
} -properties {
  context_bar:onevalue
  title:onevalue
  server_name:onevalue
  tests:multirow
  packages:multirow
  categories:multirow
  by_package_key:onevalue
  by_category:onevalue
  view_by:onevalue
  quiet:onevalue
}
set title "System test cases"
set context_bar [list $title]

if {$by_package_key != ""} {
  append title " for package $by_package_key"
}
if {$by_category != ""} {
  append title ", category $by_category"
} else {
  append title ", all categories"
}


foreach testcase [nsv_get aa_test cases] {
  set testcase_id [lindex $testcase 0]
  set testcase_desc [lindex $testcase 1]
  set package_key   [lindex $testcase 3]
  set categories    [lindex $testcase 4]
  set results("$testcase_id,$package_key") \
                                [list $testcase_desc $package_key $categories]
  set packages($package_key) [list 0 0 0]
}

db_foreach acs-automated-testing.results_query {
  select testcase_id, package_key,
         to_char(timestamp,'DD-MM-YYYY HH24:MI:SS') timestamp, passes, fails
  from aa_test_final_results
} {
  if {[info exists results("$testcase_id,$package_key")]} {
    # Append results to individual testcase
    lappend results("$testcase_id,$package_key") $timestamp $passes $fails

    #
    # If viewing by package, update the by-package results, taking into
    # account whether a specific category has been specified.
    #
    if {$view_by == "package"} {
      set package_total [lindex $packages($package_key) 0]
      set package_pass  [lindex $packages($package_key) 1]
      set package_fail  [lindex $packages($package_key) 2]
      if {$by_category != ""} {
        # Category specific, only add results if this testcase is of the
        # specified category.
        set categories  [lindex $results("$testcase_id,$package_key") 2]
        if {[lsearch $categories $by_category] != -1} {
          incr package_total
          incr package_pass $passes
          incr package_fail $fails
          set packages($package_key) [list $package_total \
                                           $package_pass $package_fail]
        }
      } else {
        # No category specified, add results.
        incr package_total
        incr package_pass $passes
        incr package_fail $fails
        set packages($package_key) [list $package_total \
                                         $package_pass $package_fail]
      }
    }
  }
}

if {$view_by == "package"} {
  #
  # Prepare the template data for a view_by "package"
  #
  template::multirow create packageinfo key total passes fails
  foreach package_key [lsort [array names packages]] {
    set total  [lindex $packages($package_key) 0]
    set passes [lindex $packages($package_key) 1]
    set fails  [lindex $packages($package_key) 2]
    template::multirow append packageinfo $package_key $total $passes $fails
  }
} else {
  #
  # Prepare the template data for a view_by "testcase"
  #
  template::multirow create tests id description package_key categories \
                                     timestamp passes fails marker
  set old_package_key ""
  foreach testcase [nsv_get aa_test cases] {
    set testcase_id        [lindex $testcase 0]
    set package_key        [lindex $testcase 3]

    set testcase_desc      [lindex $results("$testcase_id,$package_key") 0]
    regexp {^(.+?\.)\s} $testcase_desc "" testcase_desc
    set categories         [lindex $results("$testcase_id,$package_key") 2]
    set categories_str     [string map {" " ", "} $categories]
    set testcase_timestamp [lindex $results("$testcase_id,$package_key") 3]
    set testcase_passes    [lindex $results("$testcase_id,$package_key") 4]
    set testcase_fails     [lindex $results("$testcase_id,$package_key") 5]
    #
    # Only add the testcase to the template multirow if either
    # - The package key is blank or it matches the specified.
    # - The category is blank or it matches the specified.
    #
    if {($by_package_key == "" || ($by_package_key == $package_key)) && \
        ($by_category == "" || ([lsearch $categories $by_category] != -1))} {
      # Swap the highlight flag between packages.
      if {$old_package_key != $package_key} {
        set marker 1
        set old_package_key $package_key
      } else {
        set marker 0
      }
      template::multirow append tests $testcase_id $testcase_desc \
                                      $package_key \
                                      $categories_str \
                                      $testcase_timestamp \
                                      $testcase_passes $testcase_fails \
                                      $marker
    }
  }
}

#
# Create the category multirow
#
template::multirow create all_categories name
foreach category [nsv_get aa_test categories] {
  template::multirow append all_categories $category
}

ad_return_template
