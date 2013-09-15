//######################################################################
#sp interface

//#include <systemc>
#include <systemperl.h>

#include <deque>

#include "dlsc_stereobm_models_sc.h"

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;
#ifdef PARAM_IS_BUFFERED
    sc_clock core_clk;
#endif

    void stim_thread();
    void watchdog_thread();

    // input driver
    void in_method();
    std::deque<in_type> in_vals;

    // output checking
    void out_method();
    std::deque<out_type> out_vals;
    unsigned int frames_done;

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

#include "dlsc_bv.h"

// aim for clocks that are mostly throughput-matched
#define CLK_MHZ (20.0)
#define CORE_CLK_MHZ ( PARAM_CORE_CLK_FACTOR * (CLK_MHZ * (IMG_WIDTH-DISPARITIES+SAD)/(1.0*IMG_WIDTH)) * (DISPARITIES)/(1.0*MULT_D*PARAM_MULT_R) )

#ifdef PARAM_IS_BUFFERED
SP_CTOR_IMP(__MODULE__) : clk("clk",1000.0/CLK_MHZ,SC_NS), core_clk("core_clk",1000.0/CORE_CLK_MHZ,SC_NS) /*AUTOINIT*/ {
#else
SP_CTOR_IMP(__MODULE__) : clk("clk",1000.0/CORE_CLK_MHZ,SC_NS) /*AUTOINIT*/ {
#endif
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst = 1;

    SC_METHOD(in_method);
        sensitive << clk.posedge_event();

    SC_METHOD(out_method);
        sensitive << clk.posedge_event();

    frames_done = 0;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

// image data input
void __MODULE__::in_method() {
    if(rst) {
        in_vals.clear();
        in_valid    = 0;
        in_left     = 0;
        in_right    = 0;
    } else if(!in_valid || in_ready) {
        if(!in_vals.empty() && (rand()%25) ) {
            in_type in = in_vals.front(); in_vals.pop_front();

            dlsc_bv<MULT_R,DATA> left, right;
            for(unsigned int i=0;i<MULT_R;++i) {
                left[i] = in.left[i];
                right[i] = in.right[i];
            }

            in_valid          = 1;
            in_left.write(left);
            in_right.write(right);
        } else {
            in_valid          = 0;
            in_left           = 0;
            in_right          = 0;
        }
    }
}

// output check
void __MODULE__::out_method() {
    if(rst) {
        out_vals.clear();
        out_ready   = 0;
    } else {
        if(out_valid) {
            if(out_vals.empty()) {
                dlsc_error("unexpected data");
            } else if(out_ready) {
                out_type chk = out_vals.front(); out_vals.pop_front();

                dlsc_bv<MULT_R,DISP_BITS_S> disp_bv     = out_disp.read();
                dlsc_bv<MULT_R,1,bool>      masked_bv   = out_masked.read();
                dlsc_bv<MULT_R,1,bool>      filtered_bv = out_filtered.read();
                dlsc_bv<MULT_R,DATAF>       left_bv     = out_left.read();
                dlsc_bv<MULT_R,DATAF>       right_bv    = out_right.read();

                for(unsigned int i=0;i<MULT_R;++i)
                {
                    dlsc_assert_equals(masked_bv[i], !chk.disp_valid[i]);
#if OUT_LEFT>0
                    dlsc_assert_equals(left_bv[i], chk.left[i]);
#endif
#if OUT_RIGHT>0
                    dlsc_assert_equals(right_bv[i], chk.right[i]);
#endif
                    if(chk.disp_valid[i]) {
                        dlsc_assert_equals(filtered_bv[i], chk.disp_filtered[i]);
                        dlsc_assert_equals(disp_bv[i],chk.disp[i]);
//                        if(d != chk.disp[i]) {
//                            dlsc_error("at (" << chk.x << "," << (chk.y+i) << "), out_disp[" << i << "] (" << d << ") != chk.disp (" << chk.disp[i] << ")");
//                        }
                    }
                }

//                dlsc_assert_equals(out_frame_first , chk.frame_first);
//                dlsc_assert_equals(out_frame_last  , chk.frame_last);
//                dlsc_assert_equals(out_row_first   , chk.row_first);
//                dlsc_assert_equals(out_row_last    , chk.row_last);

                if(chk.frame_first) {
                    dlsc_info("starting frame " << frames_done);
                }
                if(chk.row_first) {
                    dlsc_info("starting row " << chk.y);
                }
                if(chk.frame_last) {
                    dlsc_info("completed frame " << frames_done);
                    ++frames_done;
                }
            }
        }
        if(!out_ready || out_valid) {
//            out_ready = 1;
            if(out_ready) {
                if(rand() % 2000 == 0) {
                    out_ready = 0;
                }
            } else {
                if(rand() % 200 == 0) {
                    out_ready = 1;
                }
            }
            out_ready = (rand() % 4);
        }
    }
}

void __MODULE__::stim_thread() {

    dlsc_info("core clock frequency: " << CORE_CLK_MHZ << " MHz");

    rst     = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst     = 0;

    dlsc_stereobm_run_test(
        "data/tsukuba.scene1.row3.col3.ppm",
        "data/tsukuba.scene1.row3.col2.ppm",
        in_vals,
        out_vals);

    // reset after ~15 rows
    wait( (1.0/CLK_MHZ)*(IMG_WIDTH*(SAD+15)) ,SC_US);
    wait(clk.posedge_event());
    rst     = 1;
    wait(clk.posedge_event());
    rst     = 0;

    dlsc_stereobm_run_test(
        "data/tsukuba.scene1.row3.col1.ppm",
        "data/tsukuba.scene1.row3.col5.ppm",
        in_vals,
        out_vals);

    dlsc_stereobm_run_test(
        "data/tsukuba.scene1.row3.col2.ppm",
        "data/tsukuba.scene1.row3.col4.ppm",
        in_vals,
        out_vals);

    while(frames_done < 2) {
        wait(100,SC_US);
    }

    wait(100,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(200,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



