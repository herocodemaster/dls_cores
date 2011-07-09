//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define DATA            PARAM_DATA
#define DEPTH           (1<<PARAM_ADDR)
#define ALMOST_FULL     PARAM_ALMOST_FULL
#define ALMOST_EMPTY    PARAM_ALMOST_EMPTY

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
        dlsc_assert_equals(rd_empty,1);
        dlsc_assert_equals(rd_almost_empty,1);
        dlsc_assert_equals(wr_full,0);
        dlsc_assert_equals(wr_almost_full,0);
        fifo.clear();
        return;
    }

    // update model
    // pop first
    if(rd_pop) {
        if(fifo.empty()) {
            dlsc_error("underflow");
        } else {
            fifo.pop_front();
        }
    }

    // then push
    // (to correctly support simultaneous pop and push when full)
    if(wr_push) {
        if(fifo.size() == DEPTH) {
            dlsc_error("overflow");
        } else {
            fifo.push_back(wr_data.read());
        }
    }

    // check empty flags
    if(fifo.empty()) {
        dlsc_assert_equals(rd_empty,1);
        dlsc_assert_equals(rd_almost_empty,1);
    } else if(fifo.size() > 1) {
        dlsc_assert_equals(rd_empty,0);
        dlsc_assert_equals(rd_almost_empty,(fifo.size() <= ALMOST_EMPTY));
    } else {
        // TODO
    }

    // check full flags
    dlsc_assert_equals(wr_full,(fifo.size() == DEPTH));
    dlsc_assert_equals(wr_almost_full,(fifo.size() >= (DEPTH-ALMOST_FULL)));

    // check data
    if(!fifo.empty() && !rd_empty) {
        dlsc_assert_equals(rd_data,fifo.front());
    }
}

void __MODULE__::stim_method() {

    if(rst) {
        wr_push         = 0;
        wr_data         = 0;
        rd_pop          = 0;
        return;
    }

    bool read_en    = ((rand()%100) >= read_pct ) && !rd_empty;
    bool write_en   = ((rand()%100) >= write_pct) && (read_en || !wr_full);

    if(read_en) {
        rd_pop          = 1;
    } else {
        rd_pop          = 0;
    }

    if(write_en) {
        wr_push         = 1;
        wr_data         = rand() % ((1<<DATA)-1);
    } else {
        wr_push         = 0;
        wr_data         = 0;
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

        wait(10,SC_US);
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



