//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include "dlsc_tlm_initiator_nb.h"

// for syntax highlighter: SC_MODULE

/*AUTOSUBCELL_CLASS*/

#define OUTPUTS 8

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();
    void stim_thread();
    void watchdog_thread();
    
    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

    uint64_t counts[OUTPUTS];

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
    clk("clk",1000000000.0/PARAM_FREQ_IN,SC_NS)
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

void __MODULE__::reg_write(uint32_t addr, uint32_t data) {
    csr_initiator->b_write(addr<<2,data);
    dlsc_verb("wrote 0x" << std::hex << addr << " : 0x" << data);
}

uint32_t __MODULE__::reg_read(uint32_t addr) {
    uint32_t data = csr_initiator->b_read(addr<<2);
    dlsc_verb("read 0x" << std::hex << addr << " : 0x" << data);
    return data;
}

const uint32_t REG_CONTROL      = 0;
const uint32_t REG_FREQUENCY    = 1;
const uint32_t REG_COUNTER_LOW  = 4;
const uint32_t REG_COUNTER_HIGH = 5;
const uint32_t REG_ADJUST_LOW   = 6;
const uint32_t REG_ADJUST_HIGH  = 7;

void __MODULE__::clk_method() {
    if(rst) {
        for(int i=0;i<OUTPUTS;++i) {
            counts[i] = 0;
        }
    } else {
        for(int i=0;i<OUTPUTS;++i) {
            if(clk_en_out.read() & (1u << i)) {
                counts[i]++;
            }
        }
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst     = 0;
    wait(1,SC_US);

    reg_write(REG_CONTROL,0x1);
    
    wait(clk_en_out.value_changed_event());

    uint64_t cnt_val, cnt_val_prev;

    cnt_val = reg_read(REG_COUNTER_LOW);
    cnt_val_prev = cnt.read();
    cnt_val |= (uint64_t)reg_read(REG_COUNTER_HIGH) << 32;
    dlsc_info("count value: " << cnt_val);

    dlsc_assert_equals(cnt_val,cnt_val_prev);
    cnt_val_prev = cnt_val;
    
    uint64_t adj_val = 10000000000;

    reg_write(REG_ADJUST_LOW,(uint32_t)adj_val);
    reg_write(REG_ADJUST_HIGH,(uint32_t)(adj_val>>32));

    wait(100,SC_NS);

    cnt_val = reg_read(REG_COUNTER_LOW);
    cnt_val |= (uint64_t)reg_read(REG_COUNTER_HIGH) << 32;
    dlsc_info("count value: " << cnt_val);

    wait(100,SC_US);
    reg_write(REG_CONTROL,0x0);
    reg_write(REG_CONTROL,0x1);

    reg_write(REG_FREQUENCY,PARAM_FREQ_IN*2);
    wait(5,SC_MS);

    wait(100,SC_US);
    rst     = 1;
    wait(clk.posedge_event());
    rst     = 0;

    reg_write(REG_CONTROL,0x1);

    wait(clk_en_out.value_changed_event());
    wait(10,SC_MS);
    wait(50,SC_NS);

    dlsc_assert_equals(counts[0],1+(PARAM_CNT_RATE/(PARAM_DIV0*100)));
    dlsc_assert_equals(counts[1],1+(PARAM_CNT_RATE/(PARAM_DIV1*100)));
    dlsc_assert_equals(counts[2],1+(PARAM_CNT_RATE/(PARAM_DIV2*100)));
    dlsc_assert_equals(counts[3],1+(PARAM_CNT_RATE/(PARAM_DIV3*100)));
    dlsc_assert_equals(counts[4],1+(PARAM_CNT_RATE/(PARAM_DIV4*100)));
    dlsc_assert_equals(counts[5],1+(PARAM_CNT_RATE/(PARAM_DIV5*100)));
    dlsc_assert_equals(counts[6],1+(PARAM_CNT_RATE/(PARAM_DIV6*100)));
    dlsc_assert_equals(counts[7],1+(PARAM_CNT_RATE/(PARAM_DIV7*100)));

    wait(1,SC_MS);

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

