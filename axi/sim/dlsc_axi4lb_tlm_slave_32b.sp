//######################################################################
#sp interface

#include <systemperl.h>
#include "dlsc_axi4lb_tlm_slave_template.h"

SC_MODULE(__MODULE__) {
public:
    sc_core::sc_in<bool>        clk;
    sc_core::sc_in<bool>        rst;

    sc_core::sc_out<bool>       axi_ar_ready;
    sc_core::sc_in<bool>        axi_ar_valid;
    sc_core::sc_in<uint32_t>    axi_ar_addr;
    sc_core::sc_in<uint32_t>    axi_ar_len;
    
    sc_core::sc_in<bool>        axi_r_ready;
    sc_core::sc_out<bool>       axi_r_valid;
    sc_core::sc_out<bool>       axi_r_last;
    sc_core::sc_out<uint32_t>   axi_r_data;
    sc_core::sc_out<uint32_t>   axi_r_resp;

    sc_core::sc_out<bool>       axi_aw_ready;
    sc_core::sc_in<bool>        axi_aw_valid;
    sc_core::sc_in<uint32_t>    axi_aw_addr;
    sc_core::sc_in<uint32_t>    axi_aw_len;
    
    sc_core::sc_out<bool>       axi_w_ready;
    sc_core::sc_in<bool>        axi_w_valid;
    sc_core::sc_in<bool>        axi_w_last;
    sc_core::sc_in<uint32_t>    axi_w_data;
    sc_core::sc_in<uint32_t>    axi_w_strb;
    
    sc_core::sc_in<bool>        axi_b_ready;
    sc_core::sc_out<bool>       axi_b_valid;
    sc_core::sc_out<uint32_t>   axi_b_resp;

    dlsc_tlm_initiator_nb<uint32_t>::socket_type socket;
    
    /*AUTOMETHODS*/

private:
    dlsc_axi4lb_tlm_slave_template<uint32_t,uint32_t> *slave;
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/, socket("socket") {
    SP_AUTO_CTOR;

    slave = new dlsc_axi4lb_tlm_slave_template<uint32_t,uint32_t>("slave");

    slave->clk.bind(clk);
    slave->rst.bind(rst);

    slave->axi_ar_ready.bind(axi_ar_ready);
    slave->axi_ar_valid.bind(axi_ar_valid);
    slave->axi_ar_addr.bind(axi_ar_addr);
    slave->axi_ar_len.bind(axi_ar_len);
        
    slave->axi_r_ready.bind(axi_r_ready);
    slave->axi_r_valid.bind(axi_r_valid);
    slave->axi_r_last.bind(axi_r_last);
    slave->axi_r_data.bind(axi_r_data);
    slave->axi_r_resp.bind(axi_r_resp);

    slave->axi_aw_ready.bind(axi_aw_ready);
    slave->axi_aw_valid.bind(axi_aw_valid);
    slave->axi_aw_addr.bind(axi_aw_addr);
    slave->axi_aw_len.bind(axi_aw_len);
        
    slave->axi_w_ready.bind(axi_w_ready);
    slave->axi_w_valid.bind(axi_w_valid);
    slave->axi_w_last.bind(axi_w_last);
    slave->axi_w_data.bind(axi_w_data);
    slave->axi_w_strb.bind(axi_w_strb);
        
    slave->axi_b_ready.bind(axi_b_ready);
    slave->axi_b_valid.bind(axi_b_valid);
    slave->axi_b_resp.bind(axi_b_resp);

    slave->socket.bind(socket);
}

/*AUTOTRACE(__MODULE__)*/

