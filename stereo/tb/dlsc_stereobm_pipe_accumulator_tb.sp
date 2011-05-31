//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#define IN_BITS 12
#define OUT_BITS 16
#define SAD 9
#define MULT_R 4

/*AUTOSUBCELL_CLASS*/

struct check_type {
    bool first;
    unsigned int sad[MULT_R];
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void check_thread();
    void watchdog_thread();

    void run_test(unsigned int iterations);

    std::deque<check_type> check_vals;

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include <algorithm>
#include <numeric>

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    // assumes WIDTH = 32; SAD_WINDOW = 9; DEPTH_BITS = 4; DEPTH = 16
    SP_CELL(dut,Vdlsc_stereobm_pipe_accumulator);
        /*AUTOINST*/

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);

    SC_METHOD(check_thread);
        sensitive << clk.posedge_event();
}

void __MODULE__::run_test(unsigned int iterations) {
    std::deque<unsigned int> prev[MULT_R];

    check_type chk;
    chk.first = true;

#if (MULT_R*IN_BITS) <= 64
    uint64_t in;
#else
    sc_bv<MULT_R*IN_BITS> in;
#endif

    unsigned int i = 0, j;
    while(i < iterations) {
        if(rand() % 10) {
            in = 0;
            for(j=0;j<MULT_R;++j) {
                uint64_t val = rand() & ((1<<IN_BITS)-1);
#if (MULT_R*IN_BITS) <= 64
                in |= (val << (IN_BITS*j));
#else
                in.range((j*IN_BITS)+IN_BITS-1,(j*IN_BITS)) = val;
#endif
                prev[j].push_back(val);
            }

            if(prev[0].size() == SAD) {
                for(j=0;j<MULT_R;++j) {
                    chk.sad[j] = std::accumulate(prev[j].begin(),prev[j].end(),0);
                    prev[j].pop_front();
                }
                check_vals.push_back(chk);
                chk.first = false;
            }
            
            in_valid    = 1;
            in_first    = (i == 0);
            in_sad.write(in);

            ++i;
        } else {
            in_valid    = 0;
        }

        wait(clk.posedge_event());
    }

    in_valid    = 0;
}

void __MODULE__::stim_thread() {
    rst     = 1;

    wait(100,SC_NS);
    wait(clk.posedge_event());
    rst     = 0;
    
    wait(100,SC_NS);
    wait(clk.posedge_event());

    for(int i=0;i<100;++i) {
        run_test( (rand() % 100) + SAD );
        if( (rand() % 10) == 0 ) {
            wait(100,SC_NS);
            wait(clk.posedge_event());
            rst     = 1;
            wait(clk.posedge_event());
            rst     = 0;
            wait(clk.posedge_event());
        }
    }

    run_test(42);
    run_test(33);
    run_test(SAD);
    run_test(234);
    run_test(SAD+1);
    run_test(33);
    
    wait(100,SC_NS);

    // confirm that a single-cycle reset works
    wait(clk.posedge_event());
    rst     = 1;
    wait(clk.posedge_event());
    rst     = 0;
    
    run_test(153);
    run_test(20);

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::check_thread() {
    if(out_valid) {
        if(check_vals.empty()) {
            dlsc_error("unexpected output");
        } else {
            check_type chk = check_vals.front(); check_vals.pop_front();
            sc_bv<MULT_R*OUT_BITS> sad;
            for(unsigned int i=0;i<MULT_R;++i) {
                sad.range((i*OUT_BITS)+OUT_BITS-1,(i*OUT_BITS)) = chk.sad[i];
            }
            dlsc_assert(out_sad.read() == sad);
        }
    }
}

void __MODULE__::watchdog_thread() {
    wait(1,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



