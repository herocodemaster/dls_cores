//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define ADDR            PARAM_ADDR
#define LEN             PARAM_LEN
#define MAX_SIZE        PARAM_MAX_SIZE

struct check_type {
    uint64_t    addr;
    uint32_t    len;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void send_stim();

    void stim_method();
    void check_method();

    std::deque<check_type>  stim_queue;
    std::deque<uint64_t>    check_queue;

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
        axi_ar_valid    = 0;
        axi_ar_addr     = 0;
        axi_ar_len      = 0;
        stim_queue.clear();
    }

    if(!axi_ar_valid || axi_ar_ready) {
        if(!stim_queue.empty() && (rand()%100) < 95) {

            check_type chk = stim_queue.front(); stim_queue.pop_front();

            assert( chk.len < (1<<LEN) );
            assert( ((chk.addr & 0xFFF) + ((chk.len+1)*4)) <= 4096 );

            axi_ar_valid    = 1;
            axi_ar_addr     = chk.addr>>2;
            axi_ar_len      = chk.len;

            for(unsigned int i=0;i<=chk.len;i++,chk.addr+=4) {
                check_queue.push_back(chk.addr);
            }

        } else {
            axi_ar_valid    = 0;
            axi_ar_addr     = 0;
            axi_ar_len      = 0;
        }
    }
}

void __MODULE__::check_method() {
    if(rst) {
        tlp_h_ready     = 0;
        check_queue.clear();
    }

    if(tlp_h_ready && tlp_h_valid) {
        uint32_t max_len    = (32 << max_read_request.read());
        if(max_len > (MAX_SIZE/4)) max_len = (MAX_SIZE/4);

        uint32_t len        = tlp_h_len.read();
        
        if(len == 0) len = 1024;

        dlsc_assert(len <= max_len);

        uint64_t addr       = tlp_h_addr.read() * 4;

        if( ((addr & 0xFFF) + (len*4)) > 4096 ) {
            dlsc_error("crossed 4K boundary (addr = 0x" << std::hex << addr << ", len = " << std::dec << (len*4) << ")");
        }

        for(unsigned int i=0;i<len;++i,addr+=4) {
            if(check_queue.empty()) {
                dlsc_error("unexpected addr: 0x" << std::hex << addr);
                continue;
            }
            dlsc_assert_equals(check_queue.front(),addr);
            check_queue.pop_front();
        }

    }

    tlp_h_ready     = (rand()%100) < 95;
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
    check_type chk;
    while(len > 0) {
        chk.addr    = addr;
        chk.len     = rand()%((1<<LEN)-1);

        if(chk.len >= (unsigned int)len) {
            chk.len     = len-1;
        }

        stim_queue.push_back(chk);

        addr        += (chk.len+1)*4;
        len         -= (chk.len+1);
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);

    int mrr = 0;
    for(int i=128;i<=4096;i*=2,++mrr) {
        dlsc_info("testing max_read_request = " << std::dec << i);

        wait(clk.posedge_event());
        rst     = 1;
        max_read_request = mrr;
        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());

        for(int j=0;j<1000;++j) {
            send_stim();
        }

        while(!stim_queue.empty() || !check_queue.empty()) {
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



