//######################################################################
#sp interface

// for syntax highlighter: SC_MODULE

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

#define MAX_H PARAM_MAX_H
#define MAX_V PARAM_MAX_V

#if (PARAM_FIXED_MODELINE>0)
#define FIXED_MODELINE
#define MODELINE_CONST const
#else
#define MODELINE_CONST 
#endif

#if (PARAM_FIXED_PIXEL>0)
#define FIXED_PIXEL
#define PIXEL_CONST const
#else
#define PIXEL_CONST 
#endif

#define PARAM_BYTES_PER_ROW (PARAM_HDISP*PARAM_BYTES_PER_PIXEL)
#define PARAM_ROW_STEP PARAM_BYTES_PER_ROW

class cfg_type {
public:
    cfg_type();
    void randomize();

    MODELINE_CONST  uint32_t    hdisp;
    MODELINE_CONST  uint32_t    hsyncstart;
    MODELINE_CONST  uint32_t    hsyncend;
    MODELINE_CONST  uint32_t    htotal;
    MODELINE_CONST  uint32_t    vdisp;
    MODELINE_CONST  uint32_t    vsyncstart;
    MODELINE_CONST  uint32_t    vsyncend;
    MODELINE_CONST  uint32_t    vtotal;

    PIXEL_CONST     uint32_t    bytes_per_pixel;
    PIXEL_CONST     uint32_t    pos_r;
    PIXEL_CONST     uint32_t    pos_g;
    PIXEL_CONST     uint32_t    pos_b;
    PIXEL_CONST     uint32_t    pos_a;

                    uint32_t    bytes_per_row;
                    uint32_t    row_step;
};

struct px_type {
    px_type() { r=0;g=0;b=0;a=0; }
    uint32_t    r;
    uint32_t    g;
    uint32_t    b;
    uint32_t    a;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;
    sc_clock px_clk;

    void clk_method();
    void px_clk_method();

    void stim_thread();
    void watchdog_thread();

    cfg_type cfg;
    void cfg_write();

    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *apb_initiator;
    
    dlsc_tlm_memory<uint32_t>   *memory;

    sc_core::sc_event frame_done_event;

    uint32_t cnt_vsync;
    uint32_t cnt_hsync;
    uint32_t cnt_frame_valid;
    uint32_t cnt_line_valid;
    uint32_t cnt_valid;

    uint32_t cur_addr;
    std::deque<uint32_t> row_data;

