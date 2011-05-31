//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define IN_DATA     PARAM_IN_DATA
#define OUT_DATA    PARAM_OUT_DATA
#define OUT_CLAMP   PARAM_OUT_CLAMP
#define IMG_WIDTH   PARAM_IMG_WIDTH
#define IMG_HEIGHT  PARAM_IMG_HEIGHT

#define OUT_OFFSET (OUT_CLAMP/2)

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void run_image();

    void in_method();
    std::deque<uint32_t> in_vals;

    void out_method();
    std::deque<uint32_t> out_vals;

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
    
    SC_METHOD(in_method);
        sensitive << clk.negedge_event();
    
    SC_METHOD(out_method);
        sensitive << clk.negedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::in_method() {
    if(rst) {
        in_valid    = 0;
        in_px       = 0;
        in_vals.clear();
        return;
    }

    if(!in_valid || in_ready) {
        if(!in_vals.empty() && rand()%10) {

            in_valid    = 1;
            in_px       = in_vals.front(); in_vals.pop_front();

        } else {
            in_valid    = 0;
            in_px       = 0;
        }
    }
}

void __MODULE__::out_method() {
    if(rst) {
        out_ready   = 0;
        out_vals.clear();
        return;
    }

    if(out_valid) {
        if(out_vals.empty()) {
            dlsc_error("unexpected data");
        } else if(out_ready) {
            dlsc_assert_equals(out_px,out_vals.front());
            out_vals.pop_front();
        }
    }

    if(!out_ready || out_valid) {
        if(!out_ready) {
            if(rand()%100 == 0) out_ready = 1;
        } else {
            if(rand()%1000 == 0) out_ready = 0;
        }
    }
}

void __MODULE__::run_image() {

    uint8_t *img[IMG_HEIGHT];
    
    int x,y;

    // allocate memory and create random image
    for(y=0;y<IMG_HEIGHT;++y) {
        img[y] = new uint8_t[IMG_WIDTH];
        for(x=0;x<IMG_WIDTH;++x) {
            img[y][x] = (uint8_t)(rand());
            in_vals.push_back(img[y][x]);
        }
    }

    // compute xsobel
    for(y=0;y<IMG_HEIGHT;++y) {

        const uint8_t *r0 = (y > 0)              ? img[y-1] : img[y+1];
        const uint8_t *r1 =                                  img[y  ];
        const uint8_t *r2 = (y < (IMG_HEIGHT-1)) ? img[y+1] : img[y-1];

        out_vals.push_back(OUT_OFFSET); // first pixel

        for(int x=1;x<(IMG_WIDTH-1);++x) {
            
            int d0  = r0[x+1] - r0[x-1];
            int d1  = r1[x+1] - r1[x-1];
            int d2  = r2[x+1] - r2[x-1];

            int v   = d0 + 2*d1 + d2 + OUT_OFFSET;

            if(v < 0) v = 0;
            else if(v > OUT_CLAMP) v = OUT_CLAMP;

            out_vals.push_back((uint8_t)v);

        }
        
        out_vals.push_back(OUT_OFFSET); // last pixel

    }

    // cleanup
    for(y=0;y<IMG_HEIGHT;++y) {
        delete img[y];
    }

}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);
    wait(clk.negedge_event());
    rst     = 0;

    for(int i=0;i<10;++i) {
        while(in_vals.size()>110) {
            wait(1,SC_US);
        }
        dlsc_info("sending frame " << i);
        run_image();
    }

    while(!out_vals.empty()) wait(1,SC_US);

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



