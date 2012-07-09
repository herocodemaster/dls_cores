//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include "dlsc_tlm_initiator_nb.h"

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void pulse_thread();
    void clk_method();
    void stim_thread();
    void watchdog_thread();
    
    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

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

    SC_THREAD(pulse_thread);

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

const uint32_t REG_CORE_MAGIC       = 0x0;
const uint32_t REG_CORE_VERSION     = 0x1;
const uint32_t REG_CORE_INTERFACE   = 0x2;
const uint32_t REG_CORE_INSTANCE    = 0x3;

const uint32_t REG_CONTROL          = 0x4;
const uint32_t REG_TIMEBASE         = 0x5;
const uint32_t REG_DELAY            = 0x6;
const uint32_t REG_ACTIVE           = 0x7;

void __MODULE__::reg_write(uint32_t addr, uint32_t data) {
    csr_initiator->b_write(addr<<2,data);
    dlsc_verb("wrote 0x" << std::hex << addr << " : 0x" << data);
}

uint32_t __MODULE__::reg_read(uint32_t addr) {
    uint32_t data = csr_initiator->b_read(addr<<2);
    dlsc_verb("read 0x" << std::hex << addr << " : 0x" << data);
    return data;
}

void __MODULE__::pulse_thread() {
    in_pulse    = 0;

    int glitchcnt[PARAM_CHANNELS]   = {0};
    int glitchdelay[PARAM_CHANNELS] = {0};
    
    while(1) {
        wait(dlsc_rand(10,100),SC_NS);
        uint32_t in_next = in_pulse.read();
        for(int i=0;i<PARAM_CHANNELS;i++) {
            if(glitchcnt[i] > 0) {
                if(dlsc_rand_bool(20.0)) {
                    glitchcnt[i]--;
                    in_next ^= (1u<<i);
                }
            } else if(glitchdelay[i] <= 0) {
                glitchcnt[i]    = dlsc_rand(0,5)*2 + 1;    // odd number so it always winds up inverted
                glitchdelay[i]  = dlsc_rand(2000,20000);
            } else {
                glitchdelay[i]--;
            }
        }
        in_pulse.write(in_next);
    }
}

void __MODULE__::clk_method() {
    if(rst) {
        timebase_en     = 0;
        timebases_cnt   = -100;
        return;
    }

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

    // 1us for counters; 100ns for filters
    reg_write(REG_TIMEBASE,     2 | (1 << 16));

    reg_write(REG_DELAY,        50);
    reg_write(REG_ACTIVE,       100);
    
    // rising-edge
    reg_write(REG_CONTROL,      (1u<<2));
    
    wait(5,SC_MS);
    
    reg_write(REG_DELAY,        100);
    reg_write(REG_ACTIVE,       500);
    
    wait(5,SC_MS);
    
    // falling-edge
    reg_write(REG_CONTROL,      (1u<<3));
    
    wait(5,SC_MS);
    
    reg_write(REG_DELAY,        10);
    reg_write(REG_ACTIVE,       20);
    
    wait(5,SC_MS);

    // both edges
    reg_write(REG_CONTROL,      (1u<<2)|(1u<<3));
    
    wait(5,SC_MS);
    
    reg_write(REG_DELAY,         0);
    reg_write(REG_ACTIVE,       10);
    
    wait(5,SC_MS);
    
    // 10us for counters; 100ns for filters
    reg_write(REG_TIMEBASE,     3 | (1 << 16));
    
    wait(5,SC_MS);

    // both edges, invert
    reg_write(REG_CONTROL,      (1u<<1)|(1u<<2)|(1u<<3));
    
    wait(5,SC_MS);

    // bypass
    reg_write(REG_CONTROL,      (1u<<0));
    
    wait(5,SC_MS);

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

