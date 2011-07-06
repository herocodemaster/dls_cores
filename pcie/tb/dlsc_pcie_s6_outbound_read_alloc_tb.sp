//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define ADDR            PARAM_ADDR
#define TAG             PARAM_TAG
#define BUFA            PARAM_BUFA
#define CPLH            PARAM_CPLH
#define CPLD            PARAM_CPLD

#define TAGS            (1<<TAG)
#define BUF_SIZE        (1<<BUFA)

struct alloc_type {
    uint32_t        tag;
    uint32_t        len;
    uint32_t        addr;
    uint32_t        bufa;
};

struct tlph_type {
    uint64_t        addr;
    uint32_t        len;
    uint32_t        tag;
    uint32_t        bufa;
    unsigned int    cplh;
    unsigned int    cpld;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock                clk;

    void                    stim_thread();
    void                    watchdog_thread();

    void                    send_tlp();

    void                    clk_method();

    std::deque<alloc_type>  alloc_queue;
    std::deque<tlph_type>   tlph_queue;
    std::deque<tlph_type>   rd_tlph_queue;

    unsigned int            alloc_init_next;

    unsigned int            rd_tlp_h_cnt;

    uint32_t                tag_next;
    uint32_t                bufa_next;

    unsigned int            dealloc_cplh_cnt;
    unsigned int            dealloc_cpld_cnt;
    unsigned int            dealloc_tag_cnt;
    unsigned int            dealloc_data_cnt;

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

SP_CTOR_IMP(__MODULE__) : clk("clk",16,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst         = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::send_tlp() {

    // random length
    int len;

    switch(rand()%10) {
        case 0:     len = 1; break;
        case 1:     len = 1024; break;
        default:    len = (rand()%1024) + 1;
    }

    unsigned int rcb_bytes = rcb ? 128 : 64;

    if(len > BUF_SIZE) len = BUF_SIZE;
    if(len > (int)((rcb_bytes/4)*CPLH)) len = ((rcb_bytes/4)*CPLH);
    if(len > (4*CPLD)) len = (4*CPLD);

    // random address
    uint64_t addr = rand();
    addr *= 4;

    // prevent 4k crossings
    int boundary = ((addr & 0xFFF) + (len*4)) - 4096;
    if(boundary > 0) {
        addr -= boundary;
    }

    addr &= (((uint64_t)1)<<ADDR)-1;

    unsigned int cplh;
    unsigned int cpld;
        
    // hack..
    while(true) {
        // from Xilinx UG654
        cplh = ((addr % rcb_bytes) + (len*4) + (rcb_bytes-1)) / rcb_bytes;
        cpld = ((addr % 16       ) + (len*4) + 15           ) / 16;
        if(cplh <= CPLH && cpld <= CPLD) break;
        len--;
    }

    assert(len > 0 && len <= BUF_SIZE);
    assert(cplh > 0 && cpld > 0);
    assert(cplh <= CPLH && cpld <= CPLD);

    tlph_type tlp;
    tlp.addr        = addr>>2;
    tlp.len         = len & 0x3FF;
    tlp.tag         = tag_next;
    tlp.cplh        = cplh;
    tlp.cpld        = cpld;
    tlp.bufa        = bufa_next;

    tlph_queue.push_back(tlp);

    tag_next        = (tag_next + 1) & ((2<<TAG)-1);
    bufa_next       = (bufa_next + len) & ((1<<BUFA)-1);
}


void __MODULE__::clk_method() {
    if(rst) {
        // signals
        dealloc_cplh        = 0;
        dealloc_cpld        = 0;
        dealloc_tag         = 0;
        dealloc_data        = 0;
        tlp_h_valid         = 0;
        tlp_h_addr          = 0;
        tlp_h_len           = 0;
        rd_tlp_h_ready      = 0;
        // variables
        alloc_init_next     = 0;
        rd_tlp_h_cnt        = 0;
        tag_next            = 0;
        bufa_next           = 0;
        dealloc_cplh_cnt    = 0;
        dealloc_cpld_cnt    = 0;
        dealloc_tag_cnt     = 0;
        dealloc_data_cnt    = 0;
        // queues
        alloc_queue.clear();
        tlph_queue.clear();
        rd_tlph_queue.clear();
        return;
    }

    if(!dma_en || alloc_init) {
        dlsc_assert_equals(tlp_pending,0);
        dlsc_assert_equals(rd_tlp_h_cnt,0);
    }

    if(alloc_init && alloc_valid) {
        dlsc_assert(alloc_tag <= alloc_init_next);
        if(alloc_tag == alloc_init_next) {
            ++alloc_init_next;
        }
        if(rd_tlp_h_valid) {
            dlsc_error("shouldn't produce TLP during init");
        }
    }

    if(!alloc_init && alloc_valid) {
        if(alloc_init_next != (2<<TAG)) {
            dlsc_error("didn't initialize all tags");
            alloc_init_next = (2<<TAG);
        }
    }

    if(!tlp_h_valid || tlp_h_ready) {
        if(!tlph_queue.empty() && (rand()%100) < 75) {
            tlph_type tlp = tlph_queue.front(); tlph_queue.pop_front();

            tlp_h_valid     = 1;
            tlp_h_addr      = tlp.addr;
            tlp_h_len       = tlp.len;
            
            alloc_type alc;
            alc.tag         = tlp.tag;
            alc.len         = tlp.len;
            alc.addr        = tlp.addr & 0x1F;
            alc.bufa        = tlp.bufa;
            alloc_queue.push_back(alc);

            tlp.tag         &= ((1<<TAG)-1);
            rd_tlph_queue.push_back(tlp);
        } else {
            tlp_h_valid     = 0;
            tlp_h_addr      = 0;
            tlp_h_len       = 0;
        }
    }

    if(alloc_valid && !alloc_init) {
        if(alloc_queue.empty()) {
            dlsc_error("unexpected alloc");
        } else {
            alloc_type alc = alloc_queue.front(); alloc_queue.pop_front();
            dlsc_assert_equals(alloc_tag,alc.tag);
            dlsc_assert_equals(alloc_len,alc.len);
            dlsc_assert_equals(alloc_addr,alc.addr);
            dlsc_assert_equals(alloc_bufa,alc.bufa);
        }
    }

    dealloc_cplh    = 0;
    dealloc_cpld    = 0;
    dealloc_tag     = 0;
    dealloc_data    = 0;

    if(dealloc_cplh_cnt > 0 && (rand()%100) == 0) {
        dealloc_cplh    = 1;
        --dealloc_cplh_cnt;
    }
    if(dealloc_cpld_cnt > 0 && (rand()%5) == 0) {
        dealloc_cpld    = 1;
        --dealloc_cpld_cnt;
    }
    if(dealloc_tag_cnt > 0 && (rand()%1000) == 0) {
        dealloc_tag     = 1;
        --dealloc_tag_cnt;
    }
    if(dealloc_data_cnt > 0 && (rand()%100) < 80) {
        dealloc_data    = 1;
        --dealloc_data_cnt;
    }

    if(rd_tlp_h_ready && rd_tlp_h_valid) {
        ++rd_tlp_h_cnt;
        if(rd_tlph_queue.empty()) {
            dlsc_error("unexpected rd_tlp_h");
        } else {
            tlph_type tlp = rd_tlph_queue.front(); rd_tlph_queue.pop_front();
            dlsc_assert_equals(rd_tlp_h_addr,tlp.addr);
            dlsc_assert_equals(rd_tlp_h_len,tlp.len);
            dlsc_assert_equals(rd_tlp_h_tag,tlp.tag);
            dealloc_cplh_cnt    += tlp.cplh;
            dealloc_cpld_cnt    += tlp.cpld;
            dealloc_tag_cnt     += 1;
            dealloc_data_cnt    += (tlp.len == 0) ? 1024 : tlp.len;
        }
    }

    rd_tlp_h_ready      = (rand()%100) < 65;
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);

    for(int i=0;i<20;++i) {
        dlsc_info("iteration " << std::dec << i);
        wait(clk.posedge_event());
        dma_en  = 0;
        rst     = 1;
        rcb     = i%2;
        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());

        for(int j=0;j<100;++j) {
            send_tlp();
        }

        wait(1,SC_US);
        dlsc_assert_equals(rd_tlp_h_cnt,0);
        wait(clk.posedge_event());
        dma_en  = 1;

        while(!( alloc_queue.empty() && tlph_queue.empty() && rd_tlph_queue.empty() &&
                !dealloc_cplh_cnt && !dealloc_cpld_cnt && !dealloc_tag_cnt && !dealloc_data_cnt )) {
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



