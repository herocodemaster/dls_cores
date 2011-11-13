//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_channel.h"

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

#define MAX_H       PARAM_MAX_H
#define MAX_V       PARAM_MAX_V
#define BPP         PARAM_BYTES_PER_PIXEL
#define READERS     PARAM_READERS

#define MAX_PX      ((1u<<(PARAM_BYTES_PER_PIXEL*8))-1)

#define MEM_SIZE    (1ull<<PARAM_AXI_ADDR)

#if (PARAM_IN_ASYNC>0)
    #define IN_ASYNC 1
    #define IN_CLK in_clk
    #define IN_RST in_rst
#else
    #define IN_SYNC 1
    #define IN_CLK clk
    #define IN_RST rst
#endif

#if (PARAM_OUT_ASYNC>0)
    #define OUT_ASYNC 1
    #define OUT0_CLK out0_clk
    #define OUT1_CLK out1_clk
    #define OUT2_CLK out2_clk
    #define OUT3_CLK out3_clk
    #define OUT0_RST out0_rst
    #define OUT1_RST out1_rst
    #define OUT2_RST out2_rst
    #define OUT3_RST out3_rst
#else
    #define OUT_SYNC 1
    #define OUT0_CLK clk
    #define OUT1_CLK clk
    #define OUT2_CLK clk
    #define OUT3_CLK clk
    #define OUT0_RST rst
    #define OUT1_RST rst
    #define OUT2_RST rst
    #define OUT3_RST rst
