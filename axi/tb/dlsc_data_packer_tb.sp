//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#if (PARAM_WORDS_ZERO)
    #define WORDS_ZERO
#endif

#ifdef WORDS_ZERO
    #define MAX_WORDS ((1<<PARAM_WLEN))
#else
    #define MAX_WORDS ((1<<PARAM_WLEN)-1)
#endif

struct cmd_type {
    uint32_t    offset;
    uint32_t    bpw;        // bytes per word
    uint32_t    words;
};

struct out_type {
    bool        last;
    uint32_t    data;
    uint32_t    strb;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();

    void stim_thread();
    void watchdog_thread();

    std::deque<cmd_type> cmd_queue;
    std::deque<uint32_t> in_queue;
    std::deque<out_type> out_queue;

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
        cmd_bpw     = 0;
        cmd_words   = 0;
        in_valid    = 0;
        in_data     = 0;
        out_ready   = 0;

        in_queue.clear();
        out_queue.clear();
    } else {

        // ** commands **

        if( cmd_ready ) {
            cmd_valid   = 0;
        }

        if( (cmd_ready || !cmd_valid) && !cmd_queue.empty() && dlsc_rand_bool(25.0) ) {
            cmd_type cmd = cmd_queue.front(); cmd_queue.pop_front();

            assert(cmd.words > 0 && cmd.words <= MAX_WORDS);
            assert(cmd.offset <= 3);
            assert(cmd.bpw > 0 && cmd.bpw <= 4);

            cmd_valid   = 1;
            cmd_offset  = cmd.offset;
            cmd_bpw     = (cmd.bpw-1);  // 0 based
            #ifdef WORDS_ZERO
                cmd_words   = (cmd.words-1);// 0 based
            #else
                cmd_words   = cmd.words;    // 1 based
            #endif

            // generate words and corresponding byte stream
            std::deque<uint8_t> bytes;
            std::deque<bool> strobes;
            uint32_t d = 0;
            for(int i=0;i<(cmd.words*cmd.bpw);++i) {
                uint32_t b  = (i+1) & 0xFF;//dlsc_rand_u32(0,0xFF);
                bytes.push_back(b);
                strobes.push_back(true);
                d |= (b << ((i%cmd.bpw)*8));
                if( (i%cmd.bpw) == (cmd.bpw-1) ) {
                    in_queue.push_back(d);
                    d = 0;
                }
            }

            // pad the front
            for(int i=0;i<cmd.offset;++i) {
                strobes.push_front(false);
                bytes.push_front(0);
            }
            // pad the back
            while((bytes.size()%4) != 0) {
                strobes.push_back(false);
                bytes.push_back(0);
            }

            // convert bytes to output data
            out_type out;
            for(int i=0;i<bytes.size();i+=4) {
                out.data =  (bytes[i  ]      ) |
                            (bytes[i+1] << 8 ) |
                            (bytes[i+2] << 16) |
                            (bytes[i+3] << 24);
                out.strb =  (strobes[i  ] ? 0x1 : 0x0) |
                            (strobes[i+1] ? 0x2 : 0x0) |
                            (strobes[i+2] ? 0x4 : 0x0) |
                            (strobes[i+3] ? 0x8 : 0x0);
                out.last = (i == (bytes.size()-4));
                out_queue.push_back(out);
            }
        }

        // ** data **

        if(in_ready) {
            in_valid    = 0;
        }

        if( (in_ready || !in_valid) && !in_queue.empty() && dlsc_rand_bool(95.0) ) {
            in_valid    = 1;
            in_data     = in_queue.front(); in_queue.pop_front();
        }

        // ** words **

        if(out_ready && out_valid) {
            if(out_queue.empty()) {
                dlsc_error("unexpected data");
            } else {
                out_type out = out_queue.front(); out_queue.pop_front();

                dlsc_assert_equals(out.last,out_last);
                dlsc_assert_equals(out.data,out_data);
                dlsc_assert_equals(out.strb,out_strb);
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

    for(int i=0;i<1000;++i) {
        cmd_type cmd;
        switch(dlsc_rand_u32(0,20)) {
            case 3:  cmd.words = 1; break;
            case 7:  cmd.words = MAX_WORDS; break;
            default: cmd.words = dlsc_rand_u32(1,MAX_WORDS);
        }
        cmd.offset  = dlsc_rand_u32(0,3);
        cmd.bpw     = dlsc_rand_u32(1,4);
        cmd_queue.push_back(cmd);
    }

    while( !(cmd_queue.empty() && in_queue.empty() && out_queue.empty()) ) {
        wait(1,SC_US);
    }

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(100,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/

