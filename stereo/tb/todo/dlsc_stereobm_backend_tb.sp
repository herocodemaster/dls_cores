//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define IMG_WIDTH   320
#define IMG_HEIGHT  21
#define DISP_BITS   6
#define DISPARITIES (1<<DISP_BITS)
#define MULT_R      3
#define SAD         9
#define DATA        9

#define DISP_BITS_R (DISP_BITS*MULT_R)
#define DATA_R      (DATA*MULT_R)

#define END_WIDTH   ( IMG_WIDTH - (DISPARITIES-1) - (SAD-1) )

struct front_type {
    unsigned int    left[MULT_R];
    unsigned int    right[MULT_R];
};

struct check_type {
    unsigned int    disp[MULT_R];
    bool            disp_valid[MULT_R];
    bool            disp_valid_any;
    unsigned int    left[MULT_R];
    unsigned int    right[MULT_R];
    unsigned int    x;
    unsigned int    y;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void frontend_method();

    void input_method();
    std::deque<check_type> input_vals;

    void input_thread();

    void check_method();

    void stim_thread();
    void watchdog_thread();

    unsigned int frames_run;

    std::deque<check_type> check_vals;
    std::deque<front_type> front_vals;

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
    SP_CELL(dut,Vdlsc_stereobm_backend);
        /*AUTOINST*/

    frames_run = 0;

    SC_THREAD(input_thread);
    
    SC_METHOD(frontend_method);
        sensitive << clk.posedge_event();
    
    SC_METHOD(input_method);
        sensitive << clk.posedge_event();
    
    SC_METHOD(check_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::frontend_method() {
    if(rst) {
        front_vals.clear();
        back_valid      = 0;
        back_left       = 0;
        back_right      = 0;
        return;
    }

    if(!back_busy && front_vals.size() < 16 && (rand()%4) == 0) {
        front_type frnt;
        back_valid          = 1;

#if DATA_R <= 64
        uint64_t left       = 0;
        uint64_t right      = 0;
#else
        sc_bv<DATA_R> left  = 0;
        sc_bv<DATA_R> right = 0;
#endif

        for(unsigned int i=0;i<MULT_R;++i) {
            frnt.left[i]  = rand() & ((1<<DATA)-1);
            frnt.right[i] = rand() & ((1<<DATA)-1);
#if DATA_R <= 64
            left  |= ( ((uint64_t)frnt.left[i])  << (i*DATA) );
            right |= ( ((uint64_t)frnt.right[i]) << (i*DATA) );
#else
            left.range ( (i*DATA)+DATA-1 , (i*DATA) ) = frnt.left[i];
            right.range( (i*DATA)+DATA-1 , (i*DATA) ) = frnt.right[i];
#endif
        }

        back_left.write(left);
        back_right.write(right);

        front_vals.push_back(frnt);
    } else {
        back_valid          = 0;
        back_left           = 0;
        back_right          = 0;
    }
}

void __MODULE__::input_thread() {
    check_type chk;
    front_type frnt;

    while(true) {

        dlsc_verb("starting frame " << frames_run);

        for(unsigned int yr=0;yr<IMG_HEIGHT;yr+=MULT_R) {

            wait(1,SC_US);

            dlsc_verb("starting row " << yr);

            for(unsigned int x=0;x<IMG_WIDTH;++x) {

                while(front_vals.empty() || input_vals.size() > 10) {
                    wait(clk.posedge_event());
                }
                
                frnt = front_vals.front(); front_vals.pop_front();

                chk.disp_valid_any = false;
                for(unsigned int i=0;i<MULT_R;++i) {
                    unsigned int y = yr+i;

                    chk.disp_valid[i]   = ( y >= (SAD/2) ) &&
                                          ( y <  (IMG_HEIGHT-(SAD/2)) ) &&
                                          ( x >= ((SAD/2)+(DISPARITIES-1)) ) &&
                                          ( x <  (IMG_WIDTH-(SAD/2)) );
                    chk.disp[i]         = chk.disp_valid[i] ? ( rand()%DISPARITIES ) : 0;
                    chk.left[i]         = frnt.left[i];
                    chk.right[i]        = frnt.right[i];

                    if(chk.disp_valid[i])
                        chk.disp_valid_any = true;
                }
                    
                chk.x       = x;
                chk.y       = yr;

                input_vals.push_back(chk);
                check_vals.push_back(chk);
            }
        }
        
        wait(10,SC_US);

        ++frames_run;
    }
}

void __MODULE__::input_method() {
    if(!input_vals.empty()) {

        check_type chk = input_vals.front(); input_vals.pop_front();

#if DISP_BITS_R <= 64
        uint64_t disp = 0;
#else
        sc_bv<DISP_BITS_R> disp = 0;
#endif

        for(unsigned int i=0;i<MULT_R;++i) {
#if DISP_BITS_R <= 64
            disp |= ( ((uint64_t)chk.disp[MULT_R-1-i]) << (i*DISP_BITS) );
#else
            disp.range( (i*DISP_BITS)+DISP_BITS-1 , (i*DISP_BITS) ) = chk.disp[MULT_R-1-i];
#endif
        }

        in_valid    = chk.disp_valid_any;
        in_disp     = disp;

    } else {
        in_valid    = 0;
        in_disp     = 0;
    }
}

void __MODULE__::check_method() {
    if(out_ready && out_valid) {
        if(check_vals.empty()) {
            dlsc_error("unexpected output");
        } else {
            check_type chk = check_vals.front(); check_vals.pop_front();

            sc_bv<DISP_BITS_R>  disp        = out_disp.read();
            sc_bv<MULT_R>       disp_valid  = out_disp_valid.read();
            sc_bv<DATA_R>       left        = out_left.read();
            sc_bv<DATA_R>       right       = out_right.read();

            for(unsigned int i=0;i<MULT_R;++i) {
                dlsc_assert(disp.range( (i*DISP_BITS)+DISP_BITS-1 , (i*DISP_BITS) ) == chk.disp[i]);
                dlsc_assert(disp_valid[i]  == chk.disp_valid[i]);
                dlsc_assert( left.range( (i*DATA)+DATA-1 , (i*DATA) ) == chk.left [i]);
                dlsc_assert(right.range( (i*DATA)+DATA-1 , (i*DATA) ) == chk.right[i]);
            }

            dlsc_assert(out_frame_first == (chk.x == 0 && chk.y == 0));
            dlsc_assert(out_frame_last  == (chk.x == (IMG_WIDTH-1) && chk.y == (IMG_HEIGHT-MULT_R)));
            dlsc_assert(out_row_first   == (chk.x == 0));
            dlsc_assert(out_row_last    == (chk.x == (IMG_WIDTH-1)));
        }
    }

    if(!check_vals.empty()) {
        if(!out_ready && (rand() % 20) == 0) {
            out_ready  = 1;
        } else if(out_ready && (rand() % 10) == 0) {
            out_ready  = 0;
        }
    } else {
        out_ready   = 0;
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);

    wait(clk.posedge_event());
    rst     = 1;
    wait(clk.posedge_event());
    rst     = 0;

    while(frames_run < 3) {
        wait(100,SC_US);
    }

    wait(10,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(5,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



