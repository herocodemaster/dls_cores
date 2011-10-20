//######################################################################
#sp interface

#include <systemperl.h>
#include <tlm.h>

#include <deque>
#include <map>

#include <boost/shared_ptr.hpp>

#include "dlsc_tlm_target_nb.h"
#include "dlsc_tlm_initiator_nb.h"
#include "dlsc_pcie_tlp.h"

using namespace dlsc;
using namespace dlsc::pcie;

SC_MODULE(__MODULE__) {
public:

    // ********** Pins **********

    // ** System Interface **
    sc_core::sc_in<bool>        sys_clk;
    sc_core::sc_in<bool>        sys_reset;
    sc_core::sc_out<bool>       received_hot_reset;
    
    // ** Common Interface **
    sc_core::sc_out<bool>       user_clk_out;
    sc_core::sc_out<bool>       user_reset_out;
    sc_core::sc_out<bool>       user_lnk_up;
    sc_core::sc_in<uint32_t>    fc_sel;
    sc_core::sc_out<uint32_t>   fc_ph;
    sc_core::sc_out<uint32_t>   fc_pd;
    sc_core::sc_out<uint32_t>   fc_nph;
    sc_core::sc_out<uint32_t>   fc_npd;
    sc_core::sc_out<uint32_t>   fc_cplh;
    sc_core::sc_out<uint32_t>   fc_cpld;

    // ** Transmit Interface **
    sc_core::sc_out<bool>       s_axis_tx_tready;
    sc_core::sc_in<bool>        s_axis_tx_tvalid;
    sc_core::sc_in<bool>        s_axis_tx_tlast;
    sc_core::sc_in<uint32_t>    s_axis_tx_tdata;
    sc_core::sc_in<uint32_t>    s_axis_tx_tuser;
    sc_core::sc_out<uint32_t>   tx_buf_av;
    sc_core::sc_out<bool>       tx_err_drop;
    sc_core::sc_out<bool>       tx_cfg_req;
    sc_core::sc_in<bool>        tx_cfg_gnt;

    // ** Receive Interface **
    sc_core::sc_in<bool>        m_axis_rx_tready;
    sc_core::sc_out<bool>       m_axis_rx_tvalid;
    sc_core::sc_out<bool>       m_axis_rx_tlast;
    sc_core::sc_out<uint32_t>   m_axis_rx_tdata;
    sc_core::sc_out<uint32_t>   m_axis_rx_tuser;
    sc_core::sc_in<bool>        rx_np_ok;

    // ** Configuration Interface **
    // Configuration space read
    sc_core::sc_out<uint32_t>   cfg_do;
    sc_core::sc_out<bool>       cfg_rd_wr_done;
    sc_core::sc_in<uint32_t>    cfg_dwaddr;
    sc_core::sc_in<bool>        cfg_rd_en;
    // Configuration space values
    sc_core::sc_out<uint32_t>   cfg_bus_number;
    sc_core::sc_out<uint32_t>   cfg_device_number;
    sc_core::sc_out<uint32_t>   cfg_function_number;
    sc_core::sc_out<uint32_t>   cfg_status;
    sc_core::sc_out<uint32_t>   cfg_command;
    sc_core::sc_out<uint32_t>   cfg_dstatus;
    sc_core::sc_out<uint32_t>   cfg_dcommand;
    sc_core::sc_out<uint32_t>   cfg_lstatus;
    sc_core::sc_out<uint32_t>   cfg_lcommand;
    // Power management
    sc_core::sc_out<bool>       cfg_to_turnoff;
    sc_core::sc_in<bool>        cfg_turnoff_ok;
    sc_core::sc_in<bool>        cfg_pm_wake;
    sc_core::sc_out<uint32_t>   cfg_pcie_link_state;
    // Misc
    sc_core::sc_in<bool>        cfg_trn_pending;
    sc_core::sc_in<uint64_t>    cfg_dsn;
    
    // ** Interrupts **
    sc_core::sc_in<bool>        cfg_interrupt;
    sc_core::sc_out<bool>       cfg_interrupt_rdy;
    sc_core::sc_in<bool>        cfg_interrupt_assert;
    sc_core::sc_in<uint32_t>    cfg_interrupt_di;
    sc_core::sc_out<uint32_t>   cfg_interrupt_do;
    sc_core::sc_out<uint32_t>   cfg_interrupt_mmenable;
    sc_core::sc_out<bool>       cfg_interrupt_msienable;

    // ** Error Reporting Signals **
    sc_core::sc_in<bool>        cfg_err_ecrc;
    sc_core::sc_in<bool>        cfg_err_ur;
    sc_core::sc_in<bool>        cfg_err_cpl_timeout;
    sc_core::sc_in<bool>        cfg_err_cpl_abort;
    sc_core::sc_in<bool>        cfg_err_posted;
    sc_core::sc_in<bool>        cfg_err_cor;
    sc_core::sc_in<uint64_t>    cfg_err_tlp_cpl_header;
    sc_core::sc_out<bool>       cfg_err_cpl_rdy;
    sc_core::sc_in<bool>        cfg_err_locked;


    // ********** TLM **********

    // ** Initiator **
    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction i_transaction;
    typedef dlsc_tlm_initiator_nb<uint32_t>::socket_type i_socket_type;
    i_socket_type initiator_socket;
    dlsc_tlm_initiator_nb<uint32_t> *initiator;

    // ** Target **
    typedef dlsc_tlm_target_nb<__MODULE__,uint32_t>::transaction t_transaction;
    typedef dlsc_tlm_target_nb<__MODULE__,uint32_t>::socket_type t_socket_type;
    t_socket_type target_socket;
    dlsc_tlm_target_nb<__MODULE__,uint32_t> *target;
    virtual void target_callback(t_transaction ts);


    // ********** Functions **********

    void                        set_bar(int bar, bool enabled, uint64_t mask, uint64_t base, bool b64=false);
    void                        set_interrupt_mode(bool msi);
    bool                        get_interrupt(int index, bool ack=true);

    
    /*AUTOMETHODS*/

private:

    typedef boost::shared_ptr<dlsc::pcie::pcie_tlp> tlp_type;

    void                        user_clk_thread();

    void                        init_method();
    void                        clk_method();
    void                        rst_method();

    // Properties
    unsigned int                max_payload_size;
    unsigned int                max_read_request;
    unsigned int                rcb;                // read completion boundary (64 or 128 bytes)
    uint64_t                    rcb_mask;
    bool                        bar_enabled[7];     // BAR0-BAR5,ROM
    uint64_t                    bar_mask[7];
    uint64_t                    bar_base[7];

    // Error interface
    void                        err_method();

    // Configuration interface
    void                        cfg_method();
    bool                        cfg_rd_pending;

    // Interrupt interface
    void                        int_method();
    bool                        int_state[32];

    // Transmit interface
    std::deque<uint32_t>        txi_queue;          // words for a single TLP being receive over TX
    bool                        txi_dsc;            // discontinued
    bool                        txi_str;            // streaming
    bool                        txi_str_err;        // streaming error
    bool                        txi_err;            // error forward
    int                         txi_pct;            // ready percent
    void                        txi_method();
    void                        txi_tlp_process(tlp_type &tlp);
    void                        txi_tlp_read_process(tlp_type &tlp);
    void                        txi_tlp_write_process(tlp_type &tlp);

    // Receive interface
    std::deque<uint32_t>        rxi_queue;          // words for a single TLP to be sent over RX
    int                         rxi_pct;            // valid percent
    bool                        rxi_arb_ini;        // select initiator or target queue
    void                        rxi_method();

    // TLM initiator
    struct                      initiator_state;
    typedef boost::shared_ptr<initiator_state> ini_type;
    std::deque<ini_type>        ini_queue;
    std::deque<tlp_type>        ini_rxi_tlp_queue;  // completion TLPs to be sent over RX
    void                        ini_method();
    void                        ini_launch(ini_type &ini);
    void                        ini_complete(ini_type &ini);
    bool                        ini_get_rxi_tlp(tlp_type &tlp);

    // TLM target
    struct                      target_state;
    typedef boost::shared_ptr<target_state> tgt_type;
    std::deque<t_transaction>   tgt_ts_queue;       // buffer TLM transactions until we're ready for them
    std::deque<tgt_type>        tgt_rxi_queue;      // buffer transactions/TLPs until they're sent over PCIe (at which point they move to tgt_cpl_queue if non-posted)
    std::deque<tgt_type>        tgt_cpl_queue;      // buffer transactions/TLPs that have been sent over PCIe but need a response
    std::deque<unsigned int>    tgt_tag_queue;      // track available PCIe tags
    void                        tgt_method();
    void                        tgt_write(t_transaction &ts);
    void                        tgt_read(t_transaction &ts);
    bool                        tgt_get_rxi_tlp(tlp_type &tlp);
    void                        tgt_complete(tlp_type &tlp);
    bool                        tgt_allow_io;

};

