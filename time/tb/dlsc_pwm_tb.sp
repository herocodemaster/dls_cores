//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include "dlsc_tlm_initiator_nb.h"

#include <deque>

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

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

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

const uint32_t REG_CORE_MAGIC       = 0x00;
const uint32_t REG_CORE_VERSION     = 0x01;
const uint32_t REG_CORE_INTERFACE   = 0x02;
const uint32_t REG_CORE_INSTANCE    = 0x03;

const uint32_t REG_CONTROL          = 0x04;
const uint32_t REG_FORCE            = 0x05;
const uint32_t REG_TIMEBASE         = 0x06;
const uint32_t REG_TRIGGER          = 0x07;
const uint32_t REG_CHANNEL_ENABLE   = 0x08;
const uint32_t REG_CHANNEL_INVERT   = 0x09;
const uint32_t REG_CYCLES_PER_SHOT  = 0x0A;
const uint32_t REG_SHOT_DELAY       = 0x0B;
const uint32_t REG_PERIOD           = 0x0C;
const uint32_t REG_INT_FLAGS        = 0x10;
const uint32_t REG_INT_SELECT       = 0x11;
const uint32_t REG_CHANNEL_FLAGS    = 0x12;
const uint32_t REG_CHANNEL_SELECT   = 0x13;
const uint32_t REG_CHANNEL_STATE    = 0x14;
const uint32_t REG_STATUS           = 0x15;
const uint32_t REG_COUNT            = 0x16;
const uint32_t REG_CYCLE            = 0x17;
const uint32_t REG_COMPARE_A        = 0x20;
const uint32_t REG_COMPARE_B        = 0x30;

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
        timebase_en     = 0;
//      trigger         = 0;
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
    trigger = 0;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst     = 0;
    wait(1,SC_US);

    uint32_t cycles     = 2;
    uint32_t shot_delay = 50;
    uint32_t period     = 100;


    reg_write(REG_TIMEBASE,         2);             // 1us
    reg_write(REG_TRIGGER,          0 | (1u<<8));   // rising-edge
    reg_write(REG_CHANNEL_ENABLE,   0xFFFF);

    reg_write(REG_CYCLES_PER_SHOT,  cycles);
    reg_write(REG_SHOT_DELAY,       shot_delay);
    reg_write(REG_PERIOD,           period);

    reg_write(REG_INT_FLAGS,        0xFFFFFFFF);
    reg_write(REG_INT_SELECT,       0);
    reg_write(REG_CHANNEL_FLAGS,    0xFFFFFFFF);
    reg_write(REG_CHANNEL_SELECT,   0);

    uint32_t inv = 0;

    for(unsigned int j=0;j<PARAM_CHANNELS;j++ ) {
        if(dlsc_rand_bool(50.0)) {
            inv |= (1u<<j);
        }
        uint32_t cmpa = dlsc_rand_u32(0,period);
        uint32_t cmpb = dlsc_rand_u32(cmpa,period);
        reg_write(REG_COMPARE_A+j, cmpa);
        reg_write(REG_COMPARE_B+j, cmpb);
    }

    reg_write(REG_CHANNEL_INVERT,   inv);

    reg_write(REG_CONTROL,          0x3);

    for(int i=0;i<10;i++) {
        wait(dlsc_rand(100,1000)*1.0,SC_US);
        wait(clk.posedge_event());
        trigger = ((1u<<PARAM_TRIGGERS)-1u);
        wait(2,SC_US);
        wait(clk.posedge_event());
        trigger = 0;
    }
    
    reg_write(REG_TRIGGER,          0 | (1u<<8) | (1u<<10));    // active-high

    for(int i=0;i<10;i++) {
        wait(dlsc_rand(200,2000)*1.0,SC_US);
        wait(clk.posedge_event());
        trigger = trigger.read() ^ ((1u<<PARAM_TRIGGERS)-1u);
    }

    trigger = 0;
    
    reg_write(REG_CONTROL,          0x0);
    
    reg_write(REG_TRIGGER,          0 | (1u<<8));   // rising-edge

    reg_write(REG_CONTROL,          0x1);   // enable, free-running

    wait(100,SC_US);

    reg_write(REG_FORCE,            0x1);   // trigger

    wait(50,SC_US);

    // write new config
    
    cycles     = 1;
    shot_delay = 100;
    period     = 200;

    reg_write(REG_CYCLES_PER_SHOT,  cycles);
    reg_write(REG_SHOT_DELAY,       shot_delay);
    reg_write(REG_PERIOD,           period);

    for(unsigned int j=0;j<PARAM_CHANNELS;j++ ) {
        if(dlsc_rand_bool(50.0)) {
            inv |= (1u<<j);
        }
        uint32_t cmpa = dlsc_rand_u32(0,period);
        uint32_t cmpb = dlsc_rand_u32(cmpa,period);
        reg_write(REG_COMPARE_A+j, cmpa);
        reg_write(REG_COMPARE_B+j, cmpb);
    }

    wait(2,SC_MS);

    reg_write(REG_FORCE,            0x2);   // latch new config

    for(int i=0;i<10;i++) {
        wait(dlsc_rand(100,1000)*1.0,SC_US);
        wait(clk.posedge_event());
        trigger = ((1u<<PARAM_TRIGGERS)-1u);
        wait(2,SC_US);
        wait(clk.posedge_event());
        trigger = 0;
    }

    wait(100,SC_US);

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

