//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include "dlsc_tlm_initiator_nb.h"

#include <deque>

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

struct in_state {
    uint32_t data;
    sc_time last_change;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();
    void stim_thread();
    void watchdog_thread();
    
    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

    in_state ins[PARAM_CHANNELS];

    int timebases_cnt;

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
    clk("clk",10,SC_NS)
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/
    
    SP_CELL(csr_master,dlsc_csr_tlm_master_32b);
        /*AUTOINST*/
    
    csr_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("csr_initiator",1);
    csr_initiator->socket.bind(csr_master->socket);

    rst         = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

const uint32_t REG_CORE_MAGIC      = 0x0;
const uint32_t REG_CORE_VERSION    = 0x1;
const uint32_t REG_CORE_INTERFACE  = 0x2;
const uint32_t REG_CORE_INSTANCE   = 0x3;

const uint32_t REG_TIMEBASE        = 0x4;
const uint32_t REG_BYPASS          = 0x5;
const uint32_t REG_DELAY_TARGET    = 0x6;
const uint32_t REG_DELAY_CURRENT   = 0x7;

void __MODULE__::reg_write(uint32_t addr, uint32_t data) {
    csr_initiator->b_write(addr<<2,data);
    dlsc_verb("wrote 0x" << std::hex << addr << " : 0x" << data);
}

uint32_t __MODULE__::reg_read(uint32_t addr) {
    uint32_t data = csr_initiator->b_read(addr<<2);
    dlsc_verb("read 0x" << std::hex << addr << " : 0x" << data);
    return data;
}

void __MODULE__::clk_method() {
    if(rst) {
        in_data = 0;
        for(int i=0;i<PARAM_CHANNELS;i++) {
            ins[i].data = 0;
            ins[i].last_change = sc_core::SC_ZERO_TIME;
        }
        timebases_cnt = -100;
        return;
    }

    for(int i=0;i<PARAM_CHANNELS;i++) {
        if(dlsc_rand_bool(1.0)) {
            ins[i].data = (ins[i].data + 1 + i) & ((1u<<PARAM_DATA)-1u);
        }
    }

#if ((PARAM_CHANNELS*PARAM_DATA)<=64)
    uint64_t data = 0;
    for(int i=0;i<PARAM_CHANNELS;i++) {
        data |= ins[i].data << (i*PARAM_DATA);
    }
    in_data.write(data);
#else
    // TODO
    assert(0);
#endif

    if(timebases_cnt >= 0) {
        uint32_t next_timebase_en = 0;
        int mod = 1;
        for(int i=0;i<PARAM_TIMEBASES;i++) {
            if( (timebases_cnt % mod) == 0 ) {
                next_timebase_en |= (1u<<i);
            }
            mod *= 10;
        }
        timebase_en.write(next_timebase_en);
    }
    timebases_cnt++;
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst     = 0;
    wait(1,SC_US);

    reg_write(REG_TIMEBASE,1);//dlsc_rand_u32(0,PARAM_TIMEBASES-1));
    reg_write(REG_BYPASS,0);

    for(int i=0;i<100;i++) {
        reg_write(REG_DELAY_TARGET,dlsc_rand_u32(0,PARAM_DELAY-1));
        wait(100,SC_US);
    }

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    for(int i=0;i<100;i++) {
        wait(1,SC_MS);
        dlsc_info(".");
    }

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/