struct __MODULE__::initiator_state {
    initiator_state() { launched = false; };
    tlp_type                    tlp;        // requesting TLP
    bool                        launched;
    std::deque<i_transaction>   ts_queue;   // resultant transaction(s)
    // fields for response TLPs
    std::deque<unsigned int>    bytes_remaining_queue;
    std::deque<unsigned int>    lower_addr_queue;
};

struct __MODULE__::target_state {
    // track state of non-posted requests (all reads and I/O writes)
    target_state() { tlp_index = 0; };
    t_transaction               ts;         // TLM transaction
    std::deque<tlp_type>        tlp_queue;  // TLPs generated for TLM transaction
    int                         tlp_index;  // index into tlp_queue for tgt_get_rxi_tlp
    std::deque<uint32_t>        data;       // accumulated response data (for reads)
};

//######################################################################
#sp implementation

/*AUTOSUBCELL_INCLUDE*/

#include <algorithm>
#include "dlsc_common.h"

SP_CTOR_IMP(__MODULE__) /*AUTOINIT*/,
    initiator_socket("initiator_socket"),
    target_socket("target_socket")
{
    SP_AUTO_CTOR;
    
    initiator = new dlsc_tlm_initiator_nb<uint32_t>("initiator",128); // max_length = 128 dwords = 512 bytes
        initiator->socket.bind(initiator_socket);
    
    target = new dlsc_tlm_target_nb<__MODULE__,uint32_t>("target", this, &__MODULE__::target_callback, 1024);
        target_socket.bind(target->socket);

    SC_THREAD(user_clk_thread);
    
    SC_METHOD(clk_method);
        sensitive << user_clk_out.pos();

    max_payload_size    = 512;
    max_read_request    = 4096;
    rcb                 = 128;  // 128 or 64
    rcb_mask            = (rcb==128) ? 0x7F: 0x3F; // [6:0] : [5:0]

    bar_enabled[0]      = true;
    bar_mask[0]         = 0xFFFFFFFF;
    bar_base[0]         = 0;

    for(int i=1;i<7;++i) {
        bar_enabled[i]      = false;
        bar_mask[i]         = 0;
        bar_base[i]         = 0;
    }

    txi_pct             = 95;
    rxi_pct             = 95;

    tgt_allow_io        = true;

    init_method();
}

