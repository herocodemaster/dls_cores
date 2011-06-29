
#ifndef DLSC_TLM_MEMTEST_INCLUDED
#define DLSC_TLM_MEMTEST_INCLUDED

#include <vector>
#include <deque>
#include <algorithm>

#include "dlsc_tlm_initiator_nb.h"

//#include <boost/random/uniform_int.hpp>
//#include <boost/random/variate_generator.hpp>

template <typename DATATYPE = uint32_t>
class dlsc_tlm_memtest : public sc_core::sc_module {
public:
    typename dlsc_tlm_initiator_nb<DATATYPE>::socket_type socket;
    
    dlsc_tlm_initiator_nb<DATATYPE> *initiator;
    
    dlsc_tlm_memtest(const sc_core::sc_module_name &nm);

    SC_HAS_PROCESS(dlsc_tlm_memtest);

    bool test(uint64_t addr, unsigned int length, unsigned int iterations);

    void set_ignore_error(const bool ignore_error) { this->ignore_error = ignore_error; }

private:
    typedef typename dlsc_tlm_initiator_nb<DATATYPE>::transaction transaction;

    std::vector<std::deque<transaction> > outstanding; // queue of per-port outstanding transactions
//    std::deque<transaction> outstanding; // queue of outstanding transactions

    sc_core::sc_time    delay;          // local time

    DATATYPE            *mem_array;     // expected memory values
    uint8_t             *init_done;     // indication of if a location has been initialized (sucessfully written to at least once)
    uint8_t             *read_pending;  // indication of pending reads from memory  (don't write to something with a pending read)
    uint8_t             *write_pending; // indication of pending writes to memory   (don't read from something with a pending write)
    DATATYPE            *data;          // data array for generating/checking transactions
    
    // statistics
    sc_core::sc_time    start_time;
    std::vector<unsigned int> bytes_written;
    std::vector<unsigned int> bytes_read;
    std::vector<unsigned int> errors;

    // parameters
    uint64_t            base_addr;      // beginning of region-under-test
    unsigned int        size;           // size of region-under-test
    unsigned int        max_length;     // max burst length
    unsigned int        max_mots;       // max multiple-outstanding-transactions
    bool                ignore_error;   // don't flag failed transactions as an error

    // clears all allocated memory
    void clear();

    // initializes all members and allocates memory for a new test run
    void init();

    // issues a random transaction
    bool launch(int socket_id);

    // issue a read
    void launch_read(int socket_id, unsigned int index, unsigned int length);

    // issue a write (will generate random data)
    void launch_write(int socket_id, unsigned int index, unsigned int length);

    // finds a random region suitable for reading/writing
    bool find_region(unsigned int &index, unsigned int &length, bool &read);

    // finishes a transaction and checks/updates results
    void complete(transaction ts);

    // marks a region as in-use
    inline void open_region(
        unsigned int    index,
        unsigned int    length,
        uint8_t         *pending);      // read_pending,    write_pending

    // marks a region as unused
    inline void close_region(
        unsigned int    index,
        unsigned int    length,
        uint8_t         *pending);      // read_pending,    write_pending
};

template <typename DATATYPE>
dlsc_tlm_memtest<DATATYPE>::dlsc_tlm_memtest(
    const sc_core::sc_module_name &nm
) :
    sc_module(nm),
    socket("socket")
{
    initiator = new dlsc_tlm_initiator_nb<DATATYPE>("initiator");
        initiator->socket.bind(socket);

    mem_array       = 0;
    init_done       = 0;
    read_pending    = 0;
    write_pending   = 0;
    data            = 0;

    ignore_error    = false;
}

