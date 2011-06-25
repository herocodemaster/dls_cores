//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

// Verilog parameters
#define START           PARAM_START
#define STOP            PARAM_STOP
#define DATA            PARAM_DATA
#define PARITY          PARAM_PARITY
#define CLKFREQ         PARAM_CLKFREQ
#define BAUD            PARAM_BAUD
#define FIFO_DEPTH      PARAM_FIFO_DEPTH
#define OVERSAMPLE      PARAM_OVERSAMPLE

#define DATA_MAX ((1<<DATA)-1)

#define BITS (START+STOP+DATA+(PARITY?1:0))

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void wire_method();

    void in_method();
    void check_method();

    void send();

    std::deque<uint32_t> in_vals;
    std::deque<uint32_t> check_vals;

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

SP_CTOR_IMP(__MODULE__) : clk("clk",1000000.0/CLKFREQ,SC_US) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst     = 1;
    rx      = 1;
    rx_mask = 0;

    SC_METHOD(wire_method);
        sensitive << tx;
        sensitive << tx_en;

    SC_METHOD(in_method);
        sensitive << clk.negedge_event();
    SC_METHOD(check_method);
        sensitive << clk.negedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::wire_method() {
    rx = tx_en.read() ? tx : 1;
}

void __MODULE__::in_method() {
    if(rst) {
        tx_push = 0;
        tx_data = 0;
        in_vals.clear();
        return;
    }

    if(!tx_full && !in_vals.empty() && (rand()%10)==0) {
        tx_push = 1;
        tx_data = in_vals.front(); in_vals.pop_front();
    } else {
        tx_push = 0;
        tx_data = 0;
    }
}

void __MODULE__::check_method() {
    if(rst) {
        rx_pop  = 0;
        check_vals.clear();
        return;
    }

    if(!rx_empty && (rand()%10)==0) {
        rx_pop  = 1;
        if(check_vals.empty()) {
            dlsc_error("unexpected data");
        } else {
            dlsc_assert_equals(rx_data,check_vals.front());
            check_vals.pop_front();
        }
    } else {
        rx_pop  = 0;
    }
}

void __MODULE__::send() {

    uint32_t d = rand()%DATA_MAX;

    in_vals.push_back(d);
    check_vals.push_back(d);

}

void __MODULE__::stim_thread() {

    rst = 1;
    wait(1,SC_US);

    for(int j=0;j<5;++j) {
        wait(clk.posedge_event());
        rst = 1;

        while(!in_vals.empty()) wait(1,SC_US);
        wait(clk.posedge_event());
        rst = 0;

        for(int i=0;i<100;++i) {
            send();
        }

        while(check_vals.size() > 10) wait(1,SC_US);
    }

    while(!check_vals.empty()) wait(1,SC_US);

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait( (1000.0/BAUD) * 25.0 * 5.0 * 100.0 ,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