void __MODULE__::set_bar(int bar, bool enabled, uint64_t mask, uint64_t base, bool b64) {
    assert(bar >= 0 && bar < 7);
    bar_enabled[bar] = enabled;
    if(!enabled) {
        return;
    }
    if(!b64) {
        assert( (mask >> 32) == 0 );
        assert( (base >> 32) == 0 );
    } else {
        assert( (bar % 2) == 0 );
        assert(!bar_enabled[bar+1]);    // 64-bit BARs require two adjacent registers
    }
    assert( (mask & base) == 0 );
    bar_mask[bar]   = mask;
    bar_base[bar]   = base;
}

void __MODULE__::set_interrupt_mode(bool msi) {
    for(int i=0;i<32;++i) {
        if(int_state[i]) {
            dlsc_warn("interrupt mode changed with interrupts pending");
            break;
        }
    }
    cfg_interrupt_msienable = msi;
}

bool __MODULE__::get_interrupt(int index, bool ack) {
    assert(index >= 0 && index < 32);
    bool interrupt = int_state[index];
    if(ack && cfg_interrupt_msienable) {
        int_state[index] = false;
    }
    return interrupt;
}

void __MODULE__::user_clk_thread() {

    user_clk_out        = 0;

    while(true) {
        wait(8,SC_NS);
        user_clk_out        = !user_clk_out;
    }

}

void __MODULE__::init_method() {

    // config
    cfg_rd_pending      = false;

    // interrupts
    std::fill(int_state,int_state+32,false);

    // transmit
    txi_queue.clear();
    txi_dsc             = false;
    txi_str             = false;
    txi_str_err         = false;
    txi_err             = false;

    // recieve
    rxi_queue.clear();
    rxi_arb_ini         = false;

    // initiator
    ini_queue.clear();
    ini_rxi_tlp_queue.clear();
    
    // target
    while(!tgt_ts_queue.empty()) {
        dlsc_verb("lost transaction to reset (tgt_ts_queue)");
        t_transaction ts = tgt_ts_queue.front(); tgt_ts_queue.pop_front();
        ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        ts->complete();
    }
    while(!tgt_rxi_queue.empty()) {
        dlsc_verb("lost transaction to reset (tgt_rxi_queue)");
        t_transaction ts = tgt_rxi_queue.front()->ts; tgt_rxi_queue.pop_front();
        ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        ts->complete();
    }
    while(!tgt_cpl_queue.empty()) {
        dlsc_verb("lost transaction to reset (tgt_cpl_queue)");
        t_transaction ts = tgt_cpl_queue.front()->ts; tgt_cpl_queue.pop_front();
        ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        ts->complete();
    }
    tgt_tag_queue.clear();
    for(int i=0;i<32;++i) {
        tgt_tag_queue.push_back(i);
    }

}

void __MODULE__::clk_method() {

    user_reset_out      = sys_reset;

    if(user_reset_out) {
        rst_method();
    } else {
        err_method();
        cfg_method();
        int_method();
        txi_method();
        ini_method();
        tgt_method();
        rxi_method();
    }
}

