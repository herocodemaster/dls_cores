//######################################################################
#sp interface

#include <systemperl.h>
#include <iostream>
#include <vector>

namespace dlsc {
    namespace pcie {
        class pcie_tlp;
    }
}

/*AUTOSUBCELL_CLASS*/

struct vect_wrapper {
    std::vector<uint32_t> v;
};

std::ostream& operator << ( std::ostream &os, const vect_wrapper &vw );

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    sc_fifo<vect_wrapper> rx_fifo;
    sc_fifo<dlsc::pcie::pcie_tlp>   tlp_fifo;
    sc_fifo<dlsc::pcie::pcie_tlp>   data_fifo;

    void rx_thread();
    void tlp_thread();
    void data_thread();
    
    void stim_thread();

    void watchdog_thread();

    /*AUTOSUBCELL_DECL*/
    /*AUTOSIGNAL*/

public:
    /*AUTOMETHODS*/

};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

//#include "dlsc_common.h"

#include <iostream>
#include <iomanip>

#include <scv.h>

//#define DLSC_TB dlsc_pcie_tlp_decoder_tb
#include "dlsc_main.cpp"

#include "dlsc_pcie_tlp.h"
#include "dlsc_pcie_tlp_scv.h"

using namespace dlsc::pcie;
using namespace std;