    uint32_t px_x;
    uint32_t px_y;

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

const uint32_t REG_CONTROL      = 0x0;
const uint32_t REG_STATUS       = 0x1;
const uint32_t REG_INT_FLAGS    = 0x2;
const uint32_t REG_INT_SELECT   = 0x3;
const uint32_t REG_BUF_ADDR     = 0x4;
const uint32_t REG_BPR          = 0x5;
const uint32_t REG_STEP         = 0x6;
const uint32_t REG_PXCFG        = 0x7;
const uint32_t REG_HDISP        = 0x8;
const uint32_t REG_HSYNCSTART   = 0x9;
const uint32_t REG_HSYNCEND     = 0xA;
const uint32_t REG_HTOTAL       = 0xB;
const uint32_t REG_VDISP        = 0xC;
const uint32_t REG_VSYNCSTART   = 0xD;
const uint32_t REG_VSYNCEND     = 0xE;
const uint32_t REG_VTOTAL       = 0xF;

#define MEM_SIZE (4*1024*1024)

SP_CTOR_IMP(__MODULE__) :
    clk("clk",10,SC_NS),
    px_clk("px_clk",12,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/
    
    SP_CELL(apb_master,dlsc_apb_tlm_master_32b);
        /*AUTOINST*/
    
    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
    
    memory          = new dlsc_tlm_memory<uint32_t>("memory",MEM_SIZE,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(20,SC_NS));
    axi_slave->socket.bind(memory->socket);
    
    apb_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("apb_initiator",1);
    apb_initiator->socket.bind(apb_master->socket);

    rst         = 1;
    px_rst      = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_METHOD(px_clk_method);
        sensitive << px_clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::clk_method() {
    if(rst) {
    } else {
    }
}

void __MODULE__::px_clk_method() {
    if(!px_en) {
        cnt_vsync       = 0;
        cnt_hsync       = 0;
        cnt_frame_valid = 0;
        cnt_line_valid  = 0;
        cnt_valid       = 0;
        px_x            = 0;
        px_y            = 0;
    } else {
        if(px_vsync) {
            cnt_vsync++;
        } else if(cnt_vsync) {
            dlsc_assert_equals(cnt_vsync,(cfg.htotal*(cfg.vsyncend-cfg.vsyncstart)));
            cnt_vsync = 0;
        }
        if(px_hsync) {
            cnt_hsync++;
        } else if(cnt_hsync) {
            dlsc_assert_equals(cnt_hsync,(cfg.hsyncend-cfg.hsyncstart));
            cnt_hsync = 0;
        }
        if(px_frame_valid) {
            cnt_frame_valid++;
        } else if(cnt_frame_valid) {
            dlsc_info("got end of frame");
            frame_done_event.notify();
            dlsc_assert_equals(cnt_frame_valid,(cfg.vdisp*cfg.htotal));
            cnt_frame_valid = 0;
        }
        if(px_line_valid) {
            cnt_line_valid++;
        } else if(cnt_line_valid) {
            dlsc_verb("got end of line");
            dlsc_assert_equals(cnt_line_valid,cfg.hdisp);
            cnt_line_valid = 0;
        }
        if(px_valid) {
            cnt_valid++;
        } else if(cnt_valid) {
            dlsc_assert_equals(cnt_valid,cfg.hdisp);
            cnt_valid = 0;
        }

        if(px_valid) {
            uint32_t row_addr   = cur_addr + cfg.row_step*px_y;
            uint32_t row_offset = cfg.bytes_per_pixel*px_x + (row_addr&0x3);

            if(px_x == 0) {
                // need to get data for row
                uint32_t start_addr = row_addr & ~0x3u;
                uint32_t end_addr   = (row_addr + cfg.bytes_per_row + 0x3) & ~0x3u;
                memory->nb_read(start_addr,(end_addr-start_addr)>>2,row_data);
            }

            // get current pixel
            px_type px;
            for(unsigned int i=0;i<cfg.bytes_per_pixel;++i,++row_offset) {
                assert( (row_offset>>2) < row_data.size());
                uint32_t data = row_data[row_offset>>2];
                data >>= (row_offset&0x3)*8;
                data &= 0xFF;
                if(cfg.pos_r == i) px.r = data;
                if(cfg.pos_g == i) px.g = data;
                if(cfg.pos_b == i) px.b = data;
                if(cfg.pos_a == i) px.a = data;
            }

            // check
            dlsc_assert_equals(px_r,px.r);
            dlsc_assert_equals(px_g,px.g);
            dlsc_assert_equals(px_b,px.b);
            dlsc_assert_equals(px_a,px.a);

            // update coordinates
            px_x++;
            if(px_x == cfg.hdisp) {
                px_x = 0;
                px_y++;
                if(px_y == cfg.vdisp) {
                    px_y = 0;
                }
            }
        }
    }
}

void __MODULE__::reg_write(uint32_t addr, uint32_t data) {
    dlsc_info("wrote 0x" << std::hex << addr << " : 0x" << data);
    apb_initiator->b_write(addr<<2,data);
}

uint32_t __MODULE__::reg_read(uint32_t addr) {
    uint32_t data = apb_initiator->b_read(addr<<2);
    dlsc_verb("read 0x" << std::hex << addr << " : 0x" << data);
    return data;
}

void __MODULE__::cfg_write() {
    reg_write(REG_BPR,          cfg.bytes_per_row);
    reg_write(REG_STEP,         cfg.row_step);
#ifndef FIXED_MODELINE
    reg_write(REG_HDISP,        cfg.hdisp-1);
    reg_write(REG_HSYNCSTART,   cfg.hsyncstart-1);
    reg_write(REG_HSYNCEND,     cfg.hsyncend-1);
    reg_write(REG_HTOTAL,       cfg.htotal-1);
    reg_write(REG_VDISP,        cfg.vdisp-1);
    reg_write(REG_VSYNCSTART,   cfg.vsyncstart-1);
    reg_write(REG_VSYNCEND,     cfg.vsyncend-1);
    reg_write(REG_VTOTAL,       cfg.vtotal-1);
#endif
#ifndef FIXED_PIXEL
    uint32_t data;
    data  = (cfg.bytes_per_pixel-1);
    data |= cfg.pos_r << 4;
    data |= cfg.pos_g << 8;
    data |= cfg.pos_b << 12;
    data |= cfg.pos_a << 16;
    reg_write(REG_PXCFG,data);
#endif
}

void __MODULE__::stim_thread() {
    rst         = 1;
    px_rst      = 1;
    wait(100,SC_NS);
    wait(clk.posedge_event());
    rst         = 0;
    wait(px_clk.posedge_event());
    px_rst      = 0;
    wait(clk.posedge_event());

    for(int i=0;i<10;++i) {
        dlsc_info("iteration " << i);

        // disable
        reg_write(REG_CONTROL,0);
        wait(100,SC_NS);
        dlsc_assert(!px_en);

        // new config
        cfg.randomize();
        cfg_write();
        cur_addr = dlsc_rand_u32(0,MEM_SIZE-(cfg.vdisp*cfg.row_step)-1);
        reg_write(REG_BUF_ADDR,cur_addr);

        // randomize memory
        std::deque<uint32_t> data;
        for(int j=0;j<(cfg.vdisp*cfg.row_step)/4;++j) {
            data.push_back(dlsc_rand_u32());
        }
        memory->nb_write(cur_addr&~0x3u,data);

        // enable
        reg_write(REG_CONTROL,1);

        wait(frame_done_event);
        wait(frame_done_event);
        wait(dlsc_rand_u32(0,1000),SC_US);
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


cfg_type::cfg_type() :
    hdisp ( PARAM_HDISP ),
    hsyncstart ( PARAM_HSYNCSTART ),
    hsyncend ( PARAM_HSYNCEND ),
    htotal ( PARAM_HTOTAL ),
    vdisp ( PARAM_VDISP ),
    vsyncstart ( PARAM_VSYNCSTART ),
    vsyncend ( PARAM_VSYNCEND ),
    vtotal ( PARAM_VTOTAL ),
    bytes_per_pixel ( PARAM_BYTES_PER_PIXEL ),
    pos_r ( PARAM_RED_POS ),
    pos_g ( PARAM_GREEN_POS ),
    pos_b ( PARAM_BLUE_POS ),
    pos_a ( PARAM_ALPHA_POS ),
    bytes_per_row ( PARAM_BYTES_PER_ROW ),
    row_step ( PARAM_ROW_STEP )
{
}

void cfg_type::randomize() {
#ifndef FIXED_MODELINE
    // horizontal
    htotal          = dlsc_rand_u32(100,MAX_H);
    hdisp           = dlsc_rand_u32(50,htotal-25);
    hsyncstart      = dlsc_rand_u32(hdisp+1,htotal-10);
    hsyncend        = dlsc_rand_u32(hsyncstart+1,htotal-5);
    // vertical
    vtotal          = dlsc_rand_u32(50,MAX_V);
    vdisp           = dlsc_rand_u32(25,vtotal-8);
    vsyncstart      = dlsc_rand_u32(vdisp+1,vtotal-3);
    vsyncend        = dlsc_rand_u32(vsyncstart+1,vtotal-1);
#endif
#ifndef FIXED_PIXEL
    bytes_per_pixel = dlsc_rand_u32(1,4);
    pos_r           = dlsc_rand_u32(0,bytes_per_pixel-1);
    pos_g           = dlsc_rand_u32(0,bytes_per_pixel-1);
    pos_b           = dlsc_rand_u32(0,bytes_per_pixel-1);
    pos_a           = dlsc_rand_u32(0,bytes_per_pixel-1);
#endif
    bytes_per_row   = bytes_per_pixel*hdisp;
    if(dlsc_rand_bool(50.0)) {
        row_step        = bytes_per_row;
    } else {
        row_step        = dlsc_rand_u32(bytes_per_row,bytes_per_row*2);
    }
}


/*AUTOTRACE(__MODULE__)*/

