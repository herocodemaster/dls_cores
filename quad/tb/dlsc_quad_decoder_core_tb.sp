//######################################################################
#sp interface

#include <systemperl.h>
#include <deque>

#include "dlsc_quad_encoder_model.h"

// Verilog parameters
#define FILTER          PARAM_FILTER
#define BITS            PARAM_BITS

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void check_method();

    std::deque<int> check_vals;

    dlsc_quad_encoder_model *enc;

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",100,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    enc = new dlsc_quad_encoder_model("enc", check_vals);
        enc->quad_a.bind(in_a);
        enc->quad_b.bind(in_b);
        enc->quad_z.bind(in_z);

    rst     = 1;
    clk_en_filter = 1;

    SC_METHOD(check_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::check_method() {
    if(rst) {
        check_vals.clear();
        return;
    }

    if(quad_en) {
        if(check_vals.empty()) {
            dlsc_error("unexpected quad_en");
        } else {
            dlsc_assert_equals(count, check_vals.front());
            check_vals.pop_front();
        }
    }
}

void __MODULE__::stim_thread() {

    cfg_count_min   = 0;
    cfg_count_max   = 799;
    cfg_index_qual  = 1;
    cfg_index_clr   = 0;

    rst = 1;
    wait(1,SC_US);

    rst = 0;
    wait(1,SC_US);

    enc->move(100.0);
    enc->move(-120.0);
    enc->move(24.0);
    enc->move(-10.0);

    wait(100,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(100,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



