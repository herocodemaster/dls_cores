//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include <boost/shared_ptr.hpp>


/*AUTOSUBCELL_CLASS*/

#define ADDR            PARAM_ADDR
#define LEN             PARAM_LEN
#define BUFA            PARAM_BUFA
#define TOKN            PARAM_TOKN

#define AR_MAX_SIZE_DW  std::min( (1<<LEN) , (1<<BUFA)/4 )
#define RCB_MAX_SIZE_DW ( (1<<BUFA)/2 )

// SC_MODULE

struct req_type {
    bool        mem;
    uint64_t    addr;
    uint32_t    len;
    uint32_t    be_first;
    uint32_t    be_last;
};

struct cplh_type {
    uint32_t    addr;
    uint32_t    len;
    uint32_t    bytes;
    uint32_t    resp;
    bool        last;
};

struct cpld_type {
    uint32_t    data;
    bool        last;
};

struct ar_type {
    uint64_t    addr;
    uint32_t    len;
    uint32_t    token;
    bool        last;
};

struct r_type {
    uint32_t    data;
    uint32_t    resp;
    bool        last;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock                clk;

    void                    stim_thread();
    void                    watchdog_thread();

    void                    send_tlp();

    void                    clk_method();

    std::deque<req_type>    req_queue;
    std::deque<cplh_type>   cplh_queue;
    std::deque<cpld_type>   cpld_queue;
    std::deque<ar_type>     ar_queue;
    std::deque<r_type>      r_queue;
    int                     r_cnt;

    bool                    st_cplh;

    uint32_t                token_next;
    std::deque<uint32_t>    token_queue;

    bool                    get_token(uint32_t &token, bool write);

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

