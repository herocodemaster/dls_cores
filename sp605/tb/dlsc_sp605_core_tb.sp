//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>
#include <boost/shared_ptr.hpp>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

// for syntax highlighter: SC_MODULE

#if (PARAM_LOCAL_DMA_DESC)
#define LOCAL_DMA_DESC
#endif

#define SRAM_SIZE PARAM_SRAM_SIZE

/*AUTOSUBCELL_CLASS*/

struct dma_desc {
    dma_desc() { len = 0; addr = 0; trig_in = 0; trig_out = 0; }
    uint32_t len;
    uint64_t addr;
    uint32_t trig_in;
    uint32_t trig_out;
};

struct dma_op_type {
    dma_op_type() { dir_wr = false; src_cmd_len = 0; src_cmd_addr = 0; dest_cmd_len = 0; dest_cmd_addr = 0; }
    bool dir_wr; // false: host -> mig; true: mig -> host
    std::deque<dma_desc> srcq;
    std::deque<dma_desc> destq;
    uint32_t src_cmd_len;
    uint64_t src_cmd_addr;
    uint32_t dest_cmd_len;
    uint64_t dest_cmd_addr;
};

typedef boost::shared_ptr<dma_op_type> dma_op;

SC_MODULE (__MODULE__) {
private:
    sc_clock        sys_clk;
    sc_signal<bool> sys_reset;

    sc_clock        clk;
    sc_signal<bool> rst;

    sc_clock        px_clk;
    sc_signal<bool> px_rst;

    void stim_thread();
    void watchdog_thread();
    
    dlsc_tlm_initiator_nb<uint32_t> *initiator;
    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction transaction;

    dlsc_tlm_memtest<uint32_t>  *memtest;

    dlsc_tlm_memory<uint32_t>   *memory_host;
    dlsc_tlm_memory<uint32_t>   *memory_mig;
    
    void reg_write(uint32_t device, uint32_t addr, uint32_t data, bool nb=false);
    uint32_t reg_read(uint32_t device, uint32_t addr);

    void dma_desc_serialize(const std::deque<dma_desc> &desc_queue, std::deque<uint32_t> &data);
    int dma_check(dma_op op);
    void dma_run(dma_op op);

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

//                                                  000FFFFF
const uint64_t REG_BASE                 = 0x0042CAFEBE300000;
//                                                  07FFFFFF
const uint64_t MEM_BASE                 = 0x0000000038000000;
const uint64_t SRAM_BASE                = 0x0000000007F00000 + MEM_BASE; // SRAM overlays top 1 MB of DRAM

const uint32_t REG_PCIE                 = 0;
const uint32_t REG_PCIE_CONFIG          = 1;
const uint32_t REG_DMA_RD               = 2;
const uint32_t REG_DMA_WR               = 3;

const uint32_t REG_PCIE_CONTROL         = 0x0;
const uint32_t REG_PCIE_STATUS          = 0x1;
const uint32_t REG_PCIE_INT_FLAGS       = 0x2;
const uint32_t REG_PCIE_INT_SELECT      = 0x3;
const uint32_t REG_PCIE_OBINT_FORCE     = 0x4;
const uint32_t REG_PCIE_OBINT_FLAGS     = 0x5;
const uint32_t REG_PCIE_OBINT_SELECT    = 0x6;
const uint32_t REG_PCIE_OBINT_ACK       = 0x7;

const uint32_t REG_DMA_CONTROL          = 0x0;
const uint32_t REG_DMA_STATUS           = 0x1;
const uint32_t REG_DMA_INT_FLAGS        = 0x2;
const uint32_t REG_DMA_INT_SELECT       = 0x3;
const uint32_t REG_DMA_COUNTS           = 0x4;
const uint32_t REG_DMA_TRIG_IN          = 0x8;
const uint32_t REG_DMA_TRIG_OUT         = 0x9;
const uint32_t REG_DMA_TRIG_IN_ACK      = 0xA;
const uint32_t REG_DMA_TRIG_OUT_ACK     = 0xB;
const uint32_t REG_DMA_FRD_LO           = 0xC;
const uint32_t REG_DMA_FRD_HI           = 0xD;
const uint32_t REG_DMA_FWR_LO           = 0xE;
const uint32_t REG_DMA_FWR_HI           = 0xF;

SP_CTOR_IMP(__MODULE__) :
    sys_clk("sys_clk",10,SC_NS),
    clk("clk",10,SC_NS),
    px_clk("px_clk",12,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/

    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SP_CELL(pcie,dlsc_pcie_s6_model);
        /*AUTOINST*/

    SP_CELL(mig,dlsc_sp605_mig_model);
        /*AUTOINST*/
        SP_PIN(mig,c3_s0_axi_aclk,clk);
        SP_PIN(mig,c3_s1_axi_aclk,clk);
        SP_PIN(mig,c3_s2_axi_aclk,clk);
        SP_PIN(mig,c3_s3_axi_aclk,clk);
    
    memory_host     = new dlsc_tlm_memory<uint32_t>("memory_host",8ull*1024*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(20,SC_NS)); // 8 GB
    pcie->initiator_socket.bind(memory_host->socket);
    
    memory_mig      = new dlsc_tlm_memory<uint32_t>("memory_mig" ,128*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(20,SC_NS)); // 128 MB
    mig->socket.bind(memory_mig->socket);
    
    memtest         = new dlsc_tlm_memtest<uint32_t>("memtest",16);
    memtest->socket.bind(pcie->target_socket);

    initiator       = new dlsc_tlm_initiator_nb<uint32_t>("initiator",128);
    initiator->socket.bind(pcie->target_socket);

    pcie->set_bar(0,true,0x000FFFFF,REG_BASE,true); //   1 MB
    pcie->set_bar(2,true,0x07FFFFFF,MEM_BASE,true); // 128 MB

    rst             = 1;
    px_rst          = 1;
    sys_reset       = 1;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::dma_desc_serialize(const std::deque<dma_desc> &desc_queue, std::deque<uint32_t> &data) {

    for(std::deque<dma_desc>::const_iterator it = desc_queue.begin(); it != desc_queue.end(); it++) {
        dma_desc desc = (*it);

        uint32_t len = desc.len << 2;

        if( (desc.addr >> 32) != 0 || dlsc_rand_bool(20)) {
            len |= 0x1; // 64-bit address present
        }
        if(desc.trig_in || desc.trig_out || dlsc_rand_bool(20)) {
            len |= 0x2; // trigger field present
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

int __MODULE__::dma_check(dma_op op) {
    std::deque<dma_desc> src_descs  = op->srcq;
    std::deque<dma_desc> dest_descs = op->destq;
    dlsc_tlm_memory<uint32_t> *rd_memory = op->dir_wr ? memory_mig  : memory_host;
    dlsc_tlm_memory<uint32_t> *wr_memory = op->dir_wr ? memory_host : memory_mig;

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

    int total_length = data_src.size();

    dma_desc src, dest;

    src     = src_descs.front(); src_descs.pop_front();
    dest    = dest_descs.front(); dest_descs.pop_front();

    int srci = 1, desti = 1;

    while(true) {

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

        if(data_src.empty()) break;
        
        src.len     -= 1;
        src.addr    += 4;
        if(src.len == 0) {
            assert(!src_descs.empty());
            src         = src_descs.front();
            src_descs.pop_front();
            srci++;
        }

        dest.len    -= 1;
        dest.addr   += 4;
        if(dest.len == 0) {
            assert(!dest_descs.empty());
            dest        = dest_descs.front();
            dest_descs.pop_front();
            desti++;
        }
    }

    return total_length;
}

void __MODULE__::dma_run(dma_op op) {

    std::deque<uint32_t> data;
    uint64_t addr;

    sc_core::sc_time elapsed = sc_core::sc_time_stamp();

    dlsc_info("setting up DMA" << (op->dir_wr?" to host" : " from host"));

    // source commands
    data.clear();
    dma_desc_serialize(op->srcq,data);
    op->src_cmd_len     = data.size();
#ifdef LOCAL_DMA_DESC
    addr                = dlsc_rand_u32(0x00000,0x0F000) & 0xFFF00;
    op->src_cmd_addr    = addr;
    while(data.size() > 16) {
        initiator->nb_write(MEM_BASE+addr,data.begin(),data.begin()+16);
        data.erase(data.begin(),data.begin()+16);
        addr+=(16*4);
    }
    initiator->nb_write(MEM_BASE+addr,data);
#else
    addr                = dlsc_rand_u64(0,8ull*1024*1024*1024 - 0x10000) & ~0xFFull;
    op->src_cmd_addr    = addr;
    memory_host->nb_write(addr,data);
#endif

    // destination commands
    data.clear();
    op->destq.back().trig_out = 0x1;
    dma_desc_serialize(op->destq,data);
    op->dest_cmd_len    = data.size();
#ifdef LOCAL_DMA_DESC
    addr                = dlsc_rand_u32(0x10000,0x1F000) & 0xFFF00;
    op->dest_cmd_addr   = addr;
    while(data.size() > 16) {
        initiator->nb_write(MEM_BASE+addr,data.begin(),data.begin()+16);
        data.erase(data.begin(),data.begin()+16);
        addr+=(16*4);
    }
    initiator->nb_write(MEM_BASE+addr,data);
#else
    addr                = dlsc_rand_u64(0,8ull*1024*1024*1024 - 0x10000) & ~0xFFull;
    op->dest_cmd_addr   = addr;
    memory_host->nb_write(addr,data);
#endif

    uint32_t dev = op->dir_wr ? REG_DMA_WR : REG_DMA_RD;

    dlsc_info("starting DMA");

    // setup completion interrupt
    reg_write(dev,REG_DMA_INT_SELECT    ,0x80000001 ,true);         // select trig_out[0] (and error)
    reg_write(REG_PCIE,REG_PCIE_OBINT_SELECT,0xFFFFFFFF,true);

    // write commands (starts DMA operation)
    reg_write(dev,REG_DMA_FRD_LO        ,op->src_cmd_addr&0xFFFFFFFF,true);
    reg_write(dev,REG_DMA_FRD_HI        ,op->src_cmd_addr>>32,true);
    reg_write(dev,REG_DMA_FWR_LO        ,op->dest_cmd_addr&0xFFFFFFFF,true);
    reg_write(dev,REG_DMA_FWR_HI        ,op->dest_cmd_addr>>32,true);

    // wait for interrupt
    while(pcie->get_interrupt(0) == false) {
        wait(1,SC_US);
    }
    
    // cleanup
    reg_write(dev,REG_DMA_TRIG_OUT_ACK  ,0x0000FFFF ,true);         // acknowledge any pending triggers

    elapsed = sc_core::sc_time_stamp() - elapsed;

    dlsc_info("DMA done");

    wait(10,SC_US);

    int bytes = dma_check(op) * 4;
    double mbps = (bytes*1.0) / (elapsed.to_seconds()*1000000.0);
    dlsc_info("..transferred " << bytes << " bytes in " << elapsed << " (throughput: " << mbps << " MB/s)");
}

void __MODULE__::reg_write(uint32_t device, uint32_t addr, uint32_t data, bool nb) {
    uint64_t addr64 = REG_BASE + (device*0x1000) + (addr<<2);
    if(nb) {
        initiator->nb_write(addr64,&data,(&data)+1);
    } else {
        initiator->b_write(addr64,data);
    }
    dlsc_info("wrote 0x" << std::hex << addr64 << " : 0x" << data);
}

uint32_t __MODULE__::reg_read(uint32_t device, uint32_t addr) {
    uint64_t addr64 = REG_BASE + (device*0x1000) + (addr<<2);
    uint32_t data = initiator->b_read(addr64);
    dlsc_info("read 0x" << std::hex << addr64 << " : 0x" << data);
    return data;
}

void __MODULE__::stim_thread() { 
    int i,j;
    transaction ts, tswait;
    std::deque<uint32_t> data;
    std::deque<uint32_t> strb;

    wait(1,SC_US);
    wait(sys_clk.posedge_event());
    sys_reset       = 0;
    wait(clk.posedge_event());
    rst             = 0;
    wait(px_clk.posedge_event());
    px_rst          = 0;
    wait(1,SC_US);

    dlsc_info("testing config space");
    for(i=0;i<25;++i) {
        uint32_t r = dlsc_rand_u32(0,0x400);
        uint32_t d = reg_read(REG_PCIE_CONFIG,r);
        dlsc_assert_equals(r,d);
    }
    
    // test DRAM
    dlsc_info("testing DRAM");
    memory_mig->set_error_rate_read(1.0);
    memtest->set_ignore_error_read(true);
    memtest->set_max_outstanding(16);   // more MOT for improved performance
    memtest->set_strobe_rate(1);        // sparse strobes are very slow over PCIe
    memtest->test(MEM_BASE,4*4096,1*1000*10);

    // test SRAM
    dlsc_info("testing SRAM");
    memtest->set_ignore_error(false);
    memtest->test(SRAM_BASE,SRAM_SIZE/4,1*1000*10);
    
    // provide background traffic during DMA test
    memory_mig->set_error_rate_read(0.0);
    memtest->set_max_outstanding(8);
    memtest->test(MEM_BASE+64ull*1024*1024,1*4096,1*1000*5,true);
    wait(100,SC_US);

    dma_op op;
    dma_desc desc;

    // DMA read (host -> mig)
    op          = dma_op(new dma_op_type);
    op->dir_wr  = false;
    desc.len    = 1024;
    for(i=0;i<64;++i) {
        desc.addr   = dlsc_rand_u64(0,8ull*1024*1024*1024 - (desc.len*4)) & ~0x3ull;
        op->srcq.push_back(desc);
        desc.addr   = dlsc_rand_u64(0x20000,64ull*1024*1024 - (desc.len*4)) & ~0x3ull;
        op->destq.push_back(desc);
    }
    dma_run(op);
    
    // DMA write (mig -> host)
    op          = dma_op(new dma_op_type);
    op->dir_wr  = true;
    desc.len    = 1024;
    for(i=0;i<64;++i) {
        desc.addr   = dlsc_rand_u64(0,8ull*1024*1024*1024 - (desc.len*4)) & ~0x3ull;
        op->destq.push_back(desc);
        desc.addr   = dlsc_rand_u64(0x20000,64ull*1024*1024 - (desc.len*4)) & ~0x3ull;
        op->srcq.push_back(desc);
    }
    dma_run(op);

    memtest->wait();

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(10,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/

