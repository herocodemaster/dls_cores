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

struct check_type {
    uint32_t    data;
    bool        frame_error;
    bool        parity_error;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void in_thread();
    void check_method();

    void send();

    std::deque<uint32_t> in_vals;
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
#include <boost/shared_array.hpp>

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",1000000.0/FREQ_IN,SC_US) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst     = 1;
    rx      = 1;

    SC_THREAD(in_thread);
    
    SC_METHOD(check_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::in_thread() {

    uint32_t txd = 1;

    const float bit_time_us = 1000000.0/FREQ_OUT;

    while(true) {

        wait(bit_time_us * (1.0 + ((rand()%100)/2000.0)),SC_US);
//        wait(bit_time_us,SC_US);

        if(rst) {
            txd     = 1;
            rx      = 1;
            in_vals.clear();
            continue;
        }

        if(txd == 1) {
            if(!rx || in_vals.empty()) {
                rx      = 1;
                continue;
            }

            if((rand()%10) == 0) {
                wait(bit_time_us * (rand()%100)*1.0,SC_US);
            }

            txd = in_vals.front(); in_vals.pop_front();
            txd |= (1<<BITS);
        }

        rx      = (txd & 1) ? 1 : 0;
        txd     >>= 1;
    }

}

void __MODULE__::check_method() {
    if(rst) {
        check_vals.clear();
        return;
    }

    if(valid) {
        if(check_vals.empty()) {
            dlsc_error("unexpected data");
        } else {
            check_type chk = check_vals.front(); check_vals.pop_front();
            dlsc_assert_equals(data,chk.data);
            dlsc_assert_equals(frame_error,chk.frame_error);
            dlsc_assert_equals(parity_error,chk.parity_error);
        }
    }
}

void __MODULE__::send() {

    bool bad_start, bad_stop, bad_parity;

    bad_start   = false;
    bad_stop    = (rand()%25) == 0;
    bad_parity  = (rand()%25) == 0;

    check_type chk;

    chk.data            = rand() % DATA_MAX;
    chk.frame_error     = bad_start || bad_stop;
    chk.parity_error    = PARITY && bad_parity;

    check_vals.push_back(chk);

    uint32_t start  = 0 ^ (bad_start?1:0);
    uint32_t stop   = ((1<<STOP)-1) ^ (bad_stop?1:0);
    uint32_t parity = ((PARITY==1) ? 1 : 0) ^ (bad_parity?1:0);

    for(int i=0;i<DATA;++i) {
        parity ^= (chk.data & (1<<i)) ? 1 : 0;
    }

    uint32_t all = stop;
    if(PARITY) {
        all <<= 1;
        all |= parity;
    }
    all <<= DATA;
    all |= chk.data;
    all <<= START;
    all |= start;

    in_vals.push_back(all);

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
    wait( (1000.0/FREQ_OUT) * 25.0 * 5.0 * 100.0 ,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



