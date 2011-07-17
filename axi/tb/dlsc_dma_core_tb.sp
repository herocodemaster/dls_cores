//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>
#include <boost/shared_ptr.hpp>

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

#define TRIG_MASK   ((1<<TRIGGERS)-1)

struct dma_desc {
    uint32_t len;
    uint64_t addr;
    uint32_t trig_in;
    uint32_t trig_out;
};

struct dma_op_type {
    int id;
    std::deque<dma_desc> srcq;
    std::deque<dma_desc> destq;
    uint32_t src_cmd_len;
    uint64_t src_cmd_addr;
    uint32_t dest_cmd_len;
    uint64_t dest_cmd_addr;
};

typedef boost::shared_ptr<dma_op_type> dma_op;

enum mem_region {
    MEM_CMD = 0,
    MEM_RD  = 1,
    MEM_WR  = 2
};


SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void int_thread();
    void clk_method();
    
    dlsc_tlm_memory<uint32_t> *cmd_memory;
    dlsc_tlm_memory<uint32_t> *rd_memory;
    dlsc_tlm_memory<uint32_t> *wr_memory;

    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);

    void mem_fill(const std::deque<dma_desc> &descs);

    void desc_serialize(const std::deque<dma_desc> &desc_queue, std::deque<uint32_t> &data);
    void desc_alloc(mem_region rgn, std::deque<dma_desc> &descs);
    void desc_free(mem_region rgn, std::deque<dma_desc> &descs);

    void dma_check(std::deque<dma_desc> src_descs, std::deque<dma_desc> dest_descs);
    void do_dma();

    // allocator
    uint8_t *mem_cmd_busy;
    uint8_t *mem_rd_busy;
    uint8_t *mem_wr_busy;

    uint64_t mem_alloc(mem_region rgn, unsigned int length);
    void mem_free(mem_region rgn, uint64_t addr, unsigned int length);

    const uint64_t mem_size;

    uint32_t trig_in_busy;
    uint32_t trig_out_busy;

    // allocates everything; writes descriptors to memory; writes to address FIFOs
    void op_pend(dma_op &op);
    // fills source memory; sets trigger
    void op_trig(dma_op &op);
    // checks dest memory; frees everything
    void op_check(dma_op &op);

    std::deque<dma_op> pend_queue;
    std::deque<dma_op> trig_queue;
    std::deque<dma_op> check_queue;

    int next_id;


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


SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS), mem_size(1024*1024) /*AUTOINIT*/ {
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

    
    cmd_memory = new dlsc_tlm_memory<uint32_t>("cmd_memory",4*mem_size,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(100,SC_NS));
    axi_slave_cmd->socket.bind(cmd_memory->socket);
    
    rd_memory = new dlsc_tlm_memory<uint32_t>("rd_memory",4*mem_size,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(100,SC_NS));
    axi_slave_rd->socket.bind(rd_memory->socket);
    
    wr_memory = new dlsc_tlm_memory<uint32_t>("wr_memory",4*mem_size,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(100,SC_NS));
    axi_slave_wr->socket.bind(wr_memory->socket);

    mem_cmd_busy    = new uint8_t[mem_size];
    mem_rd_busy     = new uint8_t[mem_size];
    mem_wr_busy     = new uint8_t[mem_size];

    std::fill(mem_cmd_busy,mem_cmd_busy+mem_size,0);
    std::fill(mem_rd_busy ,mem_rd_busy +mem_size,0);
    std::fill(mem_wr_busy ,mem_wr_busy +mem_size,0);

    trig_in_busy    = 0;
    trig_out_busy   = 0;

    next_id         = 0;

    rst             = 1;

    SC_THREAD(int_thread);

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::int_thread() {

    do {
        wait(clk.posedge_event());
    } while(rst);

    dlsc_assert_equals(int_out,0);

    while(true) {
        
        wait(clk.posedge_event());

        if(int_out) {
            uint32_t fl = reg_read(REG_INT_FLAGS);
            uint32_t ack = 0;

            if( (fl & (1<<19)) && (fl & (1<<17)) && !pend_queue.empty() ) {

                uint32_t cnt = reg_read(REG_COUNTS);
                uint32_t frd_free = ((cnt >> 16) & 0xFF);
                uint32_t fwr_free = ((cnt >> 24) & 0xFF);

                dlsc_assert(frd_free >= 4);
                dlsc_assert(fwr_free >= 4);

                while(frd_free > 0 && fwr_free > 0 && !pend_queue.empty() && trig_in_busy != TRIG_MASK && trig_out_busy != TRIG_MASK) {
                    dma_op op = pend_queue.front(); pend_queue.pop_front();
                    op_pend(op);
                    reg_write(REG_FRD_LO,op->src_cmd_addr);
                    reg_write(REG_FRD_HI,op->src_cmd_addr>>32);
                    reg_write(REG_FWR_LO,op->dest_cmd_addr);
                    reg_write(REG_FWR_HI,op->dest_cmd_addr>>32);
                    trig_queue.push_back(op);
                    frd_free--;
                    fwr_free--;
                }
            }

            while(!check_queue.empty() && (check_queue.front()->destq.back().trig_out & fl)) {
                dma_op op = check_queue.front(); check_queue.pop_front();
                ack |= op->destq.back().trig_out;
                op_check(op);
            }

            if(ack) {
                dlsc_assert_equals( (trig_out.read() & ack) , ack );
                reg_write(REG_TRIG_OUT_ACK,ack);
                wait(clk.posedge_event());
                dlsc_assert_equals( (trig_out.read() & ack) , 0 );
                trig_out_busy &= ~ack;
            }

            if(pend_queue.empty()) {
                // mask empty interrupt
                reg_write(REG_INT_SELECT,0x8000FFFF);
            }
        } else {
            if(!pend_queue.empty() && trig_queue.empty() && check_queue.empty()) {
                // unmask empty interrupt
                reg_write(REG_INT_SELECT,0x800FFFFF);
            }
        }

        wait(1,SC_US);
    }
}

void __MODULE__::clk_method() {
    if(rst) {
        return;
    }

    // ** triggers **

    uint32_t trig = trig_in.read();

    trig            &= ~(trig_in_ack.read());
    trig_in_busy    &= ~(trig_in_ack.read());

    if(!trig_queue.empty() && check_queue.size() <= 3 && (rand()%1000) == 0) {
        dma_op op = trig_queue.front(); trig_queue.pop_front();
        op_trig(op);
        trig |= op->srcq.front().trig_in;
        check_queue.push_back(op);
    }

    trig_in.write(trig);
}
    
uint64_t __MODULE__::mem_alloc(mem_region rgn, unsigned int length) {
    uint8_t *busy;

    switch(rgn) {
        case MEM_CMD: busy = mem_cmd_busy; break;
        case MEM_RD:  busy = mem_rd_busy; break;
        case MEM_WR:  busy = mem_wr_busy; break;
        default: busy = NULL;
    }

    assert(busy);

    uint64_t begin      = rand() & (mem_size-1);
    uint64_t i          = begin;
    uint64_t index      = 0;
    unsigned int len    = 0;

    // find region
    do {
        if(i == 0) len = 0; // reset len on wrap

        if( !busy[i] ) {
            if(!len) index = i;
            ++len;
        } else {
            len = 0;
        }
    
        if(++i == mem_size) i = 0; // wrapping increment
    } while(i != begin && len != length);

    assert( len == length );

    assert( (index+length) <= mem_size );

    std::fill(busy+index,busy+index+length,0xFF);

    return (index<<2);
}

void __MODULE__::mem_free(mem_region rgn, uint64_t addr, unsigned int length) {
    uint8_t *busy;

    switch(rgn) {
        case MEM_CMD: busy = mem_cmd_busy; break;
        case MEM_RD:  busy = mem_rd_busy; break;
        case MEM_WR:  busy = mem_wr_busy; break;
        default: busy = NULL;
    }

    assert(busy);

    addr >>= 2;

    assert( (addr+length) <= mem_size );

    std::fill(busy+addr,busy+addr+length,0);
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

void __MODULE__::desc_serialize(const std::deque<dma_desc> &desc_queue, std::deque<uint32_t> &data) {

    for(std::deque<dma_desc>::const_iterator it = desc_queue.begin(); it != desc_queue.end(); it++) {
        dma_desc desc = (*it);

        uint32_t len = desc.len << 2;

        if( (desc.addr >> 32) != 0 || (rand()%100) < 20) {
            len |= 0x1;
        }
        if(desc.trig_in || desc.trig_out || (rand()%100) < 20) {
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

void __MODULE__::desc_alloc(mem_region rgn, std::deque<dma_desc> &descs) {
    for(std::deque<dma_desc>::iterator it = descs.begin(); it != descs.end(); it++) {
        (*it).addr = mem_alloc(rgn,(*it).len);
    }
}

void __MODULE__::desc_free(mem_region rgn, std::deque<dma_desc> &descs) {
    for(std::deque<dma_desc>::iterator it = descs.begin(); it != descs.end(); it++) {
        mem_free(rgn,(*it).addr,(*it).len);
    }
}

void __MODULE__::op_pend(dma_op &op) {

    // allocate triggers
    assert(trig_in_busy != TRIG_MASK);
    assert(trig_out_busy != TRIG_MASK);

    uint32_t trig = 0x1;
    while(trig_in_busy & trig) trig <<= 1;

    trig_in_busy |= trig;
    op->srcq.front().trig_in = trig;

    trig = 0x1;
    while(trig_out_busy & trig) trig <<= 1;

    trig_out_busy |= trig;
    op->destq.back().trig_out = trig;

    // allocate memory
    desc_alloc(MEM_RD,op->srcq);
    desc_alloc(MEM_WR,op->destq);
    
    // allocate commands
    std::deque<uint32_t> data;

    data.clear();
    desc_serialize(op->srcq,data);
    op->src_cmd_len = data.size();
    op->src_cmd_addr = mem_alloc(MEM_CMD,data.size());
    cmd_memory->nb_write(op->src_cmd_addr,data);

    data.clear();
    desc_serialize(op->destq,data);
    op->dest_cmd_len = data.size();
    op->dest_cmd_addr = mem_alloc(MEM_CMD,data.size());
    cmd_memory->nb_write(op->dest_cmd_addr,data);

    dlsc_info("op_pend " << std::dec << op->id);
}

void __MODULE__::op_trig(dma_op &op) {
    mem_fill(op->srcq);

    dlsc_info("op_trig " << std::dec << op->id);
}

void __MODULE__::op_check(dma_op &op) {

    dma_check(op->srcq,op->destq);

    desc_free(MEM_RD,op->srcq);
    desc_free(MEM_WR,op->destq);
    mem_free(MEM_CMD,op->src_cmd_addr,op->src_cmd_len);
    mem_free(MEM_CMD,op->dest_cmd_addr,op->dest_cmd_len);

    dlsc_info("op_check " << std::dec << op->id);
}

void __MODULE__::do_dma() {

    unsigned int length = (rand() % 100000) + 1;
    unsigned int lim;
    dma_desc desc;
    desc.trig_in    = 0;
    desc.trig_out   = 0;

    dma_op op(new dma_op_type);

    op->id = next_id++;

    dlsc_info("performing DMA operation, length: " << std::dec << length);


    // source

    lim             = length;

    while(lim > 0) {
        desc.len    = (rand() % 100000) + 1;
        if(desc.len > lim)
            desc.len    = lim;
        op->srcq.push_back(desc);
        lim -= desc.len;
    }


    // destination
    
    lim             = length;

    while(lim > 0) {
        desc.len    = (rand() % 100000) + 1;
        if(desc.len > lim)
            desc.len    = lim;
        op->destq.push_back(desc);
        lim -= desc.len;
    }


    while(pend_queue.size() > 10) wait(1,SC_US);

    pend_queue.push_back(op);
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
    
    dlsc_verb("write to 0x" << std::hex << addr << ": 0x" << std::hex << data);
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

    dlsc_verb("read from 0x" << std::hex << addr << ": 0x" << std::hex << data);

    return data;
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);
    wait(clk.posedge_event());
    rst     = 0;

    for(int i=0;i<20;++i) {
        do_dma();
    }

    while( !(pend_queue.empty() && trig_queue.empty() && check_queue.empty()) ) wait(1,SC_US);

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



