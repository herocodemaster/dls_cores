//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

// Verilog parameters
#define DATA            PARAM_DATA

#define DATA_MAX ((1<<DATA)-1)

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    sc_signal<uint32_t> tb_cycle;
    sc_signal<uint32_t> tb_state;

    void stim_thread();
    void watchdog_thread();

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
    clk_en      = 0;
    st          = 0;
    px_push     = 0;
    px_masked   = 0;
    px_last     = 0;
    px_row_red  = 1;
    px_in       = 0;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

struct vng_check_type {
    // axes_grad
    int grad_w;
    int grad_e;
    int grad_n;
    int grad_s;
    
    // diag_grad
    int grad_nw;
    int grad_sw;
    int grad_ne;
    int grad_se;

    // thresh
    int thresh;

    // sum
    int sum_red;
    int sum_green;
    int sum_blue;
    int sum_cnt;

    // diff
    int diff_redgreen;
    int diff_blue;

    // output
    int out_red;
    int out_green;
    int out_blue;
};


#define WIDTH 2000

void __MODULE__::stim_thread() {

    int i,x,y;

    // generate 5 rows of pixel data
    int * img[5];
    vng_check_type * chk;

    chk = new vng_check_type[WIDTH];

    for(y=0;y<5;++y) {
        img[y] = new int[WIDTH];
        for(x=0;x<WIDTH;++x) {
//            img[y][x] = ((y+1)*10)+x;
            img[y][x] = dlsc_rand(0,DATA_MAX);
        }
    }

    // scale factors
    int64_t scalei[9];
    scalei[0] = 0;
    for(i=1;i<9;++i) {
        scalei[i] = (int64_t)((1.0/i)*(1<<14));
    }

    // compute expected results
    // from: http://scien.stanford.edu/pages/labsite/1999/psych221/projects/99/tingchen/algodep/vargra.html 
    y = 2;
    for(x=2;x<(WIDTH-2);++x) {

        bool is_green = (x % 2);

        int64_t rs,gs,bs;
        int cs;
        rs = gs = bs = 0;
        cs = 0;

        if(is_green) {
            // green pixel
            int G1  = img[y-2][x-2], R2  = img[y-2][x-1], G3  = img[y-2][x  ], R4  = img[y-2][x+1], G5  = img[y-2][x+2];
            int B6  = img[y-1][x-2], G7  = img[y-1][x-1], B8  = img[y-1][x  ], G9  = img[y-1][x+1], B10 = img[y-1][x+2];
            int G11 = img[y  ][x-2], R12 = img[y  ][x-1], G13 = img[y  ][x  ], R14 = img[y  ][x+1], G15 = img[y  ][x+2];
            int B16 = img[y+1][x-2], G17 = img[y+1][x-1], B18 = img[y+1][x  ], G19 = img[y+1][x+1], B20 = img[y+1][x+2];
            int G21 = img[y+2][x-2], R22 = img[y+2][x-1], G23 = img[y+2][x  ], R24 = img[y+2][x+1], G25 = img[y+2][x+2];

            chk[x].grad_n  = std::abs(G3  - G13)*2 + std::abs(B8  - B18)*2 + std::abs(G7  - G17)   + std::abs(G9  - G19) + std::abs(R2  - R12) + std::abs(R4  - R14); 
            chk[x].grad_e  = std::abs(R14 - R12)*2 + std::abs(G15 - G13)*2 + std::abs(G9  - G7 )   + std::abs(G19 - G17) + std::abs(B10 - B8 ) + std::abs(B20 - B18); 
            chk[x].grad_s  = std::abs(B18 - B8 )*2 + std::abs(G23 - G13)*2 + std::abs(G19 - G9 )   + std::abs(G17 - G7 ) + std::abs(R24 - R14) + std::abs(R22 - R12); 
            chk[x].grad_w  = std::abs(R12 - R14)*2 + std::abs(G11 - G13)*2 + std::abs(G17 - G19)   + std::abs(G7  - G9 ) + std::abs(B16 - B18) + std::abs(B6  - B8 ); 
            chk[x].grad_ne = std::abs(G9  - G17)*2 + std::abs(G5  - G13)*2 + std::abs(R4  - R12)*2 + std::abs(B10 - B18)*2; 
            chk[x].grad_se = std::abs(G19 - G7 )*2 + std::abs(G25 - G13)*2 + std::abs(B20 - B8 )*2 + std::abs(R24 - R12)*2; 
            chk[x].grad_nw = std::abs(G7  - G19)*2 + std::abs(G1  - G13)*2 + std::abs(B6  - B18)*2 + std::abs(R2  - R14)*2; 
            chk[x].grad_sw = std::abs(G17 - G9 )*2 + std::abs(G21 - G13)*2 + std::abs(R22 - R14)*2 + std::abs(B16 - B8 )*2; 

            int lo = std::min(std::min(std::min(std::min(std::min(std::min(std::min(chk[x].grad_n,chk[x].grad_e),chk[x].grad_s),chk[x].grad_w),chk[x].grad_ne),chk[x].grad_se),chk[x].grad_nw),chk[x].grad_sw);
            int hi = std::max(std::max(std::max(std::max(std::max(std::max(std::max(chk[x].grad_n,chk[x].grad_e),chk[x].grad_s),chk[x].grad_w),chk[x].grad_ne),chk[x].grad_se),chk[x].grad_nw),chk[x].grad_sw);

            chk[x].thresh = lo + hi/2;
            
            if(chk[x].grad_n < chk[x].thresh) {
                ++cs;
                rs += R2 + R4;
                gs += G3 + G13;
                bs += B8*2;
            }
            if(chk[x].grad_e < chk[x].thresh) {
                ++cs;
                rs += R14*2;
                gs += G13 + G15;
                bs += B10 + B20;
            }
            if(chk[x].grad_s < chk[x].thresh) {
                ++cs;
                rs += R22 + R24;
                gs += G13 + G23;
                bs += B18*2;
            }
            if(chk[x].grad_w < chk[x].thresh) {
                ++cs;
                rs += R12*2;
                gs += G11 + G13;
                bs += B6 + B16;
            }
            if(chk[x].grad_ne < chk[x].thresh) {
                ++cs;
                rs += R4 + R14;
                gs += G9*2;
                bs += B8 + B10;
            }
            if(chk[x].grad_se < chk[x].thresh) {
                ++cs;
                rs += R14 + R24;
                gs += G19*2;
                bs += B18 + B20;
            }
            if(chk[x].grad_nw < chk[x].thresh) {
                ++cs;
                rs += R2 + R12;
                gs += G7*2;
                bs += B6 + B8;
            }
            if(chk[x].grad_sw < chk[x].thresh) {
                ++cs;
                rs += R12 + R22;
                gs += G17*2;
                bs += B16 + B18;
            }

        } else {
            // not green
            int R1  = img[y-2][x-2], G2  = img[y-2][x-1], R3  = img[y-2][x  ], G4  = img[y-2][x+1], R5  = img[y-2][x+2];
            int G6  = img[y-1][x-2], B7  = img[y-1][x-1], G8  = img[y-1][x  ], B9  = img[y-1][x+1], G10 = img[y-1][x+2];
            int R11 = img[y  ][x-2], G12 = img[y  ][x-1], R13 = img[y  ][x  ], G14 = img[y  ][x+1], R15 = img[y  ][x+2];
            int G16 = img[y+1][x-2], B17 = img[y+1][x-1], G18 = img[y+1][x  ], B19 = img[y+1][x+1], G20 = img[y+1][x+2];
            int R21 = img[y+2][x-2], G22 = img[y+2][x-1], R23 = img[y+2][x  ], G24 = img[y+2][x+1], R25 = img[y+2][x+2];

            chk[x].grad_n  = std::abs(G8  - G18)*2 + std::abs(R3  - R13)*2 + std::abs(B7  - B17) + std::abs(B9  - B19) + std::abs(G2  - G12) + std::abs(G4  - G14); 
            chk[x].grad_e  = std::abs(G14 - G12)*2 + std::abs(R15 - R13)*2 + std::abs(B9  - B7 ) + std::abs(B19 - B17) + std::abs(G10 - G8 ) + std::abs(G20 - G18); 
            chk[x].grad_s  = std::abs(G18 - G8 )*2 + std::abs(R23 - R13)*2 + std::abs(B19 - B9 ) + std::abs(B17 - B7 ) + std::abs(G24 - G14) + std::abs(G22 - G12); 
            chk[x].grad_w  = std::abs(G12 - G14)*2 + std::abs(R11 - R13)*2 + std::abs(B17 - B19) + std::abs(B7  - B9 ) + std::abs(G16 - G18) + std::abs(G6  - G8 ); 
            chk[x].grad_ne = std::abs(B9  - B17)*2 + std::abs(R5  - R13)*2 + std::abs(G8  - G12) + std::abs(G14 - G18) + std::abs(G4  - G8 ) + std::abs(G10 - G14); 
            chk[x].grad_se = std::abs(B19 - B7 )*2 + std::abs(R25 - R13)*2 + std::abs(G14 - G8 ) + std::abs(G18 - G12) + std::abs(G20 - G14) + std::abs(G24 - G18); 
            chk[x].grad_nw = std::abs(B7  - B19)*2 + std::abs(R1  - R13)*2 + std::abs(G12 - G18) + std::abs(G8  - G14) + std::abs(G6  - G12) + std::abs(G2  - G8 ); 
            chk[x].grad_sw = std::abs(B17 - B9 )*2 + std::abs(R21 - R13)*2 + std::abs(G18 - G14) + std::abs(G12 - G8 ) + std::abs(G22 - G18) + std::abs(G16 - G12);

            int lo = std::min(std::min(std::min(std::min(std::min(std::min(std::min(chk[x].grad_n,chk[x].grad_e),chk[x].grad_s),chk[x].grad_w),chk[x].grad_ne),chk[x].grad_se),chk[x].grad_nw),chk[x].grad_sw);
            int hi = std::max(std::max(std::max(std::max(std::max(std::max(std::max(chk[x].grad_n,chk[x].grad_e),chk[x].grad_s),chk[x].grad_w),chk[x].grad_ne),chk[x].grad_se),chk[x].grad_nw),chk[x].grad_sw);

            chk[x].thresh = lo + hi/2;

            if(chk[x].grad_n < chk[x].thresh) {
                ++cs;
                rs += R3 + R13;
                gs += G8*2;
                bs += B7 + B9;
            }
            if(chk[x].grad_e < chk[x].thresh) {
                ++cs;
                rs += R13 + R15;
                gs += G14*2;
                bs += B9 + B19;
            }
            if(chk[x].grad_s < chk[x].thresh) {
                ++cs;
                rs += R13 + R23;
                gs += G18*2;
                bs += B17 + B19;
            }
            if(chk[x].grad_w < chk[x].thresh) {
                ++cs;
                rs += R13 + R11;
                gs += G12*2;
                bs += B7 + B17;
            }
            if(chk[x].grad_ne < chk[x].thresh) {
                ++cs;
                rs += R13 + R5;
                gs += (G4 + G8 + G10 + G14)/2;
                bs += B9*2;
            }
            if(chk[x].grad_se < chk[x].thresh) {
                ++cs;
                rs += R13 + R25;
                gs += (G14 + G18 + G20 + G24)/2;
                bs += B19*2;
            }
            if(chk[x].grad_nw < chk[x].thresh) {
                ++cs;
                rs += R13 + R1;
                gs += (G2 + G6 + G8 + G12)/2;
                bs += B7*2;
            }
            if(chk[x].grad_sw < chk[x].thresh) {
                ++cs;
                rs += R13 + R21;
                gs += (G12 + G16 + G18 + G22)/2;
                bs += B17*2;
            }
        }

        chk[x].sum_red      = rs;
        chk[x].sum_green    = gs;
        chk[x].sum_blue     = bs;
        chk[x].sum_cnt      = cs;

        if(is_green) {
            chk[x].diff_redgreen    = ((rs - gs) * scalei[cs]) >> 15;
            chk[x].diff_blue        = ((bs - gs) * scalei[cs]) >> 15;
            chk[x].out_red          = img[y][x] + chk[x].diff_redgreen;
            chk[x].out_green        = img[y][x];
            chk[x].out_blue         = img[y][x] + chk[x].diff_blue;
        } else {
            chk[x].diff_redgreen    = ((gs - rs) * scalei[cs]) >> 15;
            chk[x].diff_blue        = ((bs - rs) * scalei[cs]) >> 15;
            chk[x].out_red          = img[y][x];
            chk[x].out_green        = img[y][x] + chk[x].diff_redgreen;
            chk[x].out_blue         = img[y][x] + chk[x].diff_blue;
        }

             if(chk[x].out_red   < 0)        chk[x].out_red   = 0;
        else if(chk[x].out_red   > DATA_MAX) chk[x].out_red   = DATA_MAX;
             if(chk[x].out_green < 0)        chk[x].out_green = 0;
        else if(chk[x].out_green > DATA_MAX) chk[x].out_green = DATA_MAX;
             if(chk[x].out_blue  < 0)        chk[x].out_blue  = 0;
        else if(chk[x].out_blue  > DATA_MAX) chk[x].out_blue  = DATA_MAX;
    }

    rst = 1;
    st  = 0;

    wait(1,SC_US);
    rst = 0;

    wait(clk.posedge_event());

    int cycle = -1;
    int state;

    while(cycle<((WIDTH-1)*6)) {

        // ** check **

        if(clk_en) {
            // only check if was previously enabled

            // check gradients
            i   = cycle - 43;
            y   = 2;
            x   = (i/6)+2;

            if(i>=0) {
                if((i%6)<4) {
                    dlsc_assert_equals(grad_push,1);
                    switch(i%6) {
                        case 0:
                            dlsc_assert_equals(grad_axes,(unsigned int)chk[x].grad_w);
                            dlsc_assert_equals(grad_diag,(unsigned int)chk[x].grad_nw);
                            break;
                        case 1:
                            dlsc_assert_equals(grad_axes,(unsigned int)chk[x].grad_e);
                            dlsc_assert_equals(grad_diag,(unsigned int)chk[x].grad_sw);
                            break;
                        case 2:
                            dlsc_assert_equals(grad_axes,(unsigned int)chk[x].grad_n);
                            dlsc_assert_equals(grad_diag,(unsigned int)chk[x].grad_ne);
                            break;
                        case 3:
                            dlsc_assert_equals(grad_axes,(unsigned int)chk[x].grad_s);
                            dlsc_assert_equals(grad_diag,(unsigned int)chk[x].grad_se);
                            break;
                    }
                } else {
                    dlsc_assert_equals(grad_push,0);
                }
            }

            // check thresh
            i   = cycle - 50;
            y   = 2;
            x   = (i/6)+2;

            if(i>=0) {
                dlsc_assert_equals(thresh,(unsigned int)chk[x].thresh);
            }

            // check sum
            i   = cycle - 56;
            y   = 2;
            x   = (i/6)+2;

            if(i>=0) {
                dlsc_assert_equals(sum_red,  (unsigned int)chk[x].sum_red);
                dlsc_assert_equals(sum_green,(unsigned int)chk[x].sum_green);
                dlsc_assert_equals(sum_blue, (unsigned int)chk[x].sum_blue);
                dlsc_assert_equals(sum_cnt,  (unsigned int)chk[x].sum_cnt);
            }

            // check diff
            i   = cycle - 62;
            y   = 2;
            x   = (i/6)+2;

            if(i>=0) {
                int32_t diff = (uint32_t)(diff_norm.read());
                if((i%6)<3) {
                    dlsc_assert_equals(diff,chk[x].diff_redgreen);
                } else {
                    dlsc_assert_equals(diff,chk[x].diff_blue);
                }
            }

            // check output
            i   = cycle - 68;
            y   = 2;
            x   = (i/6)+2;

            if(i>=0) {
                if((i%6)==0) {
                    dlsc_assert_equals(out_red,  (unsigned int)chk[x].out_red);
                    dlsc_assert_equals(out_green,(unsigned int)chk[x].out_green);
                    dlsc_assert_equals(out_blue, (unsigned int)chk[x].out_blue);
                } else {
                    dlsc_assert_equals(out_valid,0);
                }
            } else {
                dlsc_assert_equals(out_valid,0);
            }
        }


        // ** stim **

        if(dlsc_rand_bool(10.0)) {
            clk_en      = 0;
            px_push     = 0;
            px_in       = 0;
            wait(clk.posedge_event());
            continue;
        }

        ++cycle;
        
        state       = cycle % 12;

        // waveform visible cycle/state (for debug)
        tb_cycle    = cycle;
        tb_state    = state;


        clk_en      = 1;

        // drive next state (1 early, to account for ROM registering)
        st          = ((state+1)%12);

        // supply input pixels
        if(state != 5 && state != 11) {
            px_push     = 1;
            y           = (state < 5) ? (state) : (state - 6);
            x           = (cycle/6);
            px_in       = img[y][x];
        } else {
            px_push     = 0;
            px_in       = 0;
        }

        wait(clk.posedge_event());
    }

    clk_en      = 0;

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(1,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



