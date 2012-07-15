//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

// for syntax highlighter: SC_MODULE

#ifndef PARAM_CORE_TEST
    #include "dlsc_tlm_initiator_nb.h"
    #define PARAM_XB            (dlsc_clog2(PARAM_MAX_WIDTH))
    #define PARAM_YB            (dlsc_clog2(PARAM_MAX_HEIGHT))
    #define PARAM_BINB          (dlsc_clog2(PARAM_MAX_BIN))
#else
    #define PARAM_MAX_WIDTH     (PARAM_WIDTH)
    #define PARAM_MAX_HEIGHT    (1<<PARAM_YB)
    #define PARAM_MAX_BIN       (1<<PARAM_BINB)
    #define PARAM_CSR_DOMAIN    0
    #define PARAM_PX_DOMAIN     1
#endif

/*AUTOSUBCELL_CLASS*/

struct out_type {
    uint32_t r;
    uint32_t g;
    uint32_t b;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock        clk;
    sc_signal<bool> rst;
    
    sc_clock        csr_clk;
    sc_signal<bool> csr_rst;

    void clk_method();
    void stim_thread();
    void watchdog_thread();

    void send_frame_acc_px(uint32_t *frame, int x, int y, out_type &out);
    void send_frame();
    int width;
    int height;
    int binx;
    int biny;

    std::deque<uint32_t> in_queue;
    std::deque<out_type> out_queue;

    double in_rate;
    double out_rate;

#ifndef PARAM_CORE_TEST
    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

    uint32_t    cfg_width;
    uint32_t    cfg_height;
    uint32_t    cfg_bin_x;
    uint32_t    cfg_bin_y;
    bool        cfg_bayer;
    bool        cfg_first_r;
    bool        cfg_first_g;
#endif

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
    clk("clk",10,SC_NS),
    csr_clk("csr_clk",15,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/
#ifndef PARAM_CORE_TEST
#ifdef PARAM_PX_DOMAIN
        SP_PIN(dut,csr_clk,clk);
        SP_PIN(dut,csr_rst,rst);
#else
        SP_PIN(dut,csr_clk,csr_clk);
        SP_PIN(dut,csr_rst,csr_rst);
#endif
        SP_PIN(dut,px_clk,clk);
        SP_PIN(dut,px_rst,rst);
        SP_PIN(dut,px_in_ready,in_ready);
        SP_PIN(dut,px_in_valid,in_valid);
        SP_PIN(dut,px_in_data,in_data);
        SP_PIN(dut,px_out_ready,out_ready);
        SP_PIN(dut,px_out_valid,out_valid);
        SP_PIN(dut,px_out_data_r,out_data_r);
        SP_PIN(dut,px_out_data_g,out_data_g);
        SP_PIN(dut,px_out_data_b,out_data_b);
#endif
    
#ifndef PARAM_CORE_TEST
    SP_CELL(csr_master,dlsc_csr_tlm_master_32b);
        /*AUTOINST*/
#ifdef PARAM_PX_DOMAIN
        SP_PIN(csr_master,clk,clk);
        SP_PIN(csr_master,rst,rst);
#else
        SP_PIN(csr_master,clk,csr_clk);
        SP_PIN(csr_master,rst,csr_rst);
#endif
    
    csr_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("csr_initiator",1);
    csr_initiator->socket.bind(csr_master->socket);
#endif

    rst         = 1;
    csr_rst     = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

#ifndef PARAM_CORE_TEST
const uint32_t REG_CORE_MAGIC       = 0x0;
const uint32_t REG_CORE_VERSION     = 0x1;
const uint32_t REG_CORE_INTERFACE   = 0x2;
const uint32_t REG_CORE_INSTANCE    = 0x3;
const uint32_t REG_CONTROL          = 0x4;
const uint32_t REG_STATUS           = 0x5;
const uint32_t REG_WIDTH            = 0x8;
const uint32_t REG_HEIGHT           = 0x9;
const uint32_t REG_BIN_X            = 0xA;
const uint32_t REG_BIN_Y            = 0xB;
const uint32_t REG_BAYER            = 0xC;

void __MODULE__::reg_write(uint32_t addr, uint32_t data) {
    csr_initiator->b_write(addr<<2,data);
    dlsc_verb("wrote 0x" << std::hex << addr << " : 0x" << data);
}

uint32_t __MODULE__::reg_read(uint32_t addr) {
    uint32_t data = csr_initiator->b_read(addr<<2);
    dlsc_verb("read 0x" << std::hex << addr << " : 0x" << data);
    return data;
}
#endif

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
            dlsc_assert_equals(out.r,out_data_r);
            dlsc_assert_equals(out.g,out_data_g);
            dlsc_assert_equals(out.b,out_data_b);
        }
    }

    out_ready = dlsc_rand_bool(out_rate);

}

