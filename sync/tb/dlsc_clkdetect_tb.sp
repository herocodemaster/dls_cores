//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

#define OUTPUTS 8

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void mclk_thread();
    bool mclk_en;
    double mclk_period;

    void stim_thread();
    void watchdog_thread();

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) :
    clk("clk",10.0,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst         = 1;

    mclk_en     = false;
    mclk_period = 5.0;

    SC_THREAD(mclk_thread);

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::mclk_thread() {
    clk_monitor = 0;
    while(true) {
        wait(mclk_period/2.0,SC_NS);
        if(mclk_en) {
            clk_monitor = !clk_monitor;
        } else {
            clk_monitor = 0;
        }
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst     = 0;

    for(int i=0;i<100;i++) {
        // start monitored clock
        // takes up to 3*mclk_period + 3*10.0 for handshake to get back.. this time must be less than 10.0*PARAM_PROP
        mclk_period     = 0.1 * dlsc_rand(10,(100*(PARAM_PROP-3))/3);
        mclk_en         = true;

        dlsc_info("period: " << mclk_period << " ns; frequency: " << (1000.0/mclk_period) << " MHz");

        // confirm that module doesn't detect it for at least FILTER cycles
        dlsc_assert_equals(active,0);
        wait(std::max(10.0,mclk_period)*PARAM_FILTER,SC_NS);
        dlsc_assert_equals(active,0);
        
        // confirm that it is detected after a while
        wait(std::max(10.0,mclk_period)*5*PARAM_FILTER,SC_NS);
        dlsc_assert_equals(active,1);

        // confirm that it is still active 10us later
        wait(10,SC_US);
        dlsc_assert_equals(active,1);

        // disable monitored clock
        mclk_en         = false;

        // confirm that it is detected as inactive quickly
        wait(mclk_period + (PARAM_PROP+4)*10.0,SC_NS);
        dlsc_assert_equals(active,0);

        wait(10,SC_US);

        if(dlsc_rand_bool(30.0)) {
            wait(clk.posedge_event());
            rst = 1;
            wait(clk.posedge_event());
            dlsc_assert_equals(active,0);
            rst = 0;
            wait(clk.posedge_event());
        }
    }

    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    for(int i=0;i<100;i++) {
        wait(1,SC_MS);
        dlsc_info(".");
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/

