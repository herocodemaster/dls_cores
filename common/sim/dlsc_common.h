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


#ifndef DLSC_COMMON_INCLUDED
#define DLSC_COMMON_INCLUDED

#include <systemc>
#include <iostream>
#include <iomanip>

// globals defined in dlsc_main.cpp
extern int _dlsc_chk_cnt;
extern int _dlsc_warn_cnt;
extern int _dlsc_err_cnt;

#define dlsc_display(msg) do { std::cout << std::setw(15) << std::setfill(' ') << sc_core::sc_time_stamp() << " : [" << this->name() << ":" << __func__ << "] : " << std::dec << msg << std::endl; } while(0)

#ifdef DLSC_DEBUG_WARN
# define dlsc_warn(msg) do { _dlsc_warn_cnt++; dlsc_display("WARNING : " << msg); } while(0)
#else
# define dlsc_warn(msg) do { _dlsc_warn_cnt++; } while(0)
#endif

#ifdef DLSC_DEBUG_INFO
# define dlsc_info(msg) do { dlsc_display("INFO : " << msg); } while(0)
#else
# define dlsc_info(msg) do { } while(0)
#endif

#ifdef DLSC_DEBUG_VERB
# define dlsc_verb(msg) do { dlsc_display("VERB : " << msg); } while(0)
#else
# define dlsc_verb(msg) do { } while(0)
#endif

#ifdef DLSC_DEBUG_OKAY
# define dlsc_okay(msg) do { _dlsc_chk_cnt++; dlsc_display("OKAY : " << msg); } while(0)
#else
# define dlsc_okay(msg) do { _dlsc_chk_cnt++; } while(0)
#endif

#define dlsc_error(msg) do { _dlsc_chk_cnt++; _dlsc_err_cnt++; dlsc_display("*** ERROR *** : " << msg); } while(0)

#define dlsc_assert(cond) do { if((cond)) { dlsc_okay("dlsc_assert('" << #cond << "') passed"); } else { dlsc_error("dlsc_assert('" << #cond << "') failed!"); } } while(0)

#define dlsc_assert_equals(lhs,rhs) do { \
    if((lhs)==(rhs)) { \
        dlsc_okay("dlsc_assert_equals( " << #lhs << " , " << #rhs << " ) passed"); \
    } else { \
        dlsc_error("dlsc_assert_equals( " << #lhs << " ('" << std::hex << (lhs) << "') , " << #rhs << " ('" << (rhs) << "') ) failed!"); \
    } } while(0)

#endif

