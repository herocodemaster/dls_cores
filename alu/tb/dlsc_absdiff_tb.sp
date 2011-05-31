//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define WIDTH PARAM_WIDTH
#define META PARAM_META

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void check_thread();
    void watchdog_thread();

    void run_test(unsigned int iterations);

    std::deque<uint32_t> check_vals;
    std::deque<uint32_t> check_metas;

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
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);

    SC_METHOD(check_thread);
        sensitive << clk.posedge_event();
}

void __MODULE__::run_test(unsigned int iterations) {
    in_valid    = 0;

    uint32_t val0, val1, meta;

    unsigned int i = 0;
    while(i<iterations) {
        if(rand()%10) {
            val0 = rand() % ((1<<WIDTH)-1);
            val1 = rand() % ((1<<WIDTH)-1);
            meta = rand() % ((1<<META)-1);

            in_valid    = 1;
            in_meta     = meta;
            in0         = val0;
            in1         = val1;

            check_vals.push_back(abs((int)val0-(int)val1));
            check_metas.push_back(meta);

            ++i;
        } else {
            in_valid    = 0;
            in_meta     = 0;
            in0         = 0;
            in1         = 0;
        }

        wait(clk.posedge_event());
    }

    in_valid    = 0;
    in_meta     = 0;
    in0         = 0;
    in1         = 0;

    // wait for completion
    while(!check_vals.empty()) {
        wait(clk.posedge_event());
    }
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
    
    wait(100,SC_NS);

    // confirm that a single-cycle reset works
    wait(clk.posedge_event());
    rst     = 1;
    wait(clk.posedge_event());
    rst     = 0;
    wait(clk.posedge_event());
    
    run_test(153);

    wait(10,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::check_thread() {
    if(out_valid) {
        if(check_vals.empty()) {
            dlsc_error("unexpected data");
        } else {
            dlsc_assert_equals(out,check_vals.front());
            dlsc_assert_equals(out_meta,check_metas.front());
            check_vals.pop_front();
            check_metas.pop_front();
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



