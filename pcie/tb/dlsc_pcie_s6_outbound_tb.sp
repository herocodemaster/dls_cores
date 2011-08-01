//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"

/*AUTOSUBCELL_CLASS*/

#define ADDR            PARAM_ADDR
#define LEN             PARAM_LEN
#define TAG             PARAM_TAG
#define WRITE_SIZE      PARAM_WRITE_SIZE
#define READ_MOT        PARAM_READ_MOT
#define READ_SIZE       PARAM_READ_SIZE
#define READ_CPLH       PARAM_READ_CPLH
#define READ_CPLD       PARAM_READ_CPLD
#define READ_TIMEOUT    PARAM_READ_TIMEOUT

SC_MODULE (__MODULE__) {
private:
    sc_clock sys_clk;
    sc_clock async_clk;

    sc_signal<bool> pcie_clk;
    sc_signal<bool> pcie_rst;
    sc_signal<bool> clk;
    sc_signal<bool> rst;

    void clk_driver_method();

    void stim_thread();
    void watchdog_thread();

    void pcie_clk_method();
    
    dlsc_tlm_initiator_nb<uint32_t> *initiator;
    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction transaction;

    dlsc_tlm_memtest<uint32_t> *memtest;

    dlsc_tlm_memory<uint32_t> *memory;

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

#define MEMTEST

SP_CTOR_IMP(__MODULE__) :
    sys_clk("sys_clk",10,SC_NS),
    async_clk("async_clk",10,SC_NS) // TODO
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        SP_PIN(dut,axi_clk,clk);
        SP_PIN(dut,axi_rst,rst);
        /*AUTOINST*/

    // tie-off
    pcie_max_payload_size    = 2;    // 512 bytes
    pcie_max_read_request    = 5;    // 4096 bytes
    pcie_rcb                 = 1;    // 128 bytes
    pcie_dma_en              = 1;
    
    SP_CELL(axi_master,dlsc_axi4lb_tlm_master_32b);
        /*AUTOINST*/

    SP_CELL(pcie,dlsc_pcie_s6_model);
        // RX
        SP_PIN(pcie,m_axis_rx_tready,pcie_rx_ready);
        SP_PIN(pcie,m_axis_rx_tvalid,pcie_rx_valid);
        SP_PIN(pcie,m_axis_rx_tlast, pcie_rx_last);
        SP_PIN(pcie,m_axis_rx_tdata, pcie_rx_data);
        // TX
        SP_PIN(pcie,s_axis_tx_tready,pcie_tx_ready);
        SP_PIN(pcie,s_axis_tx_tvalid,pcie_tx_valid);
        SP_PIN(pcie,s_axis_tx_tlast, pcie_tx_last);
        SP_PIN(pcie,s_axis_tx_tdata, pcie_tx_data);
        // FC
        SP_PIN(pcie,fc_sel,pcie_fc_sel);
        SP_PIN(pcie,fc_ph,pcie_fc_ph);
        SP_PIN(pcie,fc_pd,pcie_fc_pd);
        /*AUTOINST*/

    // tie-off
    tx_cfg_gnt      = 1;
    rx_np_ok        = 1;
    
    memtest = new dlsc_tlm_memtest<uint32_t>("memtest",(1<<LEN));
    initiator = new dlsc_tlm_initiator_nb<uint32_t>("initiator",(1<<LEN));

#ifdef MEMTEST
    memtest->socket.bind(axi_master->socket);
    initiator->socket.bind(pcie->target_socket);    // tie-off
#else
    memtest->socket.bind(pcie->target_socket);      // tie-off
    initiator->socket.bind(axi_master->socket);
#endif

    memory = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(20,SC_NS));

    pcie->initiator_socket.bind(memory->socket);

    sys_reset       = 1;

    SC_METHOD(clk_driver_method);
        sensitive << user_clk_out;
        sensitive << async_clk;

    SC_METHOD(pcie_clk_method);
        sensitive << pcie_clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::clk_driver_method() {
    pcie_clk.write(user_clk_out);
    pcie_rst.write(user_reset_out);
    rst.write(user_reset_out); // TODO
#ifdef PARAM_ASYNC
    clk.write(async_clk);
#else
    clk.write(user_clk_out);
#endif
}

void __MODULE__::pcie_clk_method() {
    if(pcie_rst) {
        return;
    }

    if(pcie_err_ready && pcie_err_valid) {
        dlsc_error("got error: unexpected = " << pcie_err_unexpected.read() << ", timeout = " << pcie_err_timeout.read());
    }

    pcie_err_ready       = (rand()%100) < 95;
}

void __MODULE__::stim_thread() {
    sys_reset       = 1;
    wait(1,SC_US);
    wait(sys_clk.posedge_event());
    sys_reset       = 0;
    wait(sys_clk.posedge_event());
    wait(clk.posedge_event());

#ifdef MEMTEST
    memory->set_error_rate_read(1.0);
    memtest->set_ignore_error_read(true);
    memtest->set_max_outstanding(16);   // more MOT for improved performance
    memtest->set_strobe_rate(1);        // sparse strobes are very slow over PCIe
    memtest->test(0,4*4096,1*1000*10);
#else

    std::deque<uint32_t> data;
    std::deque<uint32_t> strb;

    data.push_back(0x12345678);
    data.push_back(0xFEEDFACE);
    data.push_back(0xABCDEF98);
    initiator->nb_write(0,data);

    initiator->nb_read(4,16);

    initiator->wait();
#endif

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



