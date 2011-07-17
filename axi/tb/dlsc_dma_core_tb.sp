//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

#define APB_ADDR    PARAM_APB_ADDR
#define CMD_ADDR    PARAM_CMD_ADDR
#define CMD_LEN     PARAM_CMD_LEN
#define READ_ADDR   PARAM_READ_ADDR
#define READ_LEN    PARAM_READ_LEN
#define READ_MOT    PARAM_READ_MOT
#define WRITE_ADDR  PARAM_WRITE_ADDR
#define WRITE_LEN   PARAM_WRITE_LEN
#define WRITE_MOT   PARAM_WRITE_MOT
#define DATA        PARAM_DATA
#define TRIGGERS    PARAM_TRIGGERS

struct dma_desc {
    uint32_t len;
    uint64_t addr;
    uint32_t trig_in;
    uint32_t trig_out;
};


SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();
    
    dlsc_tlm_memory<uint32_t> *cmd_memory;
    dlsc_tlm_memory<uint32_t> *rd_memory;
    dlsc_tlm_memory<uint32_t> *wr_memory;

    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);

    void mem_fill(const std::deque<dma_desc> &descs);
    unsigned int desc_write(uint64_t addr, const std::deque<dma_desc> &desc_queue);
    void dma_check(std::deque<dma_desc> src_descs, std::deque<dma_desc> dest_descs);
    void do_dma();

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


const uint32_t REG_CONTROL         = 0x0;
const uint32_t REG_STATUS          = 0x1;
const uint32_t REG_INT_FLAGS       = 0x2;
const uint32_t REG_INT_SELECT      = 0x3;
const uint32_t REG_COUNTS          = 0x4;
const uint32_t REG_TRIG_IN         = 0x8;
const uint32_t REG_TRIG_OUT        = 0x9;
const uint32_t REG_TRIG_IN_ACK     = 0xA;
const uint32_t REG_TRIG_OUT_ACK    = 0xB;
const uint32_t REG_FRD_LO          = 0xC;
const uint32_t REG_FRD_HI          = 0xD;
const uint32_t REG_FWR_LO          = 0xE;
const uint32_t REG_FWR_HI          = 0xF;


SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SP_CELL(axi_slave_cmd,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
    SP_TEMPLATE(axi_slave_cmd,"axi_(.*)","cmd_$1");

    SP_CELL(axi_slave_rd,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
    SP_TEMPLATE(axi_slave_rd,"axi_(.*)","rd_$1");

    SP_CELL(axi_slave_wr,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
    SP_TEMPLATE(axi_slave_wr,"axi_(.*)","wr_$1");

    
    cmd_memory = new dlsc_tlm_memory<uint32_t>("cmd_memory",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(100,SC_NS));
    axi_slave_cmd->socket.bind(cmd_memory->socket);
    
    rd_memory = new dlsc_tlm_memory<uint32_t>("rd_memory",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(100,SC_NS));
    axi_slave_rd->socket.bind(rd_memory->socket);
    
    wr_memory = new dlsc_tlm_memory<uint32_t>("wr_memory",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(100,SC_NS));
    axi_slave_wr->socket.bind(wr_memory->socket);

    rst     = 1;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}


void __MODULE__::mem_fill(const std::deque<dma_desc> &descs) {
    std::deque<uint32_t> data;
    for(std::deque<dma_desc>::const_iterator it = descs.begin() ; it != descs.end() ; it++) {
        const dma_desc desc = (*it);
        data.clear();
        while(data.size() < desc.len) {
            data.push_back(rand());
        }
        rd_memory->nb_write(desc.addr,data);
    }
}

unsigned int __MODULE__::desc_write(uint64_t addr, const std::deque<dma_desc> &desc_queue) {

    std::deque<uint32_t> data;

    for(std::deque<dma_desc>::const_iterator it = desc_queue.begin(); it != desc_queue.end(); it++) {
        const dma_desc desc = (*it);

        uint32_t len = desc.len << 2;

        if( (desc.addr >> 32) != 0 ) {
            len |= 0x1;
        }
        if(desc.trig_in || desc.trig_out) {
            len |= 0x2;
        }

        data.push_back(len);
        data.push_back(desc.addr);
        if(len & 0x1) {
            data.push_back(desc.addr >> 32);
        }
        if(len & 0x2) {
            data.push_back(desc.trig_in | (desc.trig_out << 16));
        }
    }

    data.push_back(0);

    cmd_memory->nb_write(addr,data);

    return data.size();
}

void __MODULE__::dma_check(std::deque<dma_desc> src_descs, std::deque<dma_desc> dest_descs) {

    std::deque<uint32_t> data_src;

    for(std::deque<dma_desc>::const_iterator it = src_descs.begin(); it != src_descs.end(); it++) {
        const dma_desc desc = (*it);
        data_src.resize(data_src.size() + desc.len);
        rd_memory->nb_read(desc.addr,data_src.end()-desc.len,data_src.end());
    }

    std::deque<uint32_t> data_dest;

    for(std::deque<dma_desc>::const_iterator it = dest_descs.begin(); it != dest_descs.end(); it++) {
        const dma_desc desc = (*it);
        data_dest.resize(data_dest.size() + desc.len);
        wr_memory->nb_read(desc.addr,data_dest.end()-desc.len,data_dest.end());
    }

    assert(data_src.size() == data_dest.size());

    dma_desc src, dest;

    src     = src_descs.front(); src_descs.pop_front();
    dest    = dest_descs.front(); dest_descs.pop_front();

    int srci = 1, desti = 1;

    while(!data_src.empty()) {

        if(data_src.front() != data_dest.front()) {
            dlsc_error("miscompare! src.addr: 0x" << std::hex << src.addr <<
                ", src.len: " << std::dec << src.len <<
                ", dest.addr: 0x" << std::hex << dest.addr <<
                ", dest.len: " << std::dec << dest.len <<
                "; expected: 0x" << std::hex << data_src.front() <<
                ", got: 0x" << std::hex << data_dest.front());
        } else {
            dlsc_okay("match");
        }

        data_src.pop_front();
        data_dest.pop_front();
        
        src.len     -= 4;
        src.addr    += 4;
        if(src.len == 0) {
            src         = src_descs.front();
            src_descs.pop_front();
            srci++;
        }

        dest.len    -= 4;
        dest.addr   += 4;
        if(dest.len == 0) {
            dest        = dest_descs.front();
            dest_descs.pop_front();
            desti++;
        }
    }
}

void __MODULE__::do_dma() {

    const unsigned int mem_size = 1024*1024;

    unsigned int length = (rand() % 100000) + 1;
    unsigned int lim;
    dma_desc desc;

    std::deque<dma_desc> srcq, destq;

    dlsc_info("performing DMA operation, length: " << std::dec << length);


    // source

    desc.trig_in    = 0;
    desc.trig_out   = 0;
    lim             = length;

    while(lim > 0) {
        desc.len    = (rand() % 100000) + 1;
        if(desc.len > lim)
            desc.len    = lim;

        desc.addr   = rand() % mem_size;

        if(desc.len > (mem_size-desc.addr))
            desc.len    = (mem_size-desc.addr);

        desc.addr *= 4;

        srcq.push_back(desc);
        lim -= desc.len;
    }

    srcq.front().trig_in = 0x1;


    // destination
    
    desc.trig_in    = 0;
    desc.trig_out   = 0;
    lim             = length;

    while(lim > 0) {
        desc.len    = (rand() % 100000) + 1;
        if(desc.len > lim)
            desc.len    = lim;

        desc.addr   = rand() % mem_size;

        if(desc.len > (mem_size-desc.addr))
            desc.len    = (mem_size-desc.addr);

        desc.addr *= 4;

        destq.push_back(desc);
        lim -= desc.len;
    }

    destq.back().trig_out = 0x1;


    // write to memory

    mem_fill(srcq);

    uint64_t srcq_addr  = (rand() % mem_size)*4;
    uint64_t destq_addr = srcq_addr + (desc_write(srcq_addr,srcq)*4);
    desc_write(destq_addr,destq);


    wait(clk.posedge_event());
    trig_in = 0;
    reg_write(REG_TRIG_IN_ACK,0xFFFF);
    reg_write(REG_TRIG_OUT_ACK,0xFFFF);
    reg_write(REG_INT_SELECT,0x1);
    
    reg_write(REG_FRD_LO,srcq_addr);
    reg_write(REG_FRD_HI,srcq_addr >> 32);
    reg_write(REG_FWR_LO,destq_addr);
    reg_write(REG_FWR_HI,destq_addr >> 32);

    dlsc_assert_equals(int_out,0);

    sc_core::sc_time start = sc_core::sc_time_stamp();
    trig_in = 1;

    wait(int_out.posedge_event());

    dlsc_assert_equals(int_out,1);

    start = sc_core::sc_time_stamp() - start;

    dlsc_info("done; elapsed time: " << start);

    uint32_t r = reg_read(REG_COUNTS);
    dlsc_assert_equals( (r&0xFF), srcq.size() );
    dlsc_assert_equals( ((r>>8)&0xFF), destq.size() );

    dma_check(srcq,destq);
}

void __MODULE__::reg_write(uint32_t addr, uint32_t data) {
    apb_sel     = 1;
    apb_enable  = 0;
    apb_write   = 1;
    apb_addr    = addr << 2;
    apb_wdata   = data;

    wait(clk.posedge_event());
    apb_enable  = 1;

    do {
        wait(clk.posedge_event());
    } while(!apb_ready);

    apb_sel     = 0;
    apb_enable  = 0;
}

uint32_t __MODULE__::reg_read(uint32_t addr) {
    apb_sel     = 1;
    apb_enable  = 0;
    apb_write   = 0;
    apb_addr    = addr << 2;
    apb_wdata   = 0;

    wait(clk.posedge_event());
    apb_enable  = 1;

    do {
        wait(clk.posedge_event());
    } while(!apb_ready);

    apb_sel     = 0;
    apb_enable  = 0;

    uint32_t data = apb_rdata.read();

    return data;
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);
    wait(clk.posedge_event());
    rst     = 0;

    for(int i=0;i<10;++i) {
        do_dma();
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



