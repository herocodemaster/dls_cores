//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

#include "dlsc_random.h"

/*AUTOSUBCELL_CLASS*/

int const WR_CYCLES     = PARAM_WR_CYCLES;
int const RD_CYCLES     = PARAM_RD_CYCLES;
int const WR_PIPELINE   = PARAM_WR_PIPELINE;
int const RD_PIPELINE   = PARAM_RD_PIPELINE;

int const DATA          = PARAM_DATA;
int const ADDR          = PARAM_ADDR;
int const ALMOST_FULL   = PARAM_ALMOST_FULL;
int const ALMOST_EMPTY  = PARAM_ALMOST_EMPTY;

bool const FREE         = PARAM_FREE;
bool const COUNT        = PARAM_COUNT;

size_t const DEPTH      = (1u<<ADDR);

uint64_t DATA_MAX      = ((1ull<<DATA)-1ull);

SC_MODULE (__MODULE__) {
private:
    void StimThread();
    void WatchdogThread();
    
    dlsc_random rng_;

    int RandCycles();
    double RandPeriod();
    double RandRate();

    double rd_clk_period_;
    double wr_clk_period_;

    void WrClkThread();
    void RdClkThread();

    double rd_rate_;
    double wr_rate_;

    void WrMethod();
    void WrPushMethod();
    void RdMethod();
    void RdPopMethod();

    bool wr_push_prev_;
    bool rd_pop_prev_;

    std::deque<uint64_t> rd_vals_;

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

SP_CTOR_IMP(__MODULE__) :
    rd_clk_period_(10.0),
    wr_clk_period_(10.0),
    rd_rate_(0.5),
    wr_rate_(0.5)
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

    SC_METHOD(WrMethod);
        sensitive << wr_clk.posedge_event();
    SC_METHOD(WrPushMethod);
        sensitive << wr_clk.posedge_event();
        sensitive << wr_full;

    SC_METHOD(RdMethod);
        sensitive << rd_clk.posedge_event();
    SC_METHOD(RdPopMethod);
        sensitive << rd_clk.posedge_event();
        sensitive << rd_empty;

    SC_THREAD(WrClkThread);
    SC_THREAD(RdClkThread);

    SC_THREAD(StimThread);
    SC_THREAD(WatchdogThread);
}

int __MODULE__::RandCycles()
{
    switch(rng_.rand(0,3)) {
        case 0:     return rng_.rand(0,9);
        case 1:     return rng_.rand(10,99);
        case 2:     return rng_.rand(100,999);
        default:    return rng_.rand(1000,9999);
    }
}

double __MODULE__::RandPeriod()
{
    switch(rng_.rand(0,2)) {
        case 0:     return rng_.rand( 1.0,  5.0);
        case 1:     return rng_.rand( 5.0, 25.0);
        default:    return rng_.rand(25.0,125.0);
    }
}

double __MODULE__::RandRate()
{
    switch(rng_.rand(0,3)) {
        case 0:     return rng_.rand(0.01,0.05);
        case 1:     return rng_.rand(0.05,0.25);
        case 2:     return rng_.rand(0.25,1.00);
        default:    return 1.0;
    }
}

void __MODULE__::WrClkThread()
{
    wr_clk_period_ = RandPeriod();
    wr_clk.write(0);
    while(1)
    {
        // active time
        {
            int const cycles = RandCycles();
            for(int i=0;i<cycles;++i) {
                wait(wr_clk_period_*0.5,SC_NS);
                wr_clk.write(!wr_clk.read());
            }
        }

        // inactive time
        {
            int const cycles = RandCycles();
            wait(wr_clk_period_*static_cast<double>(cycles)*0.5,SC_NS);
        }
    }
}

void __MODULE__::RdClkThread()
{
    rd_clk_period_ = RandPeriod();
    rd_clk.write(0);
    while(1)
    {
        // active time
        {
            int const cycles = RandCycles();
            for(int i=0;i<cycles;++i) {
                wait(rd_clk_period_*0.5,SC_NS);
                rd_clk.write(!rd_clk.read());
            }
        }

        // inactive time
        {
            int const cycles = RandCycles();
            wait(rd_clk_period_*static_cast<double>(cycles)*0.5,SC_NS);
        }
    }
}

