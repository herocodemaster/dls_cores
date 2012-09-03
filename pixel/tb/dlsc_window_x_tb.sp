//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

// for syntax highlighter: SC_MODULE

#define WIN         PARAM_WIN
#define PX_MAX      ((1u<<PARAM_BITS)-1u)

#define EM_FILL     (PARAM_EDGE_MODE == 1)
#define EM_REPEAT   (PARAM_EDGE_MODE == 2)
#define EM_MIRROR   (PARAM_EDGE_MODE == 3)
#define EM_NONE     (!(EM_FILL || EM_REPEAT || EM_MIRROR))

/*AUTOSUBCELL_CLASS*/

struct in_type {
    bool        last;
    uint32_t    data;
};

struct out_type {
    bool        last;
    uint32_t    data[WIN];
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();

    void stim_thread();
    void watchdog_thread();

    void send_row();

    std::deque<in_type> in_queue;
    std::deque<out_type> out_queue;

    float in_rate;
    float out_rate;

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
    clk("clk",10,SC_NS)
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

void __MODULE__::clk_method() {
    if(rst) {
        in_valid    = 0;
        in_last     = 0;
        in_data     = 0;
        out_ready   = 0;
        in_queue.clear();
        out_queue.clear();
        return;
    }

    // ** input **

    if(in_ready) in_valid = 0;
    if(!in_queue.empty() && (!in_valid || in_ready) && dlsc_rand_bool(in_rate)) {
        in_type in = in_queue.front(); in_queue.pop_front();

        in_valid    = 1;
        in_last     = in.last;
        in_data     = in.data;
    }

    // ** output **

    if(out_ready && out_valid) {
        if(out_queue.empty()) {
            dlsc_error("unexpected output");
        } else {
            out_type out = out_queue.front(); out_queue.pop_front();
            dlsc_assert_equals(out.last,out_last);
            for(int i=0;i<WIN;i++) {
                uint32_t data = (out_data.read() >> (i*PARAM_BITS)) & PX_MAX;
                dlsc_assert_equals(out.data[i],data);
            }
        }
    }

    out_ready = dlsc_rand_bool(out_rate);
}

void __MODULE__::send_row() {
    if(dlsc_rand_bool(10)) {
        in_rate     = 1.0f * dlsc_rand(10,100);
    }
    if(dlsc_rand_bool(10)) {
        out_rate    = 1.0f * dlsc_rand(10,100);
    }

    int width = dlsc_rand(WIN+5,1000);

    uint32_t *px = new uint32_t[width+WIN-1];
    px += (WIN/2);

    // randomize input
    for(int x=0;x<width;x++) {
        // create pixel
        px[x]   = dlsc_rand_u32(0,PX_MAX);
        //px[x]   = x+1; // TODO
        // drive input
        in_type in;
        in.last = (x == (width-1));
        in.data = px[x];
        in_queue.push_back(in);
    }

    // fill edges
    for(int i=1;i<=(WIN/2);i++) {
        px[-i]          = 0;
        px[width-1+i]   = 0;
        #if EM_FILL
            px[-i]          = cfg_fill.read();
            px[width-1+i]   = cfg_fill.read();
        #endif
        #if EM_REPEAT
            px[-i]          = px[0];
            px[width-1+i]   = px[width-1];
        #endif
        #if EM_MIRROR
            px[-i]          = px[i];
            px[width-1+i]   = px[width-1-i];
        #endif
    }

    // generate output
    #if EM_NONE
        for(int x=0;x<(width-(WIN-1));x++) {
            out_type out;
            out.last    = (x == (width-(WIN-1)-1));
            for(int i=0;i<WIN;i++) {
                out.data[i] = px[x+i];
            }
            out_queue.push_back(out);
        }
    #else
        for(int x=0;x<width;x++) {
            out_type out;
            out.last    = (x == (width-1));
            for(int i=0;i<WIN;i++) {
                out.data[i] = px[x+i-(WIN/2)];
            }
            out_queue.push_back(out);
        }
    #endif

    px -= (WIN/2);
    delete px;
}

void __MODULE__::stim_thread() {
    in_rate     = 100.0f;
    out_rate    = 100.0f;
    rst         = 1;
    wait(100,SC_NS);

    for(int i=0;i<10000;i++) {
        if((i%500) == 0) {
            dlsc_info("iteration " << i);
        }
        if(rst) {
            wait(clk.posedge_event());
            assert(in_queue.empty() && out_queue.empty());
            cfg_fill.write(dlsc_rand_u32(0,PX_MAX));
            wait(clk.posedge_event());
            rst = 0;
            wait(clk.posedge_event());
        }

        while(in_queue.size() > 1000) wait(clk.posedge_event());
            
        send_row();

        if(dlsc_rand_bool(1.0)) {
            // going to reset..
            if(dlsc_rand_bool(50.0)) {
                // wait until idle before reset
                while(!(in_queue.empty() && out_queue.empty())) wait(clk.posedge_event());
            }
            wait(clk.posedge_event());
            rst = 1;
            wait(clk.posedge_event());
            if(dlsc_rand_bool(50.0)) {
                wait(dlsc_rand(1,10000),SC_NS);
            }
        }
    }

    while(!(in_queue.empty() && out_queue.empty())) wait(1,SC_US);

    wait(10,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(500,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/