template <typename DATATYPE>
bool dlsc_tlm_memtest<DATATYPE>::test(
    uint64_t addr,
    unsigned int length,
    unsigned int iterations)
{
    base_addr   = addr;
    size        = length;
    max_length  = 16;
    max_mots    = 4;

    assert(base_addr % max_length == 0);

    init();

    delay = sc_core::SC_ZERO_TIME;

    dlsc_info("initializing memory");

    initiator->set_socket(0);

    for(unsigned int i=0;i<size;i+=max_length) {
        launch_write(0,i,max_length);
        if(outstanding[0].size() >= max_mots) {
            transaction ts = outstanding[0].front(); outstanding[0].pop_front();
            ts->wait(delay);
            complete(ts);
        }
    }
    
    start_time = sc_core::sc_time_stamp();
    std::fill(errors.begin(),errors.end(),0);
    std::fill(bytes_read.begin(),bytes_read.end(),0);
    std::fill(bytes_written.begin(),bytes_written.end(),0);

    dlsc_info("testing memory");

    for(unsigned int i=0;i<iterations;++i) {
        bool launched = false;

        do {
            // complete finished transactions
            for(unsigned int j=0;j<outstanding.size();++j) {
                while(!outstanding[j].empty() && outstanding[j].front()->nb_done(delay)) {
                    transaction ts = outstanding[j].front(); outstanding[j].pop_front();
                    ts->wait(delay);
                    complete(ts);
                }
            }

            // launch a new one, if possible
            for(unsigned int j=0;j<outstanding.size();++j) {
                unsigned int socket_id = (j+i)%outstanding.size();
                if(outstanding[socket_id].size() < max_mots) {
                    launch(socket_id);
                    launched = true;
                    break;
                }
            }

            // if couldn't launch, wait until something completes
            if(!launched) {
                outstanding[rand()%outstanding.size()].front()->wait(delay);
            }
        } while(!launched);

        if(i%(iterations/10)==0) {
            std::cout << " .. " << std::dec << i << ": " << (sc_core::sc_time_stamp()+delay) << std::endl;
            wait(delay); delay = sc_core::SC_ZERO_TIME;
        }
    }

    std::cout << " .. done" << std::endl;

    for(unsigned int i=0;i<outstanding.size();++i) {
        while(!outstanding[i].empty()) {
            transaction ts = outstanding[i].front(); outstanding[i].pop_front();
            ts->wait(delay);
            complete(ts);
        }
    }
    
    wait(delay); delay = sc_core::SC_ZERO_TIME;

    sc_core::sc_time elapsed = sc_core::sc_time_stamp() - start_time;

    unsigned int total_bytes_read = 0, total_bytes_written = 0;
    
    dlsc_info("Elapsed time: " << elapsed);
    for(unsigned int i=0;i<initiator->get_socket_size();++i) {
        total_bytes_read += bytes_read[i];
        total_bytes_written += bytes_written[i];
        double mbps = ( bytes_read[i] + bytes_written[i] + 0.0 ) / (elapsed.to_seconds()*1000000.0);
        dlsc_info("For socket #" << std::dec << i << ": read: " << bytes_read[i] << ", wrote: " << bytes_written[i] << ", throughput: " << mbps << " MB/s");
        if(errors[i] > 0) {
            if(ignore_error) {
                dlsc_info("Bytes errored: " << errors[i] << " (but ignored)");
            } else {
                dlsc_error("Bytes errored: " << errors[i]);
            }
        }
    }
        
    double mbps = ( total_bytes_read + total_bytes_written + 0.0 ) / (elapsed.to_seconds()*1000000.0);
    dlsc_info("Combined:      read: " << total_bytes_read << ", wrote: " << total_bytes_written << ", throughput: " << mbps << " MB/s");

    return true;
}

// clears all allocated memory
template <typename DATATYPE>
void dlsc_tlm_memtest<DATATYPE>::clear() {
    if(mem_array)       delete mem_array;
    if(init_done)       delete init_done;
    if(read_pending)    delete read_pending;
    if(write_pending)   delete write_pending;
    if(data)            delete data;

    errors.clear();
    bytes_read.clear();
    bytes_written.clear();
    outstanding.clear();

    mem_array       = 0;
    init_done       = 0;
    read_pending    = 0;
    write_pending   = 0;
    data            = 0;
}

// initializes all members and allocates memory for a new test run
template <typename DATATYPE>
void dlsc_tlm_memtest<DATATYPE>::init() {
    clear();

    assert(size > 0 && (size & (size-1)) == 0);

    mem_array       = new DATATYPE[size];
    init_done       = new uint8_t[size];
    read_pending    = new uint8_t[size];
    write_pending   = new uint8_t[size];
    data            = new DATATYPE[max_length];

    errors.resize(initiator->get_socket_size());
    bytes_read.resize(initiator->get_socket_size());
    bytes_written.resize(initiator->get_socket_size());
    outstanding.resize(initiator->get_socket_size());

    std::fill(errors.begin(),errors.end(),0);
    std::fill(bytes_read.begin(),bytes_read.end(),0);
    std::fill(bytes_written.begin(),bytes_written.end(),0);

    std::fill(init_done,init_done+size,0);
    std::fill(read_pending,read_pending+size,0);
    std::fill(write_pending,write_pending+size,0);
}

// issues a random transaction
template <typename DATATYPE>
bool dlsc_tlm_memtest<DATATYPE>::launch(int socket_id) {
    unsigned int index;
    unsigned int length;

    bool read = rand() % 2; // TODO

    if(!find_region(index,length,read)) {
        read = false;
        if(!find_region(index,length,read)) {
            dlsc_warn("launch failed");
            return false;
        }
    }
    
    if(read) {
        launch_read(socket_id,index,length);
    } else {
        launch_write(socket_id,index,length);
    }

    return true;
}

