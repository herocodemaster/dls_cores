//######################################################################
#sp interface

#include <systemperl.h>
#include <verilated.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_quad_encoder_model.h"

// Verilog parameters
#define FILTER          PARAM_FILTER
#define BITS            PARAM_BITS

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void clk_method();

    std::deque<int> check_vals;

    dlsc_quad_encoder_model *enc;
    
    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *csr_initiator;

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:

    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",100,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    enc = new dlsc_quad_encoder_model("enc", check_vals);
        enc->quad_a.bind(in_a);
        enc->quad_b.bind(in_b);
        enc->quad_z.bind(in_z);
    
    SP_CELL(csr_master,dlsc_csr_tlm_master_32b);
        /*AUTOINST*/
    
    csr_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("csr_initiator",1);
    csr_initiator->socket.bind(csr_master->socket);

    rst     = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

const uint32_t REG_CORE_MAGIC      = 0x0;
const uint32_t REG_CORE_VERSION    = 0x1;
const uint32_t REG_CORE_INTERFACE  = 0x2;
const uint32_t REG_CORE_INSTANCE   = 0x3;

const uint32_t REG_CONTROL         = 0x4;
const uint32_t REG_COUNT_MIN       = 0x5;
const uint32_t REG_COUNT_MAX       = 0x6;
const uint32_t REG_INT_FLAGS       = 0x7;
const uint32_t REG_INT_SELECT      = 0x8;
const uint32_t REG_STATUS          = 0x9;
const uint32_t REG_COUNT           = 0xA;
const uint32_t REG_INDEX           = 0xB;

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
        check_vals.clear();
        return;
    }

    if(quad_en) {
        if(check_vals.empty()) {
            dlsc_error("unexpected quad_en");
        } else {
//          dlsc_assert_equals(count, check_vals.front());
            check_vals.pop_front();
        }
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst     = 0;
    wait(clk.posedge_event());

    enc->set_range(-400.0,400.0);
    enc->set_acceleration(0.0); // infinite acceleration

    uint32_t data;

    reg_write(REG_COUNT_MIN,(uint32_t)(-400));
    reg_write(REG_COUNT_MAX,399);
    reg_write(REG_CONTROL,0x11);
    
    wait(clk.posedge_event());

    enc->move(1600.0);
    enc->move(-810.0);
    enc->move(24.0);
    enc->move(-10.0);

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



