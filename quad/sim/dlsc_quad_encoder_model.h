
#ifndef DLSC_QUAD_ENCODER_MODEL_INCLUDED
#define DLSC_QUAD_ENCODER_MODEL_INCLUDED

#include <systemc>
#include <deque>

class dlsc_quad_encoder_model : public sc_core::sc_module {
public:
    // quadrature signals
    sc_core::sc_out<bool>       quad_a;
    sc_core::sc_out<bool>       quad_b;
    sc_core::sc_out<bool>       quad_z;

    // Configuration
    void set_range(double min, double max);     // internal count will cover interval [min,max)
    void set_index(double min, double max);     // index will be asserted in interval [min,max)
    void set_velocity(double max_vel);          // maximum velocity in ticks/second
    void set_acceleration(double max_accel);    // maximum acceleration in ticks/second^2 (0 for infinite acceleration)
    void set_glitch(sc_core::sc_time min, sc_core::sc_time max);
    void reset();

    // Change Position
    // Call blocks until delta_pos is achieved. Velocity when delta_pos is
    // reached will NOT be 0, so position will overshoot on next invocation.
    void move(double delta_pos, double target_vel=0.0, double accel=0.0);

    // Constructor
    dlsc_quad_encoder_model(
        const sc_core::sc_module_name &nm,
        std::deque<int> &pos_queue);

    SC_HAS_PROCESS(dlsc_quad_encoder_model);

private:

    // configuration
    double range_min;
    double range_max;
    double index_min;
    double index_max;
    double vel_max;
    double accel_max;
    sc_core::sc_time glitch_min;    // minimum width of a single glitch
    sc_core::sc_time glitch_max;    // maximum duration of all glitches for a given transition
    std::deque<int> &pos_queue;
    const sc_core::sc_time time_step;

    // state
    double pos;
    double vel;

    // internal signals
    sc_core::sc_signal<bool>    ideal_a;
    sc_core::sc_signal<bool>    ideal_b;
    sc_core::sc_signal<bool>    ideal_z;

    // update threads
    void update_signal(sc_core::sc_out<bool> &sig, sc_core::sc_signal<bool> &ideal);
    void a_thread();
    void b_thread();
    void z_thread();
};

// constructor
dlsc_quad_encoder_model::dlsc_quad_encoder_model(
    const sc_core::sc_module_name &nm,
    std::deque<int> &pos_queue
) :
    sc_module(nm),
    quad_a("quad_a"),
    quad_b("quad_b"),
    quad_z("quad_z"),
    pos_queue(pos_queue),
    time_step(sc_core::sc_time(10,SC_NS))
{
    pos     = 0.0;
    vel     = 0.0;

    set_range(0.0, 4.0*200);            // 200 CPR
    set_index(0.5,1.5);                 // index asserted for part of 0 and 1 state 
    set_velocity(100000.0);             // 100,000 ticks/second (50,000 transitions/second for each line)
    set_acceleration(10*100000.0);      // reach max velocity in 0.1s
    set_glitch(sc_core::sc_time(10,SC_NS), sc_core::sc_time(500, SC_NS));

    SC_THREAD(a_thread);
    SC_THREAD(b_thread);
    SC_THREAD(z_thread);
}

void dlsc_quad_encoder_model::set_range(
    double min,
    double max
) {
    assert(max > min);
    range_min   = min;
    range_max   = max;
}

void dlsc_quad_encoder_model::set_index(
    double min,
    double max
) {
    assert(max > min);
    index_min   = min;
    index_max   = max;
}

void dlsc_quad_encoder_model::set_velocity(
    double max_vel
) {
    assert(max_vel > 0.0);
    vel_max     = max_vel;
}

void dlsc_quad_encoder_model::set_acceleration(
    double max_accel
) {
    accel_max   = max_accel;
}

void dlsc_quad_encoder_model::set_glitch(
    sc_core::sc_time min,
    sc_core::sc_time max
) {
    // TODO
}

void dlsc_quad_encoder_model::reset() {
    pos         = 0.0;
    vel         = 0.0;
    ideal_a.write(false);
    ideal_b.write(false);
    bool index = (pos >= index_min && pos < index_max);
    ideal_z.write(index);
}

void dlsc_quad_encoder_model::move(
    double delta_pos,
    double target_vel,
    double accel
) {
    if(target_vel <= 0.0) target_vel = vel_max;
    if(accel <= 0.0) accel = accel_max;

    sc_core::sc_time delay = sc_core::SC_ZERO_TIME;

    double dt = time_step.to_seconds();

    int pos_i = (int)floor(pos);
    int pos_prev_i = pos_i;

    bool index = ideal_z.read();
    bool index_prev = index;

    bool done = false;

    while(!done) {
        
        // advance local time
        delay += time_step;

        // update velocity
        if(accel <= 0.0) {
            // infinite acceleration
            vel = delta_pos/dt;
        } else {
            // conventional acceleration
            if(delta_pos < 0) {
                vel -= (accel * dt);
            } else {
                vel += (accel * dt);
            }
        }

        // clamp velocity
        if(vel < -vel_max) vel = -vel_max;
        if(vel >  vel_max) vel =  vel_max;

        // update delta position
        double delta = (vel * dt);
        if(std::abs(delta_pos) <= std::abs(delta)) {
            done = true;
        }
        delta_pos -= delta;
        
        // update absolute position
        pos += delta;
        if(pos < range_min) pos += (range_max-range_min);
        else if(pos >= range_max) pos -= (range_max-range_min);
        pos_prev_i = pos_i;
        pos_i = (int)floor(pos);

        // update index
        index_prev = index;
        index = (pos >= index_min && pos < index_max);
        if(index != index_prev) {
            // sync with simulation time
            sc_core::wait(delay);
            delay = sc_core::SC_ZERO_TIME;

            // update
            ideal_z.write(index);
        }

        // check for tick
        if(pos_i != pos_prev_i) {
            // sync with simulation time
            sc_core::wait(delay);
            delay = sc_core::SC_ZERO_TIME;
            
            // change state
            pos_queue.push_back(pos_i);
            switch(pos_i & 0x3) {
                case 0:
                    ideal_a.write(false);
                    ideal_b.write(false);
                    break;
                case 1:
                    ideal_a.write(true);
                    ideal_b.write(false);
                    break;
                case 2:
                    ideal_a.write(true);
                    ideal_b.write(true);
                    break;
                case 3:
                    ideal_a.write(false);
                    ideal_b.write(true);
                    break;
            }
        }
    }

    // sync with simulation time
    sc_core::wait(delay);
    delay = sc_core::SC_ZERO_TIME;
}
    
void dlsc_quad_encoder_model::update_signal(sc_core::sc_out<bool> &sig, sc_core::sc_signal<bool> &ideal) {
    bool val = ideal.read();
    if(sig.read() != val) {
        // TODO: add glitches
        sig.write(val);
    }
}

void dlsc_quad_encoder_model::a_thread() {
    while(true) {
        wait(ideal_a.value_changed_event());
        update_signal(quad_a,ideal_a);
    }
}

void dlsc_quad_encoder_model::b_thread() {
    while(true) {
        wait(ideal_b.value_changed_event());
        update_signal(quad_b,ideal_b);
    }
}

void dlsc_quad_encoder_model::z_thread() {
    while(true) {
        wait(ideal_z.value_changed_event());
        update_signal(quad_z,ideal_z);
    }
}


#endif // DLSC_QUAD_ENCODER_MODEL_INCLUDED

