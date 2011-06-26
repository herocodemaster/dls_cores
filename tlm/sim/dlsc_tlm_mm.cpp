
#include <stdint.h>
#include "dlsc_tlm_mm.h"

#include "dlsc_common.h"

dlsc_tlm_mm::dlsc_tlm_mm(const unsigned int pool_size, const unsigned int payload_size) : dsize(payload_size) {
    outstanding = 0;
    set_size(pool_size);
}

dlsc_tlm_mm::~dlsc_tlm_mm() {
    std::vector<tlm::tlm_generic_payload*>::iterator it = pool.begin();

    while(it != pool.end()) {
        delete_trans(*it);
        it++;
    }

//    if(outstanding) {
//        dlsc_warn("destroyed with outstanding transactions");
//    }
}

void dlsc_tlm_mm::set_size(const unsigned int pool_size) {
    assert(pool_size > 0);

    size = pool_size;
    
    while(pool.size() > size) {
        delete_trans(pool.back());
        pool.pop_back();
    }
}

void dlsc_tlm_mm::free(tlm::tlm_generic_payload *trans) {
    assert(trans != NULL);

    trans->reset();

    if(pool.size() >= size) {
        delete_trans(trans);
    } else {
        pool.push_back(trans);
    }
    
    outstanding--;
}

void dlsc_tlm_mm::delete_trans(tlm::tlm_generic_payload *trans) {
    if(dsize) {
        assert(trans->get_data_ptr() && trans->get_byte_enable_ptr());
        delete trans->get_data_ptr();
        delete trans->get_byte_enable_ptr();
    }
    delete trans;
}

tlm::tlm_generic_payload *dlsc_tlm_mm::alloc() {
    tlm::tlm_generic_payload *trans;

    if(!pool.empty()) {
        trans = pool.back();
        pool.pop_back();
    } else {
        trans = new tlm::tlm_generic_payload();
        trans->set_mm(this);

        if(dsize) {
            uint8_t *ptr = new uint8_t[dsize];
            trans->set_data_ptr(ptr);
            ptr = new uint8_t[dsize];
            trans->set_byte_enable_ptr(ptr);
        }
    }

    trans->set_command(tlm::TLM_IGNORE_COMMAND);
    trans->set_address(0);
//  trans->set_data_ptr(NULL);
    trans->set_data_length(0);
//  trans->set_byte_enable_ptr(NULL);
    trans->set_byte_enable_length(0);
    trans->set_streaming_width(0);
    trans->set_dmi_allowed(false);
    trans->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
    
    outstanding++;

    return trans;
}

