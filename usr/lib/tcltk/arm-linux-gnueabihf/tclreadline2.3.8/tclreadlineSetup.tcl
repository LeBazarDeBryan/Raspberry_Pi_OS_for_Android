# FILE: tclreadlineSetup.tcl.in
# $Id: 1ba2cc394ecab927dafd6d7e9148c587062b5aae $
# ---
# tclreadline -- gnu readline for tcl
# https://github.com/flightaware/tclreadline/
# Copyright (c) 1998 - 2014, Johannes Zellner <johannes@zellner.org>
# This software is copyright under the BSD license.
# ---


package provide tclreadline 2.3.8

rename unknown _unknown
proc unknown args {

    global auto_noexec auto_noload env unknown_pending tcl_interactive
    global errorCode errorInfo

    # Save the values of errorCode and errorInfo variables, since they
    # may get modified if caught errors occur below.  The variables will
    # be restored just before re-executing the missing command.

    # If for some reson these don't exists, don't save or restore them.

    if {[info exists errorCode]} { set savedErrorCode $errorCode }
    if {[info exists errorInfo]} { set savedErrorInfo $errorInfo }
    set name [lindex $args 0]
    if {![info exists auto_noload]} {
        #
        # Make sure we're not trying to load the same proc twice.
        #
        if {[info exists unknown_pending($name)]} {
            return -code error "self-referential recursion in \"unknown\" for command \"$name\""
        }
        set unknown_pending($name) pending
        set ret [catch {auto_load $name [uplevel 1 {namespace current}]} msg]
        unset unknown_pending($name)
        if {$ret != 0} {
            return -code $ret -errorcode $errorCode "error while autoloading \"$name\": $msg"
        }
        if {![array size unknown_pending]} {
            unset unknown_pending
        }
        if {$msg} {
            if {[info exists savedErrorCode]} { set errorCode $savedErrorCode }
            if {[info exists savedErrorInfo]} { set errorInfo $savedErrorInfo }
            set code [catch {uplevel 1 $args} msg]
            if {$code == 1} {
                #
                # Strip the last five lines off the error stack (they're
                # from the "uplevel" command).
                #

                set new [split $errorInfo \n]
                set new [join [lrange $new 0 [expr {[llength $new] - 6}]] \n]
                return -code error -errorcode $errorCode -errorinfo $new $msg
            } else {
                return -code $code $msg
            }
        }
    }

    if {([info level] == 1) && [info exists tcl_interactive] && $tcl_interactive} {
    if {![info exists auto_noexec]} {
        set new [auto_execok $name]
        if {$new != ""} {
            if {[info exists savedErrorCode]} { set errorCode $savedErrorCode }
            if {[info exists savedErrorInfo]} { set errorInfo $savedErrorInfo }
            set redir ""
            if {[info commands console] == ""} {
                set redir ">&@stdout <@stdin"
            }
            # look for glob stuff in $args
            return [uplevel eval exec $redir $new [::tclreadline::Glob [lrange $args 1 end]]]
        }
    }
    if {[info exists savedErrorCode]} { set errorCode $savedErrorCode }
    if {[info exists savedErrorInfo]} { set errorInfo $savedErrorInfo }
    if {$name == "!!"} {
        set newcmd [history event]
    } elseif {[regexp {^!(.+)$} $name dummy event]} {
        set newcmd [history event $event]
    } elseif {[regexp {^\^([^^]*)\^([^^]*)\^?$} $name dummy old new]} {
        set newcmd [history event -1]
        catch {regsub -all -- $old $newcmd $new newcmd}
    }
    if {[info exists newcmd]} {
        tclLog $newcmd
        history change $newcmd 0
        return [uplevel $newcmd]
    }

    set ret [catch {set cmds [info commands $name*]} msg]
    if {[string compare $name "::"] == 0} {
        set name ""
    }
    if {$ret != 0} {
        return -code $ret -errorcode $errorCode \
            "error in unknown while checking if \"$name\" is a unique command abbreviation: $msg"
    }
    if {[llength $cmds] == 1} {
        return [uplevel [lreplace $args 0 0 $cmds]]
    }
    if {[llength $cmds] != 0} {
        if {$name == ""} {
            return -code error "empty command name \"\""
        } else {
            return -code error "ambiguous command name \"$name\": [lsort $cmds]"
        }
    }
    }
    return -code error "invalid command name \"$name\""
}


namespace eval tclreadline {

    namespace export Setup Loop InitTclCmds InitTkCmds Print ls

    proc ls {args} {
        if {[exec uname -s] == "Linux"} {
            eval exec ls --color -FC [Glob $args]
        } else {
            eval exec ls -FC [Glob $args]
        }
    }

