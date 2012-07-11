//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_channel.h"

// for syntax highlighter: SC_MODULE

#define MAX_H       PARAM_MAX_H
#define MAX_V       PARAM_MAX_V
#define READERS     PARAM_READERS

#define READERS_MASK ((1u<<PARAM_READERS)-1)

#define MAX_PX      ((1u<<(PARAM_BYTES_PER_PIXEL*8))-1)

#define MEM_SIZE    (1ull<<PARAM_AXI_ADDR)

#if (PARAM_AXI_ASYNC>0)
    #define AXI_ASYNC 1
    #define AXI_CLK axi_clk
#else
    #define AXI_SYNC 1
    #define AXI_CLK clk
#endif

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

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;
    sc_clock axi_clk;
    sc_clock in_clk;
    sc_clock out0_clk;
    sc_clock out1_clk;
    sc_clock out2_clk;
    sc_clock out3_clk;

    sc_signal<bool> axi_rst;
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

    void alloc_buffers(std::deque<uint32_t> &buf_addrs, uint32_t buf_size, unsigned int buffers, bool aligned);
    
    void reg_write(uint32_t dev, uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t dev, uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

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

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) :
    clk("clk",10,SC_NS),
    axi_clk("axi_clk",8,SC_NS),
    in_clk("in_clk",12,SC_NS),
    out0_clk("out0_clk",21,SC_NS),
    out1_clk("out1_clk",10,SC_NS),
    out2_clk("out2_clk",7,SC_NS),
    out3_clk("out3_clk",3,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/
        SP_PIN(dut,csr_clk,clk);
        SP_PIN(dut,csr_rst,rst);
#ifdef AXI_ASYNC
        SP_PIN(dut,axi_clk,axi_clk);
        SP_PIN(dut,axi_rst,axi_rst);
#else
        SP_PIN(dut,axi_clk,clk);
        SP_PIN(dut,axi_rst,rst);
#endif
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
    
    SP_CELL(csr_master,dlsc_csr_tlm_master_32b);
        /*AUTOINST*/

    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
#ifdef AXI_ASYNC
        SP_PIN(axi_slave,clk,axi_clk);
        SP_PIN(axi_slave,rst,axi_rst);
#else
        SP_PIN(axi_slave,clk,clk);
        SP_PIN(axi_slave,rst,rst);
#endif
        /*AUTOINST*/
    
    memory      = new dlsc_tlm_memory<uint32_t>("memory",MEM_SIZE,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(10,SC_NS));

    channel     = new dlsc_tlm_channel<uint32_t>("channel");

    channel->set_delay(sc_core::sc_time(100,SC_NS),sc_core::sc_time(1000,SC_NS));

    axi_slave->socket.bind(channel->in_socket);
    channel->out_socket.bind(memory->socket);
    
    csr_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("csr_initiator",1);
    csr_initiator->socket.bind(csr_master->socket);

    rst         = 1;
    axi_rst     = 1;
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
#ifdef AXI_ASYNC
    wait(axi_clk.posedge_event());
    axi_rst     = rst_val;
#endif
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
#ifdef AXI_ASYNC
    wait(axi_clk.posedge_event());
#endif
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
    addr += dev<<10;
    csr_initiator->b_write(addr<<2,data);
    dlsc_verb("wrote 0x" << std::hex << addr << " : 0x" << data);
}

