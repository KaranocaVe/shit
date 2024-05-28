set shitexecdir {@@shitexecdir@@}
if { [info exists ::env(shit_GUI_LIB_DIR) ] } {
	set shitguilib $::env(shit_GUI_LIB_DIR)
} else {
	set shitguilib {@@shitGUI_LIBDIR@@}
}

set env(PATH) "$shitexecdir:$env(PATH)"

if {[string first -psn [lindex $argv 0]] == 0} {
	lset argv 0 [file join $shitexecdir shit-gui]
}

if {[file tail [lindex $argv 0]] eq {shitk}} {
	set argv0 [lindex $argv 0]
	set AppMain_source $argv0
} else {
	set argv0 [file join $shitexecdir [file tail [lindex $argv 0]]]
	set AppMain_source [file join $shitguilib shit-gui.tcl]
	if {[info exists env(PWD)]} {
		cd $env(PWD)
	} elseif {[pwd] eq {/}} {
		cd $env(HOME)
	}
}

unset shitexecdir shitguilib
set argv [lrange $argv 1 end]
source $AppMain_source
