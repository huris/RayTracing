cmake_minimum_required(VERSION 3.20.3)
project(inOneWeekend)

set(CMAKE_CXX_STANDARD 14)

include_directories(.)

add_executable(inOneWeekend
        RayTracing.cpp
        vec3.h
        color.h
        ray.h
        hittable.h
        sphere.h
        hittable_list.h
        rtweekend.h
        camera.h)