SP_CTOR_IMP(__MODULE__) : clk("clk",16,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL (dut,Vdlsc_pcie_tlp_decoder);
        /*AUTOINST*/

    SC_THREAD(rx_thread);
    SC_THREAD(tlp_thread);
    SC_THREAD(data_thread);
    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::rx_thread() {
    vect_wrapper vw;
    vector<uint32_t> dw;
    vector<uint32_t>::iterator it;
    pcie_tlp tlp;

    scv_bag<bool> bool_bag;
    bool_bag.push(false,5);
    bool_bag.push(true,95);
    scv_smart_ptr<bool> rand_bool;
    rand_bool->set_mode(bool_bag);

    rx_data    = 0;
    rx_valid   = 0;
    rx_last    = 0;
    
    wait(clk.posedge_event());

    while(1) {
        if(!rx_fifo.nb_read(vw)) {
            rx_data    = 0;
            rx_valid   = 0;
            rx_last    = 0;
            rx_fifo.read(vw);
            wait(clk.posedge_event());
        }

        tlp.deserialize(vw.v);
        tlp_fifo.write(tlp);
        data_fifo.write(tlp);
        
        dw = vw.v;
        it = dw.begin();
        while(1) {
            rx_data    = *it;
            rx_last    = (it == dw.end()-1);

            if(rx_ready || !rx_valid) {
                rand_bool->next();
                rx_valid = *rand_bool;
            }

            wait(clk.posedge_event());

            if(rx_ready && rx_valid && (++it == dw.end())) {
                break;
            }
        }
    }
}

void __MODULE__::data_thread() {
    vector<uint32_t> dw;
    vector<uint32_t>::iterator it = dw.end();
    pcie_tlp tlp;

    scv_bag<bool> bool_bag;
    bool_bag.push(false,5);
    bool_bag.push(true,95);
    scv_smart_ptr<bool> rand_bool;
    rand_bool->set_mode(bool_bag);
    
    data_ready  = 0;

    while(1) {
        wait(clk.posedge_event());

        if(it == dw.end() && data_fifo.nb_read(tlp) && !tlp.malformed) {
            dw = tlp.data;
            if(tlp.td) {
                dw.push_back(tlp.digest);
            }
            it = dw.begin();
        }

        if(data_valid && data_ready) {
            if(dw.empty()) {
                dlsc_error("unexpected data");
            } else {
                dlsc_assert(data == *it);
                if(++it == dw.end()) {
                    dlsc_assert(data_last == 1);
                } else {
                    dlsc_assert(data_last == 0);
                }
            }
        }

        if(data_valid || !data_ready) {
            rand_bool->next();
            data_ready = *rand_bool;
        }
    }
}

void __MODULE__::tlp_thread() {
    pcie_tlp tlp;

    scv_bag<bool> bool_bag;
    bool_bag.push(false,20);
    bool_bag.push(true,80);
    scv_smart_ptr<bool> rand_bool;
    rand_bool->set_mode(bool_bag);

    tlp_ready   = 0;

    while(1) {
        wait(clk.posedge_event());

        if(tlp_valid && tlp_ready) {
            if(!tlp_fifo.nb_read(tlp)) {
                dlsc_error("unexpected TLP");
            } else {
                dlsc_assert(tlp_malformed == tlp.malformed);
                if(!tlp.malformed) {
                    dlsc_assert(tlp.fmt     == tlp_fmt);
                    dlsc_assert(tlp.type    == tlp_type);
                    dlsc_assert(tlp.tc      == traffic_class);
                    dlsc_assert(tlp.td      == digest_present);
                    dlsc_assert(tlp.ep      == poisoned);
                    // TODO: attributes
                    dlsc_assert((tlp.length==1024?0:tlp.length) == length);
                    dlsc_assert(tlp.src_id == src_id);
                
                    if(tlp.type_mem || tlp.type_io || tlp.type_cfg || tlp.type_msg) {
                        dlsc_assert(tlp.src_tag     == src_tag);
                    }

                    if(tlp.type_cpl) {
                        dlsc_assert(tlp.cpl_status  == cpl_status);
                        dlsc_assert(tlp.cpl_bcm     == cpl_bcm);
                        dlsc_assert(tlp.cpl_bytes   == cpl_bytes);
                        dlsc_assert(tlp.cpl_tag     == cpl_tag);
                        dlsc_assert(tlp.cpl_addr    == cpl_addr);
                    }

                    if(tlp.type_mem || tlp.type_io || tlp.type_cfg) {
                        dlsc_assert(tlp.be_last     == be_last);
                        dlsc_assert(tlp.be_first    == be_first);
                    }

                    if(tlp.type_msg) {
                        dlsc_assert(tlp.msg_code    == msg_code);
                    }

                    if(tlp.type_mem || tlp.type_io) {
                        dlsc_assert(tlp.dest_addr   == (dest_addr << 2));
                    }

                    if(tlp.type_cfg || tlp.type_cpl) {
                        dlsc_assert(tlp.dest_id     == dest_id);
                    }

                    if(tlp.type_cfg) {
                        dlsc_assert(tlp.cfg_reg     == cfg_reg);
                    }
                }
            }
        }

        if(tlp_valid || !tlp_ready) {
            rand_bool->next();
            tlp_ready = *rand_bool;
        }
    }
}

void __MODULE__::stim_thread() {

    rst = 1;

    wait(100,SC_NS);
    wait(clk.posedge_event());

    rst = 0;
    
    wait(100,SC_NS);

    // random distribution for pcie_type
    scv_bag<pcie_type> type_bag;
    type_bag.push(TYPE_MEM,         30);
    type_bag.push(TYPE_MEM_LOCKED,  5);
    type_bag.push(TYPE_IO,          15);
    type_bag.push(TYPE_CONFIG_0,    5);
    type_bag.push(TYPE_CONFIG_1,    5);
    type_bag.push(TYPE_MSG_TO_RC,   1);
    type_bag.push(TYPE_MSG_BY_ADDR, 1);
    type_bag.push(TYPE_MSG_BY_ID,   1);
    type_bag.push(TYPE_MSG_FROM_RC, 1);
    type_bag.push(TYPE_MSG_LOCAL,   1);
    type_bag.push(TYPE_MSG_PME_RC,  1);
//    type_bag.push(TYPE_CPL,         30);
//    type_bag.push(TYPE_CPL_LOCKED,  5);

    scv_smart_ptr<pcie_type> type;
    type->set_mode(type_bag);

    scv_smart_ptr<bool> rand_bool;
    scv_smart_ptr<uint32_t> rand_32;
    scv_smart_ptr<uint64_t> rand_64;

    pcie_tlp tlp;
    vector<uint32_t> dw;
    vect_wrapper vw;

    for(int i=0;i<100;i++) {
        tlp.clear();

        type->next();
        tlp.set_type(*type);

        if(tlp.type_mem || tlp.type_io || tlp.type_cfg || tlp.type_cpl) {
            rand_32->next();
            int length = *rand_32 & 0x3FF;
            if(length == 0) length = 1;
            tlp.set_length(length);

            rand_32->next();
            tlp.set_byte_enables( (*rand_32>>4) & 0xF, *rand_32 & 0xF);

            rand_bool->next();
            if(*rand_bool) {
                // generate data payload
                dw.clear();
                for(int i=0;i<tlp.length;i++) {
                    rand_32->next();
                    dw.push_back(*rand_32);
                }
                tlp.set_data(dw);
            }
        }

        if(tlp.type_mem || tlp.type_io || tlp.type == TYPE_MSG_BY_ADDR) {
            rand_64->next();
            rand_bool->next();
            if(*rand_bool) {
                tlp.set_address(*rand_64 & 0xFFFFFFFFFFFFFFFC);
            } else {
                tlp.set_address(*rand_64 & 0xFFFFFFFC);
            }
        }

        rand_32->next();
        tlp.set_traffic_class(*rand_32 & 0x7);

        rand_bool->next();
        if(*rand_bool) {
            rand_32->next();
            tlp.set_digest(*rand_32);
        }

        rand_32->next();
        tlp.set_source(*rand_32 & 0xFFFF);

//        cout << "*** stim thread *** " << endl << tlp;

        dw.clear();
        tlp.serialize(dw);
        vw.v = dw;

        rx_fifo.write(vw);

        rand_32->next();
        int del = *rand_32 & 0xFFFF;

        //wait(del,SC_NS);
    }

    wait(1000,SC_NS);

    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(10,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

std::ostream& operator << ( std::ostream &os, const vect_wrapper &vw ) {
    return os;
}

/*AUTOTRACE(__MODULE__)*/