    proc Setup {args} {

        uplevel #0 {

            if {"" == [info commands ::tclreadline::readline]} {
                ::tclreadline::Init
            }

            if {"" == [info procs ::tclreadline::prompt1] && [info nameofexecutable] != ""} {

                namespace eval ::tclreadline {
                    variable prompt_string
                    set base [file tail [info nameofexecutable]]

                    if {[string match tclsh* $base] && [info exists tcl_version]} {
                        set prompt_string "\[0;31mtclsh$tcl_version\[0m"
                    } elseif {[string match wish* $base] && [info exists tk_version]} {
                        set prompt_string "\[0;34mwish$tk_version\[0m"
                    } else {
                        set prompt_string "\[0;31m$base\[0m"
                    }

                }

                if {"" == [info procs ::tclreadline::prompt1]} {
                    proc ::tclreadline::prompt1 {} {
                        variable prompt_string
                        global env
                        if {[catch {set pwd [pwd]} tmp]} {
                            set pwd "unable to get pwd"
                        }

                        if {[info exists env(HOME)]} {
                            variable normalized_home
                            if {![info exists normalized_home]} {
                                set normalized_home [file normalize $env(HOME)]
                            }
                            if {[string equal -length [string length $normalized_home] $pwd $normalized_home]} {
                                set pwd "~[string range $pwd [string length $normalized_home] end]"
                            }
                        }
                        return "$prompt_string \[$pwd\] "
                    }
                }
            }

            if {"" == [info procs ::tclreadline::prompt2] && [info nameofexecutable] != ""} {

                if {"" == [info procs ::tclreadline::prompt2]} {
                    proc ::tclreadline::prompt2 {} {
                        return "> "
                    }
                }
            }

            if {"" == [info procs exit]} {

                catch {rename ::tclreadline::Exit ""}
                rename exit ::tclreadline::Exit

                proc exit {args} {

                    if {[catch {::tclreadline::readline write [::tclreadline::HistoryFileGet]} \
                             ::tclreadline::errorMsg]} {
                        puts stderr $::tclreadline::errorMsg
                    }

                    # this call is ignored, if tclreadline.c
                    # was compiled with CLEANUP_AFER_SIGNAL
                    # not defined. This is the case for
                    # older versions of libreadline.
                    #
                    ::tclreadline::readline reset-terminal

                    if {[catch "eval ::tclreadline::Exit $args" message]} {
                        puts stderr "error:"
                        puts stderr "$message"
                    }
                    # NOTREACHED
                }
            }

        }

        global env
        variable historyfile

        if {[string trim [llength $args]]} {
            set historyfile ""
            catch {set historyfile [file nativename [lindex $args 0]]}
            if {"" == [string trim $historyfile]} {
                set historyfile [lindex $args 0]
            }
        } else {
            if {[info exists env(HOME)]} {
                set historyfile $env(HOME)/.tclsh-history
            } else {
                set historyfile .tclsh-history
            }
        }
        set ::tclreadline::errorMsg [readline initialize $historyfile]
        if {$::tclreadline::errorMsg != ""} {
            puts stderr $::tclreadline::errorMsg
        }

        # InitCmds

        rename Setup ""
    }

    proc HistoryFileGet {} {
        variable historyfile
        return $historyfile
    }

    # obsolete
    #
    proc Glob {string} {

        set commandstring ""
        foreach name $string {
            set replace [glob -nocomplain -- $name]
            if {$replace == ""} {
                lappend commandstring $name
            } else {
                lappend commandstring $replace
            }
        }
        # return $commandstring
        # Christian Krone <krischan@sql.de> proposed
        return [eval concat $commandstring]
    }


    proc Loop {args} {

        eval Setup ${args}

        uplevel #0 {

            while {1} {

                if {[catch {
                    set prompt "% "
                    if {"" != [info procs ::tclreadline::prompt1]} {
                        set prompt [::tclreadline::prompt1]
                    }
                    set ::tclreadline::LINE [::tclreadline::readline read $prompt]
                    while {![::tclreadline::readline complete $::tclreadline::LINE]} {
                        append ::tclreadline::LINE "\n"
                        set prompt2 "> "
                        if {"" != [info procs ::tclreadline::prompt2]} {
                            set prompt2 [::tclreadline::prompt2]
                        }
                        append ::tclreadline::LINE [tclreadline::readline read $prompt2]
                    }
                } ::tclreadline::errorMsg]} {
                    puts stderr "tclreadline::Loop: error. $::tclreadline::errorMsg"
                    continue
                }

                # Magnus Eriksson <magnus.eriksson@netinsight.se> proposed
                # to add the line also to tclsh's history.
                #
                # I decided to add only lines which are different from
                # the previous one to the history. This is different
                # from tcsh's behaviour, but I found it quite convenient
                # while using mshell on os9.
                #
                if {[string length $::tclreadline::LINE]
                        && [history event 0] != $::tclreadline::LINE} {
                    history add $::tclreadline::LINE
                    if {[info exists ::tclreadline::autosave] && \
			    [string is true -strict $::tclreadline::autosave] && \
			    [catch {::tclreadline::readline write [::tclreadline::HistoryFileGet]} \
                             ::tclreadline::errorMsg]} {
                        puts stderr $::tclreadline::errorMsg
                    }
                }

                if {[catch {
                    set ::tclreadline::result [eval $::tclreadline::LINE]
                    if {$::tclreadline::result != "" && [tclreadline::Print]} {
                        puts $::tclreadline::result
                    }
                    set ::tclreadline::result ""
                } ::tclreadline::errorMsg]} {
                    puts stderr $::tclreadline::errorMsg
                    puts stderr "while evaluating $::tclreadline::LINE"
                }

            }
        }
    }

    proc Print {args} {
        variable PRINT
        if {![info exists PRINT]} {
            set PRINT yes
        }
        catch {set PRINT [expr {$args ? "yes" : "no"}]}
        return $PRINT
    }


