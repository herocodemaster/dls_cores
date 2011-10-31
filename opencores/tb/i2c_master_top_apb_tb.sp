//######################################################################
#sp interface

// for syntax highlighter: SC_MODULE

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"

/*AUTOSUBCELL_CLASS*/

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    sc_signal<bool> scl;
    sc_signal<bool> sda;

    void i2c_method();

    void stim_thread();
    void watchdog_thread();

    void reg_write(uint32_t addr, uint32_t data);
    uint32_t reg_read(uint32_t addr);
    dlsc_tlm_initiator_nb<uint32_t> *apb_initiator;

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

#include <boost/shared_array.hpp>

#include "dlsc_main.cpp"

#define REG_I2C_PRE_LO 0x0
#define REG_I2C_PRE_HI 0x1

#define REG_I2C_CTR 0x2
#define REG_I2C_CTR_EN (1<<7)
#define REG_I2C_CTR_IEN (1<<6)

#define REG_I2C_TXR 0x3
#define REG_I2C_RXR 0x3

#define REG_I2C_CR 0x4
#define REG_I2C_CR_STA (1<<7)
#define REG_I2C_CR_STO (1<<6)
#define REG_I2C_CR_RD (1<<5)
#define REG_I2C_CR_WR (1<<4)
#define REG_I2C_CR_ACK (1<<3)
#define REG_I2C_CR_IACK (1<<0)

#define REG_I2C_SR 0x4
#define REG_I2C_SR_RXACK (1<<7)
#define REG_I2C_SR_BUSY (1<<6)
#define REG_I2C_SR_AL (1<<5)
#define REG_I2C_SR_TIP (1<<1)
#define REG_I2C_SR_IF (1<<0)

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    SP_CELL(apb_master,dlsc_apb_tlm_master_32b);
        /*AUTOINST*/
    
    apb_initiator   = new dlsc_tlm_initiator_nb<uint32_t>("apb_initiator",1);
    apb_initiator->socket.bind(apb_master->socket);

    rst         = 1;

    SC_METHOD(i2c_method);
        sensitive << scl_out;
        sensitive << scl_oe;
        sensitive << sda_out;
        sensitive << sda_oe;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::i2c_method() {
    if(scl_oe) {
        scl = scl_out;
        scl_in = scl_out;
    } else {
        scl = 1;
        scl_in = 1;
    }
    if(sda_oe) {
        sda = sda_out;
        sda_in = sda_out;
    } else {
        sda = 1;
        sda_in = 1;
    }
}

void __MODULE__::reg_write(uint32_t addr, uint32_t data) {
    dlsc_verb("wrote 0x" << std::hex << addr << " : 0x" << data);
    apb_initiator->b_write(addr<<2,data);
}

uint32_t __MODULE__::reg_read(uint32_t addr) {
    uint32_t data = apb_initiator->b_read(addr<<2);
    dlsc_verb("read 0x" << std::hex << addr << " : 0x" << data);
    return data;
}

void __MODULE__::stim_thread() {
    rst         = 1;
    wait(1,SC_US);
    wait(clk.posedge_event());
    rst         = 0;
    wait(clk.posedge_event());

    uint32_t data;

    data = (100000000/(5*100000))-1; // prescaler
    reg_write(REG_I2C_PRE_LO,data&0xFF);
    reg_write(REG_I2C_PRE_HI,data>>8);
    reg_write(REG_I2C_CTR,REG_I2C_CTR_EN|REG_I2C_CTR_IEN);
    
    dlsc_assert(reg_read(REG_I2C_PRE_LO)==(data&0xFF));

    reg_write(REG_I2C_TXR,0x42);
    reg_write(REG_I2C_CR,REG_I2C_CR_STA|REG_I2C_CR_WR|REG_I2C_CR_IACK);

    wait(int_out.posedge_event());

    reg_write(REG_I2C_TXR,0xAE);
    reg_write(REG_I2C_CR,REG_I2C_CR_STO|REG_I2C_CR_WR|REG_I2C_CR_IACK);
    
    wait(int_out.posedge_event());

    reg_write(REG_I2C_CTR,0x80000000); // trigger reset

    dlsc_assert(reg_read(REG_I2C_PRE_LO)==0xFF);

    wait(20,SC_US);
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