void __MODULE__::send_frame_acc_px(uint32_t *frame, int x, int y, out_type &out) {
    assert(x >= 0 && x < width);
    assert(y >= 0 && y < height);
    if(!cfg_bayer) {
        out.r += frame[x+y*width];
        out.g += frame[x+y*width];
        out.b += frame[x+y*width];
    } else {
        int rx, ry, gx, gy, bx, by;
        if(!cfg_first_g && !cfg_first_r) {
            // BGBG
            // GRGR
            rx = x | 0x1;
            ry = y | 0x1;
            bx = x & ~0x1;
            by = y & ~0x1;
            gx = (y & 0x1) ? (x & ~0x1) : (x | 0x1);
            gy = y;
        } else if(!cfg_first_g && cfg_first_r) {
            // RGRG
            // GBGB
            rx = x & ~0x1;
            ry = y & ~0x1;
            bx = x | 0x1;
            by = y | 0x1;
            gx = (y & 0x1) ? (x & ~0x1) : (x | 0x1);
            gy = y;
        } else if(cfg_first_g && !cfg_first_r) {
            // GBGB
            // RGRG
            rx = x & ~0x1;
            ry = y | 0x1;
            bx = x | 0x1;
            by = y & ~0x1;
            gx = (y & 0x1) ? (x | 0x1) : (x & ~0x1);
            gy = y;
        } else {
            // GRGR
            // BGBG
            rx = x | 0x1;
            ry = y & ~0x1;
            bx = x & ~0x1;
            by = y | 0x1;
            gx = (y & 0x1) ? (x | 0x1) : (x & ~0x1);
            gy = y;
        }
        if(rx < width && ry < height) out.r += frame[rx+ry*width];
        if(gx < width && gy < height) out.g += frame[gx+gy*width];
        if(bx < width && by < height) out.b += frame[bx+by*width];
    }
}

void __MODULE__::send_frame() {
    width   = cfg_width+1;
    height  = cfg_height+1;
    binx    = cfg_bin_x+1;
    biny    = cfg_bin_y+1;

    // generate input frame
    uint32_t *frame = new uint32_t[width*height];
    for(int y=0;y<height;y++) {
        uint32_t *row = &frame[y*width];
        for(int x=0;x<width;x++) {
            row[x] = x+y+1;
            row[x] = dlsc_rand_u32(0,((1u<<PARAM_BITS)-1));
            in_queue.push_back(row[x]);
        }
    }

    // generate binned frame
    int div         = dlsc_clog2(binx) + dlsc_clog2(biny);
    int bheight     = height/biny;
    int bwidth      = width/binx;
    out_type out;
    for(int y=0;y<(bheight*biny);y+=biny) {
        for(int x=0;x<(bwidth*binx);x+=binx) {
            out.r = out.g = out.b = 0;
            for(int by=y;by<(y+biny);by++) {
                for(int bx=x;bx<(x+binx);bx++) {
                    send_frame_acc_px(frame,bx,by,out);
                }
            }
            out.r >>= div;
            out.b >>= div;
            out.g >>= div;
            out_queue.push_back(out);
        }
    }

    // cleanup
    delete frame;
}

void __MODULE__::stim_thread() {
    rst         = 1;
    csr_rst     = 1;
    
    wait(1,SC_US);

    for(int iterations=0;iterations<100;iterations++) {

        in_rate     = 1.0*dlsc_rand(10,100);
        out_rate    = 1.0*dlsc_rand(10,100);
        cfg_bayer   = dlsc_rand_bool(50.0);
        cfg_first_r = dlsc_rand_bool(50.0);
        cfg_first_g = dlsc_rand_bool(50.0);
        wait(SC_ZERO_TIME);
        switch(dlsc_rand(0,19)) {
            case 9:
                cfg_width   = PARAM_MAX_WIDTH-1;
                cfg_height  = dlsc_rand(10,20)-1;
                break;
            case 12:
                cfg_width   = dlsc_rand(10,20)-1;
                cfg_height  = PARAM_MAX_HEIGHT-1;
                break;
            default:
                cfg_width   = dlsc_rand(10,200)-1;
                cfg_height  = dlsc_rand(10,100)-1;
        }
        if(!cfg_bayer) {
            // raw mode can handle any bin factor (sorta-kinda)
            cfg_bin_x   = dlsc_rand(1,PARAM_MAX_BIN)-1;
            cfg_bin_y   = dlsc_rand(1,PARAM_MAX_BIN)-1;
        } else {
            // bayer mode can only reasonably handle powers of 2
            cfg_bin_x   = (1<<dlsc_rand(1,PARAM_BINB))-1;
            cfg_bin_y   = (1<<dlsc_rand(1,PARAM_BINB))-1;
        }
        wait(SC_ZERO_TIME);

        dlsc_info("== iteration " << iterations << " ==");
        dlsc_info("  cfg_bayer:     " << cfg_bayer);
        dlsc_info("  cfg_width:     " << (cfg_width+1));
        dlsc_info("  cfg_height:    " << (cfg_height+1));
        dlsc_info("  cfg_bin_x:     " << (cfg_bin_x+1));
        dlsc_info("  cfg_bin_y:     " << (cfg_bin_y+1));

        wait(clk.posedge_event());
        rst         = 0;
        wait(csr_clk.posedge_event());
        csr_rst     = 0;
        wait(clk.posedge_event());
        wait(csr_clk.posedge_event());

#ifndef PARAM_CORE_TEST
        reg_write(REG_CONTROL,0);
        reg_write(REG_WIDTH,cfg_width);
        reg_write(REG_HEIGHT,cfg_height);
        reg_write(REG_BIN_X,cfg_bin_x);
        reg_write(REG_BIN_Y,cfg_bin_y);
        reg_write(REG_BAYER, (
            (cfg_bayer   ? 0x1 : 0x0) |
            (cfg_first_r ? 0x2 : 0x0) |
            (cfg_first_g ? 0x4 : 0x0)) );
        reg_write(REG_CONTROL,1);
#endif

        for(int i=0;i<dlsc_rand(5,15);i++) {
            send_frame();
            while(in_queue.size() > 100) wait(1,SC_US);
        }
        
        while(!out_queue.empty()) wait(1,SC_US);

        wait(1,SC_US);
        wait(clk.posedge_event());
        rst         = 1;
        wait(csr_clk.posedge_event());
        csr_rst     = 1;
        wait(clk.posedge_event());
        wait(csr_clk.posedge_event());
        wait(1,SC_US);
    }

    wait(10,SC_US);

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

