//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_tlm_memtest.h"
#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_channel.h"
#include "dlsc_tlm_fabric.h"

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

#if (PARAM_OB_CLK_DOMAIN!=0)
#define ASYNC
#else
#define SYNC
#endif

#if (PARAM_WRITE_EN>0)
#define WRITE_EN
#endif

#if (PARAM_READ_EN>0)
#define READ_EN
#endif

SC_MODULE (__MODULE__) {
private:
    sc_clock        sys_clk;
    sc_signal<bool> sys_reset;
    
    sc_signal<bool> rst;
    sc_signal<bool> pcie_clk;
    sc_signal<bool> pcie_rst;

#ifdef ASYNC
    sc_clock        clk;
#else
    sc_signal<bool> clk;
#endif

    void stim_thread();
    void watchdog_thread();

    dlsc_tlm_initiator_nb<uint32_t> *initiator;
    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction transaction;

    dlsc_tlm_memtest<uint32_t> *memtest;

    dlsc_tlm_fabric<uint32_t> *fabric;

    dlsc_tlm_memory<uint32_t> *memory;

    dlsc_tlm_channel<uint32_t> *pcie_channel;
    dlsc_tlm_channel<uint32_t> *dummy_channel;

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

SP_CTOR_IMP(__MODULE__) :
    sys_clk("sys_clk",10,SC_NS)
#ifdef ASYNC
    ,clk("clk",10,SC_NS) // TODO
#endif
    /*AUTOINIT*/
{
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
#ifdef ASYNC
        SP_PIN(dut,pcie_clk,pcie_clk);
        SP_PIN(dut,pcie_rst,pcie_rst);
#else
        SP_PIN(dut,pcie_clk,clk);
        SP_PIN(dut,pcie_rst,rst);
#endif
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
#ifdef READ_EN
        SP_PIN(axi_master, axi_ar_addr,         axi_ar_addr);
        SP_PIN(axi_master, axi_ar_id,           axi_ar_id);
        SP_PIN(axi_master, axi_ar_len,          axi_ar_len);
        SP_PIN(axi_master, axi_ar_ready,        axi_ar_ready);
        SP_PIN(axi_master, axi_ar_valid,        axi_ar_valid);
        SP_PIN(axi_master, axi_r_data,          axi_r_data);
        SP_PIN(axi_master, axi_r_id,            axi_r_id);
        SP_PIN(axi_master, axi_r_last,          axi_r_last);
        SP_PIN(axi_master, axi_r_ready,         axi_r_ready);
        SP_PIN(axi_master, axi_r_resp,          axi_r_resp);
        SP_PIN(axi_master, axi_r_valid,         axi_r_valid);
#else
        SP_PIN(axi_master, axi_ar_addr,         dummy_ar_addr);
        SP_PIN(axi_master, axi_ar_id,           dummy_ar_id);
        SP_PIN(axi_master, axi_ar_len,          dummy_ar_len);
        SP_PIN(axi_master, axi_ar_ready,        dummy_ar_ready);
        SP_PIN(axi_master, axi_ar_valid,        dummy_ar_valid);
        SP_PIN(axi_master, axi_r_data,          dummy_r_data);
        SP_PIN(axi_master, axi_r_id,            dummy_r_id);
        SP_PIN(axi_master, axi_r_last,          dummy_r_last);
        SP_PIN(axi_master, axi_r_ready,         dummy_r_ready);
        SP_PIN(axi_master, axi_r_resp,          dummy_r_resp);
        SP_PIN(axi_master, axi_r_valid,         dummy_r_valid);
#endif
#ifdef WRITE_EN
        SP_PIN(axi_master, axi_aw_addr,         axi_aw_addr);
        SP_PIN(axi_master, axi_aw_id,           axi_aw_id);
        SP_PIN(axi_master, axi_aw_len,          axi_aw_len);
        SP_PIN(axi_master, axi_aw_ready,        axi_aw_ready);
        SP_PIN(axi_master, axi_aw_valid,        axi_aw_valid);
        SP_PIN(axi_master, axi_b_id,            axi_b_id);
        SP_PIN(axi_master, axi_b_ready,         axi_b_ready);
        SP_PIN(axi_master, axi_b_resp,          axi_b_resp);
        SP_PIN(axi_master, axi_b_valid,         axi_b_valid);
        SP_PIN(axi_master, axi_w_data,          axi_w_data);
        SP_PIN(axi_master, axi_w_id,            axi_w_id);
        SP_PIN(axi_master, axi_w_last,          axi_w_last);
        SP_PIN(axi_master, axi_w_ready,         axi_w_ready);
        SP_PIN(axi_master, axi_w_strb,          axi_w_strb);
        SP_PIN(axi_master, axi_w_valid,         axi_w_valid);
#else
        SP_PIN(axi_master, axi_aw_addr,         dummy_aw_addr);
        SP_PIN(axi_master, axi_aw_id,           dummy_aw_id);
        SP_PIN(axi_master, axi_aw_len,          dummy_aw_len);
        SP_PIN(axi_master, axi_aw_ready,        dummy_aw_ready);
        SP_PIN(axi_master, axi_aw_valid,        dummy_aw_valid);
        SP_PIN(axi_master, axi_b_id,            dummy_b_id);
        SP_PIN(axi_master, axi_b_ready,         dummy_b_ready);
        SP_PIN(axi_master, axi_b_resp,          dummy_b_resp);
        SP_PIN(axi_master, axi_b_valid,         dummy_b_valid);
        SP_PIN(axi_master, axi_w_data,          dummy_w_data);
        SP_PIN(axi_master, axi_w_id,            dummy_w_id);
        SP_PIN(axi_master, axi_w_last,          dummy_w_last);
        SP_PIN(axi_master, axi_w_ready,         dummy_w_ready);
        SP_PIN(axi_master, axi_w_strb,          dummy_w_strb);
        SP_PIN(axi_master, axi_w_valid,         dummy_w_valid);
#endif

    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
        SP_TEMPLATE(axi_slave,"axi_(.*)","dummy_$1");

    SP_CELL(pcie,dlsc_pcie_s6_model);
        /*AUTOINST*/
#ifdef ASYNC
        SP_PIN(pcie,user_clk_out,pcie_clk);
        SP_PIN(pcie,user_reset_out,pcie_rst);
#else
        SP_PIN(pcie,user_clk_out,clk);
        SP_PIN(pcie,user_reset_out,rst);
#endif
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
        // Error
        SP_PIN(pcie,cfg_err_cpl_rdy,pcie_err_ready);
        SP_PIN(pcie,cfg_err_cor,pcie_err_unexpected);
        SP_PIN(pcie,cfg_err_cpl_timeout,pcie_err_timeout);

    // tie-off
    tx_cfg_gnt      = 1;
    rx_np_ok        = 1;
    
    fabric          = new dlsc_tlm_fabric<uint32_t>("fabric");
    fabric->out_socket.bind(axi_master->socket);
    
    memtest         = new dlsc_tlm_memtest<uint32_t>("memtest",(1<<LEN));
    memtest->socket.bind(fabric->in_socket);

    initiator       = new dlsc_tlm_initiator_nb<uint32_t>("initiator",(1<<LEN));
    initiator->socket.bind(fabric->in_socket);
    initiator->socket.bind(pcie->target_socket);    // tie-off

    memory          = new dlsc_tlm_memory<uint32_t>("memory",4*1024*1024,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(20,SC_NS));

    pcie_channel    = new dlsc_tlm_channel<uint32_t>("pcie_channel");
    pcie->initiator_socket.bind(pcie_channel->in_socket);
    pcie_channel->out_socket.bind(memory->socket);
    pcie_channel->set_delay(sc_core::sc_time(500,SC_NS),sc_core::sc_time(1000,SC_NS));

    dummy_channel   = new dlsc_tlm_channel<uint32_t>("dummy_channel");
    axi_slave->socket.bind(dummy_channel->in_socket);
    dummy_channel->out_socket.bind(memory->socket);
    dummy_channel->set_delay(sc_core::sc_time(1500,SC_NS),sc_core::sc_time(2000,SC_NS)); // longer delay, to prevent reads before a posted write completes

#ifdef ASYNC
    rst             = 1;
#endif
    sys_reset       = 1;

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::stim_thread() {
    wait(1,SC_US);
    wait(sys_clk.posedge_event());
    sys_reset       = 0;
#ifdef ASYNC
    wait(clk.posedge_event());
    rst             = 0;
#endif
    wait(sys_clk.posedge_event());
    wait(clk.posedge_event());

    memory->set_error_rate_read(1.0);
    memtest->set_ignore_error_read(true);
    memtest->set_max_outstanding(16);   // more MOT for improved performance
    memtest->set_strobe_rate(1);        // sparse strobes are very slow over PCIe
    memtest->test(0,4*4096,1*1000*10);

    // test link reset recovery
    transaction ts, tswait;
    std::deque<uint32_t> data;
    std::deque<uint32_t> strb;
    
    int i,j;

    for(i=0;i<20;++i) {     // resets
        dlsc_info("testing reset recovery (" << (i+1) << "/20)");
        for(j=0;j<100;++j) {     // transactions
            if((rand()%100)>=50) {
                // write
                data.resize((rand()%(1<<LEN))+1);
                ts = initiator->nb_write((rand()%500)*4,data);
            } else {
                // read
                ts = initiator->nb_read((rand()%500)*4,(rand()%(1<<LEN))+1);
            }
            if(j==35) tswait = ts;
        }
        // wait for some transactions to complete
        tswait->wait();
        // reset it
        wait(sys_clk.posedge_event());
        dlsc_verb("applying sys_reset");
        sys_reset       = 1;
        wait(100+(rand()%1000),SC_NS);
        wait(sys_clk.posedge_event());
        dlsc_verb("removing sys_reset");
        sys_reset       = 0;
        wait(sys_clk.posedge_event());

        // wait for all transactions to finish
        initiator->wait();

        while(rst) {
            // wait for AXI reset to subside
            wait(clk.posedge_event());
        }
    }

    // run another memtest
    memtest->test(0,4*4096,1*1000*1);

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



