
#ifndef DLSC_RAND_H_INCLUDED
#define DLSC_RAND_H_INCLUDED

#include <stdint.h>
#include <boost/random/mersenne_twister.hpp>
#include <boost/random/uniform_int_distribution.hpp>
#include <boost/random/uniform_real_distribution.hpp>
#include <boost/random/bernoulli_distribution.hpp>

class dlsc_random
{
public:
    dlsc_random() :
        gen_(dlsc_random::get_seed())
    {
    }

    template <typename T>
    T operator() (T const min, T const max)
    {
        return this->rand<T>(min,max);
    }

    template <typename T>
    T rand(T const min, T const max);

    bool rand_bool(double const p)
    {
        assert(p >= 0.0 && p <= 1.0);
        boost::random::bernoulli_distribution<double> dist(p);
        return dist(gen_);
    }

private:
    boost::mt19937 gen_;

private:
    static uint32_t get_seed();
};

template <typename T>
T dlsc_random::rand(T const min, T const max)
{
    assert(min <= max);
    boost::random::uniform_int_distribution<T> dist(min, max);
    return dist(gen_);
}

template <>
double dlsc_random::rand(double const min, double const max)
{
    assert(min <= max);
    boost::random::uniform_real_distribution<double> dist(min, max);
    return dist(gen_);
}

template <>
float dlsc_random::rand(float const min, float const max)
{
    assert(min <= max);
    boost::random::uniform_real_distribution<float> dist(min, max);
    return dist(gen_);
}

#endif // DLSC_RAND_H_INCLUDED

