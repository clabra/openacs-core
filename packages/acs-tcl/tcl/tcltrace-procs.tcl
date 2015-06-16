ad_library {

    Tcl trace procs, accompanied by tcltrace-init.tcl

    Add Tcl execution traces to asserted Tcl commands

    @author Gustaf Neumann (neumann@wu-wien.ac.at)
    @creation-date 2015-06-11
    @cvs-id $Id$
}


namespace eval ::tcltrace {

    ad_proc -private before-ns_return { cmd op } {
	Execute this proc before ns_return is called

	@param cmd the full command as executed by Tcl
	@param op the trace operation 
    } {
	lassign $cmd cmdname statuscode mimetype content
	
	if {[::parameter::get_from_package_key \
		 -package_key acs-tcl \
		 -parameter TclTraceSaveNsReturn \
		 -default 0]} {
	    if {$statuscode == 200
		&& $mimetype eq "text/html"} {
		set name [ns_conn url]
		regsub {/$} $name /index name
		set fullname [ad_tmpdir]/ns_saved$name.html
		ns_log notice "before-ns_return: save content of ns_return to file:$fullname"
		set dirname [file dirname $fullname]
		if {![file isdirectory $dirname]} {
		    file mkdir $dirname
		}
		set f [open $fullname w]
		puts $f $content
		close $f
	    } else {
		ns_log notice "before-ns_return: ignore statuscode $statuscode mime-type $mimetype"
	    }
	}
    }

    ad_proc -private before-ns_log { cmd op } {
	Execute this proc before ns_log is called

	@param cmd the full command as executed by Tcl
	@param op the trace operation 
    } {
	lassign $cmd cmdname severity msg
	set severity [string totitle $severity]
	if {![info exists ::__log_severities]} {
	    set ::__log_severities [::parameter::get_from_package_key \
					-package_key acs-tcl \
					-parameter TclTraceLogServerities \
					-default ""]
	}
	if {$severity in $::__log_severities} {
	    catch {ds_comment "$cmdname $severity $msg"}
	} else {
	    #catch {ds_comment "ignore $severity $msg"}
	}
    }   
}