void __MODULE__::rst_method() {
    received_hot_reset      = 0;
//  user_clk_out            = 0;
//  user_reset_out          = 0;
    user_lnk_up             = 0;
    fc_ph                   = 32;   // TODO
    fc_pd                   = 256;  // TODO
    fc_nph                  = 0;
    fc_npd                  = 0;
    fc_cplh                 = 0;
    fc_cpld                 = 0;
    s_axis_tx_tready        = 0;
    tx_buf_av               = 0;
    tx_err_drop             = 0;
    tx_cfg_req              = 0;
    m_axis_rx_tvalid        = 0;
    m_axis_rx_tlast         = 0;
    m_axis_rx_tdata         = 0;
    m_axis_rx_tuser         = 0;
    cfg_do                  = 0;
    cfg_rd_wr_done          = 0;
    cfg_bus_number          = 0;
    cfg_device_number       = 0;
    cfg_function_number     = 0;
    cfg_status              = 0;
    cfg_command             = 0;
    cfg_dstatus             = 0;
    cfg_dcommand            = 0;
    cfg_lstatus             = 0;
    cfg_lcommand            = 0;
    cfg_to_turnoff          = 0;
    cfg_pcie_link_state     = 0;
    cfg_interrupt_rdy       = 0;
    cfg_interrupt_do        = 0;
    cfg_interrupt_mmenable  = 0;
//  cfg_interrupt_msienable = 0;
    cfg_err_cpl_rdy         = 0;

    // TODO
    cfg_command             = (0x1<<2);             // bus master enable
    cfg_dcommand            = (0x2<<5) | (0x5<<12); // max payload 512; max read request 4096
    cfg_lcommand            = (0x1<<3);             // RCB 128
    
    init_method();
}

void __MODULE__::err_method() {

    if( (rand()%1000) == 42 ) {
        cfg_err_cpl_rdy         = 1;
    }

    if(cfg_err_ecrc) {
        dlsc_info("got cfg_err_ecrc");
    }
    if(cfg_err_cpl_timeout) {
        dlsc_info("got cfg_err_cpl_timeout");
    }
    if(cfg_err_cor) {
        dlsc_info("got cfg_err_cor");
    }

    if(cfg_err_cpl_rdy && (cfg_err_ur || cfg_err_cpl_abort)) {
        if(cfg_err_ur && cfg_err_cpl_abort) {
            dlsc_error("cfg_err_ur and cfg_err_cpl_abort should not assert simultaneously");
        }
        sc_bv<48> header = cfg_err_tlp_cpl_header.read();

        // errors are reported via separate interface..
        // translate them into TLPs to be processed normally
        tlp_type tlp(new pcie_tlp);
        tlp->set_type(TYPE_CPL);
        tlp->set_completion_status(cfg_err_ur ? CPL_UR : CPL_CA);
        tlp->set_lower_addr(header.range(47,41).to_uint());
        tlp->set_byte_count(header.range(40,29).to_uint());
        tlp->set_traffic_class(header.range(28,26).to_uint());
        tlp->set_attributes(header[25].to_bool(),header[24].to_bool());
        tlp->set_destination(header.range(23,8).to_uint());
        tlp->set_completion_tag(header.range(7,0).to_uint());
        tlp->set_source(0); // TODO {bus_number,device_number,function_number}

        // process the TLP as if it had come in on the TX interface
        txi_tlp_process(tlp);

        if( (rand()%100) < 50 ) {
            cfg_err_cpl_rdy         = 0;
        }
    } else {
        if(cfg_err_ur) {
            dlsc_error("cfg_err_ur cannot be asserted without cfg_err_cpl_rdy");
        }
        if(cfg_err_cpl_abort) {
            dlsc_error("cfg_err_cpl_abort cannot be asserted without cfg_err_cpl_rdy");
        }
    }

}

void __MODULE__::cfg_method() {

    if(cfg_rd_en) {
        if(cfg_rd_pending) {
            dlsc_error("cfg_rd_en should only be asserted for 1 cycle");
        }
        cfg_rd_pending  = true;
        if(cfg_dwaddr > 0x3FF) {
            dlsc_error("cfg_dwaddr must be less than 0x3FF");
        }
    }

    if(cfg_rd_wr_done) {
        cfg_rd_wr_done  = 0;
        cfg_do          = 0;
        cfg_rd_pending  = 0;
    }

    if(cfg_rd_pending) {
        if((rand()%100) < 30) {
            cfg_rd_wr_done  = 1;
            cfg_do          = cfg_dwaddr;   // address pattern
        }
    }

}

void __MODULE__::int_method() {

    if(cfg_interrupt_rdy) {
        cfg_interrupt_rdy   = 0;
        if(!cfg_interrupt) {
            dlsc_error("cfg_interrupt should remain asserted until cfg_interrupt_rdy");
        }
        int i = cfg_interrupt_di.read();
        if(cfg_interrupt_msienable) {
            // MSI
            int lim = (1<<cfg_interrupt_mmenable.read())-1;
            assert(lim >= 0 && lim < 32);
            if(i > lim) {
                dlsc_error("cfg_interrupt_di (" << i << ") exceeds cfg_interrupt_mmenable limit (" << lim << ")");
            } else {
                dlsc_verb("interrupt " << i << " asserted");
                int_state[i] = true;
            }
        } else {
            // legacy
            if(i > 0x3) {
                dlsc_error("cfg_interrupt_di (" << i << ") must be <= 0x3 in legacy mode");
            } else {
                if(int_state[i] && cfg_interrupt_assert) {
                    dlsc_warn("interrupt " << i << " already asserted");
                } else if(!int_state[i] && !cfg_interrupt_assert) {
                    dlsc_warn("interrupt " << i << " already deasserted");
                }
                int_state[i] = cfg_interrupt_assert;
                dlsc_verb("interrupt " << i << (int_state[i] ? " asserted" : " deasserted"));
            }
        }
    } else if(cfg_interrupt && (rand()%100) < 25) {
        cfg_interrupt_rdy   = 1;
    }
}

