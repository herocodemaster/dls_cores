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


#include "systemperl.h"
#include "sp_log.h"
#include "SpCoverage.h"

#ifndef DLSC_NOT_TRACED
#include "SpTraceVcd.h"
#endif

#include <vector>
#include <string>

#include "dlsc_common.h"
#include "dlsc_util.h"


#include "dlsc_random.h"

namespace {
    dlsc_random g_dlsc_rand_inst;
};

uint32_t dlsc_random::get_seed()
{
#ifdef PARAM_RAND_SEED
    static uint32_t seed = PARAM_RAND_SEED;
#else
    static uint32_t seed = 0;
#endif
    ++seed;
    return seed;
}


// globals for assertion report
int _dlsc_chk_cnt   = 0;
int _dlsc_warn_cnt  = 0;
int _dlsc_err_cnt   = 0;


void dlsc_assert_report() {
    std::cout << std::dec << std::endl << sc_time_stamp() << " : ";

    if(_dlsc_err_cnt > 0 || _dlsc_chk_cnt == 0) {
        std::cout << "*** FAILED *** (" << _dlsc_err_cnt << " errors/" << _dlsc_chk_cnt << " assertions, ";
    } else {
        std::cout << "*** PASSED";
        if(_dlsc_warn_cnt > 0) {
            std::cout << " with WARNINGS";
        }
        std::cout << " *** (" << _dlsc_chk_cnt << " assertions evaluated, ";
    }
    
    std::cout << _dlsc_warn_cnt << " warnings)" << std::endl << std::endl;
}

namespace {
#ifndef DLSC_NOT_TRACED
    SpTraceFile *g_dlsc_tfp = NULL;
#endif
    std::string g_dlsc_vcd_file;
};

void dlsc_trace_on()
{
#ifndef DLSC_NOT_TRACED
    if(g_dlsc_tfp && !g_dlsc_tfp->isOpen())
    {
        // open trace file
        g_dlsc_tfp->open(g_dlsc_vcd_file.c_str());
    }
#endif
}

int sc_main(int argc, char **argv)
{
    sp_log_file *lfp = NULL;

    // parse arguments

    std::string log_file;
    std::string cov_file;
    
    std::vector<std::string> args;
    for(int i=1;i<argc;i++) {
        args.push_back(std::string(argv[i]));
    }

    std::vector<std::string>::iterator it = args.begin();
    while(it != args.end()) {
        if(*it == "--log" && ++it != args.end()) {
            log_file = *it;
        }
        if(*it == "--cov" && ++it != args.end()) {
            cov_file = *it;
        }
        if(*it == "--vcd" && ++it != args.end()) {
            g_dlsc_vcd_file = *it;
        }
        ++it;
    }

#ifndef DLSC_NOT_VERILATED
    Verilated::commandArgs(argc, argv);     // needed for $test$plusargs
#endif

#ifdef PARAM_RAND_SEED
    // seed random number generator with supplied value
    srand(PARAM_RAND_SEED);
#endif

#ifndef DLSC_NOT_TRACED
    if(!g_dlsc_vcd_file.empty()) {
#ifndef DLSC_NOT_VERILATED
        Verilated::traceEverOn(true);           // we're going to be tracing
#endif
        g_dlsc_tfp = new SpTraceFile;           // trace file writer
    }
#endif

    if(!log_file.empty()) {
        lfp = new sp_log_file;                  // log file writer
        lfp->open(log_file.c_str());            // open log file
        lfp->redirect_cout();                   // capture all output to log
    }

    DLSC_TB *tb = new DLSC_TB("tb");        // instantiate testbench

#ifndef DLSC_NOT_TRACED
    if(g_dlsc_tfp) {
        tb->trace(g_dlsc_tfp,99);               // trace testbench (once file is opened)
#ifndef DLSC_TRACE_DEFER
        dlsc_trace_on();                        // open trace file
#endif
    }
#endif

    if(tb) { // suppress "unused variable" warning
        sc_start();                             // run the simulation; will exit on sc_stop()
    }
    
    if(!cov_file.empty()) {
        SpCoverage::write(cov_file.c_str()); // write coverage results
    }
    
    dlsc_assert_report();                   // write pass/fail report

#ifndef DLSC_NOT_TRACED
    if(g_dlsc_tfp && g_dlsc_tfp->isOpen()) {
        g_dlsc_tfp->close();                    // close trace file
    }
#endif
    if(lfp) lfp->close();                   // close log file

    return 0;//_dlsc_err_cnt;
}

bool dlsc_is_power_of_2(const uint64_t i) {
    // http://graphics.stanford.edu/~seander/bithacks.html#DetermineIfPowerOf2
    return i && !(i & (i - 1));
}

unsigned int dlsc_log2(uint64_t i) {
    // http://stackoverflow.com/questions/994593/how-to-do-an-integer-log2-in-c
    // note: incorrectly returns 0 for an input of 0
    unsigned int l = 0;
    while(i >>= 1) ++l;
    return l;
}

unsigned int dlsc_clog2(uint64_t i) {
    // same behavior as Verilog clog2
    if(i<=1) return 0;
    return (dlsc_log2(i-1)+1);
}

bool dlsc_rand_bool(double true_pct) {
    assert(true_pct >= 0.0 && true_pct <= 100.0);
    return g_dlsc_rand_inst.rand_bool(true_pct/100.0);
}

int dlsc_rand(int min, int max) {
    return g_dlsc_rand_inst(min,max);
}

uint32_t dlsc_rand_u32(uint32_t min,uint32_t max) {
    return g_dlsc_rand_inst(min,max);
}

uint64_t dlsc_rand_u64(uint64_t min,uint64_t max) {
    return g_dlsc_rand_inst(min,max);
}

