//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_initiator_nb.h"

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

    dlsc_tlm_initiator_nb<uint32_t> *cmd_init;
    dlsc_tlm_initiator_nb<uint32_t> *rd_init;
    dlsc_tlm_initiator_nb<uint32_t> *wr_init;

    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction transaction;

    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);

    void mem_write(dlsc_tlm_initiator_nb<uint32_t> *ini, uint64_t addr, std::deque<uint32_t> &data);
    void mem_read(dlsc_tlm_initiator_nb<uint32_t> *ini, uint64_t addr, unsigned int length, std::deque<uint32_t> &data);

    void mem_fill(uint64_t addr, unsigned int length);
    void mem_check(uint64_t addr, unsigned int length);
    void desc_write(uint64_t addr, std::deque<dma_desc> &desc_queue);
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

    
    cmd_memory = new dlsc_tlm_memory<uint32_t>("cmd_memory",4*1024*1024,0,sc_core::sc_time(2.0,SC_NS),sc_core::sc_time(20,SC_NS));
    axi_slave_cmd->socket.bind(cmd_memory->socket);
    
    rd_memory = new dlsc_tlm_memory<uint32_t>("rd_memory",4*1024*1024,0,sc_core::sc_time(2.0,SC_NS),sc_core::sc_time(20,SC_NS));
    axi_slave_rd->socket.bind(rd_memory->socket);
    
    wr_memory = new dlsc_tlm_memory<uint32_t>("wr_memory",4*1024*1024,0,sc_core::sc_time(2.0,SC_NS),sc_core::sc_time(20,SC_NS));
    axi_slave_wr->socket.bind(wr_memory->socket);


    cmd_init = new dlsc_tlm_initiator_nb<uint32_t>("cmd_init",256);
    cmd_init->socket.bind(cmd_memory->socket);
    rd_init = new dlsc_tlm_initiator_nb<uint32_t>("rd_init",256);
    rd_init->socket.bind(rd_memory->socket);
    wr_init = new dlsc_tlm_initiator_nb<uint32_t>("wr_init",256);
    wr_init->socket.bind(wr_memory->socket);

    rst     = 1;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::mem_write(dlsc_tlm_initiator_nb<uint32_t> *ini, uint64_t addr, std::deque<uint32_t> &data) {
    std::deque<uint32_t> wrdata;

    while(!data.empty()) {
        unsigned int lim = 0xFFF - (addr & 0xFFF);
        if(lim > 256) lim = 256;
        if(lim > data.size()) lim = data.size();

        assert(lim > 0);

        wrdata.resize(lim);
        std::copy(data.begin(),data.begin()+lim,wrdata.begin());
        data.erase(data.begin(),data.begin()+lim);

        ini->nb_write(addr,wrdata);

        addr += (lim*4);
    }

    ini->wait();
}

void __MODULE__::mem_read(dlsc_tlm_initiator_nb<uint32_t> *ini, uint64_t addr, unsigned int length, std::deque<uint32_t> &data) {
    std::deque<transaction> ts_queue;

    data.resize(length);

    while(length != 0) {
        unsigned int lim = 0xFFF - (addr & 0xFFF);
        if(lim > 256) lim = 256;
        if(lim > length) lim = length;

        ts_queue.push_back(ini->nb_read(addr,lim));

        addr += (lim*4);
        length -= lim;
    }

    unsigned int offset = 0;

    while(!ts_queue.empty()) {
        transaction ts = ts_queue.front(); ts_queue.pop_front();
        ts->b_read(data.begin()+offset);
        offset += ts->size();
    }
}

void __MODULE__::mem_fill(uint64_t addr, unsigned int length) {

    std::deque<uint32_t> data;

    while(data.size() < length) {
        data.push_back(rand());
    }

    mem_write(rd_init,addr,data);
}

void __MODULE__::mem_check(uint64_t addr, unsigned int length) {

    std::deque<uint32_t> data_src;
    std::deque<uint32_t> data_dest;

    mem_read(rd_init,addr,length,data_src);
    mem_read(wr_init,addr,length,data_dest);

    while(!data_src.empty()) {

        if(data_src.front() != data_dest.front()) {
            dlsc_error("miscompare at 0x" << std::hex << addr <<
                        "; expected: 0x" << std::hex << data_src.front() <<
                        ", got: 0x" << std::hex << data_dest.front());
        }

        addr += 4;
    }
}

void __MODULE__::desc_write(uint64_t addr, std::deque<dma_desc> &desc_queue) {

    std::deque<uint32_t> data;

    while(!desc_queue.empty()) {
        dma_desc desc = desc_queue.front(); desc_queue.pop_front();

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

    mem_write(cmd_init,addr,data);
}

void __MODULE__::do_dma() {

    // create read list


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

    reg_write(REG_CONTROL,0x2);

    std::deque<dma_desc> desc_queue;

    dma_desc desc;


    desc.len        = 100;
    desc.addr       = 0x40;
    desc.trig_in    = 0;
    desc.trig_out   = 0;
    desc_queue.push_back(desc);
    
    desc.len        = 10;
    desc.addr       = 0x5000;
    desc.trig_in    = 0;
    desc.trig_out   = 0;
    desc_queue.push_back(desc);

    desc_write(0x400,desc_queue);


    desc_queue.clear();
    
    desc.len        = 40;
    desc.addr       = 0xFFC;
    desc.trig_in    = 0;
    desc.trig_out   = 0;
    desc_queue.push_back(desc);
    
    desc.len        = 50;
    desc.addr       = 0x100;
    desc.trig_in    = 0;
    desc.trig_out   = 0;
    desc_queue.push_back(desc);
    
    desc.len        = 20;
    desc.addr       = 0x3000;
    desc.trig_in    = 0;
    desc.trig_out   = 0;
    desc_queue.push_back(desc);

    desc_write(0xFFC,desc_queue);


    wait(clk.posedge_event());
    reg_write(REG_FRD_LO,0x400);
    reg_write(REG_FRD_HI,0x0);
    reg_write(REG_FWR_LO,0xFFC);
    reg_write(REG_FWR_HI,0x0);


    wait(100,SC_US);
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