uint32_t __MODULE__::reg_read(uint32_t dev, uint32_t addr) {
    assert(dev<=READERS);
    addr += dev<<10;
    uint32_t data = csr_initiator->b_read(addr<<2);
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
        if(out ## INDEX ## _valid) { \
            if(out_queue[INDEX].empty()) { \
                dlsc_error("unexpected data (" << INDEX << ")"); \
            } else if(out ## INDEX ## _ready)  { \
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

const uint32_t REG_CORE_MAGIC = 0x00;
const uint32_t REG_CORE_VERSION = 0x01;
const uint32_t REG_CORE_INTERFACE = 0x02;
const uint32_t REG_CORE_INSTANCE = 0x03;
const uint32_t REG_CONTROL = 0x04;
const uint32_t REG_STATUS = 0x05;
const uint32_t REG_FIFO_FREE = 0x06;
const uint32_t REG_FIFO = 0x07;
const uint32_t REG_ROWS_COMPLETED = 0x08;
const uint32_t REG_ROWS_THRESH = 0x09;
const uint32_t REG_BUFFERS_COMPLETED = 0x0A;
const uint32_t REG_BUFFERS_THRESH = 0x0B;
const uint32_t REG_ACK_ROWS = 0x0C;
const uint32_t REG_INT_FLAGS = 0x0D;
const uint32_t REG_INT_SELECT = 0x0E;
const uint32_t REG_CONFIG = 0x10;
const uint32_t REG_ACK_SELECT = 0x11;
const uint32_t REG_ACK_STATUS = 0x12;
const uint32_t REG_PIXELS_PER_ROW = 0x13;
const uint32_t REG_ROWS_PER_FRAME = 0x14;
const uint32_t REG_BYTES_PER_PIXEL = 0x15;
const uint32_t REG_BYTES_PER_ROW = 0x16;
const uint32_t REG_ROW_STEP = 0x17;
const uint32_t REG_ROWS_PER_BUFFER = 0x18;

void __MODULE__::alloc_buffers(std::deque<uint32_t> &buf_addrs, uint32_t buf_size, unsigned int buffers, bool aligned) {
    unsigned int target = buf_addrs.size() + buffers;
    while(buf_addrs.size() < target) {
        uint32_t addr = dlsc_rand_u32(0,MEM_SIZE-buf_size-1);
        if(aligned) {
            // align to 4K boundary
            addr &= ~0xFFF;
        }
        bool okay = true;
        // ugly method to detect conflicts..
        for(unsigned int j=0;j<buf_addrs.size();j++) {
            if((buf_addrs[j] >= addr) && (buf_addrs[j] < (addr+buf_size))) {
                okay = false;
                break;
            }
        }
        if(okay) {
            // didn't find any overlap with existing buffers
            buf_addrs.push_back(addr);
        }
    }
}

void __MODULE__::stim_thread() {

    wait(100,SC_NS);
    set_reset(false);

    uint32_t hdisp;
    uint32_t vdisp;
    uint32_t bpr;
    uint32_t bpp;
    uint32_t step;
    uint32_t buf_rows;
    uint32_t buf_size;
    uint32_t reader_sel;
    uint32_t buffers, max_buffers;
    std::deque<uint32_t> buf_addrs;
    uint32_t rows_thresh;
    uint32_t bufs_thresh;
    bool buf_auto;
    bool aligned;

    uint32_t data,intr;

    unsigned int j,k,x,y,frames;
    
    for(int iteration=0;iteration<100;iteration++) {
        dlsc_info("== iteration " << iteration << " ==");

        // remove from reset (if necessary)
        if(rst) {
            set_reset(false);
        }

        // disable
        for(j=0;j<=READERS;j++) {
            reg_write(j,REG_CONTROL,    0x0);           // disable
            do {
                data = reg_read(j,REG_STATUS);          // wait for enabled flag to deassert
            } while(data & 0x1);
            reg_write(j,REG_INT_FLAGS,  0xFFFFFFFF);    // clear all outstanding interrupts
        }
        
        wait(1,SC_US);

        // get parameters from hardware
        max_buffers = reg_read(0,REG_FIFO_FREE);
        bpp         = reg_read(0,REG_BYTES_PER_PIXEL);
        dlsc_assert_equals(bpp,PARAM_BYTES_PER_PIXEL);
        
        // randomize configuration
        switch(dlsc_rand(0,9)) {
            case 3:
                hdisp       = MAX_H;
                vdisp       = dlsc_rand_u32(2,8);
                break;
            case 8:
                hdisp       = dlsc_rand_u32(2,8);
                vdisp       = MAX_V;
                break;
            default:
                hdisp       = dlsc_rand_u32(2,100);
                vdisp       = dlsc_rand_u32(2,100);
                break;
        }
        bpr         = hdisp*bpp;
        step        = dlsc_rand_bool(50.0) ? bpr : dlsc_rand_u32(bpr,bpr*2);
        buf_rows    = dlsc_rand_bool(50.0) ? vdisp : dlsc_rand_u32(vdisp/10+1,vdisp);
        buf_size    = step * buf_rows;
        buffers     = dlsc_rand_u32(1,max_buffers);
        rows_thresh = dlsc_rand_u32(1,(vdisp/10)+1);
        bufs_thresh = dlsc_rand_u32(1,(vdisp/buf_rows)+1);
        buf_auto    = dlsc_rand_bool(50.0);
        aligned     = dlsc_rand_bool(20.0);

        reader_sel  = dlsc_rand_u32(1,READERS_MASK);

        // create random frames
        frames = dlsc_rand_u32(3,8);
        for(j=0;j<frames;j++) {
            for(y=0;y<vdisp;y++) {
                for(x=0;x<hdisp;x++) {
                    data = dlsc_rand_u32(0,MAX_PX);
                    in_queue.push_back(data);
                    for(k=0;k<READERS;k++) {
                        if(!(reader_sel & (1<<k))) continue;
                        out_queue[k].push_back(data);
                    }
                }
            }
        }

        assert(in_queue.size() == (frames*vdisp*hdisp));
        for(j=0;j<READERS;j++) {
            assert(out_queue[j].empty() || (out_queue[j].size() == in_queue.size()));
        }

        // create buffer addresses
        unsigned int buf_addr_index[READERS+1] = {0};
        buf_addrs.clear();
        if(buf_auto || dlsc_rand_bool(50.0)) {
            alloc_buffers(buf_addrs,buf_size,buffers,aligned);
        }

        // randomize rates
        in_pct      = dlsc_rand_u32(10,100) * 1.0;
        for(j=0;j<READERS;j++) {
            out_pct[j]  = dlsc_rand_u32(10,100) * 1.0;
        }

        // write configuration
        for(j=0;j<=READERS;j++) {
            if( j>=1 && !(reader_sel & (1<<(j-1))) ) continue;

            while(buf_addr_index[j] < buf_addrs.size()) {
                reg_write(j,REG_FIFO,buf_addrs[buf_addr_index[j]++]);
            }

            intr = (1u<<0);     // disabled flag
            data = 0;
            if(buf_auto) {
                // auto mode
                data |= 0x1;        // auto mode enable
            } else {
                // normal mode
                intr |= (1u<<4);    // FIFO empty flag
            }
            reg_write(j,REG_INT_SELECT,intr);
            reg_write(j,REG_CONFIG,data);

            reg_write(j,REG_ROWS_THRESH,rows_thresh);
            reg_write(j,REG_BUFFERS_THRESH,bufs_thresh);
            reg_write(j,REG_PIXELS_PER_ROW,hdisp);
            reg_write(j,REG_ROWS_PER_FRAME,vdisp);
            reg_write(j,REG_BYTES_PER_ROW,bpr);
            reg_write(j,REG_ROW_STEP,step);
            reg_write(j,REG_ROWS_PER_BUFFER,buf_rows);
            if(j>=1) {
                reg_write(j,REG_ACK_SELECT,0x1);
            } else {
                reg_write(0,REG_ACK_SELECT,reader_sel);
            }
        }
        
        // enable readers
        dlsc_info("readers enabled: 0x" << std::hex << reader_sel);
        for(j=0;j<READERS;j++) {
            if(!(reader_sel & (1<<j)) ) continue;
            reg_write(j+1,REG_CONTROL,0x1);
        }
        
        // enable writer last
        reg_write(0,REG_CONTROL,0x1);

        int rows_complete[READERS+1] = {0};
        int bufs_complete[READERS+1] = {0};

        // wait for completion
        bool done = false;
        bool fault = false;
        while(!done && !fault) {
            wait(1,SC_US);
            done = true;
            if(!in_queue.empty()) done = false;
            for(j=0;j<READERS;j++) {
                if(!out_queue[j].empty()) done = false;
            }

            for(j=0;j<=READERS;j++) {
                if( j>=1 && !(reader_sel & (1<<(j-1))) ) continue;
                if(!(csr_int & (1<<j)) && dlsc_rand(99.0)) continue;
                
                intr = reg_read(j,REG_INT_FLAGS);

                if(intr & (1u<<0)) {
                    // disabled
                    dlsc_error("disabled! interrupt flags: 0x" << intr);
                    fault = true;
                    continue;
                }

                if(!buf_auto && (intr & (1u<<4))) {
                    // out of addresses
                    if(buf_addr_index[j] == buf_addrs.size()) {
                        // need more addresses
                        alloc_buffers(buf_addrs,buf_size,dlsc_rand(1,max_buffers/4),aligned);
                    }
                    // push addresses
                    uint32_t free = reg_read(j,REG_FIFO_FREE);
                    while(free > 0 && buf_addr_index[j] < buf_addrs.size()) {
                        reg_write(j,REG_FIFO,buf_addrs[buf_addr_index[j]++]);
                        free--;
                    }
                }
                
                // check rows completed
                if(intr & (1u<<6)) {
                    data = reg_read(j,REG_ROWS_COMPLETED);
                    rows_complete[j] += data;
                    dlsc_assert( data >= rows_thresh );
                }
                
                // check bufs completed
                if(intr & (1u<<7)) {
                    data = reg_read(j,REG_BUFFERS_COMPLETED);
                    bufs_complete[j] += data;
                    dlsc_assert( data >= bufs_thresh );
                }
                
                reg_write(j,REG_INT_FLAGS,intr);
            }
        }

        for(j=0;j<=READERS;j++) {
            if( j>=1 && !(reader_sel & (1<<(j-1))) ) continue;
            rows_complete[j] += reg_read(j,REG_ROWS_COMPLETED);
            bufs_complete[j] += reg_read(j,REG_BUFFERS_COMPLETED);
            dlsc_assert_equals(rows_complete[j],(frames*vdisp));
            dlsc_assert_equals(bufs_complete[j],(frames*vdisp)/buf_rows);
        }

#if 0
        // check configuration
        for(j=0;j<=READERS;j++) {
            if( j>=1 && !(reader_sel & (1<<(j-1))) ) {
                data = reg_read(j,REG_CONTROL);
                dlsc_assert_equals( 0, data );
                data = reg_read(j,REG_STATUS);
                dlsc_assert_equals( 0, data );
                continue;
            }

            data = reg_read(j,REG_CONTROL);
            dlsc_assert_equals( 0x1 | (double_buffer ? 0x2 : 0x0) , data );
            data = reg_read(j,REG_BUF0_ADDR);
            dlsc_assert_equals( buf0_addr, data );
            data = reg_read(j,REG_BUF1_ADDR);
            dlsc_assert_equals( buf1_addr, data );
            data = reg_read(j,REG_BPR);
            dlsc_assert_equals( bpr, data );
            data = reg_read(j,REG_STEP);
            dlsc_assert_equals( step, data );
            data = reg_read(j,REG_HDISP);
            dlsc_assert_equals( hdisp, data );
            data = reg_read(j,REG_VDISP);
            dlsc_assert_equals( vdisp, data );

            if(j==0) {
                data = reg_read(j,REG_ACK_STATUS);
                dlsc_assert_equals( READERS_MASK, data );
                data = reg_read(j,REG_ACK_SELECT);
                dlsc_assert_equals( reader_sel, data );
                data = reg_read(j,REG_STATUS);
                dlsc_assert_equals( 0x1 | ((double_buffer && (frames%2) == 0) ? 0x2 : 0x0) , data );
            } else {
                data = reg_read(j,REG_ACK_STATUS);
                dlsc_assert_equals( 0x0, data );
                data = reg_read(j,REG_ACK_SELECT);
                dlsc_assert_equals( 0x1, data );
                data = reg_read(j,REG_STATUS);
                dlsc_assert_equals( 0x1 | ((double_buffer && (frames%2) == 1) ? 0x2 : 0x0) , data );
            }
        }
#endif

        // reset periodically
        if(fault || dlsc_rand_bool(25.0)) {
            set_reset(true);
        }
    }

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    for(int i=0;i<200;i++) {
        wait(1,SC_MS);
        dlsc_info(". " << in_queue.size() << ", " << out_queue[0].size() << ", " << out_queue[1].size() << ", " << out_queue[2].size() << ", " << out_queue[3].size());
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/

