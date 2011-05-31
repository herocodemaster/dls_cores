//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define DATA    PARAM_DATA
#define ID      PARAM_ID
#define META    PARAM_META
#define INPUTS  PARAM_INPUTS

struct check_type {
    unsigned int    id;
    unsigned int    data;
    unsigned int    meta;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void check_method();
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
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/
    
    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);

    SC_METHOD(check_method);
        sensitive << clk.posedge_event();
}

void __MODULE__::run_test(unsigned int iterations) {
    sc_bv<DATA*INPUTS>  data;
    sc_bv<ID*INPUTS>    id;

    unsigned int val_data;
    unsigned int val_id;

    check_type chk;

    unsigned int i = 0;
    while(i<iterations) {
        if(rand() % 4) {
            chk.data    = UINT_MAX;
            chk.id      = 0;
            chk.meta    = rand() % ((1<<META)-1);
            
            for(unsigned int j=0;j<INPUTS;++j) {
                val_data    = rand() % ((1<<DATA)-1);
                val_id      = rand() % ((1<<ID)-1);

                if(val_data<chk.data) {
                    chk.data    = val_data;
                    chk.id      = val_id;
                }

                data.range( (j*DATA)+DATA-1 , (j*DATA) ) = val_data;
                id.range(   (j*ID  )+ID  -1 , (j*ID) )   = val_id;
            }

            check_vals.push_back(chk);

            in_valid    = 1;
            in_meta     = chk.meta;
            
#if (ID*INPUTS) <= 64
            in_id       = id.to_uint();
#else
            in_id       = id;
#endif
#if (DATA*INPUTS) <= 64
            in_data     = data.to_uint();
#else
            in_data     = data;
#endif

            ++i;
        } else {
            in_valid    = 0;
            in_id       = 0;
            in_data     = 0;
            in_meta     = 0;
        }

        wait(clk.posedge_event());
    }

    in_valid    = 0;
    in_id       = 0;
    in_data     = 0;
    in_meta     = 0;
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
    run_test(1);
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

void __MODULE__::check_method() {
    if(out_valid) {
        if(check_vals.empty()) {
            dlsc_error("unexpected output");
        } else {
            check_type chk = check_vals.front(); check_vals.pop_front();
            dlsc_assert_equals(out_id  , chk.id);
            dlsc_assert_equals(out_data, chk.data);
            dlsc_assert_equals(out_meta, chk.meta);
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



