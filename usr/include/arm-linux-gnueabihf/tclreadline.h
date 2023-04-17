 /* ================================================================== *
  * FILE: tclreadline.h.in
  * $Id: 2a1eaebe18984ec5c57529544ba82bc41816a2de $
  * ---
  * tclreadline -- gnu readline for tcl
  * https://github.com/flightaware/tclreadline/
  * Copyright (c) 1998 - 2014, Johannes Zellner <johannes@zellner.org>
  * This software is copyright under the BSD license.
  * ================================================================== */

#ifndef TCLREADLINE_H_
#define TCLREADLINE_H_

#include <tcl.h>

#define TCLRL_LIBRARY        "/usr/lib/tcltk/arm-linux-gnueabihf/tclreadline2.3.8"

/* VERSION STRINGS */
#define TCLRL_VERSION_STR    "2.3.8"
#define TCLRL_PATCHLEVEL_STR "2.3.8"

/* VERSION NUMBERS */
#define TCLRL_MAJOR      2
#define TCLRL_MINOR      3
#define TCLRL_PATCHLEVEL 8

#ifdef __cplusplus
extern "C" {
#endif
int Tclreadline_Init(Tcl_Interp *interp);
int Tclreadline_SafeInit(Tcl_Interp *interp);
#ifdef __cplusplus
}
#endif

#endif /* TCLREADLINE_H_ */
