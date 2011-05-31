
#include <systemc>
#include <tlm.h>
#include "dlsc_tlm_utils.h"

void dlsc_tlm_quantum_wait(sc_core::sc_time &delay) {
    if(tlm::tlm_global_quantum::instance().get() != sc_core::SC_ZERO_TIME) {
        // check delay against global quantum
        sc_core::sc_time local_quantum;
        while( delay > (local_quantum = tlm::tlm_global_quantum::instance().compute_local_quantum()) ) {
            sc_core::wait(local_quantum);
            delay -= local_quantum;
        }
    }
}

