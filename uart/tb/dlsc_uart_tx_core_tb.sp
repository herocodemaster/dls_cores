//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

// Verilog parameters
#define START           PARAM_START
#define STOP            PARAM_STOP
#define DATA            PARAM_DATA
#define PARITY          PARAM_PARITY
#define OVERSAMPLE      PARAM_OVERSAMPLE
#define FREQ_IN         PARAM_FREQ_IN
#define FREQ_OUT        PARAM_FREQ_OUT

#define DATA_MAX ((1<<DATA)-1)

#define BITS (START+STOP+DATA+(PARITY?1:0))

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void check_thread();
    void in_method();

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

SP_CTOR_IMP(__MODULE__) : clk("clk",1000000.0/FREQ_IN,SC_US) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst     = 1;

    SC_THREAD(check_thread);
    
    SC_METHOD(in_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::check_thread() {

    uint32_t rxd;
    uint32_t parity;
    int i;

    const float bit_time_us = 1000000.0/FREQ_OUT;

    while(true) {

        // wait for start
        wait(tx.negedge_event());

        // align samples to center
        wait(bit_time_us*0.5,SC_US);

        // check start bits
        for(i=0;i<START;++i) {
            dlsc_assert_equals(tx,0);
            wait(bit_time_us,SC_US);
        }

        // receive data
        rxd     = 0;
        parity  = (PARITY == 1) ? 1 : 0;
        for(i=0;i<DATA;++i) {
            parity  ^= tx.read();
            rxd     |= (tx.read() << i);
            wait(bit_time_us,SC_US);
        }

        // check data
        if(check_vals.empty()) {
            dlsc_error("unexpected data");
        } else {
            dlsc_assert_equals(rxd,check_vals.front());
            check_vals.pop_front();
        }

        // check parity
        if(PARITY != 0) {
            dlsc_assert_equals(tx,parity);
            wait(bit_time_us,SC_US);
        }

        // check stop bits
        for(i=0;i<(STOP-1);++i) {
            dlsc_assert_equals(tx,1);
            wait(bit_time_us,SC_US);
        }
        dlsc_assert_equals(tx,1);

    }

}

void __MODULE__::in_method() {
    if(rst) {
        valid   = 0;
        data    = 0;
        in_vals.clear();
        return;
    }

    if(ready || !valid) {
        if(rand()%2 == 0 && !in_vals.empty()) {
            valid   = 1;
            data    = in_vals.front(); in_vals.pop_front();
        } else {
            valid   = 0;
            data    = 0;
        }
    }
}

void __MODULE__::send() {
    uint32_t val = rand() % DATA_MAX;
    in_vals.push_back(val);
    check_vals.push_back(val);
}

void __MODULE__::stim_thread() {

    rst = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst = 0;

    for(int j=0;j<50;++j) {

        while(!in_vals.empty() || !ready) wait(1,SC_US);

        wait(1000,SC_US);

        for(int i=0;i<10;++i) {
            send();
        }
    }

    while(!check_vals.empty()) wait(1,SC_US);

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait( (1000.0/FREQ_OUT) * 25.0 * 50.0 * 10.0 + 100.0 ,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



