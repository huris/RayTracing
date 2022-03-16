# Ray Tracing The Next Week

https://raytracing.github.io/books/RayTracingTheNextWeek.html



## 8. 实例

Cornell盒子里通常由两个物体，这些是相对于壁面旋转的。

首先，创建一个包含6个平面组成的轴对齐块元素：

`box.h`

```c++
#ifndef THENEXTWEEK_BOX_H
#define THENEXTWEEK_BOX_H

#include "rtweekend.h"

#include "aarect.h"
#include "hittable_list.h"

class box : public hittable  {
public:
    box() {}
    box(const point3& p0, const point3& p1, shared_ptr<material> ptr);

    virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override;

    virtual bool bounding_box(double time0, double time1, aabb& output_box) const override {
        output_box = aabb(box_min, box_max);
        return true;
    }

public:
    point3 box_min;
    point3 box_max;
    hittable_list sides;
};

box::box(const point3& p0, const point3& p1, shared_ptr<material> ptr) {
    box_min = p0;
    box_max = p1;

    sides.add(make_shared<xy_rect>(p0.x(), p1.x(), p0.y(), p1.y(), p1.z(), ptr));
    sides.add(make_shared<xy_rect>(p0.x(), p1.x(), p0.y(), p1.y(), p0.z(), ptr));

    sides.add(make_shared<xz_rect>(p0.x(), p1.x(), p0.z(), p1.z(), p1.y(), ptr));
    sides.add(make_shared<xz_rect>(p0.x(), p1.x(), p0.z(), p1.z(), p0.y(), ptr));

    sides.add(make_shared<yz_rect>(p0.y(), p1.y(), p0.z(), p1.z(), p1.x(), ptr));
    sides.add(make_shared<yz_rect>(p0.y(), p1.y(), p0.z(), p1.z(), p0.x(), ptr));
}

bool box::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    return sides.hit(r, t_min, t_max, rec);
}

#endif //THENEXTWEEK_BOX_H
```

之后添加两个物体：

`RayTracing.cpp`

```c++
#include "box.h"
...
objects.add(make_shared<box>(point3(130, 0, 65), point3(295, 165, 230), white));
objects.add(make_shared<box>(point3(265, 0, 295), point3(430, 330, 460), white));
```

得到结果：

<img src="./images/Cornell box with two blocks.png"  style="zoom:40%;" />

现在有了两个长方体，为了让它们更接近正宗的Cornell盒子，需要让它们旋转一下。

光线追踪中，通常使用**实例（Instance）**来完成这个工作。

实例是一种经过旋转或者平移等操作的几何图元，这在光线追踪中更加简单，因为我们不需要移动任何东西，取代而之是将光线移动到相反的方向。

例如，对于一个平移操作，我们可以取原点的粉色方框，将它所有的x分量加$2$，或者（就像我们在光线追踪中经常做的那样）让方框保持原样，但是在它的`hit`过程中，将射线原点的方向减去$2$。

<img src="./images/Ray-box intersection with moved ray vs box.jpg"  style="zoom:70%;" />

### 8.1 实例移动

移动`hittable`类的translate代码如下：

`hittable.h`

```c++
class translate : public hittable {
    public:
        translate(shared_ptr<hittable> p, const vec3& displacement)
            : ptr(p), offset(displacement) {}

        virtual bool hit(
            const ray& r, double t_min, double t_max, hit_record& rec) const override;

        virtual bool bounding_box(double time0, double time1, aabb& output_box) const override;

    public:
        shared_ptr<hittable> ptr;
        vec3 offset;
};

bool translate::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    ray moved_r(r.origin() - offset, r.direction(), r.time());
    if (!ptr->hit(moved_r, t_min, t_max, rec))
        return false;

    rec.p += offset;
    rec.set_face_normal(moved_r, rec.normal);

    return true;
}

bool translate::bounding_box(double time0, double time1, aabb& output_box) const {
    if (!ptr->bounding_box(time0, time1, output_box))
        return false;

    output_box = aabb(
        output_box.min() + offset,
        output_box.max() + offset);

    return true;
}
```

### 8.2 实例旋转

旋转可能就没有那么容易理解或者列出方程。

一个常用的图像技巧是**将所有的旋转都当成是绕$xyz$轴旋转**。

首先，绕$z$轴旋转，这样只会改变$xy$而不会改变$z$值。

<img src="./images/Rotation about the Z axis.jpg"  style="zoom:70%;" />

