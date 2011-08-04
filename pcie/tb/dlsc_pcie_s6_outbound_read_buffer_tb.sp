//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

/*AUTOSUBCELL_CLASS*/

#define ADDR            PARAM_ADDR
#define LEN             PARAM_LEN
#define TAG             PARAM_TAG
#define BUFA            PARAM_BUFA
#define MOT             PARAM_MOT

#define TAGS            (1<<TAG)

#define BUF_SIZE        (1<<BUFA)

struct cpl_type {
    uint32_t    data;
    uint32_t    resp;
    uint32_t    tag;
    bool        last;
};

struct ar_type {
    uint64_t    addr;
    uint32_t    len;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock                clk;
    sc_signal<uint32_t>     alloc_len;

    void                    stim_thread();
    void                    watchdog_thread();

    void                    clk_method();

    std::deque<ar_type>     ar_queue;
    std::deque<ar_type>     cmd_queue;
    std::deque<cpl_type>    r_queue;
    std::deque<cpl_type>    cpl_in_queue;
    std::deque<cpl_type>    tag_queues[TAGS];
    std::deque<cpl_type>    cpl_out_queue;

    unsigned int            ar_len_accum;

    unsigned int            buf_free;
    uint32_t                buf_addr;

    unsigned int            tag_free;
    uint32_t                tag_next;

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

SP_CTOR_IMP(__MODULE__) : clk("clk",10,SC_NS) /*AUTOINIT*/ {
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




void __MODULE__::clk_method() {

    if(rst) {
        axi_ar_valid    = 0;
        axi_ar_addr     = 0;
        axi_ar_len      = 0;
        axi_r_ready     = 0;
        cmd_ar_ready    = 0;
        cpl_valid       = 0;
        cpl_last        = 0;
        cpl_data        = 0;
        cpl_resp        = 0;
        cpl_tag         = 0;
        alloc_init      = 1;
        alloc_valid     = 1;
        alloc_tag       = 0;
        alloc_bufa      = 0;
        alloc_len       = 0;
        ar_queue.clear();
        cmd_queue.clear();
        r_queue.clear();
        for(int i=0;i<TAGS;++i) {
            tag_queues[i].clear();
        }
        ar_len_accum    = 0;
        buf_free        = BUF_SIZE;
        buf_addr        = 0;
        tag_free        = TAGS;
        tag_next        = 0;
        return;
    }

    // ** Allocator **

    if(alloc_init) {
        alloc_tag           = alloc_tag + 1;
        if(alloc_tag == (TAGS-1)) {
            alloc_tag           = 0;
            alloc_init          = 0;
            alloc_valid         = 0;
        }
    } else {
        alloc_valid         = 0;
        alloc_tag           = tag_next;
    }

    if(dealloc_tag) {
        if(tag_free == TAGS) {
            dlsc_error("dealloc_tag overflow");
        } else {
            ++tag_free;
        }
    }

    if(dealloc_data) {
        if(buf_free == BUF_SIZE) {
            dlsc_error("dealloc_data overflow");
        } else {
            ++buf_free;
        }
    }

    if(!alloc_init && ar_len_accum > 0 && tag_free > 0 && buf_free >= ar_len_accum && (!axi_ar_valid || !axi_ar_ready)) {
        assert(ar_len_accum <= BUF_SIZE);
        // have submitted commands; generate an allocation request for them now
        alloc_valid         = 1;
        alloc_bufa          = buf_addr;
        alloc_len           = ar_len_accum;

        tag_next            = (tag_next + 1) & ((2<<TAG)-1);
        tag_free            -= 1;
        buf_addr            = (buf_addr + ar_len_accum) & ((1<<(BUFA+1))-1);
        buf_free            -= ar_len_accum;

        ar_len_accum        = 0;
    }


    // ** AXI **

    if(axi_ar_valid && axi_ar_ready) {
        ar_len_accum        += axi_ar_len + 1;
    }

    if(!axi_ar_valid || axi_ar_ready) {
        if(!ar_queue.empty() && ((ar_len_accum+ar_queue.front().len+1) <= BUF_SIZE) && (rand()%100) < 95) {
            ar_type ar = ar_queue.front(); ar_queue.pop_front();
            assert(ar.len < (1<<LEN));
            axi_ar_valid        = 1;
            axi_ar_addr         = ar.addr;
            axi_ar_len          = ar.len;

            cpl_type chk;
            for(unsigned int i=0;i<=ar.len;++i) {
                chk.data            = rand();
                chk.resp            = rand() & 0x3;
                chk.tag             = 0;
                chk.last            = (i==ar.len);
                r_queue.push_back(chk);
                cpl_in_queue.push_back(chk);
            }
            ar.addr             >>= 2;
            cmd_queue.push_back(ar);

        } else {
            axi_ar_valid        = 0;
            axi_ar_addr         = 0;
            axi_ar_len          = 0;
        }
    }

    if(axi_r_ready && axi_r_valid) {
        if(r_queue.empty()) {
            dlsc_error("unexpected R data");
        } else {
            cpl_type chk = r_queue.front(); r_queue.pop_front();
            dlsc_assert_equals(chk.last,axi_r_last);
            dlsc_assert_equals(chk.data,axi_r_data);
            dlsc_assert_equals(chk.resp,axi_r_resp);
        }
    }

    axi_r_ready     = (rand()%100) < 95;

    if(cmd_ar_ready && cmd_ar_valid) {
        if(cmd_queue.empty()) {
            dlsc_error("unexpected cmd_ar");
        } else {
            ar_type ar = cmd_queue.front(); cmd_queue.pop_front();
            dlsc_assert_equals(ar.addr,cmd_ar_addr);
            dlsc_assert_equals(ar.len, cmd_ar_len);
        }
    }

    cmd_ar_ready    = (rand()%100) < 95;


    // ** Completions **

    // drive completions
    if(!cpl_valid || cpl_ready) {
        if(!cpl_out_queue.empty() && (rand()%100) < 95) {
            cpl_type chk = cpl_out_queue.front(); cpl_out_queue.pop_front();
            cpl_valid           = 1;
            cpl_last            = chk.last;
            cpl_data            = chk.data;
            cpl_resp            = chk.resp;
            cpl_tag             = chk.tag;
        } else {
            cpl_valid           = 0;
            cpl_last            = 0;
            cpl_data            = 0;
            cpl_resp            = 0;
            cpl_tag             = 0;
        }
    }

    // transfer per-tag queues to output queue
    if(cpl_out_queue.size() <= 1) {
        uint32_t tag = rand();
        for(unsigned int i=0;i<TAGS;++i,++tag) {
            tag &= ((1<<TAG)-1);
            if(tag_queues[tag].empty()) continue;

            int len = (rand() % 20);
            if(len > tag_queues[tag].size()) len = tag_queues[tag].size();
            while(len--) {
                cpl_out_queue.push_back(tag_queues[tag].front());
                tag_queues[tag].pop_front();
            }
        }
    }

    // transfer ordered input queue to per-tag queues
    if(!alloc_init && alloc_valid) {
        uint32_t tag        = alloc_tag.read() & ((1<<TAG)-1);
        uint32_t len        = alloc_len.read();
        assert(cpl_in_queue.size() >= len);
        assert(tag_queues[tag].empty());

        for(unsigned int i=0;i<len;++i) {
            cpl_type chk        = cpl_in_queue.front(); cpl_in_queue.pop_front();
            chk.tag             = tag;
            chk.last            = (i==(len-1));
            tag_queues[tag].push_back(chk);
        }
    }

}

void __MODULE__::stim_thread() {
    rst     = 1;
    wait(100,SC_NS);

    for(int i=0;i<10;++i) {

        wait(clk.posedge_event());
        rst     = 1;
        wait(clk.posedge_event());
        rst     = 0;
        wait(clk.posedge_event());

        ar_type ar;
        for(int j=0;j<10000;++j) {
            ar.addr = rand() & ((((uint64_t)1)<<ADDR)-1);
            ar.len  = rand() & ((1<<LEN)-1);
            ar_queue.push_back(ar);
        }

        while( !(ar_queue.empty() && cmd_queue.empty() && r_queue.empty() && cpl_in_queue.empty() &&
                cpl_out_queue.empty() && buf_free == BUF_SIZE && tag_free == TAGS)
        ) {
            wait(1,SC_US);
        }
    }

    wait(1,SC_US);
    dut->final();
    sc_stop();
}

void __MODULE__::watchdog_thread() {
    wait(10,SC_MS);

    dlsc_error("watchdog timeout");

    dut->final();
    sc_stop();
}

/*AUTOTRACE(__MODULE__)*/



