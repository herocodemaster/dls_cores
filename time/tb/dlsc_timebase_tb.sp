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
    void clkgen_thread();
    double clk_period_ns;

    void clk_method();
    void stim_thread();
    void watchdog_thread();
    
    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

    uint64_t counts[OUTPUTS];
    uint64_t cnt_prev;

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__)
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

    clk         = 0;
    rst         = 1;

    SC_THREAD(clkgen_thread);
    clk_period_ns = 10.0;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::clkgen_thread() {
    clk         = 0;
    while(1) {
        wait(clk_period_ns/2.0,SC_NS);
        clk         = !clk;
    }
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

const uint32_t REG_CORE_MAGIC      = 0x0;
const uint32_t REG_CORE_VERSION    = 0x1;
const uint32_t REG_CORE_INTERFACE  = 0x2;
const uint32_t REG_CORE_INSTANCE   = 0x3;

const uint32_t REG_CONTROL         = 0x4;
const uint32_t REG_PERIOD_IN       = 0x5;
const uint32_t REG_PERIOD_OUT      = 0x6;
const uint32_t REG_INT_FLAGS       = 0x7;
const uint32_t REG_INT_SELECT      = 0x8;
const uint32_t REG_COUNTER_LOW     = 0xC;
const uint32_t REG_COUNTER_HIGH    = 0xD;
const uint32_t REG_ADJUST_LOW      = 0xE;
const uint32_t REG_ADJUST_HIGH     = 0xF;

void __MODULE__::clk_method() {
    if(rst) {
        cnt_prev = 0;
        for(int i=0;i<OUTPUTS;++i) {
            counts[i] = 0;
        }
    } else {
        bool outputs[OUTPUTS];
        for(int i=0;i<OUTPUTS;++i) {
            outputs[i] = timebase_en.read() & (1u << i);
            if(outputs[i]) {
                counts[i]++;
            }
        }
        uint64_t cnt = timebase_cnt.read();
        if(!stopped) {
            dlsc_assert_equals( outputs[0] , (cnt % (PARAM_DIV0*100)) <= (cnt_prev % (PARAM_DIV0*100)) );
            dlsc_assert_equals( outputs[1] , (cnt % (PARAM_DIV1*100)) <= (cnt_prev % (PARAM_DIV1*100)) );
            dlsc_assert_equals( outputs[2] , (cnt % (PARAM_DIV2*100)) <= (cnt_prev % (PARAM_DIV2*100)) );
            dlsc_assert_equals( outputs[3] , (cnt % (PARAM_DIV3*100)) <= (cnt_prev % (PARAM_DIV3*100)) );
            dlsc_assert_equals( outputs[4] , (cnt % (PARAM_DIV4*100)) <= (cnt_prev % (PARAM_DIV4*100)) );
            dlsc_assert_equals( outputs[5] , (cnt % (PARAM_DIV5*100)) <= (cnt_prev % (PARAM_DIV5*100)) );
            dlsc_assert_equals( outputs[6] , (cnt % (PARAM_DIV6*100)) <= (cnt_prev % (PARAM_DIV6*100)) );
            dlsc_assert_equals( outputs[7] , (cnt % (PARAM_DIV7*100)) <= (cnt_prev % (PARAM_DIV7*100)) );
        }
        cnt_prev = cnt;
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst     = 0;
    wait(1,SC_US);

    reg_write(REG_CONTROL,0x1);
    
    wait(timebase_en.value_changed_event());

    uint64_t cnt_val, cnt_val_prev;
    double delta;

    cnt_val = reg_read(REG_COUNTER_LOW);
    cnt_val |= (uint64_t)reg_read(REG_COUNTER_HIGH) << 32;
    dlsc_info("count value: " << cnt_val);

    uint64_t adj_val = 1000000000000;

    reg_write(REG_ADJUST_LOW,(uint32_t)adj_val);
    reg_write(REG_ADJUST_HIGH,(uint32_t)(adj_val>>32));

    wait(100,SC_NS);

    cnt_val_prev = cnt_val;
    cnt_val = reg_read(REG_COUNTER_LOW);
    cnt_val |= (uint64_t)reg_read(REG_COUNTER_HIGH) << 32;
    dlsc_info("count value: " << cnt_val);
    
    delta = (double)cnt_val - (double)(cnt_val_prev + adj_val);
    if( std::abs(delta) > 500.0 ) {
        dlsc_error("count mismatch; delta: " << delta);
    } else {
        dlsc_okay("count okay");
    }

    wait(100,SC_US);
    reg_write(REG_CONTROL,0x0);
    
    wait(100,SC_US);
    clk_period_ns = 10.0;
    wait(clk.posedge_event());
    rst     = 1;
    wait(clk.posedge_event());
    rst     = 0;
    
    reg_write(REG_CONTROL,0x1);

    wait(timebase_en.value_changed_event());
    sc_time start = sc_core::sc_time_stamp();

    reg_write(REG_INT_FLAGS,0xFF);
    reg_write(REG_INT_SELECT,0x04);
        
    wait(100,SC_US);

    for(int i=0;i<100;i++) {
        double next_period_ns = 0.1 * dlsc_rand(50,500);
        reg_write(REG_PERIOD_IN,(uint32_t)(next_period_ns*(1u<<24)));
        clk_period_ns = next_period_ns;
        wait(100,SC_US);
    }

    start = sc_core::sc_time_stamp() - start;
    double elapsed_ns = start.to_seconds() * 1000000000.0;
    double period_out_ns = 100.0;

    dlsc_info("elapsed time: " << elapsed_ns);

//  dlsc_assert_equals(counts[0],1+(uint64_t)(elapsed_ns/(period_out_ns*PARAM_DIV0)));
    dlsc_assert_equals(counts[1],1+(uint64_t)(elapsed_ns/(period_out_ns*PARAM_DIV1)));
    dlsc_assert_equals(counts[2],1+(uint64_t)(elapsed_ns/(period_out_ns*PARAM_DIV2)));
    dlsc_assert_equals(counts[3],1+(uint64_t)(elapsed_ns/(period_out_ns*PARAM_DIV3)));
    dlsc_assert_equals(counts[4],1+(uint64_t)(elapsed_ns/(period_out_ns*PARAM_DIV4)));
    dlsc_assert_equals(counts[5],1+(uint64_t)(elapsed_ns/(period_out_ns*PARAM_DIV5)));
    dlsc_assert_equals(counts[6],1+(uint64_t)(elapsed_ns/(period_out_ns*PARAM_DIV6)));
    dlsc_assert_equals(counts[7],1+(uint64_t)(elapsed_ns/(period_out_ns*PARAM_DIV7)));

    cnt_val = timebase_cnt.read();
    
    dlsc_info("count value (port): " << cnt_val);

    delta = (double)cnt_val - elapsed_ns;
    if( std::abs(delta) > 500.0 ) {
        dlsc_error("count mismatch; delta: " << delta);
    } else {
        dlsc_okay("count okay");
    }
    
    cnt_val = reg_read(REG_COUNTER_LOW);
    cnt_val |= (uint64_t)reg_read(REG_COUNTER_HIGH) << 32;
    dlsc_info("count value (register): " << cnt_val);
    
    delta = (double)cnt_val - elapsed_ns;
    if( std::abs(delta) > 500.0 ) {
        dlsc_error("count mismatch; delta: " << delta);
    } else {
        dlsc_okay("count okay");
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

