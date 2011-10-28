//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define BPP PARAM_BPP

#define BYTES_PER_PIXEL (BPP/8)
#define MAX_PIXELS ((1<<PARAM_PLEN)-1)

struct cmd_type {
    uint32_t    offset;
    uint32_t    pixels;
};

struct px_type {
    uint32_t    data;
    bool        last;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();

    void stim_thread();
    void watchdog_thread();

    std::deque<cmd_type> cmd_queue;
    std::deque<uint32_t> data_queue;
    std::deque<px_type> px_queue;

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

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
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
        cmd_valid   = 0;
        cmd_offset  = 0;
        cmd_pixels  = 0;
        in_valid    = 0;
        in_data     = 0;
        out_ready   = 0;

        data_queue.clear();
        px_queue.clear();
    } else {

        // ** commands **

        if( cmd_ready ) {
            cmd_valid   = 0;
        }

        if( (cmd_ready || !cmd_valid) && !cmd_queue.empty() && dlsc_rand_bool(25.0) ) {
            cmd_type cmd = cmd_queue.front(); cmd_queue.pop_front();

            assert(cmd.pixels > 0);
            assert( (cmd.offset & ~0x3u) == 0 );
            #if (BPP==16)
                assert( (cmd.offset & 0x1) == 0 );
            #elif (BPP==32)
                assert( cmd.offset == 0 );
            #endif

            cmd_valid   = 1;
            cmd_pixels  = cmd.pixels;
            cmd_offset  = cmd.offset;

            // generate pixels and corresponding byte stream
            std::deque<uint8_t> bytes;
            px_type px;
            px.last     = false;
            px.data     = 0;
            for(int i=0;i<(cmd.pixels*BYTES_PER_PIXEL);++i) {
                uint32_t b  = (i+1) & 0xFF;//dlsc_rand_u32(0,0xFF);
                bytes.push_back(b);
                px.data     |= (b << ((i%BYTES_PER_PIXEL)*8));
                if( (i%BYTES_PER_PIXEL) == (BYTES_PER_PIXEL-1) ) {
                    px.last     = (i == (cmd.pixels*BYTES_PER_PIXEL)-1);
                    px_queue.push_back(px);
                    px.data     = 0;
                }
            }

            // pad the front
            for(int i=0;i<cmd.offset;++i) {
                bytes.push_front(0);
            }
            // pad the back
            while((bytes.size()%4) != 0) {
                bytes.push_back(0);
            }

            // convert bytes to input data
            uint32_t d = 0;
            for(int i=0;i<bytes.size();++i) {
                d       |= bytes[i] << ((i%4)*8);
                if( (i%4) == 3 ) {
                    data_queue.push_back(d);
                    d       = 0;
                }
            }
        }

        // ** data **

        if(in_ready) {
            in_valid    = 0;
        }

        if( (in_ready || !in_valid) && !data_queue.empty() && dlsc_rand_bool(95.0) ) {
            in_valid    = 1;
            in_data     = data_queue.front(); data_queue.pop_front();
        }

        // ** pixels **

        if(out_ready && out_valid) {
            if(px_queue.empty()) {
                dlsc_error("unexpected data");
            } else {
                px_type px = px_queue.front(); px_queue.pop_front();

                dlsc_assert_equals(px.data,out_data);
                dlsc_assert_equals(px.last,out_last);
            }
        }

        out_ready = dlsc_rand_bool(95.0);

    }
}

void __MODULE__::stim_thread() {
    rst         = 1;
    wait(100,SC_NS);
    wait(clk.posedge_event());
    rst         = 0;

    for(int i=0;i<100;++i) {
        cmd_type cmd;
        switch(dlsc_rand_u32(0,20)) {
            case 3: cmd.pixels = 1; break;
            case 7: cmd.pixels = MAX_PIXELS; break;
            default: cmd.pixels = dlsc_rand_u32(1,MAX_PIXELS);
        }
        cmd.offset = dlsc_rand_u32(0,0x3);
        #if (BPP==16)
            cmd.offset &= 0x2;
        #elif (BPP==32)
            cmd.offset = 0;
        #endif
        cmd_queue.push_back(cmd);
    }

    while( !(cmd_queue.empty() && px_queue.empty()) ) {
        wait(1,SC_US);
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