#    proc InitCmds {} {
#        # XXX
#        return
#        # XXX
#        global tcl_version tk_version
#        if {[info exists tcl_version]} {
#            InitTclCmds
#        }
#        if {[info exists tk_version]} {
#            InitTkCmds
#        }
#        rename InitCmds ""
#    }
#
#    proc InitTclCmds {} {
#        variable known_cmds
#        foreach line {
#            "after option ?arg arg ...?"
#            "append varName ?value value ...?"
#            "array option arrayName ?arg ...?"
#            "bgerror"
#            "break"
#            "catch command ?varName?"
#            "cd"
#            "clock"
#            "close <channelId>"
#            "concat"
#            "continue"
#            "eof <channelId>"
#            "error message ?errorInfo? ?errorCode?"
#            "eval arg ?arg ...?"
#            "exec ?switches? arg ?arg ...?"
#            "exit ?returnCode?"
#            "fblocked <channelId>"
#            "for start test next command"
#            "foreach varList list ?varList list ...? command"
#            "format formatString ?arg arg ...?"
#            "gets channelId ?varName?"
#            "glob"
#            "global varName ?varName ...?"
#            "incr varName ?increment?"
#            "info option ?arg arg ...?"
#            "interp cmd ?arg ...?"
#            "join list ?joinString?"
#            "lappend varName ?value value ...?"
#            "lindex list index"
#            "linsert list <index> <element> ?element ...?"
#            "list"
#            "llength list"
#            "lrange list first last"
#            "lreplace list first last ?element element ...?"
#            "lsearch ?mode? list pattern"
#            "lsort ?options? list"
#            "namespace"
#            "package option ?arg arg ...?"
#            "proc name args body"
#            "read ?-nonewline? channelId"
#            "regexp ?switches? exp string ?matchVar? ?subMatchVar subMatchVar ...?"
#            "rename oldName newName"
#            "scan <string> <format> ?varName varName ...?"
#            "set varName ?newValue?"
#            "split <string> ?splitChars?"
#            "subst ?-nobackslashes? ?-nocommands? ?-novariables? string"
#            "switch ?switches? string pattern body ... ?default body?"
#            "time <command> ?count?"
#            "unknown <cmdName> ?arg? ?...?"
#            "uplevel ?level? command ?arg ...?"
#            "vwait name"
#            "while test command"
#        } {
#            readline add $line
#            set known_cmds([lindex $line 0]) ${line}
#        }
#        rename InitTclCmds ""
#    }
#
#    proc InitTkCmds {} {
#        variable known_cmds
#        foreach line {
#            "bind window ?pattern? ?command?"
#            "bindtags window ?tags?"
#            "button pathName ?options?"
#            "canvas pathName ?options?"
#            "checkbutton pathName ?options?"
#            "clipboard option ?arg arg ...?"
#            "entry pathName ?options?"
#            "event option ?arg1?"
#            "font option ?arg?"
#            "frame pathName ?options?"
#            "grab option ?arg arg ...?"
#            "grid option arg ?arg ...?"
#            "image option ?args?"
#            "label pathName ?options?"
#            "listbox pathName ?options?"
#            "lower window ?belowThis?"
#            "menu pathName ?options?"
#            "menubutton pathName ?options?"
#            "message pathName ?options?"
#            "option cmd arg ?arg ...?"
#            "pack option arg ?arg ...?"
#            "radiobutton pathName ?options?"
#            "raise window ?aboveThis?"
#            "scale pathName ?options?"
#            "scrollbar pathName ?options?"
#            "selection option ?arg arg ...?"
#            "send ?options? interpName arg ?arg ...?"
#            "text pathName ?options?"
#            "tk option ?arg?"
#            "tkwait variable|visibility|window name"
#            "toplevel pathName ?options?"
#            "winfo option ?arg?"
#            "wm option window ?arg ...?"
#        } {
#            readline add $line
#            set known_cmds([lindex $line 0]) ${line}
#        }
#        rename InitTkCmds ""
#    }


}; # namespace tclreadline
