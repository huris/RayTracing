#ifndef INONEWEEKEND_RAY_H
#define INONEWEEKEND_RAY_H

#include "vec3.h"

class ray {
public:
    ray(){}
    ray(const point3& origin, const vec3& direction, double time): orig(origin), dir(direction), tm(time){}

    point3 origin() const {return orig;}
    vec3 direction() const {return dir;}
    double time() const {return tm;}

    point3 at(double t) const {
        return orig + t * dir;
    }

public:
    point3 orig;
    point3 dir;
    double tm;
};

#endif //INONEWEEKEND_RAY_H
