//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define DATA            PARAM_DATA
#define DEPTH           PARAM_DEPTH
#define ALMOST_FULL     PARAM_ALMOST_FULL
#define ALMOST_EMPTY    PARAM_ALMOST_EMPTY
#define FULL_IN_RESET   PARAM_FULL_IN_RESET

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void stim_method();

    void fifo_method();
    std::deque<uint32_t> fifo;

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

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst         = 1;
    read_pct    = 0;
    write_pct   = 0;

    SC_METHOD(fifo_method);
        sensitive << clk.negedge_event();
    
    SC_METHOD(stim_method);
        sensitive << clk.negedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::fifo_method() {
    // don't check at time zero
    if(sc_core::sc_time_stamp() == sc_core::SC_ZERO_TIME) return;

    if(rst) {
        // check reset values
        dlsc_assert_equals(empty,1);
        dlsc_assert_equals(almost_empty,1);
        dlsc_assert_equals(full,FULL_IN_RESET);
        dlsc_assert_equals(almost_full,FULL_IN_RESET);
        fifo.clear();
        return;
    }

    // update model
    // pop first
    if(pop_en) {
        if(fifo.empty()) {
            dlsc_error("underflow");
        } else {
            fifo.pop_front();
        }
    }

    // then push
    // (to correctly support simultaneous pop and push when full)
    if(push_en) {
        if(fifo.size() == DEPTH) {
            dlsc_error("overflow");
        } else {
            fifo.push_back(push_data.read());
        }
    }

    // check empty flags
    if(fifo.empty()) {
        dlsc_assert_equals(empty,1);
        dlsc_assert_equals(almost_empty,1);
    } else if(fifo.size() > 1) {
        dlsc_assert_equals(empty,0);
        dlsc_assert_equals(almost_empty,(fifo.size() <= ALMOST_EMPTY));
    } else {
        // TODO
    }

    // check full flags
    dlsc_assert_equals(full,(fifo.size() == DEPTH));
    dlsc_assert_equals(almost_full,(fifo.size() >= (DEPTH-ALMOST_FULL)));

    // check data
    if(!fifo.empty() && !empty) {
        dlsc_assert_equals(pop_data,fifo.front());
    }
}

void __MODULE__::stim_method() {

    if(rst) {
        push_en         = 0;
        push_data       = 0;
        pop_en          = 0;
        return;
    }

    bool read_en    = ((rand()%100) >= read_pct ) && !empty;
    bool write_en   = ((rand()%100) >= write_pct) && (read_en || !full);

    if(read_en) {
        pop_en          = 1;
    } else {
        pop_en          = 0;
    }

    if(write_en) {
        push_en         = 1;
        push_data       = rand() % ((1<<DATA)-1);
    } else {
        push_en         = 0;
        push_data       = 0;
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);

    for(int i=0;i<20;++i) {
        wait(clk.negedge_event());
        rst     = 1;

        read_pct    = (rand()%90) + 10;
        write_pct   = (rand()%90) + 10;

        wait(clk.negedge_event());
        rst     = 0;

        wait(1,SC_US);
    }

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(1,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



