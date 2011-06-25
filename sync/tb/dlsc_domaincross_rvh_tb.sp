//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define DATA            PARAM_DATA

#define DATA_MAX ((1<<DATA)-1)

SC_MODULE (__MODULE__) {
private:
    sc_clock in_clk;
    sc_clock out_clk;

    void stim_thread();
    void watchdog_thread();

    void in_method();
    void out_method();

    std::deque<uint32_t> out_vals;

    int read_pct;
    int write_pct;

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

#include <boost/shared_array.hpp>

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : in_clk("in_clk",PARAM_IN_CLK,SC_NS), out_clk("out_clk",PARAM_OUT_CLK,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst         = 1;

    read_pct    = 0;
    write_pct   = 0;

    SC_METHOD(in_method);
        sensitive << in_clk.posedge_event();

    SC_METHOD(out_method);
        sensitive << out_clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::in_method() {
    if(rst) {
        in_valid    = 0;
        in_data     = 0;
        return;
    }

    if( in_ready || !in_valid ) {
        if( ((rand()%100) >= write_pct) ) {

            uint32_t d = rand() % DATA_MAX;

            in_valid    = 1;
            in_data     = d;

            out_vals.push_back(d);

        } else {
            in_valid    = 0;
            in_data     = 0;
        }
    }
}

void __MODULE__::out_method() {
    if(rst) {
        out_ready   = 0;
        out_vals.clear();
        return;
    }

    if(out_valid) {
        if(out_vals.empty()) {
            dlsc_error("unexpected data");
        } else if(out_ready ) {
            dlsc_assert_equals(out_data,out_vals.front());
            out_vals.pop_front();
        }
    }

    if((rand()%100) >= read_pct) {
        out_ready   = 1;
    } else {
        out_ready   = 0;
    }

}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);

    for(int i=0;i<30;++i) {
        wait(out_clk.posedge_event());
        wait(in_clk.posedge_event());
        rst     = 1;

        read_pct    = (rand()%90) + 10;
        write_pct   = (rand()%90) + 10;

        wait(out_clk.posedge_event());
        wait(in_clk.posedge_event());
        rst     = 0;

        wait(2,SC_US);
    }

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(10,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



