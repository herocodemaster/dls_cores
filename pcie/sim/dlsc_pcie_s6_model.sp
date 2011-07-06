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
    dlsc_tlm_initiator_nb<uint32_t>::socket_type initiator_socket;
    dlsc_tlm_initiator_nb<uint32_t> *initiator;
    typedef dlsc_tlm_initiator_nb<uint32_t>::transaction i_transaction;

    // ** Target **
    tlm::tlm_target_socket<32> target_socket;
    dlsc_tlm_target_nb<__MODULE__,uint32_t> *target;
    typedef dlsc_tlm_target_nb<__MODULE__,uint32_t>::transaction t_transaction;
    virtual void target_callback(t_transaction ts);


    
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


    // Transmit interface
    std::deque<uint32_t>        txi_queue;
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
    std::deque<uint32_t>        rxi_queue;
    std::deque<tlp_type>        rxi_tlp_queue;
    int                         rxi_pct;            // valid percent
    void                        rxi_method();

    // Initiator
    struct                      initiator_state;
    typedef boost::shared_ptr<initiator_state> ini_type;
    std::deque<ini_type>        ini_queue;
    void                        ini_method();
    void                        ini_launch(ini_type &ini);
    void                        ini_complete(ini_type &ini);

    // Target
    struct                      target_state;
    typedef boost::shared_ptr<target_state> tgt_type;
    std::deque<t_transaction>   tgt_ts_queue;
    std::deque<tgt_type>        tgt_queue;
    std::deque<unsigned int>    tgt_tag_queue;
    void                        tgt_method();
    void                        tgt_write(t_transaction &ts);
    void                        tgt_read(t_transaction &ts);
    void                        tgt_read_complete(tlp_type &tlp);

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
    t_transaction               ts;         // TLM transaction
    tlp_type                    tlp;        // read request
    std::deque<uint32_t>        data;       // accumulated response data
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

    max_payload_size    = 128;
    max_read_request    = 4096;
    rcb                 = 128;  // 128 or 64
    rcb_mask            = (rcb==128) ? 0x7F: 0x3F; // [6:0] : [5:0]

    txi_pct             = 95;
    rxi_pct             = 95;

    init_method();
}

void __MODULE__::user_clk_thread() {

    user_clk_out        = 0;

    while(true) {
        wait(8,SC_NS);
        user_clk_out        = !user_clk_out;
    }

}

