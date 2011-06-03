// 
// Copyright (c) 2011, Daniel Strother < http://danstrother.com/ >
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//   - Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//   - Redistributions in binary form must reproduce the above copyright
//     notice, this list of conditions and the following disclaimer in the
//     documentation and/or other materials provided with the distribution.
//   - The name of the author may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
// TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#include <iostream>
#include <iomanip>

#include "systemperl.h"
#include "svdpi.h"

// globals defined in dlsc_main.cpp
extern int _dlsc_chk_cnt;
extern int _dlsc_warn_cnt;
extern int _dlsc_err_cnt;

// DPI
extern "C" {
    extern void dlsc_dpi_error (const char *str);
    extern void dlsc_dpi_warn  (const char *str);
    extern void dlsc_dpi_info  (const char *str);
    extern void dlsc_dpi_verb  (const char *str);
    extern void dlsc_dpi_okay  (const char *str);
    extern void dlsc_dpi_assert(const bool cond, const char *str);
}

void dlsc_dpi_display(const char *str, const char *severity) {
    svScope scope = svGetScope();
    const char *scopename = svGetNameFromScope(scope);

    std::cout << std::setw(15) << std::setfill(' ')
        << sc_core::sc_time_stamp()
        << " : [" << scopename << "] : "
        << severity << " : "
        << std::dec << str << std::endl;
}

void dlsc_dpi_error(const char *str) {
    ++_dlsc_chk_cnt;
    ++_dlsc_err_cnt;
    dlsc_dpi_display(str,"*** ERROR ***");
}

void dlsc_dpi_warn(const char *str) {
    ++_dlsc_warn_cnt;
#ifdef DLSC_DEBUG_WARN
    dlsc_dpi_display(str,"WARNING");
#endif
}

void dlsc_dpi_info(const char *str) {
#ifdef DLSC_DEBUG_INFO
    dlsc_dpi_display(str,"INFO");
#endif
}

void dlsc_dpi_verb(const char *str) {
#ifdef DLSC_DEBUG_VERB
    dlsc_dpi_display(str,"VERB");
#endif
}

void dlsc_dpi_okay(const char *str) {
    ++_dlsc_chk_cnt;
#ifdef DLSC_DEBUG_OKAY
    dlsc_dpi_display(str,"OKAY");
#endif
}

void dlsc_dpi_assert(const bool cond, const char *str) {
    if(cond) {
        dlsc_dpi_okay(str);
    } else {
        dlsc_dpi_error(str);
    }
}

