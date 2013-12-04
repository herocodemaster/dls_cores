//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

#include "dlsc_bv.h"
#include "dlsc_random.h"

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

struct InType
{
    dlsc_bv<3,PARAM_BITS> data;
    bool last;
};

struct OutType
{
    uint32_t data;
    bool last;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();
    void stim_thread();
    void watchdog_thread();

    dlsc_random rng_;

    double in_rate_;

    std::deque<InType> in_queue_;
    std::deque<OutType> out_queue_;

    void run_test();
    
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
    clk("clk",10,SC_NS),
    in_rate_(1.0)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst         = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::clk_method()
{
    if(rst)
    {
        in_valid    = 0;
        in_last     = 0;
        in_data     = 0;
        in_queue_.clear();
        out_queue_.clear();
        return;
    }

    // ** input **

    in_valid    = 0;

    if(!in_queue_.empty() && rng_.rand_bool(in_rate_))
    {
        InType const & in = in_queue_.front();

        in_valid        = 1;
        in_last         = in.last;
        in_data.write(in.data);

        in_queue_.pop_front();
    }

    // ** output **

    if(out_valid)
    {
        if(out_queue_.empty()) {
            dlsc_error("unexpected output");
        } else {
            OutType const & out = out_queue_.front();
            dlsc_assert_equals(out.last,out_last);
            dlsc_assert_equals(out.data,out_data);
            out_queue_.pop_front();
        }
    }
}

void __MODULE__::run_test()
{
    in_rate_ = rng_.rand_bool(0.5) ? 1.0 : rng_.rand(0.1,1.0);
    
    sc_time const end_time = sc_time_stamp() + sc_time(rng_.rand(100,2000),SC_US);

    InType in;
    OutType out;

    int64_t win[3][3];
    int64_t sorted[3][3];

    do
    {
        int const width = rng_.rand(3,1024);

        for(int col=0;col<width;++col)
        {
            // shift window
            for(int y=0;y<3;++y) {
                for(int x=1;x<3;++x) {
                    win[y][x-1] = win[y][x];
                }
            }

            // add new column
            in.last = (col == (width-1));
            for(int y=0;y<3;++y) {
                win[y][2] = rng_.rand(0ll,(1ll<<PARAM_BITS)-1ll);
                in.data[y] = win[y][2];
            }
            in_queue_.push_back(in);

            // sort window
            // TODO: bit of a hack..
            memcpy(sorted,win,3*3*sizeof(int64_t));
            std::sort(&sorted[0][0],&sorted[2][2]+1);

            out.last = in.last;
            out.data = static_cast<uint32_t>(sorted[1][1]); // median

            if(col >= 2)
                out_queue_.push_back(out);

            while(in_queue_.size() > 150)
                wait(1,SC_US);
        }
    } while(sc_time_stamp() < end_time);
}

void __MODULE__::stim_thread()
{
    rst     = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());

    int const iterations = 100;
    for(int iteration=0;iteration<iterations;++iteration)
    {
        dlsc_info("** iteration " << (iteration+1) << "/" << iterations << " **");

        wait(clk.posedge_event());
        rst = 0;
        wait(clk.posedge_event());

        run_test();

        while(!(in_queue_.empty() && out_queue_.empty())) {
            wait(1,SC_US);
        }
    
        wait(clk.posedge_event());
        rst = 1;
        wait(clk.posedge_event());
    }

    wait(10,SC_US);

    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    for(int i=0;i<50;i++) {
        wait(10,SC_MS);
        dlsc_info(". " << in_queue_.size() << " " << out_queue_.size());
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/