void __MODULE__::init_method() {

    txi_queue.clear();
    txi_dsc             = false;
    txi_str             = false;
    txi_str_err         = false;
    txi_err             = false;

    rxi_queue.clear();
    rxi_tlp_queue.clear();

    ini_queue.clear();

    while(!tgt_ts_queue.empty()) {
        dlsc_verb("lost transaction to reset");
        t_transaction ts = tgt_ts_queue.front(); tgt_ts_queue.pop_front();
        ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        ts->complete();
    }
    while(!tgt_queue.empty()) {
        dlsc_verb("lost transaction to reset");
        t_transaction ts = tgt_queue.front()->ts; tgt_queue.pop_front();
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
    cfg_interrupt_msienable = 0;
    cfg_err_cpl_rdy         = 0;
    
    init_method();
}

void __MODULE__::txi_method() {

    tx_err_drop         = 0;

    if(s_axis_tx_tready) {

        if(s_axis_tx_tvalid) {

            if(s_axis_tx_tuser & (1<<3)) {
                // source discontinue
                txi_dsc             = true;
            }
            if(s_axis_tx_tuser & (1<<2)) {
                // poison
                txi_err             = true;
            }
            if((s_axis_tx_tuser & (1<<1)) != txi_str) {
                // streaming
                if(!txi_queue.empty()) {
                    // must remain constant after first dword
                    dlsc_error("TX: streaming must be asserted for entire TLP");
                    txi_str_err         = true;
                }
                if(s_axis_tx_tuser & (1<<1)) {
                    txi_str             = true;
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
        tgt_read_complete(tlp);
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

    if(rxi_queue.empty() && !rxi_tlp_queue.empty()) {
        // TODO: correctly support rx_np_ok
        // TODO: implement TLP re-ordering

        tlp_type tlp        = rxi_tlp_queue.front(); rxi_tlp_queue.pop_front();
        assert(tlp->validate());
        tlp->serialize(rxi_queue);

        uint32_t tuser      = 0;

        if(tlp->ep) {
            // poisoned
            tuser               |= (1<<1);
        }

        // TODO: BARs

        m_axis_rx_tuser     = tuser;

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
        if(tlp->be_first & 0x9)
            bytes_remaining = 4;
        else if( (tlp->be_first & 0x5) || (tlp->be_first & 0xA) )
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
    tlp->set_source(0); // TODO
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
    rxi_tlp_queue.push_back(tlp);
}



void __MODULE__::target_callback(t_transaction ts) {
    tgt_ts_queue.push_back(ts);
}

void __MODULE__::tgt_method() {

    if(!tgt_ts_queue.empty()) {

        bool ts_valid = false;
        t_transaction ts;

        for(std::deque<t_transaction>::iterator it = tgt_ts_queue.begin(); it != tgt_ts_queue.end(); it++) {

            ts = (*it);

            if(ts->is_write() || !tgt_tag_queue.empty()) {
                tgt_ts_queue.erase(it);
                ts_valid = true;
                break;
            }
        }

        if(ts_valid) {
            if(ts->is_write()) {
                tgt_write(ts);
            } else {
                tgt_read(ts);
            }
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
        tlp->set_source(0); // TODO
        tlp->set_address(addr);
        tlp->set_byte_enables(be_first,be_last);
        tlp->set_data(data);

        // send it
        rxi_tlp_queue.push_back(tlp);

        cnt     += data.size();
        addr    += data.size()*4;
    }

    // success!
    ts->set_response_status(tlm::TLM_OK_RESPONSE);
    ts->complete();

}

void __MODULE__::tgt_read(t_transaction &ts) {

    assert(!tgt_tag_queue.empty());

    // okay for now; may override later
    ts->set_response_status(tlm::TLM_OK_RESPONSE);

    if(ts->size() > (max_read_request/4)) {
        dlsc_warn("max_read_request exceeded");
        ts->set_response_status(tlm::TLM_BURST_ERROR_RESPONSE);
        ts->complete();
    }

    tlp_type tlp(new pcie_tlp);
    tgt_type tgt(new target_state);
    tgt->ts     = ts;
    tgt->tlp    = tlp;

    tlp->set_type(TYPE_MEM);
    tlp->set_source(0); // TODO
    tlp->set_address(ts->get_address() & ~((uint64_t)0x3));
    tlp->set_byte_enables(0xF,(ts->size()>1) ? 0xF : 0);
    tlp->set_length(ts->size());
    tlp->set_tag(tgt_tag_queue.front()); tgt_tag_queue.pop_front();

    // send it
    rxi_tlp_queue.push_back(tlp);

    tgt_queue.push_back(tgt);
}

void __MODULE__::tgt_read_complete(tlp_type &tlp) {

    // find the target_state
    tgt_type tgt;
    bool tgt_valid = false;

    for(std::deque<tgt_type>::iterator it = tgt_queue.begin(); it != tgt_queue.end(); it++) {
        tgt = (*it);
        if(tgt->tlp->src_id  == tlp->dest_id &&
           tgt->tlp->src_tag == tlp->cpl_tag
        ) {
            tgt_queue.erase(it);
            tgt_valid = true;
            break;
        }
    }

    if(!tgt_valid) {
        dlsc_error("unexpected completion: " << *tlp);
        return;
    }

    t_transaction ts = tgt->ts;

    if(tlp->cpl_status != CPL_SC) {
        ts->set_response_status(tlm::TLM_GENERIC_ERROR_RESPONSE);
        ts->complete();
        // return tag to queue
        tgt_tag_queue.push_back(tgt->tlp->src_tag);
        return;
    }

    bool error = false;

    if(tlp->data.empty()) {
        dlsc_error("successful completion with no data!");
        error = true;
    }

    if(tlp->cpl_bytes != (ts->size() - tgt->data.size())*4) {
        dlsc_error("incorrect cpl_bytes");
        error = true;
    }

    if(tgt->data.empty() && tlp->cpl_addr != (tgt->tlp->dest_addr & 0x7F)) {
        dlsc_error("incorrect cpl_addr");
        error = true;
    }

    if(tlp->length > (ts->size() - tgt->data.size())) {
        dlsc_error("returned data exceeds request");
        error = true;
    }

    if(error) {
        dlsc_error("faulty TLP: " << *tlp);
        ts->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        ts->complete();
        // return tag to queue
        tgt_tag_queue.push_back(tgt->tlp->src_tag);
        return;
    }

    // append data
    tgt->data.resize(tgt->data.size()+tlp->data.size());
    std::copy(tlp->data.begin(),tlp->data.end(),tgt->data.end()-tlp->data.size());

    if(tgt->data.size() == ts->size()) {
        // done!
        ts->set_data(tgt->data);
        ts->set_response_status(tlm::TLM_OK_RESPONSE);
        ts->complete();
        // return tag to queue
        tgt_tag_queue.push_back(tgt->tlp->src_tag);
    } else {
        // not done; put back on queue
        tgt_queue.push_back(tgt);
    }
}




/*AUTOTRACE(__MODULE__)*/


