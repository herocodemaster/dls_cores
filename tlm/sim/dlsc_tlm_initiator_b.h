
#ifndef DLSC_TLM_INITIATOR_B_H_INCLUDED
#define DLSC_TLM_INITIATOR_B_H_INCLUDED

#include <systemc>
#include <tlm.h>
#include <tlm_utils/simple_initiator_socket.h>
#include <vector>
#include <algorithm>

template <typename DATATYPE = uint32_t>
class dlsc_tlm_initiator_b : public sc_core::sc_module {
public:
    tlm_utils::simple_initiator_socket<dlsc_tlm_initiator_b<DATATYPE>,sizeof(DATATYPE)*8,tlm::tlm_base_protocol_types> socket;

    dlsc_tlm_initiator_b(const sc_core::sc_module_name &nm, const unsigned int max_length = 16) :
        sc_module(nm),
        bus_width(sizeof(DATATYPE)),
        max_lengthb(max_length*bus_width)
    {
        assert(max_lengthb > 0);

        unsigned char *dptr;
        
        b_payload = new tlm::tlm_generic_payload;
        
        dptr = new unsigned char[max_lengthb];
        b_payload->set_data_ptr(dptr);
        
        dptr = new unsigned char[max_lengthb];
        b_payload->set_byte_enable_ptr(dptr);
    }

    ~dlsc_tlm_initiator_b() {
        delete b_payload->get_data_ptr();
        delete b_payload->get_byte_enable_ptr();
        delete b_payload;
    }
   
    // *** Blocking Reads (annotated) ***

    template<class InputIterator>
    bool b_read(const uint64_t addr, InputIterator first, const unsigned int length, sc_core::sc_time &delay) {
        unsigned int lengthb = length * bus_width;
        assert(lengthb != 0 && lengthb <= max_lengthb); 
        b_payload->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        b_payload->set_command(tlm::TLM_READ_COMMAND);
        b_payload->set_address(addr);
        b_payload->set_data_length(lengthb);
        b_payload->set_byte_enable_length(0);
        b_payload->set_streaming_width(lengthb);
        socket->b_transport(*b_payload,delay);
        if(b_payload->get_response_status() == tlm::TLM_OK_RESPONSE) {
            DATATYPE *dptr = reinterpret_cast<DATATYPE*>(b_payload->get_data_ptr());
            std::copy(dptr,dptr+length,first);
            return true;
        }
        return false;
    }

    inline bool b_read(const uint64_t addr, DATATYPE &data, sc_core::sc_time &delay)                                    { return b_read(addr,&data,1,delay); }
    inline bool b_read(const uint64_t addr, DATATYPE *data, const unsigned int length, sc_core::sc_time &delay)         { return b_read(addr,data,length,delay); }
    inline bool b_read(const uint64_t addr, std::vector<DATATYPE> &data, const unsigned int length, sc_core::sc_time &delay) { data.resize(length); return b_read(addr,data.begin(),length,delay); }
   
    // *** Blocking Reads (unannotated) ***

    template<class InputIterator>
    bool b_read(const uint64_t addr, InputIterator first, const unsigned int length) {
        sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
        bool result = b_read(addr,first,length,delay);
        if(delay != sc_core::SC_ZERO_TIME) sc_core::wait(delay);
        return result;
    }

    inline bool b_read(const uint64_t addr, DATATYPE &data)                                                             { return b_read(addr,&data,1); }
    inline bool b_read(const uint64_t addr, DATATYPE *data, const unsigned int length)                                  { return b_read(addr,data,length); }
    inline bool b_read(const uint64_t addr, std::vector<DATATYPE> &data, const unsigned int length)                     { data.resize(length); return b_read(addr,data.begin(),length); }

    // *** Blocking Writes (annotated) ***

    template<class InputIterator>
    bool b_write(const uint64_t addr, InputIterator first, InputIterator last, sc_core::sc_time &delay) {
        unsigned int lengthb = (last - first) * bus_width;
        assert(lengthb != 0 && lengthb <= max_lengthb); 
        b_payload->set_response_status(tlm::TLM_INCOMPLETE_RESPONSE);
        b_payload->set_command(tlm::TLM_WRITE_COMMAND);
        b_payload->set_address(addr);
        b_payload->set_data_length(lengthb);
        b_payload->set_byte_enable_length(0);
        b_payload->set_streaming_width(lengthb);
        std::copy(first,last,reinterpret_cast<DATATYPE*>(b_payload->get_data_ptr()));
        socket->b_transport(*b_payload,delay);
        return (b_payload->get_response_status() == tlm::TLM_OK_RESPONSE);
    }
    
