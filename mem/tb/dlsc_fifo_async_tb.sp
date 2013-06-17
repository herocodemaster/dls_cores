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
    void stim_thread();
    void watchdog_thread();

    int rand_cycles();
    double rand_period();
    double rand_pct();

    double rd_clk_period;
    double wr_clk_period;

    double read_pct;
    double write_pct;

    void wr_clk_thread();
    void rd_clk_thread();

    void wr_method();
    void rd_method();

    std::deque<uint32_t> rd_vals;

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

SP_CTOR_IMP(__MODULE__)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    wr_clk      = 0;
    rd_clk      = 0;

    wr_rst      = 1;
    rd_rst      = 1;

    rd_clk_period = 10.0;
    wr_clk_period = 10.0;

    read_pct    = 1.0;
    write_pct   = 1.0;

    SC_METHOD(wr_method);
        sensitive << wr_clk.negedge_event();

    SC_METHOD(rd_method);
        sensitive << rd_clk.negedge_event();

    SC_THREAD(wr_clk_thread);
    SC_THREAD(rd_clk_thread);

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

int __MODULE__::rand_cycles()
{
    switch(dlsc_rand(0,3)) {
        case 0:     return dlsc_rand(0,9);
        case 1:     return dlsc_rand(10,99);
        case 2:     return dlsc_rand(100,999);
        default:    return dlsc_rand(1000,9999);
    }
}

double __MODULE__::rand_period()
{
    switch(dlsc_rand(0,2)) {
        case 0:     return 0.1*dlsc_rand(10,49);
        case 1:     return 0.1*dlsc_rand(50,249);
        default:    return 0.1*dlsc_rand(250,1249);
    }
}

double __MODULE__::rand_pct()
{
    switch(dlsc_rand(0,3)) {
        case 0:     return 0.1*dlsc_rand(10,49);
        case 1:     return 0.1*dlsc_rand(50,249);
        case 2:     return 0.1*dlsc_rand(250,999);
        default:    return 100.0;
    }
}

void __MODULE__::wr_clk_thread()
{
    wr_clk_period = rand_period();
    wr_clk.write(0);
    while(1)
    {
        // active time
        {
            int const cycles = rand_cycles();
            for(int i=0;i<cycles;++i) {
                wait(wr_clk_period*0.5,SC_NS);
                wr_clk.write(!wr_clk.read());
            }
        }

        // inactive time
        {
            int const cycles = rand_cycles();
            wait(wr_clk_period*static_cast<double>(cycles)*0.5,SC_NS);
        }
    }
}

void __MODULE__::rd_clk_thread()
{
    rd_clk_period = rand_period();
    rd_clk.write(0);
    while(1)
    {
        // active time
        {
            int const cycles = rand_cycles();
            for(int i=0;i<cycles;++i) {
                wait(rd_clk_period*0.5,SC_NS);
                rd_clk.write(!rd_clk.read());
            }
        }

        // inactive time
        {
            int const cycles = rand_cycles();
            wait(rd_clk_period*static_cast<double>(cycles)*0.5,SC_NS);
        }
    }
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

    int const iterations = 500;

    for(int i=0;i<iterations;++i) {
        if((i%(iterations/10)) == 0) {
            dlsc_info("iteration " << i << "/" << iterations);
        }

        if(dlsc_rand_bool(25.0)) {
            wait(rd_clk.negedge_event());
            rd_rst  = 1;
            wait(wr_clk.negedge_event());
            wr_rst  = 1;
        }
        
        wait(rd_clk.negedge_event());
        wait(wr_clk.negedge_event());

        if(dlsc_rand_bool(25.0))
            read_pct    = rand_pct();
        if(dlsc_rand_bool(25.0))
            write_pct   = rand_pct();

        if(dlsc_rand_bool(25.0))
            rd_clk_period = rand_period();
        if(dlsc_rand_bool(25.0))
            wr_clk_period = rand_period();

        wait(rd_clk.negedge_event());
        rd_rst  = 0;
        wait(wr_clk.negedge_event());
        wr_rst  = 0;

        switch(dlsc_rand(0,6)) {
            case 0: 
            case 1:
                wait(dlsc_rand(1000,10000), SC_US);
                break;
            case 2:
            case 3:
            case 4:
                wait(dlsc_rand( 100, 1000), SC_US);
                break;
            case 5:
                wait(dlsc_rand(  10,  100), SC_US);
                break;
            default:
                wait(dlsc_rand(   1,   10), SC_US);
        }
    }

    wait(10,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(2000,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



