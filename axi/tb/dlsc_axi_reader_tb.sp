//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_channel.h"

/*AUTOSUBCELL_CLASS*/

#if PARAM_STROBE_EN
#define STROBE_EN
#endif

#define FIFO_SIZE (1<<PARAM_FIFO_ADDR)

#define MEM_SIZE (1ull<<PARAM_ADDR)
#define MAX_BYTES ((1u<<PARAM_BLEN)-1)

struct cmd_type {
    uint64_t    addr;
    uint32_t    len;
};

struct out_type {
    uint32_t    data;
    uint32_t    strb;
    bool        first;
    bool        last;
};

SC_MODULE (__MODULE__) {
private:
    sc_clock clk;

    void clk_method();

    void stim_thread();
    void watchdog_thread();

    dlsc_tlm_memory<uint32_t> *memory;
    dlsc_tlm_channel<uint32_t> *channel;

    std::deque<cmd_type> cmd_queue;
    std::deque<out_type> out_queue;

    uint32_t fifo_cnt;

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

    SP_CELL(axi_slave,dlsc_axi4lb_tlm_slave_32b);
        SP_PIN(axi_slave,rst,rst_axi);
        /*AUTOINST*/
    
    memory      = new dlsc_tlm_memory<uint32_t>("memory",MEM_SIZE,0,sc_core::sc_time(1.0,SC_NS),sc_core::sc_time(10,SC_NS));

    channel     = new dlsc_tlm_channel<uint32_t>("channel");

    channel->set_delay(sc_core::sc_time(100,SC_NS),sc_core::sc_time(1000,SC_NS));

    axi_slave->socket.bind(channel->in_socket);
    channel->out_socket.bind(memory->socket);

    rst         = 1;
    rst_axi     = 1;

    fifo_cnt    = 0;

    SC_METHOD(clk_method);
        sensitive << clk.posedge_event();

    SC_THREAD(stim_thread);
    SC_THREAD(watchdog_thread);
}

void __MODULE__::clk_method() {
    if(rst) {
        cmd_valid   = 0;
        cmd_addr    = 0;
        cmd_bytes   = 0;
        out_free    = 0;
        out_ready   = 0;

        out_queue.clear();

        fifo_cnt    = 0;
    } else {

        // ** commands **

        if( cmd_ready ) {
            cmd_valid   = 0;
        }

        if( (cmd_ready || !cmd_valid) && !cmd_queue.empty() && dlsc_rand_bool(25.0) ) {
            cmd_type cmd = cmd_queue.front(); cmd_queue.pop_front();
            cmd_valid   = 1;
            cmd_addr    = cmd.addr;
            cmd_bytes   = cmd.len;

            // generate expected data
            std::deque<uint32_t> data;
            out_type out;
            out.first   = true;
            out.last    = false;
            memory->nb_read(cmd.addr & ~0x3ull, (cmd.len+(cmd.addr&0x3)+3)>>2, data);
            while(!data.empty()) {
                out.data    = data.front(); data.pop_front();
                out.last    = data.empty();
                out.strb    = 0xF;
                if(out.first) {
                    switch(cmd.addr & 0x3) {
                        case 0: out.strb = 0xF; break;
                        case 1: out.strb = 0xE; break;
                        case 2: out.strb = 0xC; break;
                        case 3: out.strb = 0x8; break;
                    }
                }
                if(out.last) {
                    switch( (cmd.addr+cmd.len) & 0x3) {
                        case 1: out.strb &= 0x1; break;
                        case 2: out.strb &= 0x3; break;
                        case 3: out.strb &= 0x7; break;
                        case 0: out.strb &= 0xF; break;
                    }
                }
                out_queue.push_back(out);
                out.first   = false;
            }
        }

        // ** data **

        if(out_ready && out_valid) {
            fifo_cnt++;

            if(out_queue.empty()) {
                dlsc_error("unexpected data");
            } else {
                out_type out = out_queue.front(); out_queue.pop_front();

                dlsc_assert_equals(out.data,out_data);
                dlsc_assert_equals(out.last,out_last);
#if PARAM_STROBE_EN
                dlsc_assert_equals(out.strb,out_strb);
#endif
            }
        }

        out_ready = dlsc_rand_bool(95.0);

        // ** free **

        if(fifo_cnt > FIFO_SIZE) {
            dlsc_error("FIFO overflow");
        }

        if(fifo_cnt > 0 && dlsc_rand_bool(35.0)) {
            fifo_cnt--;
        }

        out_free = FIFO_SIZE - fifo_cnt;

    }
}

void __MODULE__::stim_thread() {
    rst         = 1;
    rst_axi     = 1;
    wait(100,SC_NS);
    wait(clk.posedge_event());
    rst         = 0;
    rst_axi     = 0;

    for(int i=0;i<100;++i) {
        cmd_type cmd;
        cmd.addr = dlsc_rand_u64(0,MEM_SIZE - MAX_BYTES);
        switch(dlsc_rand_u32(0,2)) {
            case 0:  cmd.len = dlsc_rand_u32(1,16); break;
            default: cmd.len = dlsc_rand_u32(1,MAX_BYTES); break;
        }
        cmd_queue.push_back(cmd);
    }

    while( !(cmd_queue.empty() && out_queue.empty() && !fifo_cnt) ) {
        wait(1,SC_US);
        if(dlsc_rand_bool(2.0)) {
            wait(clk.posedge_event());
            axi_halt    = 1;
            if(dlsc_rand_bool(35.0)) {
                while(axi_busy) wait(dlsc_rand_u32(100,1000),SC_NS);
            } else {
                wait(dlsc_rand_u32(100,1000),SC_NS);
            }
            wait(clk.posedge_event());
            axi_halt    = 0;
        }
    }

    // again, but with errors
    memory->set_error_rate(1.0);

    for(int i=0;i<100;++i) {
        cmd_type cmd;
        cmd.addr = dlsc_rand_u64(0,MEM_SIZE - MAX_BYTES);
        switch(dlsc_rand_u32(0,2)) {
            case 0:  cmd.len = dlsc_rand_u32(1,16); break;
            default: cmd.len = dlsc_rand_u32(1,MAX_BYTES); break;
        }
        cmd_queue.push_back(cmd);
    }

    while( !(cmd_queue.empty() && out_queue.empty() && !fifo_cnt) ) {
        wait(1,SC_US);
        wait(clk.posedge_event());

        if(axi_error && !axi_busy) {
            rst         = 1;
            wait(clk.posedge_event());
            rst         = 0;
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

