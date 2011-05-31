//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

// Verilog parameters
#define DATA            PARAM_DATA
#define IMG_WIDTH       PARAM_IMG_WIDTH
#define IMG_HEIGHT      PARAM_IMG_HEIGHT
#define DISP_BITS       PARAM_DISP_BITS
#define DISPARITIES     PARAM_DISPARITIES
#define MULT_D          PARAM_MULT_D
#define MULT_R          PARAM_MULT_R
#define SAD             PARAM_SAD
#define TEXTURE         PARAM_TEXTURE
#define TEXTURE_CONST   PARAM_TEXTURE_CONST

#define SAD_R           (SAD+MULT_R-1)
#define DATA_R          (DATA*MULT_R)

#define PASSES          (DISPARITIES/MULT_D)

struct pipe_type {
    bool            valid;
    bool            first;
    bool            leftv[SAD_R];
    unsigned int    left[SAD_R];
    unsigned int    right[SAD_R];
    unsigned int    frame;
    unsigned int    x;
    unsigned int    y;
};

struct pipe_pair {
    unsigned int    left[MULT_R];
    unsigned int    right[MULT_R];
};

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void back_busy_thread();
    void back_busy_method();
    unsigned int    back_busy_cnt;

    // input generation
    void send_frame();
    unsigned int    frames_sent;

    // input driver
    void in_method();
    std::deque<pipe_pair> in_vals;

    // pipeline check
    void pipe_method();
    std::deque<pipe_type> pipe_vals;
    bool out_right_valid_reg;
    bool out_valid_reg;
    
    // backend check
    void back_method();
    std::deque<pipe_pair> back_vals;
    unsigned int    chk_back_addr;
    unsigned int    rows_done;
    unsigned int    frames_done;
    bool back_valid_reg;

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

    rst             = 1;
    back_busy       = 0;

    back_busy_cnt   = 0;
    
    frames_sent     = 0;

    rows_done       = 0;
    frames_done     = 0;

    out_right_valid_reg = false;
    out_valid_reg       = false;
    back_valid_reg      = false;

    SC_THREAD(back_busy_thread);
    SC_METHOD(back_busy_method);
        sensitive << clk.posedge_event();

    SC_METHOD(in_method);
        sensitive << clk.posedge_event();
    SC_METHOD(back_method);
        sensitive << clk.posedge_event();
    SC_METHOD(pipe_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
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

// image data input
void __MODULE__::in_method() {
    if(rst) {
        in_vals.clear();
        in_valid    = 0;
        in_left     = 0;
        in_right    = 0;
        return;
    }
    
    if(!in_valid || in_ready) {
        if(!in_vals.empty() && (rand()%25) ) {
            pipe_pair pp = in_vals.front(); in_vals.pop_front();
            back_vals.push_back(pp);

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

// image data output to backend
void __MODULE__::back_method() {
    if(rst) {
        back_vals.clear();
        chk_back_addr   = 0;
        rows_done       = 0;
        back_valid_reg  = false;
        return;
    }
    
    if(back_valid_reg) {
        if(back_vals.empty()) {
            dlsc_error("unexpected data (back)");
        } else {
            pipe_pair pp = back_vals.front(); back_vals.pop_front();
            
            sc_bv<DATA_R> left  = back_left.read();
            sc_bv<DATA_R> right = back_right.read();

            for(unsigned int i=0;i<MULT_R;++i) {
                dlsc_assert( left.range( (i*DATA)+DATA-1 , (i*DATA) ) == pp.left [i]);
                dlsc_assert(right.range( (i*DATA)+DATA-1 , (i*DATA) ) == pp.right[i]);
            }
        }

        ++back_busy_cnt;

        if(chk_back_addr == (IMG_WIDTH-1)) {
            chk_back_addr   = 0;
            rows_done       += MULT_R;
            if( (rows_done % IMG_HEIGHT) == 0 ) {
                dlsc_info("completed frame: " << frames_done);
                frames_done     += 1;
            }
        } else {
            chk_back_addr   += 1;
        }
    }

    back_valid_reg = back_valid;
}

// data output to pipeline
void __MODULE__::pipe_method() {
    if(rst) {
        pipe_vals.clear();
        out_right_valid_reg = false;
        out_valid_reg       = false;
        return;
    }
    
    if(out_right_valid_reg || out_valid_reg) {
        dlsc_assert(out_right_valid_reg);

        if(pipe_vals.empty()) {
            dlsc_error("unexpected data (pipeline)");
        } else {
            pipe_type chk = pipe_vals.front(); pipe_vals.pop_front();

            if(chk.first) {
                dlsc_verb("got first of frame: " << chk.frame << ", x: " << chk.x << ", y: " << chk.y);
            }

            sc_bv<DATA*SAD_R> left    = out_left.read();
            sc_bv<DATA*SAD_R> right   = out_right.read();

            for(unsigned int i=0;i<SAD_R;++i) {
                if(!chk.leftv[i]) continue;

                unsigned int rr = right.range((i*DATA)+DATA-1,(i*DATA)).to_uint();
                if( rr != chk.right[i]) {
                    dlsc_error("right[" << i << "] (" << rr << ") != chk.right[] (" << chk.right[i] << ")");
                } else {
                    dlsc_assert( rr == chk.right[i] );
                }

                if(chk.valid) {
                    unsigned int lr = left.range((i*DATA)+DATA-1,(i*DATA)).to_uint();
                    if( lr != chk.left[i]) {
                        dlsc_error("left[" << i << "] (" << lr << ") != chk.left[] (" << chk.left[i] << ")");
                    } else {
                        dlsc_assert( lr == chk.left[i] );
                    }
                }
            }

            dlsc_assert(out_valid_reg == chk.valid);
            if(chk.valid) {
                dlsc_assert(out_first == chk.first);
            }
        }
    }

    out_right_valid_reg = out_right_valid;
    out_valid_reg       = out_valid;
}

unsigned int rand_pixel() { return rand() % ( (((uint64_t)1)<<DATA) - 1 ); }

// generate input data
void __MODULE__::send_frame() {

    boost::shared_array<unsigned int> rows_l[IMG_HEIGHT];
    boost::shared_array<unsigned int> rows_r[IMG_HEIGHT];

    dlsc_info("generating frame: " << frames_sent);

    // create the entire frame first
    for(unsigned int y=0;y<IMG_HEIGHT;++y) {
        rows_l[y] = boost::shared_array<unsigned int>(new unsigned int[IMG_WIDTH]);
        rows_r[y] = boost::shared_array<unsigned int>(new unsigned int[IMG_WIDTH]);

//        for(unsigned int x=0;x<IMG_WIDTH;++x) {
//            rows_l[y][x] = (x * 1000) + y + (frames_sent * 1000000) + 1000000;
//            rows_r[y][x] = (x * 1000) + y + (frames_sent * 1000000) + 2000000;
//        }

        std::generate(rows_l[y].get(),rows_l[y].get()+IMG_WIDTH,rand_pixel);
        std::generate(rows_r[y].get(),rows_r[y].get()+IMG_WIDTH,rand_pixel);
    }

    // send the frame to input method
    pipe_pair pp;
    for(unsigned int yr=0;yr<IMG_HEIGHT;yr+=MULT_R) {
        for(unsigned int x=0;x<IMG_WIDTH;++x) {
            for(unsigned int i=0;i<MULT_R;++i) {
                pp.left[i]  = rows_l[yr+i][x];
                pp.right[i] = rows_r[yr+i][x];
            }
            in_vals.push_back(pp);
        }
    }

    // send the frame to pipeline checker method
    pipe_type chk;
    for(int yr=0;yr<IMG_HEIGHT;yr+=MULT_R) {
        int ym = yr+MULT_R-1; // maximum y encompassed by this pass
        if( ym >= (SAD-1) ) {
            for(int d=(DISPARITIES-MULT_D);d>=0;d-=MULT_D) {
                for(int x=(DISPARITIES-MULT_D);x<IMG_WIDTH;++x) {
                    int cnt=0;
                    for(int s=0;s<SAD_R;++s) {
                        int y = ym-(SAD_R-1-s);
                        if( y >= 0 && y < IMG_HEIGHT ) {
                            ++cnt;
                            chk.leftv[s]    = true;
                            chk.left[s]     = rows_l[y][x];
                            chk.right[s]    = rows_r[y][x-d];
                        } else {
                            chk.leftv[s]    = false;
                            chk.left[s]     = 0;
                            chk.right[s]    = 0;
                        }
                    }
                    if(cnt<SAD) { d=0; break; }
                    chk.valid   = (x >= (DISPARITIES-1));
                    chk.first   = (x == (DISPARITIES-1));
                    chk.frame   = frames_sent;
                    chk.x       = (unsigned int)x;
                    chk.y       = (unsigned int)yr;
                    pipe_vals.push_back(chk);
                }
            }
#if TEXTURE>0
            for(int x=(DISPARITIES-MULT_D);x<IMG_WIDTH;++x) {
                int cnt=0;
                for(int s=0;s<SAD_R;++s) {
                    int y = ym-(SAD_R-1-s);
                    if( y >= 0 && y < IMG_HEIGHT ) {
                        ++cnt;
                        chk.leftv[s]    = true;
                        chk.left[s]     = rows_l[y][x];
                        chk.right[s]    = TEXTURE_CONST;
                    } else {
                        chk.leftv[s]    = false;
                        chk.left[s]     = 0;
                        chk.right[s]    = 0;
                    }
                }
                if(cnt<SAD) { break; }
                chk.valid   = (x >= (DISPARITIES-1));
                chk.first   = (x == (DISPARITIES-1));
                chk.frame   = frames_sent;
                chk.x       = (unsigned int)x;
                chk.y       = (unsigned int)yr;
                pipe_vals.push_back(chk);
            }
#endif
        }
    }

    ++frames_sent;
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
    dlsc_assert(back_vals.empty());

    // now run a couple consecutive frames
    for(int i=0;i<3;++i) {
        send_frame();
    }

    while(frames_done < frames_sent) {
        wait(100,SC_US);
    }

    // confirm all values made it out at end of last frame
    dlsc_assert(back_vals.empty());

    wait(100,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(50,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