    inline bool b_write(const uint64_t addr, const DATATYPE data, sc_core::sc_time &delay)                              { return b_write(addr,&data,1,delay); }
    inline bool b_write(const uint64_t addr, const DATATYPE *data, const unsigned int length, sc_core::sc_time &delay)  { return b_write(addr,data,data+length,delay); }
    inline bool b_write(const uint64_t addr, const std::vector<DATATYPE> &data, sc_core::sc_time &delay)                { return b_write(addr,data.begin(),data.end(),delay); }

    // *** Blocking Writes (unannotated) ***

    template<class InputIterator>
    bool b_write(const uint64_t addr, InputIterator first, InputIterator last) {
        sc_core::sc_time delay = sc_core::SC_ZERO_TIME;
        bool result = b_write(addr,first,last,delay);
        if(delay != sc_core::SC_ZERO_TIME) sc_core::wait(delay);
        return result;
    }

    inline bool b_write(const uint64_t addr, const DATATYPE data)                                                       { return b_write(addr,&data,1); }
    inline bool b_write(const uint64_t addr, const DATATYPE *data, const unsigned int length)                           { return b_write(addr,data,data+length); }
    inline bool b_write(const uint64_t addr, const std::vector<DATATYPE> &data)                                         { return b_write(addr,data.begin(),data.end()); }

    SC_HAS_PROCESS(dlsc_tlm_initiator_b);

private:
    // no copying/assigning
    dlsc_tlm_initiator_b(const dlsc_tlm_initiator_b &src);
    dlsc_tlm_initiator_b& operator= (const dlsc_tlm_initiator_b &src);
    
    // parameters
    const unsigned int bus_width;
    const unsigned int max_lengthb;

    // blocking
    tlm::tlm_generic_payload *b_payload; // payload for use with blocking operations (class member to save alloc/dealloc time)
    
//    // dmi
//    struct dmi_range { uint64_t lower; uint64_t upper; tlm::tlm_dmi dmi_data; };
//    bool                    dmi_read_possible;
//    bool                    dmi_write_possible;
//    std::vector<dmi_range>  dmi_read;
//    std::vector<dmi_range>  dmi_write;
//    inline bool dmi_can_read(const uint64_t addr, const unsigned int lengthb) { return dmi_can(addr,lengthb,dmi_read); }
//    inline bool dmi_can_write(const uint64_t addr, const unsigned int lengthb) { return dmi_can(addr,lengthb,dmi_write); }
//    
//    bool dmi_can(const uint64_t addr, const unsigned int lengthb, std::vector<dmi_range> &dmi_vect) {
//        const unsigned int addru = addr+lengthb;
//        for(typename std::vector<dmi_range>::iterator it = dmi_vect.begin(); it != dmi_vect.end(); ++it) {
//            if(addr >= (*it).lower && addru <= (*it).upper) { return true; }
//        }
//        return false;
//    }
//
//    void dmi_set_read() {
//        dmi_set(lower,upper,dmi_read);
//        dmi_read_possible = true;
//    }
//
//    void dmi_set_write() {
//        dmi_set(lower,upper,dmi_write);
//        dmi_write_possible = true;
//    }
//
//    void dmi_set(tlm::tlm_dmi &dmi_data, std::vector<dmi_range> &dmi_vect) {
//        for(typename std::vector<dmi_range>::iterator it = dmi_vect.begin(); it != dmi_vect.end(); ++it) {
//            if( (lower >= (*it).lower && lower <= (*it).upper) ||
//                (upper >= (*it).lower && upper <= (*it).upper) )
//            {
//                (*it).lower = std::min((*it).lower,lower);
//                (*it).upper = std::max((*it).upper,upper);
//                return;
//            }
//        }
//        const dmi_range r = { lower, upper };
//        dmi_vect.push_back(r);
//    }
//
//    void dmi_clear(const uint64_t lower, const uint64_t upper) {
//        dmi_clear(lower,upper,dmi_read);
//        dmi_clear(lower,upper,dmi_write);
//    }
//
//    void dmi_clear(const uint64_t lower, const uint64_t upper, std::vector<dmi_range> &dmi_vect) {
//        for(typename std::vector<dmi_range>::iterator it = dmi_vect.begin(); it != dmi_vect.end(); ++it) {
//            if( (lower >= (*it).lower && lower <= (*it).upper) ||
//                (upper >= (*it).lower && upper <= (*it).upper) )
//            {
//                it = dmi_vect.erase(it);
//            }
//        }
//    }

};


#endif


