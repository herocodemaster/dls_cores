//######################################################################
#sp interface

#include <systemperl.h>

#include <deque>

#include "dlsc_tlm_memory.h"
#include "dlsc_tlm_channel.h"

/*AUTOSUBCELL_CLASS*/

#define FIFO_SIZE (1<<PARAM_FIFO_ADDR)

#define MEM_SIZE (1ull<<PARAM_ADDR)
#define MAX_BYTES ((1u<<PARAM_BLEN)-1)

struct cmd_type {
    uint64_t    addr;
    uint32_t    len;
};

struct in_type {
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
    std::deque<in_type> in_queue;
    std::deque<cmd_type> chk_cmd_queue;
    std::deque<in_type> chk_data_queue;
    
    uint32_t fifo_cnt;
    uint32_t fifo_cnt_pre;

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
    fifo_cnt_pre = 0;

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

        in_count    = 0;
        in_valid    = 0;
        in_data     = 0;
        in_strb     = 0;

        in_queue.clear();
        chk_cmd_queue.clear();
        chk_data_queue.clear();
        
        fifo_cnt    = 0;
        fifo_cnt_pre = 0;
    } else {

        // ** commands **

        if( cmd_ready ) {
            cmd_valid   = 0;
        }

        if( (cmd_ready || !cmd_valid) && !cmd_queue.empty() && dlsc_rand_bool(25.0) ) {
            cmd_type cmd = cmd_queue.front(); cmd_queue.pop_front();
            chk_cmd_queue.push_back(cmd);

            cmd_valid   = 1;
            cmd_addr    = cmd.addr;
            cmd_bytes   = cmd.len;

            // generate input data
            std::deque<uint32_t> data;
            data.resize( (cmd.len+(cmd.addr&0x3)+3)>>2 );
            for(int i=0;i<data.size();i++) {
                data[i] = dlsc_rand_u32();
            }
            in_type in;
            in.first   = true;
            in.last    = false;
            while(!data.empty()) {
                in.data    = data.front(); data.pop_front();
                in.last    = data.empty();
                in.strb    = 0xF;
                if(in.first) {
                    switch(cmd.addr & 0x3) {
                        case 0: in.strb = 0xF; break;
                        case 1: in.strb = 0xE; break;
                        case 2: in.strb = 0xC; break;
                        case 3: in.strb = 0x8; break;
                    }
                }
                if(in.last) {
                    switch( (cmd.addr+cmd.len) & 0x3) {
                        case 1: in.strb &= 0x1; break;
                        case 2: in.strb &= 0x3; break;
                        case 3: in.strb &= 0x7; break;
                        case 0: in.strb &= 0xF; break;
                    }
                }
                in_queue.push_back(in);
                fifo_cnt_pre++;
                in.first   = false;
            }
        }

        // ** count **

        if(in_ready && in_valid) {
            if(fifo_cnt == 0) {
                dlsc_error("FIFO underrun");
            }
            fifo_cnt_pre--;
            fifo_cnt--;
        }

        if(fifo_cnt < fifo_cnt_pre && dlsc_rand_bool(95.0)) {
            fifo_cnt++;
        }

        if(fifo_cnt > FIFO_SIZE) {
            in_count = FIFO_SIZE;
        } else {
            in_count = fifo_cnt;
        }

        // ** data **

        if( in_ready ) {
            in_valid    = 0;
        }

        if( (in_ready || !in_valid) && !in_queue.empty() && dlsc_rand_bool(95.0) ) {
            // drive data
            in_type in = in_queue.front(); in_queue.pop_front();
            chk_data_queue.push_back(in);
            
            in_valid    = 1;
            in_data     = in.data;
            in_strb     = in.strb;
        }

        // ** check completed commands **

        if(cmd_done) {

            if(chk_cmd_queue.empty()) {
                dlsc_error("unexpected cmd_done");
            } else {
                cmd_type cmd = chk_cmd_queue.front(); chk_cmd_queue.pop_front();
                
                // get memory contents
                std::deque<uint32_t> data;
                memory->nb_read(cmd.addr & ~0x3ull, (cmd.len+(cmd.addr&0x3)+3)>>2, data);
            
                while(!data.empty()) {
                    if(chk_data_queue.empty()) {
                        dlsc_error("chk_data_queue underrun");
                        break;
                    }
                    
                    in_type in = chk_data_queue.front(); chk_data_queue.pop_front();

                    uint32_t d_expect, d_dut, d_mask;

                    d_mask      = ( (in.strb & 0x1) ? 0x000000FF : 0 ) |
                                  ( (in.strb & 0x2) ? 0x0000FF00 : 0 ) |
                                  ( (in.strb & 0x4) ? 0x00FF0000 : 0 ) |
                                  ( (in.strb & 0x8) ? 0xFF000000 : 0 );

                    d_expect    = in.data & d_mask;
                    d_dut       = data.front() & d_mask; data.pop_front();

                    if(!axi_error) {
                        dlsc_assert_equals(d_expect,d_dut);
                    }

                    cmd.addr    = (cmd.addr & ~0x3ull) + 4;
                }
            }

        }

    }
}

void __MODULE__::stim_thread() {
    rst         = 1;
    rst_axi     = 1;
    wait(100,SC_NS);
    wait(clk.posedge_event());
    rst         = 0;
    rst_axi     = 0;

    dlsc_info("testing without AXI errors");

    for(int i=0;i<100;++i) {
        cmd_type cmd;
        cmd.addr = dlsc_rand_u64(0,MEM_SIZE - MAX_BYTES);
        switch(dlsc_rand_u32(0,2)) {
            case 0:  cmd.len = dlsc_rand_u32(1,16); break;
            default: cmd.len = dlsc_rand_u32(1,MAX_BYTES); break;
        }
        cmd_queue.push_back(cmd);
    }

    while( !(cmd_queue.empty() && in_queue.empty() && chk_cmd_queue.empty() && chk_data_queue.empty() ) ) {
        wait(1,SC_US);
        if(axi_error) {
            dlsc_error("axi_error should never assert during this test");
        }
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

    dlsc_info("testing with AXI errors");

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

    while( !(cmd_queue.empty() && in_queue.empty() && chk_cmd_queue.empty() && chk_data_queue.empty() ) ) {
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