void __MODULE__::txi_method() {

    tx_err_drop         = 0;

    if(s_axis_tx_tready) {

        if(s_axis_tx_tvalid) {

            if(s_axis_tx_tuser.read() & (1<<3)) {
                // source discontinue
                txi_dsc             = true;
            }
            if(s_axis_tx_tuser.read() & (1<<1)) {
                // poison
                txi_err             = true;
            }
            if(!(s_axis_tx_tuser.read() & (1<<2)) == txi_str) {
                // streaming
                if(txi_queue.empty()) {
                    txi_str             = true;
                } else {
                    // must remain constant after first dword
                    dlsc_error("TX: streaming must be asserted for entire TLP");
                    txi_str_err         = true;
                }
            }

            txi_queue.push_back(s_axis_tx_tdata);

            if(s_axis_tx_tlast) {
                if(txi_dsc) {
                    dlsc_verb("TX: discontinued");
                }
                if(txi_str_err) {
                    dlsc_error("TX: streaming error");
                }
                if(!txi_dsc && !txi_str_err) {
                    tlp_type tlp(new pcie_tlp);
                    if(!tlp->deserialize(txi_queue)) {
                        dlsc_error("TX: failed to deserialize TLP");
                    } else {
                        if(txi_err) {
                            dlsc_verb("TX: poisoned");
                            tlp->set_poisoned(true);
                        }
                        txi_tlp_process(tlp);
                    }
                }

                txi_queue.clear();
                txi_dsc             = false;
                txi_str             = false;
                txi_str_err         = false;
                txi_err             = false;
            }

        } else if(!txi_queue.empty()) {
            if(txi_str) {
                // streaming, but data wasn't presented on consecutive cycles
                dlsc_error("TX: must present streaming data on concsecutive cycles");
                tx_err_drop         = 1;
                txi_str_err         = true;
            }
        }

    }

    s_axis_tx_tready    = txi_str || (rand()%100) < txi_pct;

}

void __MODULE__::txi_tlp_process(tlp_type &tlp) {

    if(!tlp->validate()) {
        dlsc_error("invalid TLP");
        return;
    }

    if(tlp->type_cfg) {
        dlsc_error("endpoint can't make config request");
        return;
    }

    if(tlp->type_msg) {
        dlsc_warn("message requests not supported by model");
        return;
    }

    if(tlp->type_cpl) {
        // completion
        tgt_complete(tlp);
        return;
    }

    if(!(tlp->type_mem || tlp->type_io)) {
        dlsc_error("must be memory or I/O request..");
        return;
    }

    // send transaction to initiator
    ini_type ini(new initiator_state);
    ini->tlp = tlp;
    ini_queue.push_back(ini);
}

void __MODULE__::rxi_method() {

    if(rxi_queue.empty()) {
        // TODO: implement TLP re-ordering
        tlp_type tlp;
        
        if( ( rxi_arb_ini && ini_get_rxi_tlp(tlp)) ||   // ini gets priority when arb_ini is set
            (                tgt_get_rxi_tlp(tlp)) ||   // fall back to tgt if arb_ini isn't set (or ini had nothing)
            (!rxi_arb_ini && ini_get_rxi_tlp(tlp))      // fall back to ini (again, in case arb_ini wasn't set and tgt had nothing)
        ) {
            rxi_arb_ini         = !rxi_arb_ini;
            
            assert(tlp->validate());
            tlp->serialize(rxi_queue);

            uint32_t tuser      = 0;

            if(tlp->ep) {
                // poisoned
                tuser               |= (1<<1);
            }

            if(tlp->type_mem || tlp->type_io) {
                // BARs
                int bar = -1;
                for(int i=0;i<=7;++i) {
                    if( bar_enabled[i] && (tlp->dest_addr & ~bar_mask[i]) == bar_base[i] ) {
                        bar = i;
                        break;
                    }
                }
                assert(bar >= 0 && bar < 7);
                tuser               |= (1<<(bar+2));
            }

            m_axis_rx_tuser     = tuser;
        }
    }

    if(!m_axis_rx_tvalid || m_axis_rx_tready) {

        if(!rxi_queue.empty() && (rand()%100) < rxi_pct) {

            m_axis_rx_tvalid    = 1;
            m_axis_rx_tdata     = rxi_queue.front(); rxi_queue.pop_front();
            m_axis_rx_tlast     = rxi_queue.empty();

        } else {

            m_axis_rx_tvalid    = 0;
            m_axis_rx_tdata     = 0;
            m_axis_rx_tlast     = 0;

        }

    }

}


