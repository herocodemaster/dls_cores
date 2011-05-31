//######################################################################
#sp interface

#include <systemperl.h>
#include <deque>

/*AUTOSUBCELL_CLASS*/


#define IMG_WIDTH       320
#define IMG_HEIGHT      16
#define ADDR            10
#define DISP_BITS       6
#define DISPARITIES     (1<<DISP_BITS)
#define MULT_D          4
#define MULT_R          2
#define SAD             9
#define DATA            8

#define SAD_R           (SAD+MULT_R-1)
#define DATA_R          (DATA*MULT_R)

#define PASSES          (DISPARITIES/MULT_D)

struct pipe_pair {
    unsigned int    left[MULT_R];
    unsigned int    right[MULT_R];
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void send_frame();
    unsigned int    frames_sent;

    void stim_thread();
    void watchdog_thread();

    void back_busy_thread();
    void back_busy_method();
    unsigned int    back_busy_cnt;

    void input_method();
    std::deque<pipe_pair> in_vals;

    void buf_method();
    unsigned int    chk_buf_addr;

    void pipe_method();
    unsigned int    chk_pipe_left;
    unsigned int    chk_pipe_right;
    unsigned int    chk_pipe_pass;

    void back_method();
    std::deque<pipe_pair> buf_vals;
    unsigned int    chk_back_addr;
    unsigned int    rows_done;
    unsigned int    frames_done;

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
    SP_CELL(dut,Vdlsc_stereobm_frontend_control);
        /*AUTOINST*/

    rst             = 1;
    back_busy       = 0;

    back_busy_cnt   = 0;
    
    frames_sent     = 0;

    rows_done       = 0;
    frames_done     = 0;
 
    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);

    SC_THREAD(back_busy_thread);
    SC_METHOD(back_busy_method);
        sensitive << clk.posedge_event();

    SC_METHOD(input_method);
        sensitive << clk.posedge_event();
    SC_METHOD(buf_method);
        sensitive << clk.posedge_event();
    SC_METHOD(pipe_method);
        sensitive << clk.posedge_event();
    SC_METHOD(back_method);
        sensitive << clk.posedge_event();
}

void __MODULE__::back_busy_thread() {
    while(true) {
        for(int i=0;i<PASSES-1;++i) {
            wait(clk.posedge_event());
        }
        if(back_busy_cnt > 0) {
            --back_busy_cnt;
        }
    }
}

void __MODULE__::back_busy_method() {
    if(rst) {
        back_busy_cnt   = 0;
        back_busy       = 0;
        return;
    }

    back_busy = (back_busy_cnt >= (IMG_WIDTH*9)/10);
}

void __MODULE__::send_frame() {
    pipe_pair pp;
    for(unsigned int yr=0;yr<IMG_HEIGHT;yr+=MULT_R) {
        for(unsigned int x=0;x<IMG_WIDTH;++x) {
            for(unsigned int i=0;i<MULT_R;++i) {
                pp.left[i]  = rand() & ((1<<DATA)-1);
                pp.right[i] = rand() & ((1<<DATA)-1);
            }

            in_vals.push_back(pp);
        }
    }
    ++frames_sent;
}

void __MODULE__::input_method() {
    if(rst) {
        in_valid    = 0;
        in_left     = 0;
        in_right    = 0;
        in_vals.clear();
        return;
    }

    if(!in_valid || in_ready) {
        if(!in_vals.empty() && rand() % 4) {
            pipe_pair pp = in_vals.front(); in_vals.pop_front();
            buf_vals.push_back(pp);

#if DATA_R <= 64
            uint64_t left       = 0;
            uint64_t right      = 0;
            for(unsigned int i=0;i<MULT_R;++i) {
                left  |= ( ((uint64_t)pp.left[i])  << (i*DATA) );
                right |= ( ((uint64_t)pp.right[i]) << (i*DATA) );
            }
#else
            sc_bv<DATA_R> left  = 0;
            sc_bv<DATA_R> right = 0;
            for(unsigned int i=0;i<MULT_R;++i) {
                left.range ( (i*DATA)+DATA-1 , (i*DATA) ) = pp.left[i];
                right.range( (i*DATA)+DATA-1 , (i*DATA) ) = pp.right[i];
            }
#endif
            in_valid          = 1;
            in_left.write(left);
            in_right.write(right);

        } else {
            in_valid    = 0;
            in_left     = 0;
            in_right    = 0;
        }
    }
}

void __MODULE__::buf_method() {
    if(rst) {
        chk_buf_addr = 0;
        return;
    }

    if(buf_write) {
        dlsc_assert(addr_left == chk_buf_addr && addr_right == chk_buf_addr);

        if(chk_buf_addr == (IMG_WIDTH-1))
            chk_buf_addr = 0;
        else
            ++chk_buf_addr;
    }
}

void __MODULE__::pipe_method() {
    if(rst) {
        chk_pipe_left   = DISPARITIES-1;
        chk_pipe_right  = 0;
        chk_pipe_pass   = 0;
        return;
    }

    if(pipe_right_valid) {
        dlsc_assert(addr_right == chk_pipe_right);
        chk_pipe_right  += 1;
    }

    if(pipe_valid) {
        dlsc_assert(pipe_first == (chk_pipe_left == (DISPARITIES-1)));
        dlsc_assert(addr_left == chk_pipe_left);
        dlsc_assert(pipe_right_valid);
        
        if(chk_pipe_left == (IMG_WIDTH-1)) {
            if(chk_pipe_pass == (DISPARITIES-MULT_D)) {
                chk_pipe_pass   = 0;
            } else {
                chk_pipe_pass   += MULT_D;
            }
            chk_pipe_left   = DISPARITIES-1;
            chk_pipe_right  = chk_pipe_pass;
        } else {
            chk_pipe_left   += 1;
        }
    }
}

void __MODULE__::back_method() {
    if(rst) {
        chk_back_addr   = 0;
        rows_done       = 0;
        buf_vals.clear();
        return;
    }

    if(back_valid) {
        if(buf_vals.empty()) {
            dlsc_error("unexpected value");
        } else {
            pipe_pair pp = buf_vals.front(); buf_vals.pop_front();
            
//            sc_bv<DATA_R> left  = back_left.read();
//            sc_bv<DATA_R> right = back_right.read();
//
//            for(unsigned int i=0;i<MULT_R;++i) {
//                dlsc_assert( left.range( (i*DATA)+DATA-1 , (i*DATA) ) == pp.left [i]);
//                dlsc_assert(right.range( (i*DATA)+DATA-1 , (i*DATA) ) == pp.right[i]);
//            }
        }

        ++back_busy_cnt;

        dlsc_assert(addr_left == chk_back_addr && addr_right == chk_back_addr);

        if(chk_back_addr == (IMG_WIDTH-1)) {
            chk_back_addr   = 0;
            rows_done       += MULT_R;
            if( (rows_done % IMG_HEIGHT) == 0 ) {
                frames_done     += 1;
            }
        } else {
            chk_back_addr   += 1;
        }
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);

    wait(clk.posedge_event());
    rst     = 0;

    wait(1,SC_US);

    // send just a single frame, and confirm that it makes it through without halting
    send_frame();

    while(frames_done < frames_sent) {
        wait(100,SC_US);
    }

    // confirm all values made it out at end of single frame
    dlsc_assert(buf_vals.empty());

    // now run a couple consecutive frames
    for(int i=0;i<3;++i) {
        send_frame();
    }

    while(frames_done < frames_sent) {
        wait(100,SC_US);
    }

    // confirm all values made it out at end of last frame
    dlsc_assert(buf_vals.empty());

    wait(100,SC_US);
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



