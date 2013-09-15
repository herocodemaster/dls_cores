
#ifndef DLSC_BV_H_INCLUDED
#define DLSC_BV_H_INCLUDED

#include <systemc>
#include <stdint.h>
#include <algorithm>
#include <limits>

template <
    int ELEMENTS,               // number of elements in vector
    int BITS,                   // width of each element in bits; total width of vector is [ELEMENTS*BITS]
    typename T = uint64_t,      // type used to represent each element
    int WIDTH = (ELEMENTS*BITS) // total width of vector; derived (don't touch)
>
class dlsc_bv
{
public:
    // ** constructors **

    dlsc_bv()
    {
        std::fill(values_,values_+ELEMENTS,0);
    }

    dlsc_bv(dlsc_bv const & other)
    {
        *this = other;
    }

    dlsc_bv(sc_dt::sc_bv<WIDTH> const & other)
    {
        *this = other;
    }

    dlsc_bv(uint64_t const other)
    {
        *this = other;
    }

    // ** assignment operators **

    dlsc_bv & operator= (dlsc_bv const & other)
    {
        std::copy(other.values_,other.values_+ELEMENTS,values_);
        return *this;
    }

    dlsc_bv & operator= (sc_dt::sc_bv<WIDTH> const & other)
    {
        for(size_t i=0;i<ELEMENTS;++i)
        {
            values_[i] = other.range( i*BITS+BITS-1 , i*BITS ).to_uint64();
        }
        SignExtend();
        return *this;
    }

    dlsc_bv & operator= (uint64_t const other)
    {
        sc_dt::sc_bv<WIDTH> const bv(other);
        return (*this = bv);
    }

    // ** cast operators **

    operator sc_dt::sc_bv<WIDTH> () const
    {
        sc_dt::sc_bv<WIDTH> bv;
        for(size_t i=0;i<ELEMENTS;++i)
        {
            bv.range( i*BITS+BITS-1 , i*BITS ) = values_[i];
        }
        return bv;
    }

    operator uint64_t () const
    {
        sc_dt::sc_bv<WIDTH> const bv = *this;
        return bv.to_uint64();
    }

    // ** element access **

    T & operator[] (size_t const n)
    {
        assert(n < ELEMENTS);
        return values_[n];
    }

    T const & operator[] (size_t const n) const
    {
        assert(n < ELEMENTS);
        return values_[n];
    }

private:
    void SignExtend()
    {
        if(!std::numeric_limits<T>::is_signed)
            return;
        for(size_t i=0;i<ELEMENTS;++i)
        {
            if(values_[i] & (1ll << (BITS-1))) {
                // sign set; is negative; set all sign bits
                values_[i] |= ~((1ll << BITS) - 1ll);
            } else {
                // sign clear; is positive; clear all sign bits
                values_[i] &= ((1ll << BITS) - 1ll);
            }
        }
    }

private:
    T values_[ELEMENTS];
};

#endif

