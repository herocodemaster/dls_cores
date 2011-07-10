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

#define AW_MAX_SIZE_DW  std::min( (1<<LEN) , (1<<BUFA)/2 )

// SC_MODULE

struct req_type {
    bool        np;
    uint64_t    addr;
    uint32_t    len;
    uint32_t    be_first;
    uint32_t    be_last;
};

struct reqd_type {
    uint32_t    data;
    uint32_t    strb;
    bool        last;
};

struct cplh_type {
    uint32_t    resp;
};

struct err_type {
    bool        unsupported;
};

struct aw_type {
    uint64_t    addr;
    uint32_t    len;
};

struct w_type {
    uint32_t    data;
    uint32_t    strb;
    bool        last;
};

struct b_type {
    uint32_t    resp;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock                clk;

    void                    stim_thread();
    void                    watchdog_thread();

    void                    send_tlp();

    void                    clk_method();

    std::deque<req_type>    req_queue;
    std::deque<reqd_type>   reqd_queue;
    std::deque<cplh_type>   cplh_queue;
    std::deque<err_type>    err_queue;
    std::deque<aw_type>     aw_queue;
    std::deque<w_type>      w_queue;
    int                     w_cnt;
    std::deque<b_type>      b_queue;
    int                     b_cnt;

    uint32_t                token_next;
    bool                    get_token(uint32_t &token);

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

bool __MODULE__::get_token(uint32_t &token) {

    uint32_t token_next_p1 = (token_next+1) & ((1<<TOKN)-1);
    if(token_next_p1 == (token_wr ^ (1<<(TOKN-1))))
        return false;

    token_next  = token_next_p1;
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
    req.np          = (len == 1) && (rand()%100) < 50;

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
        req_h_valid     = 0;
        req_h_np        = 0;
        req_h_addr      = 0;
        req_h_len       = 0;
        req_h_token     = 0;
        req_d_valid     = 0;
        req_d_data      = 0;
        req_d_strb      = 0;
        cpl_h_ready     = 0;
        err_ready       = 0;
        axi_aw_ready    = 0;
        axi_w_ready     = 0;
        axi_b_valid     = 0;
        axi_b_resp      = 0;
        req_queue.clear();
        reqd_queue.clear();
        cplh_queue.clear();
        err_queue.clear();
        aw_queue.clear();
        w_queue.clear();
        w_cnt           = 0;
        b_queue.clear();
        b_cnt           = 0;
        token_next      = 0;
        return;
    }

    uint32_t token;

    if(!req_h_valid || req_h_ready) {
        if(!req_queue.empty() && (rand()%100) < 50 && get_token(token)) {

            // drive request
            req_type req = req_queue.front(); req_queue.pop_front();

            req_h_valid     = 1;
            req_h_np        = req.np;
            req_h_addr      = req.addr >> 2;
            req_h_len       = req.len;
            req_h_token     = token;

            // create expected AW, W, B, and req_d
            aw_type awt;
            awt.len         = 0;
            awt.addr        = req.addr;

            w_type wt;
            b_type bt;
            reqd_type reqd;
            cplh_type cplh;
            cplh.resp   = 0;

            bool allow_err = (rand()%100) < 5;

            for(int i=1;i<=req.len;++i) {

                wt.data         = rand();
                wt.strb         = rand() & 0xF;
                wt.last         = false;

                reqd.data       = wt.data;
                reqd.strb       = wt.strb;

                awt.len         += 1;

                if(awt.len == AW_MAX_SIZE_DW || (i==req.len)) {
                    aw_queue.push_back(awt);
                    awt.addr        += awt.len*4;
                    awt.len         = 0;
                    wt.last         = true;
                    bt.resp         = (allow_err && (rand()%100)<25) ? (rand()&0x3) : 0;
                    if(bt.resp != 0) cplh.resp = bt.resp;
                    b_queue.push_back(bt);
                }
                
                w_queue.push_back(wt);
                reqd_queue.push_back(reqd);
            }

            // create cpl_h or err
            if(req.np) {
                cplh_queue.push_back(cplh);
            } else if(cplh.resp != 0) {
                err_type err;
                err.unsupported = true;
                err_queue.push_back(err);
            }

        } else {
            req_h_valid     = 0;
        }
    }