void __MODULE__::ini_method() {

    bool write      = false;

    for(std::deque<ini_type>::iterator it = ini_queue.begin(); it != ini_queue.end();) {

        ini_type ini = (*it);

        // need to generate (launch) transactions..
        if(!ini->launched && (ini->tlp->is_write() || !write)) {
            assert(ini->ts_queue.empty());
            ini_launch(ini);
        }

        // need to complete transactions
        while(!ini->ts_queue.empty() && ini->ts_queue.front()->nb_done()) {
            ini_complete(ini);
        }

        if(ini->launched && ini->ts_queue.empty()) {
            // completed all transactions
            it = ini_queue.erase(it);
        } else {
            it++;
            if(ini->tlp->is_write()) {
                // outstanding write will block later reads
                write           = true;
            }
        }

    }

}

void __MODULE__::ini_launch(ini_type &ini) {

    tlp_type tlp = ini->tlp;

    // data (write only)
    std::deque<uint32_t> data = tlp->data;

    // strobes (read or write)
    std::deque<uint32_t> strb;

    strb.resize(tlp->size()-1);
    std::fill(strb.begin(),strb.end(),0xF);
    strb[0] = tlp->be_first;
    if(tlp->size() > 1) strb.push_back(tlp->be_last);

    uint64_t addr_first = tlp->dest_addr;
    uint64_t addr_last  = addr_first + (tlp->size()*4);
    
    uint64_t addr       = addr_first;

    bool first          = true;
    bool last           = false;

    unsigned int bytes_remaining = (tlp->size()*4);

    if(tlp->size() > 1) {
        // consider both BE fields
        // first
             if(tlp->be_first & 0x1) bytes_remaining -= 0;
        else if(tlp->be_first & 0x2) bytes_remaining -= 1;
        else if(tlp->be_first & 0x4) bytes_remaining -= 2;
        else                         bytes_remaining -= 3;
        // last
             if(tlp->be_last  & 0x8) bytes_remaining -= 0;
        else if(tlp->be_last  & 0x4) bytes_remaining -= 1;
        else if(tlp->be_last  & 0x2) bytes_remaining -= 2;
        else                         bytes_remaining -= 3;
    } else {
        // consider only first BE field
        if((tlp->be_first & 0x9) == 0x9)
            bytes_remaining = 4;
        else if( ((tlp->be_first & 0x5) == 0x5) || ((tlp->be_first & 0xA) == 0xA) )
            bytes_remaining = 3;
        else if( (tlp->be_first == 0x3) || (tlp->be_first == 0x6) || (tlp->be_first == 0xC) )
            bytes_remaining = 2;
        else
            bytes_remaining = 1;
    }

    while(!last) {

        // compute start/end addresses for this transaction
        uint64_t addr_next  = (addr & ~rcb_mask) + rcb;
        if(tlp->size() <= (max_payload_size/4) || addr_next >= addr_last) {
            // can complete in a single TLP
            addr_next           = addr_last;
            last                = true;
        }

        unsigned int offset = (addr>>2)-(addr_first>>2);
        unsigned int length = (addr_next>>2)-(addr>>2);

        // launch transaction
        i_transaction ts;
        if(tlp->is_write()) {
            ts = initiator->nb_write(
                addr,
                data.begin()+offset,
                data.begin()+offset+length,
                strb.begin()+offset,
                strb.begin()+offset+length);
        } else {
            ts = initiator->nb_read(addr,length);
        }

        ini->ts_queue.push_back(ts);

        // collect fields for response TLP
        unsigned int byte_offset = 0x0;

        if(first) {
                 if(tlp->be_first & 0x1) byte_offset = 0x0;
            else if(tlp->be_first & 0x2) byte_offset = 0x1;
            else if(tlp->be_first & 0x4) byte_offset = 0x2;
            else if(tlp->be_first & 0x8) byte_offset = 0x3;
            else                         byte_offset = 0x0; // "zero"-length read
        }
        
        unsigned int byte_addr = (addr + byte_offset) & 0x7F;

        ini->lower_addr_queue.push_back(byte_addr);
        ini->bytes_remaining_queue.push_back(bytes_remaining);

        bytes_remaining -= ((length*4) - byte_offset);
        
        addr                = addr_next;
        first               = false;
    }

    ini->launched = true;
}