void __MODULE__::WrMethod()
{
    if(wr_rst || rd_rst) {
        wr_push_prev_ = false;
        return;
    }

    if(FREE)
    {
        if(WR_CYCLES<=1) {
            dlsc_assert_equals(wr_full,(wr_free == 0));
        } else if(wr_free == 0) {
            dlsc_assert_equals(wr_full,1);
        }
        dlsc_assert_equals(wr_almost_full,(wr_free <= ALMOST_FULL));
        dlsc_assert( wr_free <= (DEPTH - rd_vals_.size()) );
    }

    if(wr_push)
    {
        if(wr_full) {
            dlsc_error("overflow (wr_full)");
        }
    }

    if((WR_PIPELINE == 0 && wr_push      ) ||
       (WR_PIPELINE == 1 && wr_push_prev_)
    ) {
        rd_vals_.push_back(wr_data.read());
        if(rd_vals_.size() > DEPTH) {
            dlsc_error("overflow (rd_vals_.size)");
        }
    }

    wr_push_prev_ = wr_push;
}

void __MODULE__::WrPushMethod()
{
    wr_push = 0;
    wr_data = rng_.rand<uint64_t>(0,DATA_MAX);
    
    if(wr_rst || rd_rst)
        return;

    if(!wr_full && rng_.rand_bool(wr_rate_))
    {
        wr_push = 1;
    }
}

void __MODULE__::RdMethod()
{
    if(rd_rst || wr_rst) {
        rd_pop_prev_ = false;
        rd_vals_.clear();
        return;
    }

    if(COUNT)
    {
        if(RD_CYCLES<=1) {
            dlsc_assert_equals(rd_empty,(rd_count == 0));
        } else if(rd_count == 0) {
            dlsc_assert_equals(rd_empty,1);
        }
        dlsc_assert_equals(rd_almost_empty,(rd_count <= ALMOST_EMPTY));
        dlsc_assert( rd_count <= rd_vals_.size() );
    }

    if((RD_PIPELINE == 0 && rd_pop      ) ||
       (RD_PIPELINE == 1 && rd_pop_prev_)
    ) {
        if(rd_vals_.empty())
        {
            dlsc_error("underflow (rd_vals_.empty)");
        }
        else
        {
            dlsc_assert_equals(rd_data,rd_vals_.front());
            rd_vals_.pop_front();
        }
    }

    rd_pop_prev_ = rd_pop;
}

void __MODULE__::RdPopMethod()
{
    rd_pop = 0;
    
    if(rd_rst || wr_rst)
        return;

    if(!rd_empty && rng_.rand_bool(rd_rate_)) {
        rd_pop = 1;
    }
}

void __MODULE__::StimThread()
{
    rd_rst  = 1;
    wr_rst  = 1;
    wait(100,SC_NS);

    int const iterations = 100;

    for(int i=0;i<iterations;++i) {
        if((i%10) == 0) {
            dlsc_info("iteration " << i << "/" << iterations);
        }

        if(rng_.rand_bool(0.25)) {
            wait(rd_clk.posedge_event());
            rd_rst = 1;
            wait(wr_clk.posedge_event());
            wr_rst = 1;
        }
        
        wait(rd_clk.posedge_event());
        wait(wr_clk.posedge_event());

        if(rng_.rand_bool(0.25))
            rd_rate_ = RandRate();
        if(rng_.rand_bool(0.25))
            wr_rate_ = RandRate();

        if(rng_.rand_bool(0.25))
            rd_clk_period_ = RandPeriod();
        if(rng_.rand_bool(0.25))
            wr_clk_period_ = RandPeriod();

        wait(rd_clk.posedge_event());
        rd_rst = 0;
        wait(wr_clk.posedge_event());
        wr_rst = 0;

        switch(rng_.rand(0,6)) {
            case 0: 
            case 1:
                wait(rng_.rand(1000,10000), SC_US);
                break;
            case 2:
            case 3:
            case 4:
                wait(rng_.rand( 100, 1000), SC_US);
                break;
            case 5:
                wait(rng_.rand(  10,  100), SC_US);
                break;
            default:
                wait(rng_.rand(   1,   10), SC_US);
        }
    }

    wait(10,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::WatchdogThread()
{
    for(int i=0;i<20;i++) {
        wait(100,SC_MS);
        dlsc_info(". " << rd_vals_.size());
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



