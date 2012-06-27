//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

// for syntax highlighter: SC_MODULE

// Verilog parameters
#define DATA            PARAM_BITS
#define DATA_MAX ((1<<DATA)-1)

/*AUTOSUBCELL_CLASS*/

struct out_type {
    uint32_t data;
    bool row_last;
    bool frame_last;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();
    void stim_thread();
    void watchdog_thread();
    
    void send_frame();
    
    std::deque<uint32_t> in_queue;
    std::deque<out_type> out_queue;

    double in_rate;
    double out_rate;

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
    clk("clk",10.0,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst     = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::clk_method() {
    if(rst) {
        in_valid    = 0;
        in_data     = 0;
        out_ready   = 0;
        in_queue.clear();
        out_queue.clear();
        return;
    }

    // ** inputs **

    if(in_ready) {
        in_valid    = 0;
        in_data     = 0;
    }

    if( (!in_valid || in_ready) && !in_queue.empty() && dlsc_rand_bool(in_rate)) {
        in_valid    = 1;
        in_data     = in_queue.front(); in_queue.pop_front();
    }

    // ** outputs **

    if(out_valid) {
        if(out_queue.empty()) {
            dlsc_error("unexpected output");
        } else if(out_ready) {
            out_type out = out_queue.front(); out_queue.pop_front();
            dlsc_assert_equals(out.row_last,out_row_last);
            dlsc_assert_equals(out.frame_last,out_frame_last);
            dlsc_assert_equals(out.data,out_data);
        }
    }

    out_ready = dlsc_rand_bool(out_rate);

}

void __MODULE__::send_frame() {
    int width       = cfg_width+1;
    int height      = cfg_height+1;

    // ** create image **

    uint32_t **img = new uint32_t*[height+4];
    img = &img[2];
    for(int y=0;y<height;y++) {
        img[y]  = new uint32_t[width+4];
        img[y]  = &img[y][2];
        for(int x=0;x<width;x++) {
            img[y][x]   = dlsc_rand_u32(0,DATA_MAX);
            img[y][x]   = (((y+1)*10)+x) & DATA_MAX;
            in_queue.push_back(img[y][x]);
        }
        // repeat columns
        img[y][-2]      = img[y][0];
        img[y][-1]      = img[y][1];
        img[y][width  ] = img[y][width-2];
        img[y][width+1] = img[y][width-1];
    }
    // repeat rows
    img[-2]         = img[0];
    img[-1]         = img[1];
    img[height  ]   = img[height-2];
    img[height+1]   = img[height-1];


    // ** compute expected results **

    for(int y=0;y<height;y++) {
        for(int x=0;x<width;x++) {

            out_type out;
            out.row_last    = (x == (width-1));
            out.frame_last  = out.row_last && (y == (height-1));
            for(int j=-2;j<=2;j++) {
                out.data        = img[y+j][x];
                out_queue.push_back(out);
            }
        }
    }


    // ** cleanup **
    for(int y=0;y<height;y++) {
        img[y] = &img[y][-2];
        delete img[y];
    }
    img = &img[-2];
    delete img;
}



void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);

    for(int iterations=0;iterations<1000;iterations++) {
        dlsc_info("== test " << iterations << " ==");

        in_rate     = 0.1 * dlsc_rand(50,1000);
        out_rate    = 0.1 * dlsc_rand(50,1000);

        cfg_width   = dlsc_rand(10,100)-1;
        cfg_height  = dlsc_rand(10,30)-1;

        wait(sc_core::SC_ZERO_TIME);

        dlsc_info("  in_rate:   " << in_rate);
        dlsc_info("  out_rate:  " << out_rate);
        dlsc_info("  width:     " << (cfg_width+1));
        dlsc_info("  height:    " << (cfg_height+1));

        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());

        for(int j=0;j<dlsc_rand(3,10);j++) {
            send_frame();
            while(in_queue.size() > 100) wait(1,SC_US);
        }
    
        while(!out_queue.empty()) wait(1,SC_US);

        wait(clk.posedge_event());
        rst     = 1;
        wait(clk.posedge_event());
    }

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    for(int i=0;i<1000;i++) {
        wait(1,SC_MS);
        dlsc_info(". " << out_queue.size());
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



