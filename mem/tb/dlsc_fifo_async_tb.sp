//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define DATA            PARAM_DATA
#define ADDR            PARAM_ADDR
#define ALMOST_FULL     PARAM_ALMOST_FULL
#define ALMOST_EMPTY    PARAM_ALMOST_EMPTY

#define DEPTH (1<<ADDR)

#define DATA_MAX ((1<<DATA)-1)

SC_MODULE (__MODULE__) {
private:
    sc_clock wr_clk;
    sc_clock rd_clk;

    void stim_thread();
    void watchdog_thread();

    void wr_method();
    void rd_method();

    std::deque<uint32_t> rd_vals;

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

const bool fast_rd_clk = (PARAM_IN_CLK > PARAM_OUT_CLK);

SP_CTOR_IMP(__MODULE__) : wr_clk("wr_clk",PARAM_IN_CLK,SC_NS), rd_clk("rd_clk",PARAM_OUT_CLK,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    wr_rst      = 1;
    rd_rst      = 1;

    read_pct    = 0;
    write_pct   = 0;

    SC_METHOD(wr_method);
        sensitive << wr_clk.negedge_event();

    SC_METHOD(rd_method);
        sensitive << rd_clk.negedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}


void __MODULE__::wr_method() {
    if(wr_rst || rd_rst) {
        wr_push = 0;
        wr_data = 0;
        return;
    }

    dlsc_assert_equals(wr_full,(wr_free == 0));
    dlsc_assert_equals(wr_almost_full,(wr_free <= ALMOST_FULL));

    dlsc_assert( wr_free <= (DEPTH - rd_vals.size()) );

    if( !wr_full && dlsc_rand_bool(write_pct) ) {

        uint32_t d = dlsc_rand_u32(0,DATA_MAX);

        wr_push = 1;
        wr_data = d;

        if(rd_vals.size() >= DEPTH) {
            dlsc_error("overflow");
        }

        rd_vals.push_back(d);

    } else {
        wr_push = 0;
        wr_data = 0;
    }
}


void __MODULE__::rd_method() {
    if(rd_rst || wr_rst) {
        rd_pop  = 0;
        rd_vals.clear();
        return;
    }

    dlsc_assert_equals(rd_empty,(rd_count == 0));
    dlsc_assert_equals(rd_almost_empty,(rd_count <= ALMOST_EMPTY));

    dlsc_assert( rd_count <= rd_vals.size() );
    
    if( !rd_vals.empty() && !rd_empty && dlsc_rand_bool(read_pct) ) {

        rd_pop  = 1;

        dlsc_assert_equals(rd_data,rd_vals.front());
        rd_vals.pop_front();

    } else {
        rd_pop  = 0;
    }

}

void __MODULE__::stim_thread() {
    rd_rst  = 1;
    wr_rst  = 1;
    wait(100,SC_NS);

    for(int i=0;i<100;++i) {
        wait(rd_clk.negedge_event());
        rd_rst  = 1;
        wait(wr_clk.negedge_event());
        wr_rst  = 1;

        read_pct    = dlsc_rand(10,100);
        write_pct   = dlsc_rand(10,100);

        wait(rd_clk.negedge_event());
        rd_rst  = 0;
        wait(wr_clk.negedge_event());
        wr_rst  = 0;

        wait(5,SC_US);
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



