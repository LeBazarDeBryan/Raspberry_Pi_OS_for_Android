# FILE: pkgIndex.tcl.in
# $Id: b509c2d405b746ae3d2c718287b7d2adefb40cb6 $
# ---
# tclreadline -- gnu readline for tcl
# https://github.com/flightaware/tclreadline/
# Copyright (c) 1998 - 2014, Johannes Zellner <johannes@zellner.org>
# This software is copyright under the BSD license.
# ---

package ifneeded tclreadline 2.3.8 \
    [list source [file join $dir tclreadlineInit.tcl]]