    if(!req_d_valid || req_d_ready) {
        if(!reqd_queue.empty() && (rand()%100) < 75) {
            reqd_type reqd = reqd_queue.front(); reqd_queue.pop_front();
            req_d_valid     = 1;
            req_d_data      = reqd.data;
            req_d_strb      = reqd.strb;
        } else {
            req_d_valid     = 0;
        }
    }

    if(cpl_h_ready && cpl_h_valid) {
        if(cplh_queue.empty()) {
            dlsc_error("unexpected cpl_h");
        } else {
            cplh_type cplh = cplh_queue.front(); cplh_queue.pop_front();
            dlsc_assert_equals(cpl_h_resp,cplh.resp);
        }
    }

    cpl_h_ready     = (rand()%100) < 75;

    if(err_ready && err_valid) {
        if(err_queue.empty()) {
            dlsc_error("unexpected err");
        } else {
            err_type err = err_queue.front(); err_queue.pop_front();
            dlsc_assert_equals(err_unsupported,err.unsupported);
        }
    }

    err_ready       = (rand()%100) < 75;

    if(axi_aw_ready && axi_aw_valid) {
        if(aw_queue.empty()) {
            dlsc_error("unexpected aw");
        } else {
            aw_type awt = aw_queue.front(); aw_queue.pop_front();
            dlsc_assert_equals(axi_aw_addr,awt.addr);
            dlsc_assert_equals(axi_aw_len,(awt.len-1));
            w_cnt += awt.len;
        }
    }

    axi_aw_ready    = (rand()%100) < 95;

    if(axi_w_ready) {
        int cnt = w_cnt;
        if(!axi_aw_ready && axi_aw_valid && !aw_queue.empty()) {
            cnt += aw_queue.front().len;
        }

        if(cnt > 0 && !axi_w_valid) {
            dlsc_error("write throttling");
        } else if(cnt == 0 && axi_w_valid) {
            dlsc_error("unexpected write data");
        } else if(cnt > 0 && axi_w_valid) {
            assert(!w_queue.empty());
            --w_cnt;
            w_type wt = w_queue.front(); w_queue.pop_front();
            dlsc_assert_equals(axi_w_data,wt.data);
            dlsc_assert_equals(axi_w_strb,wt.strb);
            dlsc_assert_equals(axi_w_last,wt.last);
        }
    }

    axi_w_ready     = (rand()%100) < 95;

    if(!axi_b_valid || axi_b_ready) {
        if(b_cnt > 0 && !b_queue.empty() && (rand()%100) < 10) {
            --b_cnt;
            b_type bt = b_queue.front(); b_queue.pop_front();
            axi_b_valid     = 1;
            axi_b_resp      = bt.resp;
        } else {
            axi_b_valid     = 0;
        }
    }

    if(axi_w_ready && axi_w_valid && axi_w_last) {
        ++b_cnt;
    }
}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);

    for(int i=0;i<20;++i) {
        dlsc_info("iteration " << std::dec << i);

        wait(clk.posedge_event());
        rst     = 1;
        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());

        for(int j=0;j<100;++j) {
            send_tlp();
        }

        while( !( req_queue.empty() && reqd_queue.empty() && cplh_queue.empty() && err_queue.empty() &&
                    aw_queue.empty() && w_queue.empty() && b_queue.empty() ) ) {
            wait(1,SC_US);
        }
    }

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(50,SC_MS);

    dlsc_error("watchdog timeout");

    dlsc_info("req_queue: " << (req_queue.size()) << \
            ", reqd_queue: " << (reqd_queue.size()) << \
            ", cplh_queue: " << (cplh_queue.size()) << \
            ", err_queue: " << (err_queue.size()) << \
            ", aw_queue: " << (aw_queue.size()) << \
            ", w_queue: " << (w_queue.size()) << \
            ", b_queue: " << (b_queue.size()) );

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



