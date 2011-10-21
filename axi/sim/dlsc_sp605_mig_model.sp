//######################################################################
#sp interface

#include <systemperl.h>

#include "dlsc_tlm_fabric.h"

/*AUTOSUBCELL_CLASS*/

SC_MODULE(__MODULE__) {
public:

    // ** Port 0 **

    sc_core::sc_in<bool>        c3_s0_axi_aclk;
    sc_core::sc_in<bool>        c3_s0_axi_aresetn;

    sc_core::sc_out<bool>       c3_s0_axi_arready;
    sc_core::sc_in<bool>        c3_s0_axi_arvalid;
    sc_core::sc_in<uint32_t>    c3_s0_axi_arid;
    sc_core::sc_in<uint32_t>    c3_s0_axi_araddr;
    sc_core::sc_in<uint32_t>    c3_s0_axi_arlen;
    sc_core::sc_in<uint32_t>    c3_s0_axi_arsize;
    sc_core::sc_in<uint32_t>    c3_s0_axi_arburst;
    sc_core::sc_in<bool>        c3_s0_axi_arlock;
    sc_core::sc_in<uint32_t>    c3_s0_axi_arcache;
    sc_core::sc_in<uint32_t>    c3_s0_axi_arprot;
    sc_core::sc_in<uint32_t>    c3_s0_axi_arqos;
    
    sc_core::sc_in<bool>        c3_s0_axi_rready;
    sc_core::sc_out<bool>       c3_s0_axi_rvalid;
    sc_core::sc_out<bool>       c3_s0_axi_rlast;
    sc_core::sc_out<uint32_t>   c3_s0_axi_rid;
    sc_core::sc_out<uint32_t>   c3_s0_axi_rdata;
    sc_core::sc_out<uint32_t>   c3_s0_axi_rresp;

    sc_core::sc_out<bool>       c3_s0_axi_awready;
    sc_core::sc_in<bool>        c3_s0_axi_awvalid;
    sc_core::sc_in<uint32_t>    c3_s0_axi_awid;
    sc_core::sc_in<uint32_t>    c3_s0_axi_awaddr;
    sc_core::sc_in<uint32_t>    c3_s0_axi_awlen;
    sc_core::sc_in<uint32_t>    c3_s0_axi_awsize;
    sc_core::sc_in<uint32_t>    c3_s0_axi_awburst;
    sc_core::sc_in<bool>        c3_s0_axi_awlock;
    sc_core::sc_in<uint32_t>    c3_s0_axi_awcache;
    sc_core::sc_in<uint32_t>    c3_s0_axi_awprot;
    sc_core::sc_in<uint32_t>    c3_s0_axi_awqos;
    
    sc_core::sc_out<bool>       c3_s0_axi_wready;
    sc_core::sc_in<bool>        c3_s0_axi_wvalid;
    sc_core::sc_in<bool>        c3_s0_axi_wlast;
    sc_core::sc_in<uint32_t>    c3_s0_axi_wdata;
    sc_core::sc_in<uint32_t>    c3_s0_axi_wstrb;
    
    sc_core::sc_in<bool>        c3_s0_axi_bready;
    sc_core::sc_out<bool>       c3_s0_axi_bvalid;
    sc_core::sc_out<uint32_t>   c3_s0_axi_bid;
    sc_core::sc_out<uint32_t>   c3_s0_axi_bresp;

    // ** Port 1 **

    sc_core::sc_in<bool>        c3_s1_axi_aclk;
    sc_core::sc_in<bool>        c3_s1_axi_aresetn;

    sc_core::sc_out<bool>       c3_s1_axi_arready;
    sc_core::sc_in<bool>        c3_s1_axi_arvalid;
    sc_core::sc_in<uint32_t>    c3_s1_axi_arid;
    sc_core::sc_in<uint32_t>    c3_s1_axi_araddr;
    sc_core::sc_in<uint32_t>    c3_s1_axi_arlen;
    sc_core::sc_in<uint32_t>    c3_s1_axi_arsize;
    sc_core::sc_in<uint32_t>    c3_s1_axi_arburst;
    sc_core::sc_in<bool>        c3_s1_axi_arlock;
    sc_core::sc_in<uint32_t>    c3_s1_axi_arcache;
    sc_core::sc_in<uint32_t>    c3_s1_axi_arprot;
    sc_core::sc_in<uint32_t>    c3_s1_axi_arqos;
    
    sc_core::sc_in<bool>        c3_s1_axi_rready;
    sc_core::sc_out<bool>       c3_s1_axi_rvalid;
    sc_core::sc_out<bool>       c3_s1_axi_rlast;
    sc_core::sc_out<uint32_t>   c3_s1_axi_rid;
    sc_core::sc_out<uint32_t>   c3_s1_axi_rdata;
    sc_core::sc_out<uint32_t>   c3_s1_axi_rresp;

    sc_core::sc_out<bool>       c3_s1_axi_awready;
    sc_core::sc_in<bool>        c3_s1_axi_awvalid;
    sc_core::sc_in<uint32_t>    c3_s1_axi_awid;
    sc_core::sc_in<uint32_t>    c3_s1_axi_awaddr;
    sc_core::sc_in<uint32_t>    c3_s1_axi_awlen;
    sc_core::sc_in<uint32_t>    c3_s1_axi_awsize;
    sc_core::sc_in<uint32_t>    c3_s1_axi_awburst;
    sc_core::sc_in<bool>        c3_s1_axi_awlock;
    sc_core::sc_in<uint32_t>    c3_s1_axi_awcache;
    sc_core::sc_in<uint32_t>    c3_s1_axi_awprot;
    sc_core::sc_in<uint32_t>    c3_s1_axi_awqos;
    
    sc_core::sc_out<bool>       c3_s1_axi_wready;
    sc_core::sc_in<bool>        c3_s1_axi_wvalid;
    sc_core::sc_in<bool>        c3_s1_axi_wlast;
    sc_core::sc_in<uint32_t>    c3_s1_axi_wdata;
    sc_core::sc_in<uint32_t>    c3_s1_axi_wstrb;
    
    sc_core::sc_in<bool>        c3_s1_axi_bready;
    sc_core::sc_out<bool>       c3_s1_axi_bvalid;
    sc_core::sc_out<uint32_t>   c3_s1_axi_bid;
    sc_core::sc_out<uint32_t>   c3_s1_axi_bresp;

    // ** Port 2 **

    sc_core::sc_in<bool>        c3_s2_axi_aclk;
    sc_core::sc_in<bool>        c3_s2_axi_aresetn;

    sc_core::sc_out<bool>       c3_s2_axi_arready;
    sc_core::sc_in<bool>        c3_s2_axi_arvalid;
    sc_core::sc_in<uint32_t>    c3_s2_axi_arid;
    sc_core::sc_in<uint32_t>    c3_s2_axi_araddr;
    sc_core::sc_in<uint32_t>    c3_s2_axi_arlen;
    sc_core::sc_in<uint32_t>    c3_s2_axi_arsize;
    sc_core::sc_in<uint32_t>    c3_s2_axi_arburst;
    sc_core::sc_in<bool>        c3_s2_axi_arlock;
    sc_core::sc_in<uint32_t>    c3_s2_axi_arcache;
    sc_core::sc_in<uint32_t>    c3_s2_axi_arprot;
    sc_core::sc_in<uint32_t>    c3_s2_axi_arqos;
    
    sc_core::sc_in<bool>        c3_s2_axi_rready;
    sc_core::sc_out<bool>       c3_s2_axi_rvalid;
    sc_core::sc_out<bool>       c3_s2_axi_rlast;
    sc_core::sc_out<uint32_t>   c3_s2_axi_rid;
    sc_core::sc_out<uint32_t>   c3_s2_axi_rdata;
    sc_core::sc_out<uint32_t>   c3_s2_axi_rresp;

    sc_core::sc_out<bool>       c3_s2_axi_awready;
    sc_core::sc_in<bool>        c3_s2_axi_awvalid;
    sc_core::sc_in<uint32_t>    c3_s2_axi_awid;
    sc_core::sc_in<uint32_t>    c3_s2_axi_awaddr;
    sc_core::sc_in<uint32_t>    c3_s2_axi_awlen;
    sc_core::sc_in<uint32_t>    c3_s2_axi_awsize;
    sc_core::sc_in<uint32_t>    c3_s2_axi_awburst;
    sc_core::sc_in<bool>        c3_s2_axi_awlock;
    sc_core::sc_in<uint32_t>    c3_s2_axi_awcache;
    sc_core::sc_in<uint32_t>    c3_s2_axi_awprot;
    sc_core::sc_in<uint32_t>    c3_s2_axi_awqos;
    
    sc_core::sc_out<bool>       c3_s2_axi_wready;
    sc_core::sc_in<bool>        c3_s2_axi_wvalid;
    sc_core::sc_in<bool>        c3_s2_axi_wlast;
    sc_core::sc_in<uint32_t>    c3_s2_axi_wdata;
    sc_core::sc_in<uint32_t>    c3_s2_axi_wstrb;
    
    sc_core::sc_in<bool>        c3_s2_axi_bready;
    sc_core::sc_out<bool>       c3_s2_axi_bvalid;
    sc_core::sc_out<uint32_t>   c3_s2_axi_bid;
    sc_core::sc_out<uint32_t>   c3_s2_axi_bresp;

    // ** Port 3 **

    sc_core::sc_in<bool>        c3_s3_axi_aclk;
    sc_core::sc_in<bool>        c3_s3_axi_aresetn;

    sc_core::sc_out<bool>       c3_s3_axi_arready;
    sc_core::sc_in<bool>        c3_s3_axi_arvalid;
    sc_core::sc_in<uint32_t>    c3_s3_axi_arid;
    sc_core::sc_in<uint32_t>    c3_s3_axi_araddr;
    sc_core::sc_in<uint32_t>    c3_s3_axi_arlen;
    sc_core::sc_in<uint32_t>    c3_s3_axi_arsize;
    sc_core::sc_in<uint32_t>    c3_s3_axi_arburst;
    sc_core::sc_in<bool>        c3_s3_axi_arlock;
    sc_core::sc_in<uint32_t>    c3_s3_axi_arcache;
    sc_core::sc_in<uint32_t>    c3_s3_axi_arprot;
    sc_core::sc_in<uint32_t>    c3_s3_axi_arqos;
    
    sc_core::sc_in<bool>        c3_s3_axi_rready;
    sc_core::sc_out<bool>       c3_s3_axi_rvalid;
    sc_core::sc_out<bool>       c3_s3_axi_rlast;
    sc_core::sc_out<uint32_t>   c3_s3_axi_rid;
    sc_core::sc_out<uint32_t>   c3_s3_axi_rdata;
    sc_core::sc_out<uint32_t>   c3_s3_axi_rresp;

    sc_core::sc_out<bool>       c3_s3_axi_awready;
    sc_core::sc_in<bool>        c3_s3_axi_awvalid;
    sc_core::sc_in<uint32_t>    c3_s3_axi_awid;
    sc_core::sc_in<uint32_t>    c3_s3_axi_awaddr;
    sc_core::sc_in<uint32_t>    c3_s3_axi_awlen;
    sc_core::sc_in<uint32_t>    c3_s3_axi_awsize;
    sc_core::sc_in<uint32_t>    c3_s3_axi_awburst;
    sc_core::sc_in<bool>        c3_s3_axi_awlock;
    sc_core::sc_in<uint32_t>    c3_s3_axi_awcache;
    sc_core::sc_in<uint32_t>    c3_s3_axi_awprot;
    sc_core::sc_in<uint32_t>    c3_s3_axi_awqos;
    
    sc_core::sc_out<bool>       c3_s3_axi_wready;
    sc_core::sc_in<bool>        c3_s3_axi_wvalid;
    sc_core::sc_in<bool>        c3_s3_axi_wlast;
    sc_core::sc_in<uint32_t>    c3_s3_axi_wdata;
    sc_core::sc_in<uint32_t>    c3_s3_axi_wstrb;
    
    sc_core::sc_in<bool>        c3_s3_axi_bready;
    sc_core::sc_out<bool>       c3_s3_axi_bvalid;
    sc_core::sc_out<uint32_t>   c3_s3_axi_bid;
    sc_core::sc_out<uint32_t>   c3_s3_axi_bresp;
    
    dlsc_tlm_fabric<uint32_t>::i_socket_type socket;

    /*AUTOMETHODS*/

private:
    dlsc_tlm_fabric<uint32_t>   *fabric;
    void rst_method();

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/, socket("socket") {
    SP_AUTO_CTOR;
    
    SP_CELL(axi_slave_s0,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
        SP_PIN(axi_slave_s0,clk,c3_s0_axi_aclk);
        SP_PIN(axi_slave_s0,rst,c3_s0_axi_areset);
        SP_TEMPLATE(axi_slave_s0,"axi_(.*)_(.*)","c3_s0_axi_$1$2");
    
    SP_CELL(axi_slave_s1,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
        SP_PIN(axi_slave_s1,clk,c3_s1_axi_aclk);
        SP_PIN(axi_slave_s1,rst,c3_s1_axi_areset);
        SP_TEMPLATE(axi_slave_s1,"axi_(.*)_(.*)","c3_s1_axi_$1$2");
    
    SP_CELL(axi_slave_s2,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
        SP_PIN(axi_slave_s2,clk,c3_s2_axi_aclk);
        SP_PIN(axi_slave_s2,rst,c3_s2_axi_areset);
        SP_TEMPLATE(axi_slave_s2,"axi_(.*)_(.*)","c3_s2_axi_$1$2");
    
    SP_CELL(axi_slave_s3,dlsc_axi4lb_tlm_slave_32b);
        /*AUTOINST*/
        SP_PIN(axi_slave_s3,clk,c3_s3_axi_aclk);
        SP_PIN(axi_slave_s3,rst,c3_s3_axi_areset);
        SP_TEMPLATE(axi_slave_s3,"axi_(.*)_(.*)","c3_s3_axi_$1$2");
    
    fabric          = new dlsc_tlm_fabric<uint32_t>("fabric");

    axi_slave_s0->socket.bind(fabric->in_socket);
    axi_slave_s1->socket.bind(fabric->in_socket);
    axi_slave_s2->socket.bind(fabric->in_socket);
    axi_slave_s3->socket.bind(fabric->in_socket);
    
    fabric->out_socket.bind(socket);

    SC_METHOD(rst_method)
        sensitive << c3_s0_axi_aresetn;
        sensitive << c3_s1_axi_aresetn;
        sensitive << c3_s2_axi_aresetn;
        sensitive << c3_s3_axi_aresetn;
}

void __MODULE__::rst_method() {
    c3_s0_axi_areset.write(!c3_s0_axi_aresetn.read());
    c3_s1_axi_areset.write(!c3_s1_axi_aresetn.read());
    c3_s2_axi_areset.write(!c3_s2_axi_aresetn.read());
    c3_s3_axi_areset.write(!c3_s3_axi_aresetn.read());
}

/*AUTOTRACE(__MODULE__)*/

