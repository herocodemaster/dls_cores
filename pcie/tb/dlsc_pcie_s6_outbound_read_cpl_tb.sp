//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include <boost/shared_ptr.hpp>

#include "dlsc_pcie_tlp.h"

/*AUTOSUBCELL_CLASS*/

#define TAG             PARAM_TAG
#define TIMEOUT         PARAM_TIMEOUT

#define TAGS            (1<<TAG)

using namespace dlsc;
using namespace dlsc::pcie;

typedef boost::shared_ptr<dlsc::pcie::pcie_tlp> tlp_type;

struct rx_type {
    uint32_t    data;
    bool        last;
    bool        err;
};

struct err_type {
    bool        unexpected;
    bool        timeout;
};

struct cpl_type {
    bool        last;
    uint32_t    data;
    uint32_t    resp;
};

struct alloc_type {
    uint32_t    tag;
    uint32_t    len;
    uint32_t    addr;
};

struct tag_type {
    uint32_t    tag;
    bool        done;
};


SC_MODULE (__MODULE__) {
private:
    sc_clock                clk;

    void                    stim_thread();
    void                    watchdog_thread();

    void                    send_tlp();
    bool                    pending_timeout;

    void                    clk_method();

    std::deque<rx_type>     rx_queue;
    std::deque<err_type>    err_queue;
    std::deque<cpl_type>    cpl_queues[TAGS];
    std::deque<alloc_type>  alloc_queue;
    std::deque<tag_type>    tag_queue;

    uint32_t                tag_next;
    unsigned int            tag_free;
    unsigned int            cplh_free;
    unsigned int            cpld_free;

    unsigned int            cplh_max;
    unsigned int            cpld_max;

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

#include "dlsc_main.cpp"

SP_CTOR_IMP(__MODULE__) : clk("clk",16,SC_NS) /*AUTOINIT*/ {
    SP_AUTO_CTOR;

    /*AUTOTIEOFF*/
    SP_CELL(dut,DLSC_DUT);
        /*AUTOINST*/

    cplh_max    = 64;
    cpld_max    = 256;

    rst         = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::send_tlp() {

    bool unexpected = false;
    bool timeout    = false;
    bool error      = false;

    if(!pending_timeout) {
        switch(rand()%100) {
            case 10:
            case 11:
                unexpected  = true; break;
            case 20:
            case 21:
            case 22:
                error       = true; break;
            case 90:
                timeout     = true; break;
        }
        pending_timeout = timeout;
    }

    // 'timeout' handled here; 'unexpected' handled below;
    // 'error' conveyed via cpl_resp interface
    if(timeout) {
        err_type err;
        err.unexpected  = false;
        err.timeout     = true;
        err_queue.push_back(err);
    }
    
    // random length
    int len;

    switch(rand()%10) {
        case 0:     len = 1; break;
        case 1:     len = 1024; break;
        default:    len = (rand()%1024) + 1;
    }

    // random address
    uint64_t addr = rand();
    addr *= 4;

    // prevent 4k crossings
    int boundary = ((addr & 0xFFF) + (len*4)) - 4096;
    if(boundary > 0) {
        addr -= boundary;
    }

    unsigned int rcb_bytes = rcb ? 128 : 64;

    // from Xilinx UG654
    unsigned int cplh = ((addr % rcb_bytes) + (len*4) + (rcb_bytes-1)) / rcb_bytes;
    unsigned int cpld = ((addr % 16       ) + (len*4) + 15           ) / 16;

    assert(cplh > 0 && cpld > 0);
    assert(cplh <= cplh_max && cpld <= cpld_max);

    // wait for credits/tags
    while( !(cplh <= cplh_free && cpld <= cpld_free && tag_free > 0) ) {
        wait(100,SC_NS);
        if(unexpected && (rand()%100) < 10) break;
    }

    uint32_t tag;

    if(!unexpected) {
        // only expected TLPs count against us
        cplh_free   -= cplh;
        cpld_free   -= cpld;
        tag_free    -= 1;

        tag         = tag_next & ((1<<TAG)-1);

        tag_type tt;
        tt.tag      = tag;
        tt.done     = false;
        tag_queue.push_back(tt);
        
        alloc_type alc;
        alc.tag     = tag_next;
        alc.len     = len;
        alc.addr    = (addr>>2) & 0x1F;
        alloc_queue.push_back(alc);

        tag_next    = (tag_next + 1) & ((2<<TAG)-1);
    } else {
        tag         = (rand() | 0x80) & 0xFF;
    }

    // create TLPs
    uint64_t addr_next  = addr;
    uint64_t addr_last  = addr + (len*4);

    bool tlp_first  = true;
    bool tlp_last   = false;
    bool tlp_error  = false;
    bool tlp_drop   = false;

    while(!tlp_last) {

        // advance by some multiple of RCB
        addr_next   += ((rand()%16) + 1) * rcb_bytes;
        // align to RCB
        addr_next   &= ~( (((uint64_t)1) << rcb_bytes) - 1 );
        // clamp to last
        if(addr_next >= addr_last) {
            tlp_last    = true;
            addr_next   = addr_last;
        }

        // length of just this TLP
        unsigned int tlp_len = (addr_next - addr)/4;

        // decide if this TLP will be erroneous
        if(error && (tlp_last || (rand()%100) < 25)) {
            tlp_error   = true;
        }

        if(timeout && tlp_last) {
            tlp_error   = true;
            tlp_drop    = true;
        }

        // create TLP
        tlp_type tlp(new pcie_tlp);
        tlp->set_type(TYPE_CPL);
        tlp->set_completion_tag(tag);
        tlp->set_lower_addr(addr & 0x7F);

        if(tlp_first && (rand()%100) < 10) {
            // byte count modified (report bytes just for this TLP)
            tlp->set_bcm(true);
            tlp->set_byte_count(tlp_len*4);
        } else {
            tlp->set_byte_count(len*4);
        }

        cpl_type cpl;

        // create data for TLP
        std::deque<uint32_t> data;
        for(unsigned int i=0;i<tlp_len;++i) {
            cpl.data    = tlp_error ? 0 : rand();
            cpl.resp    = tlp_error ? 0x2 : 0x0;    // RESP_SLVERR or RESP_OKAY
            cpl.last    = tlp_last && (i==(tlp_len-1));
            if(!unexpected) {
                assert(tag < TAGS);
                cpl_queues[tag].push_back(cpl);
            }
            data.push_back(cpl.data);
        }

        bool tlp_error_poison   = false;
        bool tlp_error_rx       = false;
        bool tlp_error_status   = false;

        if(tlp_error) {
            switch(rand()%10) {
                case 3:  tlp_error_poison   = true; break;
                case 7:  tlp_error_rx       = true; break;
                default: tlp_error_status   = true;
            }
        }

        if(tlp_error_status) {
            tlp->set_completion_status(CPL_UR);
        } else {
            tlp->set_data(data);
            tlp->set_completion_status(CPL_SC);
        }

        if(tlp_error_poison) {
            tlp->set_poisoned(true);
        }

        assert(tlp->validate());

        if(!tlp_drop) {
            std::deque<uint32_t> tlp_words;
            tlp->serialize(tlp_words);
            rx_type rxt;
            rxt.err     = tlp_error_rx;
            while(!tlp_words.empty()) {
                rxt.data    = tlp_words.front(); tlp_words.pop_front();
                rxt.last    = tlp_words.empty();
                rx_queue.push_back(rxt);
            }
            if(unexpected) {
                // one error expected per TLP
                err_type err;
                err.unexpected  = true;
                err.timeout     = false;
                err_queue.push_back(err);
            }
        }

        if(tlp_error) {
            // sent error TLP; don't send any more
            tlp_drop    = true;
        }

        // prepare for next TLP
        addr        = addr_next;
        len         -= tlp_len;
        tlp_first   = false;
    }

    assert(len == 0);

    if(unexpected) {
        dlsc_verb("generating unexpected for tag " << std::dec << tag);
    }
    if(timeout) {
        dlsc_verb("generating timeout for tag " << std::dec << tag);
    }
    if(error) {
        dlsc_verb("generating error for tag " << std::dec << tag);
    }
}


void __MODULE__::clk_method() {
    if(rst) {
        rx_valid        = 0;
        rx_data         = 0;
        rx_last         = 0;
        rx_err          = 0;
        err_ready       = 0;
        cpl_ready       = 0;
        alloc_init      = 1;
        alloc_valid     = 1;
        alloc_tag       = 0;
        alloc_len       = 0;
        alloc_addr      = 0;
        rx_queue.clear();
        err_queue.clear();
        for(int i=0;i<TAGS;++i) {
            cpl_queues[i].clear();
        }
        alloc_queue.clear();
        tag_next        = 0;
        tag_free        = TAGS;
        cplh_free       = cplh_max;
        cpld_free       = cpld_max;
        pending_timeout = false;
        return;
    }

    if(alloc_init) {
        alloc_tag       = alloc_tag + 1;
        if(alloc_tag == (TAGS-1)) {
            alloc_tag       = 0;
            alloc_init      = 0;
            alloc_valid     = 0;
        }
        return;
    }

    if(!rx_valid || rx_ready) {
        if(!rx_queue.empty() && (rand()%100) < 95) {
            rx_type rxt = rx_queue.front(); rx_queue.pop_front();
            rx_valid        = 1;
            rx_data         = rxt.data;
            rx_last         = rxt.last;
            rx_err          = rxt.err;
        } else {
            rx_valid        = 0;
            rx_data         = 0;
            rx_last         = 0;
            rx_err          = 0;
        }
    }

    if(err_ready && err_valid) {
        if(err_queue.empty()) {
            dlsc_error("unexpected err (unexpected = " << err_unexpected << ", timeout = " << err_timeout << ")");
        } else {
            err_type err = err_queue.front(); err_queue.pop_front();
            dlsc_assert_equals(err_unexpected,err.unexpected);
            dlsc_assert_equals(err_timeout,err.timeout);

            if(err.timeout) {
                dlsc_verb("cleared pending timeout");
                pending_timeout     = false;
            }
        }
    }

    err_ready       = (rand()%100) < 25;

    if(cpl_ready && cpl_valid) {
        uint32_t tag = cpl_tag;

        if(cpl_last) {
            std::deque<tag_type>::iterator it;
            for(it = tag_queue.begin(); it != tag_queue.end(); it++) {
                if((*it).tag == tag) {
                    (*it).done = true;
                    break;
                }
            }
            if(it == tag_queue.end()) {
                dlsc_error("unexpected cpl_last (tag: " << std::dec << tag << ")");
            } else {
                dlsc_verb("completed TLP request (tag: " << std::dec << tag << ")");
            }
        }

        if(tag >= TAGS || cpl_queues[tag].empty()) {
            dlsc_error("unexpected cpl (tag: " << std::dec << tag << ")");
        } else {
            cpl_type cpl = cpl_queues[tag].front(); cpl_queues[tag].pop_front();
            dlsc_assert_equals(cpl.last,cpl_last);
            dlsc_assert_equals(cpl.data,cpl_data);
            dlsc_assert_equals(cpl.resp,cpl_resp);
        }
    }

    cpl_ready       = (rand()%100) < 95;

    if(!alloc_queue.empty()) {
        alloc_type alc = alloc_queue.front(); alloc_queue.pop_front();
        alloc_init      = 0;
        alloc_valid     = 1;
        alloc_tag       = alc.tag;
        alloc_len       = alc.len;
        alloc_addr      = alc.addr;
    } else {
        alloc_init      = 0;
        alloc_valid     = 0;
        alloc_tag       = 0;
        alloc_len       = 0;
        alloc_addr      = 0;
    }
    
    dealloc_tag     = 0;
    if(!tag_queue.empty() && tag_queue.front().done && (rand()%100) == 42 && !pending_timeout) {
        dlsc_verb("deallocated tag " << std::dec << tag_queue.front().tag);
        dealloc_tag     = 1;
        tag_queue.pop_front();
        assert(tag_free < TAGS);
        ++tag_free;
    }

    if(dealloc_cplh) {
        if(cplh_free == cplh_max) {
            dlsc_error("cplh overflow");
        } else {
            ++cplh_free;
        }
    }

    if(dealloc_cpld) {
        if(cpld_free == cpld_max) {
            dlsc_error("cpld overflow");
        } else {
            ++cpld_free;
        }
    }

}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);

    for(int i=0;i<20;++i) {
        dlsc_info("iteration " << std::dec << i);
        wait(clk.posedge_event());
        rst     = 1;
        rcb     = i%2;
        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());

        for(int j=0;j<100;++j) {
            send_tlp();
        }

        while( !( rx_queue.empty() && err_queue.empty() && alloc_queue.empty() &&
                    tag_free == TAGS && cplh_free == cplh_max && cpld_free == cpld_max) ) {
            wait(1,SC_US);
        }
    }

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



