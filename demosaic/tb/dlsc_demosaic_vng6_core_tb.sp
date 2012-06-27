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
    bool out_last;
    int out_red;
    int out_green;
    int out_blue;
};

struct out_type {
    uint32_t r;
    uint32_t g;
    uint32_t b;
    bool last;
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
            dlsc_assert_equals(out.last,out_last);
            dlsc_assert_equals(out.r,out_data_r);
            dlsc_assert_equals(out.g,out_data_g);
            dlsc_assert_equals(out.b,out_data_b);
        }
    }

    out_ready = dlsc_rand_bool(out_rate);

}

void __MODULE__::send_frame() {
    int width       = cfg_width+1;
    int height      = cfg_height+1;
    bool first_r    = cfg_first_r;
    bool first_g    = cfg_first_g;


    // ** create image **

    uint32_t **img = new uint32_t*[height+4];
    img = &img[2];
    for(int y=0;y<height;y++) {
        img[y]  = new uint32_t[width+4];
        img[y]  = &img[y][2];
        for(int x=0;x<width;x++) {
            //img[y][x]   = (((y+1)*10)+x) & DATA_MAX;
            img[y][x]   = dlsc_rand_u32(0,DATA_MAX);
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
    
    // scale factors
    int64_t scalei[9];
    scalei[0] = 0;
    for(int i=1;i<9;++i) {
        scalei[i] = (int64_t)((1.0/i)*(1<<14));
    }

    vng_check_type *chk = new vng_check_type[width];

    for(int y=0;y<height;y++) {
        for(int x=0;x<width;x++) {
            bool is_green = first_g ^ ((y & 0x1) != 0) ^ ((x & 0x1) != 0);
            bool is_red   = first_r ^ ((y & 0x1) != 0); // need to swap red/blue on odd rows

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

            out_type out;
            out.last = (y == (height-1)) && (x == (width-1));
            out.r = is_red ? chk[x].out_red  : chk[x].out_blue;
            out.b = is_red ? chk[x].out_blue : chk[x].out_red ;
            out.g = chk[x].out_green;
            out_queue.push_back(out);
        }
    }


    // ** cleanup **
    delete chk;
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

    for(int iterations=0;iterations<100;iterations++) {
        dlsc_info("== test " << iterations << " ==");

        in_rate     = 0.1 * dlsc_rand(50,1000);
        out_rate    = 0.1 * dlsc_rand(50,1000);

        cfg_width   = dlsc_rand(10,100)-1;
        cfg_height  = dlsc_rand(10,30)-1;
        cfg_first_r = dlsc_rand_bool(50.0);
        cfg_first_g = dlsc_rand_bool(50.0);

        wait(sc_core::SC_ZERO_TIME);

        dlsc_info("  in_rate:   " << in_rate);
        dlsc_info("  out_rate:  " << out_rate);
        dlsc_info("  width:     " << (cfg_width+1));
        dlsc_info("  height:    " << (cfg_height+1));
        dlsc_info("  first_r:   " << cfg_first_r);
        dlsc_info("  first_g:   " << cfg_first_g);

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
    for(int i=0;i<200;i++) {
        wait(1,SC_MS);
        dlsc_info(". " << out_queue.size());
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



