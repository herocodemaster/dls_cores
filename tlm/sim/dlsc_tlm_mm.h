
#ifndef DLSC_TLM_MM_H_INCLUDED
#define DLSC_TLM_MM_H_INCLUDED

#include <vector>
#include <tlm.h>

class dlsc_tlm_mm : public tlm::tlm_mm_interface {
public:
    explicit dlsc_tlm_mm(const unsigned int pool_size = 1, const unsigned int payload_size = 0);
    ~dlsc_tlm_mm();
    void set_size(const unsigned int pool_size);
    tlm::tlm_generic_payload *alloc();
    void free(tlm::tlm_generic_payload*);
private:
    void delete_trans(tlm::tlm_generic_payload*);
    std::vector<tlm::tlm_generic_payload*> pool;
    unsigned int outstanding;
    unsigned int size;
    const unsigned int dsize;
};

#endif

