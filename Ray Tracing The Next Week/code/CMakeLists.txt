cmake_minimum_required(VERSION 3.20.3)
project(theNextWeek)

set(CMAKE_CXX_STANDARD 14)

include_directories(.)

add_executable(theNextWeek
        RayTracing.cpp
        vec3.h
        color.h
        ray.h
        hittable.h
        sphere.h
        hittable_list.h
        rtweekend.h
        camera.h
        material.h
        moving_sphere.h
        aabb.h
        bvh.h
        texture.h
        perlin.h
        rtw_stb_image.h
        aarect.h
        box.h)
