//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

struct check_type {
    bool            first;
    bool            last;
    unsigned int    disp;
    unsigned int    sad;
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

#define DATA 9
#define SAD_DATA 16
#define DISP_BITS 6
#define SAD 9

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,Vdlsc_stereobm_pipe);
        /*AUTOINST*/

    rst = 1;
    
    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);

    SC_METHOD(check_thread);
        sensitive << clk.posedge_event();
}

void __MODULE__::run_test(unsigned int iterations) {
    std::deque<unsigned int> prev;

    sc_bv<DATA*SAD> data_l;
    sc_bv<DATA*SAD> data_r;

    check_type chk;
    chk.first   = true;
    chk.last    = false;
    chk.disp    = 0;
    chk.sad     = 0;

    unsigned int i = 0;
    while(i<iterations) {
        if(rand()%10) {
            unsigned int sum = 0;
            data_l = 0;
            data_r = 0;
            for(unsigned int j=0;j<SAD;++j) {
                unsigned int l = rand() & ((1<<DATA)-1);
                unsigned int r = rand() & ((1<<DATA)-1);
                sum += abs((int)l - (int)r);
                data_l.range( (j*DATA)+DATA-1 , (j*DATA) ) = l;
                data_r.range( (j*DATA)+DATA-1 , (j*DATA) ) = r;
            }
            prev.push_back(sum);

            if(prev.size() == SAD) {
                chk.last    = (i == (iterations-1));
                chk.disp    = rand() & ((1<<DISP_BITS)-1);
                chk.sad     = std::accumulate(prev.begin(),prev.end(),0);

                check_vals.push_back(chk);

                prev.pop_front();

                chk.first = false;
            }

            in_right_valid  = 1;
            in_valid        = 1;
            in_first        = (i == 0);
            in_left         = data_l;
            in_right        = data_r;

            ++i;
        } else {
            in_right_valid  = 0;
            in_valid        = 0;
        }

        wait(clk.posedge_event());
    }

    in_right_valid = 0;
    in_valid    = 0;
}

void __MODULE__::stim_thread() {
    rst     = 1;

    wait(100,SC_NS);
    wait(clk.posedge_event());
    rst     = 0;
    
    wait(100,SC_NS);
    wait(clk.posedge_event());

    // first test
    run_test(42);
    run_test(33);
    run_test(SAD+1);
    run_test(234);
    
    wait(100,SC_NS);

    // confirm that a single-cycle reset works
    wait(clk.posedge_event());
    rst     = 1;
    wait(clk.posedge_event());
    rst     = 0;
    wait(clk.posedge_event());
    
    run_test(153);
    run_test(20);
    run_test(1789);

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
            dlsc_assert(out_sad   == chk.sad);
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