void __MODULE__::ini_complete(ini_type &ini) {

    i_transaction ts = ini->ts_queue.front(); ini->ts_queue.pop_front();
    assert(ts->nb_done());

    if(ini->tlp->is_posted()) {
        // no response TLP needed
        return;
    }

    tlp_type req_tlp = ini->tlp;
    tlp_type tlp(new pcie_tlp);

    bool success = (ts->b_status() == tlm::TLM_OK_RESPONSE);

    if(!success) {
        // don't need to send any more error TLPs
        // (after this one)
        ini->ts_queue.clear();
    }

    switch(ts->b_status()) {
        case tlm::TLM_OK_RESPONSE:
            tlp->set_completion_status(CPL_SC);
            break;
        case tlm::TLM_INCOMPLETE_RESPONSE:
        case tlm::TLM_GENERIC_ERROR_RESPONSE:
            tlp->set_completion_status(CPL_CA);
            break;
        default:
            tlp->set_completion_status(CPL_UR);
    }
    
    tlp->set_type(TYPE_CPL);
    tlp->set_traffic_class(req_tlp->tc);
    tlp->set_source( rand() & 0xFFFF );
    tlp->set_destination(req_tlp->src_id);
    tlp->set_completion_tag(req_tlp->src_tag);

    if(success && req_tlp->is_read()) {
        std::deque<uint32_t> data;
        ts->b_read(data);
        tlp->set_data(data);
    }

    if(req_tlp->type_mem && req_tlp->is_read()) {
        tlp->set_byte_count(ini->bytes_remaining_queue.front());
        tlp->set_lower_addr(ini->lower_addr_queue.front());
    } else {
        tlp->set_byte_count(4);
        tlp->set_lower_addr(0);
    }

    ini->bytes_remaining_queue.pop_front();
    ini->lower_addr_queue.pop_front();

    // send it
    ini_rxi_tlp_queue.push_back(tlp);
}

bool __MODULE__::ini_get_rxi_tlp(tlp_type &tlp) {
    if(ini_rxi_tlp_queue.empty()) {
        return false;
    }
    tlp = ini_rxi_tlp_queue.front();
    ini_rxi_tlp_queue.pop_front();
    return true;
}



void __MODULE__::target_callback(t_transaction ts) {
    tgt_ts_queue.push_back(ts);
}

void __MODULE__::tgt_method() {
    if(!tgt_ts_queue.empty() && !tgt_tag_queue.empty()) {
        t_transaction ts = tgt_ts_queue.front(); tgt_ts_queue.pop_front();

        if(ts->is_write()) {
            tgt_write(ts);
        } else {
            tgt_read(ts);
        }
    }
}

void __MODULE__::tgt_write(t_transaction &ts) {

    std::deque<uint32_t> data_all;
    std::deque<uint32_t> strb_all;
    ts->get_data(data_all);
    if(ts->has_strobes()) {
        ts->get_strobes(strb_all);
        assert(data_all.size() == strb_all.size());
    }
    assert(data_all.size() == ts->size());

    uint64_t addr = ts->get_address() & ~((uint64_t)0x3);
    unsigned int cnt = 0;

    tgt_type tgt(new target_state);
    tgt->ts     = ts;

    while(cnt < ts->size()) {
        unsigned int be_first = 0xF, be_last = 0xF;

        std::deque<uint32_t> data;

        if(ts->has_strobes()) {
            // first word
            be_first = strb_all.front(); strb_all.pop_front();
            data.push_back(data_all.front()); data_all.pop_front();
            if(be_first == 0x8 || be_first == 0xC || be_first == 0xE || be_first == 0xF) { 
                // more words
                while(be_last == 0xF && !data_all.empty() && data.size() < (max_payload_size/4)) {
                    if(strb_all.front() != 0xF &&
                       strb_all.front() != 0x7 &&
                       strb_all.front() != 0x3 &&
                       strb_all.front() != 0x1
                    ) break;
                    be_last = strb_all.front(); strb_all.pop_front();
                    data.push_back(data_all.front()); data_all.pop_front();
                }
            }
        } else {
            unsigned int copy_cnt = max_payload_size/4;
            if(copy_cnt > data_all.size()) copy_cnt = data_all.size();
            data.resize(copy_cnt);
            std::copy(data_all.begin(),data_all.begin()+copy_cnt,data.begin());
            data_all.erase(data_all.begin(),data_all.begin()+copy_cnt);
        }

        if(data.size() == 1) be_last = 0;

        // create TLP
        tlp_type tlp(new pcie_tlp);

        tlp->set_type(TYPE_MEM);
        tlp->set_source( rand() & 0xFFFF );
        tlp->set_address(addr);
        tlp->set_byte_enables(be_first,be_last);
        tlp->set_data(data);

        if(tgt_allow_io && !tlp->fmt_4dw && (ts->size() == 1) && (rand()%100) < 25) {
            // I/O instead of MEM
            tlp->set_type(TYPE_IO);
            tlp->set_tag(tgt_tag_queue.front()); tgt_tag_queue.pop_front();
        }

        // queue TLP
        tgt->tlp_queue.push_back(tlp);

        cnt     += data.size();
        addr    += data.size()*4;
    }

    // send it
    tgt_rxi_queue.push_back(tgt);
}

