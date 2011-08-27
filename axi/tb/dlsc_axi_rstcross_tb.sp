//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

#define LEN             PARAM_LEN

#if (PARAM_MASTER_RESET>0)
#define MASTER_RESET
#endif

#if (PARAM_SLAVE_RESET>0)
#define SLAVE_RESET
#endif

#if ((PARAM_MASTER_RESET>0) && (PARAM_SLAVE_RESET>0))
#define BOTH_RESET
#endif

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void stim_thread();
    void watchdog_thread();

    void m_rst_thread();
    void s_rst_thread();
    
    dlsc_tlm_memtest<uint32_t> *memtest;

    dlsc_tlm_memory<uint32_t> *memory;

    bool allow_m_rst;
    bool allow_s_rst;

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

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/


    SP_CELL(axi_master,dlsc_axi4lb_tlm_master_32b);
        SP_PIN(axi_master,rst,m_rst);
        /*AUTOINST*/
    
    SP_TEMPLATE(axi_master,"axi_(.*)","m_$1");


    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        SP_PIN(axi_slave,rst,s_rst);
        /*AUTOINST*/
    
    SP_TEMPLATE(axi_slave,"axi_(.*)","s_$1");


    memtest = new dlsc_tlm_memtest<uint32_t>("memtest",(1<<LEN));
    memtest->socket.bind(axi_master->socket);
    
    memory = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(2.5,SC_NS),sc_core::sc_time(20,SC_NS));

    axi_slave->socket.bind(memory->socket);


    m_rst       = 1;
    s_rst       = 1;

    allow_m_rst = false;
    allow_s_rst = false;

    SC_THREAD(m_rst_thread);
    SC_THREAD(s_rst_thread);

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::m_rst_thread() {
    m_rst       = 1;
    wait(100,SC_NS);
    m_rst       = 0;

    while(true) {

        wait(rand()%10000,SC_NS);
        wait(clk.posedge_event());
        m_rst       = allow_m_rst;

        if(rand()%3==0) {
            // do long reset
            wait(rand()%3000,SC_NS);
        }
        
        wait(clk.posedge_event());
        m_rst       = 0;

    }
}

void __MODULE__::s_rst_thread() {
    s_rst       = 1;
    wait(100,SC_NS);
    s_rst       = 0;

    while(true) {

        wait(rand()%10000,SC_NS);
        wait(clk.posedge_event());
        s_rst       = allow_s_rst;

        if(rand()%3==0) {
            // do long reset
            wait(rand()%3000,SC_NS);
        }
        
        wait(clk.posedge_event());
        s_rst       = 0;

    }
}

void __MODULE__::stim_thread() {
    wait(1,SC_US);

#ifdef SLAVE_RESET
    dlsc_info("testing with only s_rst");
    memory->set_error_rate(1);
    memtest->set_ignore_error(true);
    allow_m_rst = false;
    allow_s_rst = true;
    wait(10,SC_US);
    memtest->test(0,4*4096,1*1000*100);
    wait(100,SC_US);
#endif

    dlsc_info("testing with no resets");
    memory->set_error_rate(0);
    memtest->set_ignore_error(false);
    allow_m_rst = false;
    allow_s_rst = false;
    wait(10,SC_US);
    memtest->test(0,4*4096,1*1000*100);
    wait(100,SC_US);

#ifdef BOTH_RESET
    dlsc_info("testing with both m_rst and s_rst");
    memory->set_error_rate(1);
    memtest->set_ignore_error(true);
    allow_m_rst = true;
    allow_s_rst = true;
    wait(10,SC_US);
    memtest->test(0,4*4096,1*1000*100);
    wait(100,SC_US);
#endif

    dlsc_info("testing with no resets (again)");
    memory->set_error_rate(0);
    memtest->set_ignore_error(false);
    allow_m_rst = false;
    allow_s_rst = false;
    wait(10,SC_US);
    memtest->test(0,4*4096,1*1000*100);
    wait(100,SC_US);

#ifdef MASTER_RESET
    dlsc_info("testing with only m_rst");
    memory->set_error_rate(1);
    memtest->set_ignore_error(true);
    allow_m_rst = true;
    allow_s_rst = false;
    wait(10,SC_US);
    memtest->test(0,4*4096,1*1000*100);
    wait(100,SC_US);
#endif

    dlsc_info("testing with no resets (one final time)");
    memory->set_error_rate(0);
    memtest->set_ignore_error(false);
    allow_m_rst = false;
    allow_s_rst = false;
    wait(10,SC_US);
    memtest->test(0,4*4096,1*1000*100);
    wait(100,SC_US);

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



