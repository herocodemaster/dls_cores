//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define ADDR            PARAM_ADDR
#define LEN             PARAM_LEN
#define MAX_SIZE        PARAM_MAX_SIZE

struct aw_type {
    uint64_t    addr;
    uint32_t    len;
    bool        strobed;
};

struct w_type {
    uint32_t    data;
    uint32_t    strb;
    bool        last;
};

struct tlp_h_type {
    uint64_t    addr;
    uint32_t    strb;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void send_stim();

    void stim_method();
    void check_method();

    std::deque<aw_type>     aw_queue;
    std::deque<w_type>      w_queue;
    int                     b_cnt;
    std::deque<tlp_h_type>  tlp_h_queue;
    std::deque<uint32_t>    tlp_d_queue;
    int                     d_cnt;

    int                     header_credits;
    int                     data_credits;

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

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    rst         = 1;

    SC_METHOD(stim_method);
        sensitive << clk.posedge_event();
    SC_METHOD(check_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::stim_method() {
    if(rst) {
        axi_aw_valid    = 0;
        axi_aw_addr     = 0;
        axi_aw_len      = 0;
        aw_queue.clear();
        axi_w_valid     = 0;
        axi_w_last      = 0;
        axi_w_strb      = 0;
        axi_w_data      = 0;
        w_queue.clear();
        axi_b_ready     = 0;
        b_cnt           = 0;
        header_credits  = 0;
        data_credits    = 0;
    }

    if(!axi_aw_valid || axi_aw_ready) {
        if(!aw_queue.empty() && (rand()%100) < 95) {

            aw_type awt = aw_queue.front(); aw_queue.pop_front();

            assert( awt.len < (1<<LEN) );
            assert( ((awt.addr & 0xFFF) + ((awt.len+1)*4)) <= 4096 );

            axi_aw_valid    = 1;
            axi_aw_addr     = awt.addr;
            axi_aw_len      = awt.len;

            w_type wt;
            tlp_h_type tht;
            tht.addr        = awt.addr;

            for(unsigned int i=0;i<=awt.len;i++,tht.addr+=4) {
                wt.data         = rand();
                wt.strb         = awt.strobed ? (rand() & 0xF) : 0xF;
                wt.last         = (i==awt.len);
                w_queue.push_back(wt);
                tht.strb        = wt.strb;
                tlp_h_queue.push_back(tht);
                tlp_d_queue.push_back(wt.data);
            }

        } else {
            axi_aw_valid    = 0;
            axi_aw_addr     = 0;
            axi_aw_len      = 0;
        }
    }

    if(!axi_w_valid || axi_w_ready) {
        if(!w_queue.empty() && (rand()%100) < 95) {
            w_type wt = w_queue.front(); w_queue.pop_front();

            axi_w_valid     = 1;
            axi_w_last      = wt.last;
            axi_w_data      = wt.data;
            axi_w_strb      = wt.strb;

            if(wt.last) {
                ++b_cnt;
            }

        } else {
            axi_w_valid     = 0;
            axi_w_last      = 0;
            axi_w_data      = 0;
            axi_w_strb      = 0;
        }
    }

    if(axi_b_ready && axi_b_valid) {
        if(!b_cnt) {
            dlsc_error("unexpected B");
        } else {
            --b_cnt;
        }
    }

    axi_b_ready         = (rand()%100) < 95;
}

void __MODULE__::check_method() {
    if(rst) {
        wr_tlp_h_ready  = 0;
        tlp_h_queue.clear();
        wr_tlp_d_ready  = 0;
        d_cnt           = 0;
        tlp_d_queue.clear();
    }

    if(wr_tlp_h_ready && wr_tlp_h_valid) {
        uint32_t max_len    = (32 << max_payload_size.read());
        uint32_t len        = wr_tlp_h_len.read();
        
        if(len == 0) len = 1024;

        dlsc_assert(len <= max_len);

        uint64_t addr       = wr_tlp_h_addr.read() * 4;

        if( ((addr & 0xFFF) + (len*4)) > 4096 ) {
            dlsc_error("crossed 4K boundary (addr = 0x" << std::hex << addr << ", len = " << std::dec << (len*4) << ")");
        }

        tlp_h_type tht;
        for(unsigned int i=0;i<len;++i,addr+=4) {
            if(tlp_h_queue.empty()) {
                dlsc_error("unexpected addr: 0x" << std::hex << addr);
                continue;
            }

            ++d_cnt;

            tht = tlp_h_queue.front(); tlp_h_queue.pop_front();
            
            dlsc_assert_equals(tht.addr,addr);

            if(i == 0) {
                dlsc_assert_equals(tht.strb,wr_tlp_h_be_first);
            } else if(i == (len-1)) {
                dlsc_assert_equals(tht.strb,wr_tlp_h_be_last);
            } else {
                dlsc_assert_equals(tht.strb,0xF);
            }
        }

        dlsc_assert(header_credits > 0);
        --header_credits;
    }

    wr_tlp_h_ready  = (rand()%100) < 95;

    if(wr_tlp_d_ready) {
        if(!wr_tlp_d_valid) {
            dlsc_error("tlp_d shouldn't throttle");
        } else {
            assert(d_cnt && !tlp_d_queue.empty());
            --d_cnt;
            dlsc_assert_equals(tlp_d_queue.front(),wr_tlp_d_data);
            tlp_d_queue.pop_front();

            dlsc_assert(data_credits > 0);
            --data_credits;
        }
    }

    wr_tlp_d_ready  = (d_cnt > 0) && (rand()%100) < 95;

    if(header_credits < 32 && (rand()%32) > header_credits) {
        header_credits++;
    }
    if(data_credits < 1024 && (rand()%1024) > data_credits) {
        data_credits++;
    }

    fc_ph   = header_credits;
    fc_pd   = data_credits/4;   // each fc_pd is 16 bytes (4 words)
}

void __MODULE__::send_stim() {

    // random length
    int len;

    switch(rand()%10) {
        case 0:     len = 1; break;
        case 1:     len = 1024; break;
        default:    len = (rand()%1024) + 1;
    }

    // random address
    uint64_t addr = rand();
    addr *= 4;
    addr &= (((uint64_t)1)<<ADDR)-1;

    // prevent 4k crossings
    int boundary = ((addr & 0xFFF) + (len*4)) - 4096;
    if(boundary > 0) {
        addr -= boundary;
    }

    // generate AXI requests
    aw_type awt;
    awt.strobed = (rand()%10) == 0;
    while(len > 0) {
        awt.addr    = addr;
        awt.len     = rand()%((1<<LEN)-1);

        if(awt.len >= (unsigned int)len) {
            awt.len     = len-1;
        }

        aw_queue.push_back(awt);

        addr        += (awt.len+1)*4;
        len         -= (awt.len+1);
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    dma_en  = 1;
    wait(100,SC_NS);

    int mps = 0;
    for(int i=128;i<=4096;i*=2,++mps) {
        dlsc_info("testing max_payload_size = " << std::dec << i);

        wait(clk.posedge_event());
        rst     = 1;
        max_payload_size = mps;
        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());

        for(int j=0;j<1000;++j) {
            send_stim();
        }

        while( !(aw_queue.empty() && w_queue.empty() && (b_cnt == 0) && tlp_h_queue.empty() && tlp_d_queue.empty()) ) {
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