这里包含了一些三角几何，绕$z$轴逆时针旋转的公式如下：

- $x'=\cos(\theta)\cdot x-\sin(\theta)\cdot{y}$
- $y'=\sin(\theta)\cdot x+\cos(\theta)\cdot{y}$

这个公式对任何$\theta$都成立，不需要考虑象限问题，如果要顺时针旋转，只需把$\theta$改为$-\theta$即可。

类似的，绕$y$轴旋转的公式如下：

- $x'=\cos(\theta)\cdot x+\sin(\theta)\cdot{z}$
- $y'=-\sin(\theta)\cdot x+\cos(\theta)\cdot{z}$

绕$x$轴旋转的公式如下：

- $y'=\cos(\theta)\cdot y-\sin(\theta)\cdot{z}$
- $z'=\sin(\theta)\cdot y+\cos(\theta)\cdot{z}$

与平移变换不同，旋转时表面法向量也发生了变化，所以在计算完`hit`函数后还要重新计算法向量。

`hittable.h`

```c++
class rotate_y : public hittable {
public:
    rotate_y(shared_ptr<hittable> p, double angle);

    virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override;

    virtual bool bounding_box(double time0, double time1, aabb& output_box) const override {
        output_box = bbox;
        return hasbox;
    }

public:
    shared_ptr<hittable> ptr;
    double sin_theta;
    double cos_theta;
    bool hasbox;
    aabb bbox;
};

rotate_y::rotate_y(shared_ptr<hittable> p, double angle) : ptr(p) {
    auto radians = degrees_to_radians(angle);
    sin_theta = sin(radians);
    cos_theta = cos(radians);
    hasbox = ptr->bounding_box(0, 1, bbox);

    point3 min( infinity,  infinity,  infinity);
    point3 max(-infinity, -infinity, -infinity);

    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 2; j++) {
            for (int k = 0; k < 2; k++) {
                auto x = i * bbox.max().x() + (1 - i) * bbox.min().x();
                auto y = j * bbox.max().y() + (1 - j) * bbox.min().y();
                auto z = k * bbox.max().z() + (1 - k) * bbox.min().z();

                auto newx =  cos_theta * x + sin_theta * z;
                auto newz = -sin_theta * x + cos_theta * z;

                vec3 tester(newx, y, newz);

                for (int c = 0; c < 3; c++) {
                    min[c] = fmin(min[c], tester[c]);
                    max[c] = fmax(max[c], tester[c]);
                }
            }
        }
    }

    bbox = aabb(min, max);
}

bool rotate_y::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    auto origin = r.origin();
    auto direction = r.direction();

    origin[0] = cos_theta * r.origin()[0] - sin_theta * r.origin()[2];
    origin[2] = sin_theta * r.origin()[0] + cos_theta * r.origin()[2];

    direction[0] = cos_theta * r.direction()[0] - sin_theta * r.direction()[2];
    direction[2] = sin_theta * r.direction()[0] + cos_theta * r.direction()[2];

    ray rotated_r(origin, direction, r.time());

    if (!ptr->hit(rotated_r, t_min, t_max, rec)) return false;

    auto p = rec.p;
    auto normal = rec.normal;

    p[0] =  cos_theta * rec.p[0] + sin_theta * rec.p[2];
    p[2] = -sin_theta * rec.p[0] + cos_theta * rec.p[2];

    normal[0] =  cos_theta * rec.normal[0] + sin_theta * rec.normal[2];
    normal[2] = -sin_theta * rec.normal[0] + cos_theta * rec.normal[2];

    rec.p = p;
    rec.set_face_normal(rotated_r, normal);

    return true;
}
```

改变Cornell盒子：

`RayTracing.cpp`

```c++
shared_ptr<hittable> box1 = make_shared<box>(point3(0, 0, 0), point3(165, 330, 165), white);
box1 = make_shared<rotate_y>(box1, 15);
box1 = make_shared<translate>(box1, vec3(265,0,295));
objects.add(box1);

shared_ptr<hittable> box2 = make_shared<box>(point3(0,0,0), point3(165,165,165), white);
box2 = make_shared<rotate_y>(box2, -18);
box2 = make_shared<translate>(box2, vec3(130,0,65));
objects.add(box2);
```

得到结果：

<img src="./images/Standard Cornell box scene.png"  style="zoom:40%;" />

## 9. 体积体