#endif

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;
    sc_clock in_clk;
    sc_clock out0_clk;
    sc_clock out1_clk;
    sc_clock out2_clk;
    sc_clock out3_clk;

    sc_signal<bool> in_rst;
    sc_signal<bool> out0_rst;
    sc_signal<bool> out1_rst;
    sc_signal<bool> out2_rst;
    sc_signal<bool> out3_rst;

    void set_reset(bool rst_val);

    void clk_method();
    void in_method();
    void out0_method();
    void out1_method();
    void out2_method();
    void out3_method();

    std::deque<uint32_t> in_queue;
    std::deque<uint32_t> out_queue[4];

    void stim_thread();
    void watchdog_thread();
    
    void reg_write(uint32_t dev, uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t dev, uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *apb_initiator;

    dlsc_tlm_memory<uint32_t> *memory;
    dlsc_tlm_channel<uint32_t> *channel;

    double in_pct;
    double out_pct[4];

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

SP_CTOR_IMP(__MODULE__) :
    clk("clk",10,SC_NS),
    in_clk("in_clk",12,SC_NS),
    out0_clk("out0_clk",25,SC_NS),
    out1_clk("out1_clk",15,SC_NS),
    out2_clk("out2_clk",10,SC_NS),
    out3_clk("out3_clk",7,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/
#ifdef IN_ASYNC
        SP_PIN(dut,in_clk,in_clk);
        SP_PIN(dut,in_rst,in_rst);
#else
        SP_PIN(dut,in_clk,clk);
        SP_PIN(dut,in_rst,rst);
#endif
#ifdef OUT_ASYNC
        SP_PIN(dut,out0_clk,out0_clk);
        SP_PIN(dut,out0_rst,out0_rst);
        SP_PIN(dut,out1_clk,out1_clk);
        SP_PIN(dut,out1_rst,out1_rst);
        SP_PIN(dut,out2_clk,out2_clk);
        SP_PIN(dut,out2_rst,out2_rst);
        SP_PIN(dut,out3_clk,out3_clk);
        SP_PIN(dut,out3_rst,out3_rst);
#else
        SP_PIN(dut,out0_clk,clk);
        SP_PIN(dut,out0_rst,rst);
        SP_PIN(dut,out1_clk,clk);
        SP_PIN(dut,out1_rst,rst);
        SP_PIN(dut,out2_clk,clk);
        SP_PIN(dut,out2_rst,rst);
        SP_PIN(dut,out3_clk,clk);
        SP_PIN(dut,out3_rst,rst);
#endif
    
    SP_CELL(apb_master,dlsc_apb_tlm_master_32b);
        /*AUTOINST*/

    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        SP_PIN(axi_slave,rst,rst_axi);
        /*AUTOINST*/
    
    memory      = new dlsc_tlm_memory<uint32_t>("memory",MEM_SIZE,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(10,SC_NS));

    channel     = new dlsc_tlm_channel<uint32_t>("channel");

    channel->set_delay(sc_core::sc_time(100,SC_NS),sc_core::sc_time(1000,SC_NS));

    axi_slave->socket.bind(channel->in_socket);
    channel->out_socket.bind(memory->socket);
    
    apb_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("apb_initiator",1);
    apb_initiator->socket.bind(apb_master->socket);

    rst         = 1;
    rst_axi     = 1;

    in_rst      = 1;
    out0_rst    = 1;
    out1_rst    = 1;
    out2_rst    = 1;
    out3_rst    = 1;

    in_pct      = 95.0;

    for(int i=0;i<READERS;i++) {
        out_pct[i]  = 95.0;
    }

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();
    
    SC_METHOD(in_method);
        sensitive << IN_CLK.posedge_event();
    
    SC_METHOD(out0_method);
        sensitive << OUT0_CLK.posedge_event();
    SC_METHOD(out1_method);
        sensitive << OUT1_CLK.posedge_event();
    SC_METHOD(out2_method);
        sensitive << OUT2_CLK.posedge_event();
    SC_METHOD(out3_method);
        sensitive << OUT3_CLK.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::set_reset(bool rst_val) {

    wait(clk.posedge_event());
    rst         = rst_val;
    if(!rst_val) {
        rst_axi     = 0;
    }
#ifdef IN_ASYNC
    wait(in_clk.posedge_event());
    in_rst      = rst_val;
#endif
#ifdef OUT_ASYNC
    wait(out0_clk.posedge_event());
    out0_rst    = rst_val;
    wait(out1_clk.posedge_event());
    out1_rst    = rst_val;
    wait(out2_clk.posedge_event());
    out2_rst    = rst_val;
    wait(out3_clk.posedge_event());
    out3_rst    = rst_val;
#endif

    wait(clk.posedge_event());
#ifdef IN_ASYNC
    wait(in_clk.posedge_event());
#endif
#ifdef OUT_ASYNC
    wait(out0_clk.posedge_event());
    wait(out1_clk.posedge_event());
    wait(out2_clk.posedge_event());
    wait(out3_clk.posedge_event());
#endif

}
void __MODULE__::reg_write(uint32_t dev, uint32_t addr, uint32_t data) {
    assert(dev<=READERS);
    addr += dev*16;
    apb_initiator->b_write(addr<<2,data);
    dlsc_verb("wrote 0x" << std::hex << addr << " : 0x" << data);
}

uint32_t __MODULE__::reg_read(uint32_t dev, uint32_t addr) {
    assert(dev<=READERS);
    addr += dev*16;
    uint32_t data = apb_initiator->b_read(addr<<2);
    dlsc_verb("read 0x" << std::hex << addr << " : 0x" << data);
    return data;
}

void __MODULE__::clk_method() {
    if(rst) {
    } else {
    }
}

void __MODULE__::in_method() {
    if(IN_RST) {
        in_valid    = 0;
        in_data     = 0;
        in_queue.clear();
    } else {
        if(in_ready) {
            in_valid    = 0;
        }
        if( (in_ready || !in_valid) && !in_queue.empty() && dlsc_rand_bool(in_pct) ) {
            in_valid    = 1;
            in_data     = in_queue.front(); in_queue.pop_front();
        }
    }
}

#define OUT_METHOD_TEMPLATE(INDEX) \
void __MODULE__::out ## INDEX ## _method() { \
    if(OUT ## INDEX ## _RST || READERS <= INDEX) { \
        out ## INDEX ## _ready  = 0; \
        out_queue[INDEX].clear(); \
    } else { \
        if(out ## INDEX ## _ready && out ## INDEX ## _valid) { \
            if(out_queue[INDEX].empty()) { \
                dlsc_error("unexpected data (INDEX)"); \
            } else { \
                dlsc_assert_equals( out ## INDEX ## _data , out_queue[INDEX].front() ); \
                out_queue[INDEX].pop_front(); \
            } \
        } \
        out ## INDEX ## _ready = dlsc_rand_bool(out_pct[INDEX]); \
    } \
}

OUT_METHOD_TEMPLATE(0);
OUT_METHOD_TEMPLATE(1);
OUT_METHOD_TEMPLATE(2);
OUT_METHOD_TEMPLATE(3);

const uint32_t REG_CONTROL = 0;
const uint32_t REG_STATUS = 1;
const uint32_t REG_INT_FLAGS = 2;
const uint32_t REG_INT_SELECT = 3;
const uint32_t REG_BUF0_ADDR = 4;
const uint32_t REG_BUF1_ADDR = 5;
const uint32_t REG_BPR = 6;
const uint32_t REG_STEP = 7;
const uint32_t REG_HDISP = 8;
const uint32_t REG_VDISP = 9;

void __MODULE__::stim_thread() {

    wait(100,SC_NS);
    set_reset(false);

    uint32_t hdisp;
    uint32_t vdisp;
    uint32_t bpr;
    uint32_t step;
    uint32_t buf_size;
    bool     double_buffer;
    uint32_t buf0_addr;
    uint32_t buf1_addr;

    uint32_t data;
    std::deque<uint32_t> pixels;

    unsigned int i,j,k,x,y,frames;
    
    for(i=0;i<25;i++) {
        dlsc_info("iteration " << i);

        // disable
        for(j=0;j<=READERS;j++) {
            reg_write(j,REG_CONTROL,0);
        }
        
        wait(1,SC_US);
        
        // randomize configuration
        hdisp       = dlsc_rand_u32(2,100);//MAX_H);
        vdisp       = dlsc_rand_u32(2,100);//MAX_V);
        bpr         = hdisp*BPP;
        step        = dlsc_rand_bool(50.0) ? bpr : dlsc_rand_u32(bpr,bpr*2);
        buf_size    = step * vdisp;
        double_buffer = dlsc_rand_bool(50.0);
        if(double_buffer) {
            buf0_addr   = dlsc_rand_u32(0,(MEM_SIZE/2)-buf_size-1);
            buf1_addr   = dlsc_rand_u32((MEM_SIZE/2),MEM_SIZE-buf_size-1);
        } else {
            buf0_addr   = dlsc_rand_u32(0,MEM_SIZE-buf_size-1);
            buf1_addr   = 0;
        }

        in_pct      = dlsc_rand_u32(10,100) * 1.0;
        for(j=0;j<READERS;j++) {
            out_pct[j]  = dlsc_rand_u32(10,100) * 1.0;
        }

        // write configuration
        for(j=0;j<=READERS;j++) {
            reg_write(j,REG_BUF0_ADDR,buf0_addr);
            reg_write(j,REG_BUF1_ADDR,buf1_addr);
            reg_write(j,REG_BPR,bpr);
            reg_write(j,REG_STEP,step);
            reg_write(j,REG_HDISP,hdisp);
            reg_write(j,REG_VDISP,vdisp);
        }

        // enable
        data        = 0x1;
        if(double_buffer) data |= 0x2;
        for(j=0;j<=READERS;j++) {
            reg_write(j,REG_CONTROL,data);
        }

        // create random frames
        frames = dlsc_rand_u32(2,10);
        for(j=0;j<frames;j++) {
            for(y=0;y<vdisp;y++) {
                for(x=0;x<hdisp;x++) {
                    data = dlsc_rand_u32(0,MAX_PX);
                    in_queue.push_back(data);
                    for(k=0;k<READERS;k++) {
                        out_queue[k].push_back(data);
                    }
                }
            }
        }

        // wait for completion
        while( !(in_queue.empty() && out_queue[0].empty() && out_queue[1].empty() && out_queue[2].empty() && out_queue[3].empty()) ) {
            wait(1,SC_US);
        }

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

