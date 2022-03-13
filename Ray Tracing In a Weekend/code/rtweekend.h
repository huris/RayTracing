#ifndef INONEWEEKEND_RTWEEKEND_H
#define INONEWEEKEND_RTWEEKEND_H

#include "cmath"
#include "limits"
#include "memory"
#include "cstdlib"
#include "random"

// Usings
using std::shared_ptr;
using std::make_shared;
using std::sqrt;

// Constants
const double infinity = std::numeric_limits<double>::infinity();
const double pi = acos(-1.0);

// Utility Functions
inline double degrees_to_radians(double degrees) {
    return degrees * pi / 180.0;
}

inline double random_double() {
    // Returns a random real in [0, 1)
    return rand() / (RAND_MAX + 1.0);
}

//inline double random_double() {
//    // Returns a random real in [0, 1)
//    static std::uniform_real_distribution<double> distribution(0.0, 1.0);
//    static std::mt19937 generator;
//
//    return distribution(generator);
//}

inline double random_double(double MIN, double MAX){
    // Returns a random real in [min, max)
    return MIN + (MAX - MIN) * random_double();
}

inline double clamp(double x, double MIN, double MAX) {
    if(x < MIN) return MIN;
    if(x > MAX) return MAX;
    return x;
}


// Common Headers
#include "ray.h"
#include "vec3.h"

#endif //INONEWEEKEND_RTWEEKEND_H