    rst         = 1;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

bool __MODULE__::get_token(uint32_t &token, bool write) {

    if(write) {
        uint32_t token_next_p1 = (token_next+1) & ((1<<TOKN)-1);
        if(token_next_p1 == (token_oldest ^ (1<<(TOKN-1))))
            return false;

        token_next  = token_next_p1;
    }
    
    token       = token_next;

    return true;
}

void __MODULE__::send_tlp() {

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

    addr &= ((((uint64_t)1) << ADDR) - 1);

    req_type req;

    req.addr        = addr;
    req.len         = len;
    req.be_first    = 0xF;
    req.be_last     = (len == 1) ? 0x0 : 0xF;
    req.mem         = (len > 1) || (rand()%100) < 50;

    if( (rand()%100) < 30 ) {
        // strobed
        if(len == 1) {
            // single allows sparse
            req.be_first    = rand() & 0xF;
        } else {
            // multiple requires contiguous
            switch(rand()%4) {
                case 0: req.be_first    = 0xF; break;
                case 1: req.be_first    = 0xE; break;
                case 2: req.be_first    = 0xC; break;
                case 3: req.be_first    = 0x8; break;
            }
            switch(rand()%4) {
                case 0: req.be_last     = 0xF; break;
                case 1: req.be_last     = 0x7; break;
                case 2: req.be_last     = 0x3; break;
                case 3: req.be_last     = 0x1; break;
            }
        }
    }

    req_queue.push_back(req);
}


void __MODULE__::clk_method() {
    if(rst) {
        token_wr        = 0;
        req_h_valid     = 0;
        req_h_mem       = 0;
        req_h_addr      = 0;
        req_h_len       = 0;
        req_h_be_first  = 0;
        req_h_be_last   = 0;
        req_h_token     = 0;
        cpl_h_ready     = 0;
        cpl_d_ready     = 0;
        axi_ar_ready    = 0;
        axi_r_valid     = 0;
        axi_r_last      = 0;
        axi_r_data      = 0;
        axi_r_resp      = 0;
        req_queue.clear();
        cplh_queue.clear();
        cpld_queue.clear();
        ar_queue.clear();
        r_queue.clear();
        st_cplh         = true;
        r_cnt           = 0;
        token_next      = 0;
        token_queue.clear();
        return;
    }

    int mps_dw      = (32<<max_payload_size.read());
    int ar_max_dw   = std::min(mps_dw,AR_MAX_SIZE_DW);
    int rcb_max     = std::min(mps_dw,RCB_MAX_SIZE_DW)*4;

    uint32_t token;

    if(!req_h_valid || req_h_ready) {
        if(!req_queue.empty() && (rand()%100) < 95 && get_token(token,false)) {

            // drive request
            req_type req = req_queue.front();

            req_h_valid     = 1;
            req_h_mem       = req.mem;
            req_h_addr      = req.addr >> 2;
            req_h_len       = req.len;
            req_h_be_first  = req.be_first;
            req_h_be_last   = req.be_last;
            req_h_token     = token;

            // create expected AR and R
            ar_type art;
            art.len         = 0;
            art.addr        = req.addr;
            art.token       = token;
            art.last        = false;

            std::deque<r_type> data;
            r_type  rt;
            bool allow_err = (rand()%100) < 5;

            while(req.len > 0) {
                art.len         += 1;
                req.len         -= 1;
                rt.data         = rand();
                rt.resp         = allow_err ? (rand() & 0x3) : 0;
                rt.last         = false;
                if(art.len == ar_max_dw || req.len == 0) {
                    art.last        = (req.len == 0);
                    ar_queue.push_back(art);
                    art.addr        += art.len*4;
                    art.len         = 0;
                    rt.last         = true;
                }
                data.push_back(rt);
                r_queue.push_back(rt);
            }
            
            // reset req
            req = req_queue.front();

            assert(data.size() == req.len);
    
            // create expected completions
            cpld_type cpld;
            cplh_type cplh;

            cplh.bytes = (req.len*4);

            if(req.len != 1) {
                // consider both BE fields
                // first
                     if(req.be_first & 0x1) cplh.bytes -= 0;
                else if(req.be_first & 0x2) cplh.bytes -= 1;
                else if(req.be_first & 0x4) cplh.bytes -= 2;
                else                        cplh.bytes -= 3;
                // last
                     if(req.be_last  & 0x8) cplh.bytes -= 0;
                else if(req.be_last  & 0x4) cplh.bytes -= 1;
                else if(req.be_last  & 0x2) cplh.bytes -= 2;
                else                        cplh.bytes -= 3;
            } else {
                // consider only first BE field
                if((req.be_first & 0x9) == 0x9)
                    cplh.bytes = 4;
                else if( ((req.be_first & 0x5) == 0x5) || ((req.be_first & 0xA) == 0xA) )
                    cplh.bytes = 3;
                else if( (req.be_first == 0x3) || (req.be_first == 0x6) || (req.be_first == 0xC) )
                    cplh.bytes = 2;
                else
                    cplh.bytes = 1;
            }

            unsigned int byte_offset = 0;
                 
                 if(req.be_first & 0x1) byte_offset = 0x0;
            else if(req.be_first & 0x2) byte_offset = 0x1;
            else if(req.be_first & 0x4) byte_offset = 0x2;
            else if(req.be_first & 0x8) byte_offset = 0x3;
            else                        byte_offset = 0x0; // "zero"-length read

            uint64_t addr       = req.addr;
            uint64_t addr_last  = req.addr + req.len*4;
            uint64_t addr_next;

            cplh.last   = false;
            while(!cplh.last) {

                addr_next   = (addr & ~((uint64_t)rcb_max-1)) + rcb_max;
                if(addr_next >= addr_last || (req.len <= rcb_max/4)) {
                    addr_next   = addr_last;
                    cplh.last   = true;
                }

                cplh.addr   = (addr + byte_offset) & 0x7F;
                cplh.len    = (addr_next - addr)/4;
                cplh.resp   = 0;

                for(int i=1;i<=cplh.len;++i) {
                    assert(!data.empty());
                    if(data.front().resp != 0) {
                        cplh.resp = data.front().resp;
                    }
                    cpld.data = data.front().data;
                    data.pop_front();
                    cpld.last = (i==cplh.len);
                    cpld_queue.push_back(cpld);
                }
                
                if(!req.mem) {
                    cplh.addr   = 0;
                    cplh.bytes  = 4;
                }

                cplh_queue.push_back(cplh);

                cplh.bytes  -= (cplh.len*4 - byte_offset);

                addr        = addr_next;
                byte_offset = 0;
            }

            assert(data.empty());

            req_queue.pop_front();

        } else {
            req_h_valid     = 0;
        }
    }

    if(cpl_h_ready && cpl_h_valid) {
        if(cplh_queue.empty()) {
            dlsc_error("unexpected cpl_h");
        } else {
            cplh_type cplh = cplh_queue.front(); cplh_queue.pop_front();
            dlsc_assert_equals(cpl_h_addr,cplh.addr);
            uint32_t len = (cplh.len==1024) ? 0 : cplh.len;
            dlsc_assert_equals(cpl_h_len,len);
            uint32_t bytes = (cplh.bytes==4096) ? 0 : cplh.bytes;
            dlsc_assert_equals(cpl_h_bytes,bytes);
            dlsc_assert_equals(cpl_h_last,cplh.last);
            dlsc_assert_equals(cpl_h_resp,cplh.resp);
            if(bytes != cpl_h_bytes) {
                dlsc_info("addr: 0x" << std::hex << cplh.addr << ", len: " << std::dec << cplh.len);
            }
            st_cplh     = false;
        }
    }

    cpl_h_ready     = st_cplh && (rand()%100) < 75;

    if(cpl_d_ready && cpl_d_valid) {
        if(cpld_queue.empty()) {
            dlsc_error("unexpected cpl_d");
        } else {
            cpld_type cpld = cpld_queue.front(); cpld_queue.pop_front();
            dlsc_assert_equals(cpl_d_data,cpld.data);
            dlsc_assert_equals(cpl_d_last,cpld.last);
            st_cplh = cpld.last;
        }
    }

    cpl_d_ready     = !st_cplh && (rand()%100) < 95;

    if(!axi_r_valid || axi_r_ready) {
        if(r_cnt > 0 && !r_queue.empty() && (rand()%100) < 95) {
            r_type rt = r_queue.front(); r_queue.pop_front();
            axi_r_valid = 1;
            axi_r_last  = rt.last;
            axi_r_data  = rt.data;
            axi_r_resp  = rt.resp;
            r_cnt       -= 1;
        } else {
            axi_r_valid = 0;
        }
    }

    if(axi_ar_ready && axi_ar_valid) {
        if(ar_queue.empty()) {
            dlsc_error("unexpected ar");
        } else {
            ar_type art = ar_queue.front(); ar_queue.pop_front();
            dlsc_assert_equals(axi_ar_addr,art.addr);
            dlsc_assert_equals(axi_ar_len,(art.len-1));
            r_cnt += art.len;
            if( (token_wr - art.token) & (1<<(TOKN-1)) ) {
                dlsc_error("read passed write; token_wr: " << std::dec << token_wr << ", art.token: " << std::dec << art.token);
            }
        }
    }

    axi_ar_ready    = (rand()%100) < 95;

    if( (rand()%1000) < 10 && get_token(token,true) ) {
        token_queue.push_back(token);
    }

    if( (rand()%5000) < (token_queue.size()) && !token_queue.empty() ) {
        token_wr = token_queue.front(); token_queue.pop_front();
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);

    int mps = 0;
    for(int i=128;i<=4096;i*=2,++mps) {
        dlsc_info("testing max_payload_size = " << std::dec << i);

        wait(clk.posedge_event());
        rst     = 1;
        max_payload_size = mps;
        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());

        for(int j=0;j<300;++j) {
            send_tlp();
        }

        while( !( req_queue.empty() && cplh_queue.empty() && cpld_queue.empty() &&
                    ar_queue.empty() && r_queue.empty() ) ) {
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

    dlsc_info("req_queue: " << (req_queue.size()) << \
            ", cplh_queue: " << (cplh_queue.size()) << \
            ", cpld_queue: " << (cpld_queue.size()) << \
            ", ar_queue: " << (ar_queue.size()) << \
            ", r_queue: " << (r_queue.size()));

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