void __MODULE__::tgt_read(t_transaction &ts) {

    assert(!tgt_tag_queue.empty());

    // okay for now; may override later
    ts->set_response_status(tlm::TLM_OK_RESPONSE);

    if(ts->size() > (max_read_request/4)) {
        dlsc_warn("max_read_request exceeded");
        ts->set_response_status(tlm::TLM_BURST_ERROR_RESPONSE);
        ts->complete();
        return;
    }

    tlp_type tlp(new pcie_tlp);
    tgt_type tgt(new target_state);
    tgt->ts     = ts;
    tgt->tlp_queue.push_back(tlp);

    tlp->set_type(TYPE_MEM);
    tlp->set_source( rand() & 0xFFFF );
    tlp->set_address(ts->get_address() & ~((uint64_t)0x3));
    tlp->set_byte_enables(0xF,(ts->size()>1) ? 0xF : 0);
    tlp->set_length(ts->size());
    tlp->set_tag(tgt_tag_queue.front()); tgt_tag_queue.pop_front();

    if(tgt_allow_io && !tlp->fmt_4dw && (ts->size() == 1) && (rand()%100) < 25) {
        // I/O instead of MEM
        tlp->set_type(TYPE_IO);
    }

    // send it
    tgt_rxi_queue.push_back(tgt);
}

bool __MODULE__::tgt_get_rxi_tlp(tlp_type &tlp) {
    if(tgt_rxi_queue.empty()) {
        return false;
    }

    tgt_type tgt = tgt_rxi_queue.front();

    assert(!tgt->tlp_queue.empty() && (tgt->tlp_index < (int)tgt->tlp_queue.size()));
    tlp = tgt->tlp_queue[tgt->tlp_index];

    if(tlp->is_non_posted() && !rx_np_ok.read()) {
        return false;
    }

    if( ++tgt->tlp_index == (int)tgt->tlp_queue.size() ) {
        tgt_rxi_queue.pop_front();
        if(tlp->is_non_posted()) {
            // expecting a completion
            tgt_cpl_queue.push_back(tgt);
        } else {
            // complete now
            tgt->ts->set_response_status(tlm::TLM_OK_RESPONSE);
            tgt->ts->complete();
        }
    }

    return true;
}

void __MODULE__::tgt_complete(tlp_type &tlp) {

    // find the target_state
    tgt_type tgt;
    tlp_type tgt_tlp;
    bool tgt_valid = false;

    for(std::deque<tgt_type>::iterator it = tgt_cpl_queue.begin(); it != tgt_cpl_queue.end(); it++) {
        tgt = (*it);
        assert(tgt->tlp_queue.size() == 1);
        tgt_tlp = tgt->tlp_queue.front();
        if(tgt_tlp->src_id  == tlp->dest_id &&
           tgt_tlp->src_tag == tlp->cpl_tag
        ) {
            tgt_cpl_queue.erase(it);
            tgt_valid = true;
            break;
        }
    }

    if(!tgt_valid) {
        dlsc_error("unexpected completion: " << *tlp);
        return;
    }

    t_transaction ts = tgt->ts;
    bool error = false;

    if(tlp->cpl_status != CPL_SC) {
        ts->set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
        goto fin;
    }

    if(tgt_tlp->is_write()) {
        // non-posted write
        if(!tlp->data.empty()) {
            dlsc_error("write completion with data!");
            error = true;
        }
    }

    if(tgt_tlp->is_read()) {
        // read

        if(tlp->data.empty()) {
            dlsc_error("successful completion with no data!");
            error = true;
        }

        if(tlp->length > (ts->size() - tgt->data.size())) {
            dlsc_error("returned data exceeds request");
            error = true;
        }

        if(tgt_tlp->type_mem) {
            // only memory read completions set cpl_bytes and cpl_addr
            if(tlp->cpl_bytes != (ts->size() - tgt->data.size())*4) {
                dlsc_assert_equals( tlp->cpl_bytes , (ts->size() - tgt->data.size())*4 );
                error = true;
            }

            if(tlp->cpl_addr != ((tgt_tlp->dest_addr + tgt->data.size()*4) & 0x7F)) {
                dlsc_assert_equals( tlp->cpl_addr , ((tgt_tlp->dest_addr + tgt->data.size()*4) & 0x7F) );
                error = true;
            }

            if(!tgt->data.empty() && (tlp->cpl_addr & rcb_mask) != 0) {
                dlsc_error("RCB violated");
                error = true;
            }
        }
    }

    if(error) {
        dlsc_error("faulty TLP: " << *tlp);
        ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        goto fin;
    }

    if(tgt_tlp->is_write()) {
        // non-posted write
        ts->set_response_status(tlm::TLM_OK_RESPONSE);
        goto fin;
    }

    // append data
    tgt->data.resize(tgt->data.size()+tlp->data.size());
    std::copy(tlp->data.begin(),tlp->data.end(),tgt->data.end()-tlp->data.size());

    if(tgt->data.size() == ts->size()) {
        // done!
        ts->set_data(tgt->data);
        ts->set_response_status(tlm::TLM_OK_RESPONSE);
        goto fin;
    } else {
        // not done; put back on queue
        tgt_cpl_queue.push_back(tgt);
    }

    return;

fin:
    ts->complete();
    // return tag to queue
    tgt_tag_queue.push_back(tgt_tlp->src_tag);
}




/*AUTOTRACE(__MODULE__)*/