// issue a read
template <typename DATATYPE>
void dlsc_tlm_memtest<DATATYPE>::launch_read(int socket_id, unsigned int index, unsigned int length) {
    uint64_t addr = base_addr + index*sizeof(DATATYPE);
    open_region(index,length,read_pending);
    initiator->set_socket(socket_id);
    outstanding[socket_id].push_back(initiator->nb_read(addr,length,delay));
}

// issue a write (will generate random data)
template <typename DATATYPE>
void dlsc_tlm_memtest<DATATYPE>::launch_write(int socket_id, unsigned int index, unsigned int length) {
    uint64_t addr = base_addr + index*sizeof(DATATYPE);
    open_region(index,length,write_pending);
    for(unsigned int i=0;i<length;++i) {
        data[i] = rand(); // TODO
    }
    initiator->set_socket(socket_id);
    outstanding[socket_id].push_back(initiator->nb_write(addr,data,data+length,delay));
}

// finds a random region suitable for reading/writing (depending on arguments)
template <typename DATATYPE>
bool dlsc_tlm_memtest<DATATYPE>::find_region(
    unsigned int    &index,
    unsigned int    &length,
    bool            &read)
{
    unsigned int burst_boundary = 4096/sizeof(DATATYPE);

    // TODO: randomize better
    unsigned int begin  = rand() % size;                    // [0,size)
    unsigned int max    = (rand() % (max_length-1)) + 1;    // [1,max_length]

    length  = 0;
    unsigned int i = begin;

    // find region
    do {
        if(i == 0) length = 0; // reset length on wrap

        // only write to locations with no pending transactions
        // only read from initialized locations with no pending write transactions
        // (multiple reads are okay)
        if( !write_pending[i] && ( read ? init_done[i] : !read_pending[i] ) ) {
            if(!length) index = i;
            ++length;
        } else if(length) {
            break;
        }
    
        if(++i == size) i = 0; // wrapping increment
    } while(i != begin && length != max);

    // clamp to burst boundary
    unsigned int length_to_boundary = burst_boundary - ((base_addr/sizeof(DATATYPE) + index) % burst_boundary); // [1,burst_boundary]
    if(length > length_to_boundary) length = length_to_boundary;

    assert( (index+length) <= size );

    return (length != 0);
}

// finishes a transaction and checks/updates results
template <typename DATATYPE>
void dlsc_tlm_memtest<DATATYPE>::complete(transaction ts) {
    unsigned int index  = (ts->get_address() - base_addr)/sizeof(DATATYPE);
    unsigned int length = ts->size();

    assert( (index+length) <= size );
    
    if(ts->is_write()) {
        close_region(index,length,write_pending);
    } else {
        close_region(index,length,read_pending);
    }

    if(ts->b_status(delay) != tlm::TLM_OK_RESPONSE) {
        if(ts->is_write()) {
            // may have corrupted location with partial write; de-initialize
            std::fill(init_done+index,init_done+index+length,0);
        }

        errors[ts->get_socket_id()] += length * sizeof(DATATYPE);

        if(ignore_error) {
            dlsc_verb ("transaction failed at 0x" << std::hex << ts->get_address() << ", length: " << std::dec << (ts->size()*sizeof(DATATYPE)) );
        } else {
            dlsc_error("transaction failed at 0x" << std::hex << ts->get_address() << ", length: " << std::dec << (ts->size()*sizeof(DATATYPE)) );
        }
        return;
    }

    dlsc_okay("transaction completed at 0x" << std::hex << ts->get_address());

    if(ts->is_write()) {
        
        bytes_written[ts->get_socket_id()] += length * sizeof(DATATYPE);
        
        // update array with written data
        ts->b_read(mem_array+index,delay);

        // indicate location has been initialized
        std::fill(init_done+index,init_done+index+length,0xFF);

    } else {
        
        bytes_read[ts->get_socket_id()] += length * sizeof(DATATYPE);

        // compare against array
        ts->b_read(data,delay);

        for(unsigned int i=0;i<length;++i) {
            if(mem_array[i+index] != data[i]) {
                dlsc_error("miscompare at 0x" << std::hex << (ts->get_address() + i*sizeof(DATATYPE)) \
                    << "; expected 0x" << mem_array[i+index] << ", but got 0x" << data[i]);
            }
        }

    }
}

// marks a region as in-use
template <typename DATATYPE>
void dlsc_tlm_memtest<DATATYPE>::open_region(
    unsigned int    index,
    unsigned int    length,
    uint8_t         *pending)
{
    for(unsigned int i=index;i<(index+length);++i) {
        assert(pending[i] < 0xFF);
        ++pending[i];
    }
}

// marks a region as unused; also updates hit counts
template <typename DATATYPE>
void dlsc_tlm_memtest<DATATYPE>::close_region(
    unsigned int    index,
    unsigned int    length,
    uint8_t         *pending)
{
    for(unsigned int i=index;i<(index+length);++i) {
        assert(pending[i] > 0);
        --pending[i];
    }
}

#endif

