# Ray Tracing The Next Week

https://raytracing.github.io/books/RayTracingTheNextWeek.html



## 1. 概述

在Ray Tracing in One Weekend中，暴力实现了一个光线路径追踪器。

之后，会在其中加入纹理，体积体（例如烟雾），矩形，实例，光源，同时用BVH在进行加速。

当做完这些之后，将拥有一个**真正的**光线追踪器。

本文中最难的两部分是**BVH**和**柏林噪声贴图**。

## 2. 运动模糊

做光线追踪时，如果想要更好的图片质量，则意味着需要更多的程序运行时间。

例如在ray tracing in one weekend的反射部分和镜头散焦模糊中，需要对每个像素进行多重采样。

**几乎所有的特效都可以通过这种暴力来进行实现**。

**运动模糊**也可以通过这种方式来实现，想象一个真实世界的摄像机，在快门打开的时间间隔中，摄像机和物体都可以移动，则拍出来的结果是**整个运动过程中每一帧的平均值**。

### 2.1 光线追踪的空间时间

可以用随机的方法在**不同时间发射多条射线**来模拟快门的打开，只要物体在那个时间处于其正确的位置，则就能得出这条光线在那个时间点的精确平均值。

**一个简单的思路**：在快门打开时，随着时间变化随机生成光线，同时发出射线与模型相交。

一般如果摄像机和物体同时运动，并让每一条射线都拥有自己存在的一个时间点，这样光线追踪就能确定，对于指定的某条光线来说，在该时刻，物体到底在哪儿。

为了实现上述思路，首先要让每条光线都能存储自己所在的时刻，即：

`ray.h`

```c++
class ray {
    public:
        ray() {}
        ray(const point3& origin, const vec3& direction, double time = 0.0)
            : orig(origin), dir(direction), tm(time)
        {}

        point3 origin() const  { return orig; }
        vec3 direction() const { return dir; }
        double time() const    { return tm; }

        point3 at(double t) const {
            return orig + t*dir;
        }

    public:
        point3 orig;
        vec3 dir;
        double tm;
};
```

### 2.2 更新摄像机模拟运动模糊

修改摄像机让其在`time0`至`time1`时间段内随机生成射线，光线的生成时刻是**让camera类自己来运算追踪**还是**让用户自行指定光线在哪个时刻生成**，当出现这种疑惑时，最好的办法是两者同时进行构造。

`camera.h`

```c++
class camera {
    public:
        camera(
            point3 lookfrom,
            point3 lookat,
            vec3   vup,
            double vfov, // vertical field-of-view in degrees
            double aspect_ratio,
            double aperture,
            double focus_dist,
            double _time0 = 0,
            double _time1 = 0
        ) {
            auto theta = degrees_to_radians(vfov);
            auto h = tan(theta/2);
            auto viewport_height = 2.0 * h;
            auto viewport_width = aspect_ratio * viewport_height;

            w = unit_vector(lookfrom - lookat);
            u = unit_vector(cross(vup, w));
            v = cross(w, u);

            origin = lookfrom;
            horizontal = focus_dist * viewport_width * u;
            vertical = focus_dist * viewport_height * v;
            lower_left_corner = origin - horizontal/2 - vertical/2 - focus_dist*w;

            lens_radius = aperture / 2;
            time0 = _time0;
            time1 = _time1;
        }

        ray get_ray(double s, double t) const {
            vec3 rd = lens_radius * random_in_unit_disk();
            vec3 offset = u * rd.x() + v * rd.y();

            return ray(
                origin + offset,
                lower_left_corner + s*horizontal + t*vertical - origin - offset,
                random_double(time0, time1)
            );
        }

    private:
        point3 origin;
        point3 lower_left_corner;
        vec3 horizontal;
        vec3 vertical;
        vec3 u, v, w;
        double lens_radius;
        double time0, time1;  // shutter open/close times
};
```

### 2.3 增加运动的球体

我们还需要一个运动的球体，建立一个新的sphere类，当它的球心在`time0`到`time1`的时间段内从`center0`线性运动到`center1`。超出这个时间段，这个球心依然在动（即做线性插值的时候，t可以大于1.0，也可以小于0），所以这里的两个时间变量和摄像机快门的开关时刻不需要一一对应。

`moving_sphere.h`

```c++
#ifndef THENEXTWEEK_MOVING_SPHERE_H
#define THENEXTWEEK_MOVING_SPHERE_H

#include "rtweekend.h"
#include "hittable.h"

class moving_sphere:public hittable {
public:
    moving_sphere(){}
    moving_sphere(point3 cen0, point3 cen1, double _time0, double _time1, double r, shared_ptr<material> m)
        :center0(cen0), center1(cen1), time0(_time0), time1(_time1), radius(r), mat_ptr(m){};

    virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override;

    point3 center(double time) const;

public:
    point3 center0, center1;
    double time0, time1;
    double radius;
    shared_ptr<material> mat_ptr;
};

point3 moving_sphere::center(double time) const {
    return center0 + ((time - time0) / (time1 - time0)) * (center1 - center0);
}

#endif //THENEXTWEEK_MOVING_SPHERE_H
```

另外一种让球随着时间动起来的方式是取代之前新建的`moving_sphere`类，只留一个球体，让所有球都动起来，静止的球起点与终点位置相同。

`moving_sphere.h`

```c++
bool moving_sphere::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    vec3 oc = r.origin() - center(r.time());
    auto a = r.direction().length_squared();
    auto half_b = dot(oc, r.direction());
    auto c = oc.length_squared() - radius*radius;

    auto discriminant = half_b*half_b - a*c;
    if (discriminant < 0) return false;
    auto sqrtd = sqrt(discriminant);

    // Find the nearest root that lies in the acceptable range.
    auto root = (-half_b - sqrtd) / a;
    if (root < t_min || t_max < root) {
        root = (-half_b + sqrtd) / a;
        if (root < t_min || t_max < root)
            return false;
    }

    rec.t = root;
    rec.p = r.at(rec.t);
    auto outward_normal = (rec.p - center(r.time())) / radius;
    rec.set_face_normal(r, outward_normal);
    rec.mat_ptr = mat_ptr;

    return true;
}
```

### 2.4 跟踪光线相交时间

现在光线有了时间属性，需要更新`material::scatter()`方法来计算相交时间。

`material.h`

```c++
class lambertian : public material {
    ...
        virtual bool scatter(
            const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
        ) const override {
            auto scatter_direction = rec.normal + random_unit_vector();

            // Catch degenerate scatter direction
            if (scatter_direction.near_zero())
                scatter_direction = rec.normal;

            scattered = ray(rec.p, scatter_direction, r_in.time());
            attenuation = albedo;
            return true;
        }
        ...
};

class metal : public material {
    ...
        virtual bool scatter(
            const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
        ) const override {
            vec3 reflected = reflect(unit_vector(r_in.direction()), rec.normal);
            scattered = ray(rec.p, reflected + fuzz*random_in_unit_sphere(), r_in.time());
            attenuation = albedo;
            return (dot(scattered.direction(), rec.normal) > 0);
        }
        ...
};

class dielectric : public material {
    ...
        virtual bool scatter(
            ...
            scattered = ray(rec.p, direction, r_in.time());
            return true;
        }
        ...
};
```

### 2.5 把所有其他的东西都加上

下面的代码是在ray tracing in one weekend的最终场景中加以改动，使其中漫反射材质的球动起来。

摄像机的快门在`time0`时打开，在`time1`时关闭。

每个球的中心在`time0`到`time1`的时间段内从原始位置$C$线性运动到$C+(0, r/2, 0)$，其中$r$是$[0,1)$之间的随机数。

`RayTracing.cpp`

```c++
...
#include "moving_sphere.h"

...
hittable_list random_scene() {
    hittable_list world;

    auto ground_material = make_shared<lambertian>(color(0.5, 0.5, 0.5));
    world.add(make_shared<sphere>(point3(0,-1000,0), 1000, ground_material));

    for (int a = -11; a < 11; a++) {
        for (int b = -11; b < 11; b++) {
            auto choose_mat = random_double();
            point3 center(a + 0.9*random_double(), 0.2, b + 0.9*random_double());

            if ((center - vec3(4, 0.2, 0)).length() > 0.9) {
                shared_ptr<material> sphere_material;

                if (choose_mat < 0.8) {
                    // diffuse
                    auto albedo = color::random() * color::random();
                    sphere_material = make_shared<lambertian>(albedo);
                    auto center2 = center + vec3(0, random_double(0,.5), 0);
                    world.add(make_shared<moving_sphere>(
                        center, center2, 0.0, 1.0, 0.2, sphere_material));
                } else if (choose_mat < 0.95) {
                    // metal
                    auto albedo = color::random(0.5, 1);
                    auto fuzz = random_double(0, 0.5);
                    sphere_material = make_shared<metal>(albedo, fuzz);
                    world.add(make_shared<sphere>(center, 0.2, sphere_material));
                } else {
                    // glass
                    sphere_material = make_shared<dielectric>(1.5);
                    world.add(make_shared<sphere>(center, 0.2, sphere_material));
                }
            }
        }
    }

    auto material1 = make_shared<dielectric>(1.5);
    world.add(make_shared<sphere>(point3(0, 1, 0), 1.0, material1));

    auto material2 = make_shared<lambertian>(color(0.4, 0.2, 0.1));
    world.add(make_shared<sphere>(point3(-4, 1, 0), 1.0, material2));

    auto material3 = make_shared<metal>(color(0.7, 0.6, 0.5), 0.0);
    world.add(make_shared<sphere>(point3(4, 1, 0), 1.0, material3));

    return world;
}
```

同时修改视点参数：

`RayTracing.cpp`

```c++
int main() {

    // Image

    auto aspect_ratio = 16.0 / 9.0;
    int image_width = 400;
    int samples_per_pixel = 100;
    const int max_depth = 50;

    ...

    // Camera

    point3 lookfrom(13,2,3);
    point3 lookat(0,0,0);
    vec3 vup(0,1,0);
    auto dist_to_focus = 10.0;
    auto aperture = 0.1;
    int image_height = static_cast<int>(image_width / aspect_ratio);


    camera cam(lookfrom, lookat, vup, 20, aspect_ratio, aperture, dist_to_focus, 0.0, 1.0);
```

得到结果：

<img src="./images/Bouncing spheres.png"  style="zoom:30%;" />

## 3. Bounding Volume Hierarchies

BVH（层次包围盒）。

把这部分放在前面，主要是因为**BVH改写了hittable的部分代码**，代码运行更快。

之后添加三角形和箱子类的时候，也不必回来改写hittable。

**光线求交运算一直是光线追踪器的主要时间瓶颈**，运行的时间与场景中的物体数量线性相关。

在遍历物体时，多次查找同一个模型会有多余计算，应该**用二叉搜索的方法来加速查找**。

对每个模型射出多条射线，可以对模型的排序进行模拟，每一次光线求交都是一个**亚线性（subliner）**的查找。

>**亚线性（subliner）**
>
>亚线性指参数的指数小于1，即不到线性，平衡查找树的时间复杂度为$O(log_2(2))$

常见两种排序方法：

- 按空间分割（KD树，八叉树）
- 按物体分割（BVH）

### 3.1 关键思想

BVH的核心思想：找一个能包围所有物体的盒子，假设计算一个包围10个物体的大球，对于任何射不到这个大球的射线，它都无法射到球里的10个物体，反之亦然，如果射线射到了大球，则其与里面的10个物体都有可能相交。

包围盒的代码通常是这个样子的：

```c++
if(ray hits bounding object) {
	return whether ray hits bounded objects;
} else {
	return false;
}
```

关键是如何将物体分成一些子类，注意我们并不划分屏幕或者空间，每个物体都只在一个包围盒里，并且这些包围盒可以重叠。

### 3.2 包围盒的层级

为了使得每次光线求交操作**满足亚线性查找**，需要用包围盒构造出**层级（hierarchical）**。

例如**把物体分为红色和蓝色**，如下图所示：

<img src="./images/Bounding volume hierarchy.jpg"  style="zoom:50%;" />

主要蓝色和红色包围盒在紫色包围盒内部，但是他们没有重叠，也是无序的。

可以写成如下代码：

```c++
if(hits purple) {
	hit0 = hit blue enclosed objects;
	hit1 = hit red enclosed objects;
	if(hit0 or hit1) return true and info of closer hit

	return false;
}
```

### 3.3 AABB包围盒

为了使上面的代码跑起来，需要规划如何建树，同时**如何检测光线与包围盒求交**（求交计算一定要高效，并且包围盒要尽量密集）。

对大多数包围盒来说，**轴对齐包围盒**比其他种类包围盒效果更好。

通常把轴对齐包围盒称为**矩形平行管道（或AABB包围盒）**，第一步要先判断光线能否射中这个包围盒。

与击中那些会在屏幕上显示出来的物体不同，射线与AABB包围盒求交并不需要去获取那些**法向量交点（AABB包围盒不需要在屏幕上渲染出来）**。

多数人常用**堆叠法（slab）**显示n维AABB包围盒，即由n条平行线所截的区间重叠拼出来的区域。

<img src="./images/2D axis-aligned bounding box.jpg"  style="zoom:70%;" />

通常称包围的区域为slab，**一个区间就是两个端点间的距离**（例如对于$3<x<5$）。

检测一条射线是否射入一段区间，首先要检测射线是否射入这个区间的边界，对二维来说，检测$t_0$与$t_1$。

（**当光线与目标平面平行的情况下**，因为并没有交点，这两个变量将未定义）

<img src="./images/ray slab.jpg"  style="zoom:70%;" />

3D中，这些边界是平面，平面方程是$x=x_0$与$x=x_1$。

光线与平面交点可以通过如下计算：

- 光线函数：$P(t)=A+tb$
- 光线与平面交点满足：$x_0=A_x+t_0b_x$
- 可以解出：$t_0=\frac{x_0-A_x}{b_x}$
- 可以得到相似的表达：$t_1=\frac{x_1-A_x}{b_x}$

2D情况下，绿色和蓝色重叠说明穿过了包围盒，情况如下：

- 上面的射线，蓝色与绿色没有重叠，说明光线没有穿过AABB包围盒。
- 下面的射线，蓝色与绿色发生重叠，说明射线同时穿过了蓝色和绿色区域，即穿过了AABB包围盒。

对于一个维度来说，解出$t_0$和$t_1$，表示直线上的两个位置，可以按照维度进行拆分计算，然后通过$t$进行求交运算。

<img src="./images/ray slab interval.jpg"  style="zoom:70%;" />

### 3.4 光线与AABB盒交互

下面伪代码表明$t$间隔包围区域slab是否重叠：

```c++
compute(tx0, tx1);
compute(ty0, ty1);
return overlap?((tx0, tx1), (ty0, ty1));
```

对于3维的情况：

```c++
compute(tx0, tx1);
compute(ty0, ty1);
compute(tz0, tz1);
return overlap?((tx0, tx1), (ty0, ty1), (tz0, tz1));
```

需要对上述代码进行一些限制：

- 首先，假设射线从$x$轴负方向射入，这样`compute`区间$(tx_0, tx_1)$的值需要反过来，例如计算结果为$(7,3)$。

- 其次，除数不能为$0$，如果射线就在slab边界上，就会得到NaN值。

不同光线追踪器解决上述方法不一样，对于我们来说，这并不是一个运算瓶颈。

我们直接用最简洁的方式来做：$t_{x0}=\frac{x_0-A_x}{b_x}$，$t_{x_1}=\frac{x_1-A_x}{b_x}$

这里有个问题，当射线恰好在$B_x=0$时，会出现除数为$0$的错误，一些光线在slab里面，一些不在。

对于IEEE浮点型，$0$会有$\pm$号，好消息是当$b_x=0$时，$t_{x0}$和$t_{x1}$会同时为$+\infty$或$-\infty$如果结果不在$x_0$和$x_1$之间，因此可以用min或max函数来得到正确结果：$t_{x0}=\min\left(\frac{x_0-A_x}{b_x},\frac{x_1-A_x}{b_x}\right)$，$t_{x1}=\max\left(\frac{x_0-A_x}{b_x},\frac{x_1-A_x}{b_x}\right)$

现在只剩下分母$B_x=0$并且$x_0-A_x=0$和$x_1-A_x=0$这两个分子之一为$0$的特殊情况，此时会得到一个NaN值。

接着是overlap函数，假设能保证区间没有被倒过来（即第一个值比第二个值小），这种情况下`return true`，则一个计算$(d,D)$和$(e,E)$的重叠区间$(f,F)$函数可以这样表达：

```c++
bool overlap(d, D, e, E, f, F)
    f = max(d, e)
    F = min(D, E)
    return (f < F)
```

如果这里出现了任何的NaN值，结果都会返回`false`。

如果考虑那些擦边的情况，要保证我们的包围盒有一些内间距，把三个维度都写在一个循环中并传入时间间隔$[t_{min},t_{max}]$

`aabb.h`

```c++
#ifndef THENEXTWEEK_AABB_H
#define THENEXTWEEK_AABB_H

#include "rtweekend.h"
class aabb {
public:
    aabb(){}
    aabb(const point3& a, const point3& b) {minimum = a; maximum = b;}

    point3 min() const {return minimum;}
    point3 max() const {return maximum;}

    bool hit(const ray& r, double t_min, double t_max) const {
        for(int a= 0; a < 3; ++a) {
            auto t0 = fmin((minimum[a] - r.origin()[a]) / r.direction()[a],
                                   (maximum[a] - r.origin()[a]) / r.direction()[a]);

            auto t1 = fmax((minimum[a] - r.origin()[a]) / r.direction()[a],
                                   (maximum[a] - r.origin()[a]) / r.direction()[a]);

            t_min = fmax(t0, t_min);
            t_max = fmin(t1, t_max);
            if(t_max <= t_min) return false;
        }
        return true;
    }
    
    point3 minimum;
    point3 maximum;
};


#endif //THENEXTWEEK_AABB_H
```

### 3.5 一个优化的AABB碰撞算法

Andrew Kensler进行了一些实验，提出了下面版本的aabb碰撞代码。

`aabb.g`

```c++
inline bool aabb::hit(const ray& r, double t_min, double t_max) const {
    for(int a= 0; a < 3; ++a) {
        auto invD = 1.0f / r.direction()[a];
        auto t0 = (min()[a] - r.origin()[a]) * invD;
        auto t1 = (max()[a] - r.origin()[a]) * invD;

        if(invD < 0.0f) std::swap(t0, t1);

        t_min = t0 > t_min? t0: t_min;
        t_max = t1 < t_max? t1: t_max;
        if(t_max <= t_min) return false;
    }
    return true;
}
```

### 3.6 为碰撞体构造包围盒

需要添加一个为所有碰撞体计算包围盒的函数，建立一个层次树。

在这个层次树中，所有的图元（例如球体），都会在树的最底端（叶子节点），这个函数返回值是一个bool类型，因为不是所有图元都有包围盒（例如无限延伸的平面）。

另外，**物体会移动**，所以他还要接收`time0`和`time1`，包围盒会把这个时间区间内运动的物体完整包起来。

`hittable.h`

```c++
#include "aabb.h"
...

class hittable {
    public:
        ...
        virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const = 0;
        virtual bool bounding_box(double time0, double time1, aabb& output_box) const = 0;
        ...
};
```

对于一个球类，`bounding_box`函数是比较容易的：

`sphere.h`

```c++
class sphere : public hittable {
    public:
        ...
        virtual bool hit(
            const ray& r, double t_min, double t_max, hit_record& rec) const override;

        virtual bool bounding_box(double time0, double time1, aabb& output_box) const override;
        ...
};

...
bool sphere::bounding_box(double time0, double time1, aabb& output_box) const {
    output_box = aabb(
        center - vec3(radius, radius, radius),
        center + vec3(radius, radius, radius));
    return true;
}
```

对于`moving_sphere`，可以先求球体在$t_0$时刻的包围盒，之后再求$t_1$时刻的包围盒，之后再计算这两个盒子的包围盒：

`moving_sphere.h`

```c++
...
#include "aabb.h"
...

class moving_sphere : public hittable {
    public:
        ...
        virtual bool hit(
            const ray& r, double t_min, double t_max, hit_record& rec) const override;

        virtual bool bounding_box(
            double _time0, double _time1, aabb& output_box) const override;
        ...
};

...
bool moving_sphere::bounding_box(double _time0, double _time1, aabb& output_box) const {
    aabb box0(
        center(_time0) - vec3(radius, radius, radius),
        center(_time0) + vec3(radius, radius, radius));
    aabb box1(
        center(_time1) - vec3(radius, radius, radius),
        center(_time1) + vec3(radius, radius, radius));
    output_box = surrounding_box(box0, box1);
    return true;
}
```

### 3.7 创建物体列表的包围盒

对于`hittable_list`来说，可以在构造函数中就进行包围盒的运算，或者在程序运行时计算。

本文采用运行时计算，因为**这些包围盒的计算一般只有在BVH构造时才会被调用**。

`hittable_list.h`

```c++
...
#include "aabb.h"
...

class hittable_list : public hittable {
    public:
        ...
        virtual bool hit(
            const ray& r, double t_min, double t_max, hit_record& rec) const override;

        virtual bool bounding_box(
            double time0, double time1, aabb& output_box) const override;
    ...
};

...
bool hittable_list::bounding_box(double time0, double time1, aabb& output_box) const {
    if (objects.empty()) return false;

    aabb temp_box;
    bool first_box = true;

    for (const auto& object : objects) {
        if (!object->bounding_box(time0, time1, temp_box)) return false;
        output_box = first_box ? temp_box : surrounding_box(output_box, temp_box);
        first_box = false;
    }

    return true;
}
```

计算两个`aabb`包围盒的函数`surrounding_box`：

`aabb.h`

```c++
aabb surrounding_box(aabb box0, aabb box1) {
    point3 small(fmin(box0.min().x(), box1.min().x()),
                 fmin(box0.min().y(), box1.min().y()),
                 fmin(box0.min().z(), box1.min().z()));

    point3 big(fmax(box0.max().x(), box1.max().x()),
               fmax(box0.max().y(), box1.max().y()),
               fmax(box0.max().z(), box1.max().z()));

    return aabb(small,big);
}
```

### 3.8 BVH结点类

BVH继承`hittable`，相当于一个容器，包住物体，可以计算是否被光线射中。

这里采用一个类加上一个指针搞定：

`bvh.h`

```c++
#ifndef THENEXTWEEK_BVH_H
#define THENEXTWEEK_BVH_H

#include "rtweekend.h"

#include "hittable.h"
#include "hittable_list.h"

class bvh_node: public hittable {
public:
    bvh_node();

    bvh_node(const hittable_list& list, double time0, double time1)
    :bvh_node(list.objects, 0, list.objects.size(), time0, time1){}

    bvh_node(const std::vector<shared_ptr<hittable>>& src_objects, size_t start, size_t end, double time0, double time1);

    virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override;

    virtual bool bounding_box(double time0, double time1, aabb& output_box) const override;

public:
    shared_ptr<hittable> left;
    shared_ptr<hittable> right;
    aabb box;
};

bool bvh_node::bounding_box(double time0, double time1, aabb &output_box) const {
    output_box = box;
    return true;
}

#endif //THENEXTWEEK_BVH_H
```

注意孩子指针对于hittables也是通用的，他们可以成为其他的`bvh_nodes`，或者是`sphere`，或者是其他的`hittable`。

`hit`函数相当直接：检查这个节点的box是否被击中，如果被击中，则对这个节点的子节点进行判断。

`bvh.h`

```c++
bool bvh_node::hit(const ray &r, double t_min, double t_max, hit_record &rec) const {
    if(!box.hit(r, t_min, t_max)) return false;

    bool hit_left = left->hit(r, t_min, t_max, rec);
    bool hit_right = right->hit(r, t_min, hit_left? rec.t:t_max, rec);

    return hit_left || hit_right;
}
```

### 3.9 展开BVH结果

任何高效的数据结构（例如BVH），最难的部分是如何去构建它。

对于BVH来说，不断地把`bvh_node`中的物体分割成两个子集的同时，`hit`函数也会跟着执行。

如果分割算法很好，两个孩子的包围盒都比其父节点的包围盒要小，则`hit`函数自然会运行地很好，但这样只是运行地快，并不正确，需要在正确和快之间做取舍，在每次分割时沿着一个轴把物体列表分成两半。

**分割原则：**

- 随机选取一个轴分割。
- 使用库函数`sort()`对图元进行排序。
- 对半分，每个子树分一半物体。

物体分割过程递归执行，**当数组传入只剩下两个元素时，两个子树节点各放一个，并结束递归**。

`bvh.h`

```c++
#include <algorithm>
...

bvh_node::bvh_node(
    std::vector<shared_ptr<hittable>>& src_objects,
    size_t start, size_t end, double time0, double time1
) {
    auto objects = src_objects; // Create a modifiable array of the source scene objects

    int axis = random_int(0,2);
    auto comparator = (axis == 0) ? box_x_compare
                    : (axis == 1) ? box_y_compare
                                  : box_z_compare;

    size_t object_span = end - start;

    if (object_span == 1) {
        left = right = objects[start];
    } else if (object_span == 2) {
        if (comparator(objects[start], objects[start+1])) {
            left = objects[start];
            right = objects[start+1];
        } else {
            left = objects[start+1];
            right = objects[start];
        }
    } else {
        std::sort(objects.begin() + start, objects.begin() + end, comparator);

        auto mid = start + object_span/2;
        left = make_shared<bvh_node>(objects, start, mid, time0, time1);
        right = make_shared<bvh_node>(objects, mid, end, time0, time1);
    }

    aabb box_left, box_right;

    if (  !left->bounding_box (time0, time1, box_left)
       || !right->bounding_box(time0, time1, box_right)
    )
        std::cerr << "No bounding box in bvh_node constructor.\n";

    box = surrounding_box(box_left, box_right);
}
```

`rtweenkend.h`

```c++
inline int random_int(int min, int max) {
    // Returns a random integer in [min,max].
    return static_cast<int>(random_double(min, max+1));
}
```

### 3.10 Box比较函数

之后需要实现Box比较函数，通过`std::sort()`，先判断哪个轴，然脏对应的为我们的比较器赋值。

`bvh.h`

```c++
inline bool box_compare(const shared_ptr<hittable> a, const shared_ptr<hittable> b, int axis) {
    aabb box_a;
    aabb box_b;

    if (!a->bounding_box(0,0, box_a) || !b->bounding_box(0,0, box_b))
        std::cerr << "No bounding box in bvh_node constructor.\n";

    return box_a.min().e[axis] < box_b.min().e[axis];
}


bool box_x_compare (const shared_ptr<hittable> a, const shared_ptr<hittable> b) {
    return box_compare(a, b, 0);
}

bool box_y_compare (const shared_ptr<hittable> a, const shared_ptr<hittable> b) {
    return box_compare(a, b, 1);
}

bool box_z_compare (const shared_ptr<hittable> a, const shared_ptr<hittable> b) {
    return box_compare(a, b, 2);
}
```

## 4. 纹理贴图

图形学中，纹理贴图通常意味着将颜色赋予物体表面的过程。

这个过程可以是通过代码生成纹理，或者是一张图片，也可以二者结合。

这里通过类继承的方式，来实现上述两个功能。

### 4.1 第一个纹理类：连续性纹理

`texture.h`

```c++
#ifndef THENEXTWEEK_TEXTURE_H
#define THENEXTWEEK_TEXTURE_H

#include "rtweekend.h"

class texture {
public:
    virtual color value(double u, double v, const point3& p) const = 0;
};

class solid_color: public texture {
public:
    solid_color(){}
    solid_color(color c):color_value(c) {}

    solid_color(double red, double green, double blue) :solid_color(color(red, green, blue)){}

    virtual color value(double u, double v, const point3& p) const {
        return color_value;
    }

private:
    color color_value;
};

#endif //THENEXTWEEK_TEXTURE_H
```

之后需要更新`hit_record`结构来存储光线与物体交点的`u,v`坐标：

`hittable.h`

```c++
struct hit_record {
    vec3 p;
    vec3 normal;
    shared_ptr<material> mat_ptr;
    double t;
    double u;
    double v;
    bool front_face;
    ...
```

之后也需要为`hittables`计算$(u,v)$纹理坐标。

### 4.2 球体纹理坐标

对于一个球体，纹理坐标通常基于一些经纬度。

例如，对于球面坐标，计算$(\theta,\phi)$，其中$\theta$是从下轴（即$-Y$）向上的角度，$\phi$是绕$Y$轴旋转的角度（从$-X$到$+Z$到$+X$到$-Z$再回到$-X$）。

将$(\theta,\phi)$映射到纹理坐标$(u,v)$，其中$(u=0,v=0)$为纹理的左下角，$u=\frac{\theta}{2\pi},v=\frac{\phi}{\pi}$

为了计算以原点为中心的单位球面上给定点$\theta$和$\phi$，从相应的笛卡尔坐标系开始：

$x=-\cos(\phi)\sin(\theta),y=-\cos(\theta),z=\sin(\phi)\sin(\theta)$

可以通过转换这些方程来计算$\theta$和$\phi$，使用`<cmath>`库中的`atan2()`，取任一对`sin`和`cos`来返回其角度，这里可以用$x$和$z$来求解$\phi$：$\phi=atan2(z,-x)$

`atan2()`返回一个范围值$[-\pi,\pi]$，他们从$[0,\pi]$，之后翻转到$[-\pi,0]$。

虽然这在数学上是正确的，但是这里希望$u$的范围是$[0,1]$，而不是先$[0,\frac{1}{2}]$，再$[-\frac{1}{2},0]$。

幸运的是，有个公式：$atan2(a,b)=atan2(-a,-b)+\pi$，它的值域是$[0,2\pi]$，因此计算$\phi$可以写成：$\phi=atan2(-z,x)+\pi$

对于$\theta$，可以直接求出：$\theta=acos(-y)$

对于一个球体，$(u,v)$坐标计算可以通过一个工具函数来计算：

`sphere.h`

```c++
class sphere : public hittable {
    ...
    private:
        static void get_sphere_uv(const point3& p, double& u, double& v) {
            // p: a given point on the sphere of radius one, centered at the origin.
            // u: returned value [0,1] of angle around the Y axis from X=-1.
            // v: returned value [0,1] of angle from Y=-1 to Y=+1.
            //     <1 0 0> yields <0.50 0.50>       <-1  0  0> yields <0.00 0.50>
            //     <0 1 0> yields <0.50 1.00>       < 0 -1  0> yields <0.50 0.00>
            //     <0 0 1> yields <0.25 0.50>       < 0  0 -1> yields <0.75 0.50>

            auto theta = acos(-p.y());
            auto phi = atan2(-p.z(), p.x()) + pi;

            u = phi / (2*pi);
            v = theta / pi;
        }
};
```

更新`sphere::hit()`函数来使用这个函数，并更新`hit_record`uv坐标：

`sphere.h`

```c++
bool sphere::hit(...) {
    ...

    rec.t = root;
    rec.p = r.at(rec.t);
    vec3 outward_normal = (rec.p - center) / radius;
    rec.set_face_normal(r, outward_normal);
    get_sphere_uv(outward_normal, rec.u, rec.v);
    rec.mat_ptr = mat_ptr;

    return true;
}
```

现在可以通过纹理指针取代`const color& a`来制作一个纹理材质：

`material.h`

```c++
#include "texture.h"

...
class lambertian : public material {
    public:
        lambertian(const color& a) : albedo(make_shared<solid_color>(a)) {}
        lambertian(shared_ptr<texture> a) : albedo(a) {}

        virtual bool scatter(
            const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
        ) const override {
            auto scatter_direction = rec.normal + random_unit_vector();

            // Catch degenerate scatter direction
            if (scatter_direction.near_zero())
                scatter_direction = rec.normal;

            scattered = ray(rec.p, scatter_direction, r_in.time());
            attenuation = albedo->value(rec.u, rec.v, rec.p);
            return true;
        }

    public:
        shared_ptr<texture> albedo;
};
```

### 4.3 棋盘格纹理

可以使用`sin`和`cos`函数的周期性来做一个棋盘格纹理。

如果在三个维度上都乘以这个周期函数，就会形成一个3维的棋盘格模型。

`texture.h`

```c++
class checker_texture : public texture {
    public:
        checker_texture() {}

        checker_texture(shared_ptr<texture> _even, shared_ptr<texture> _odd)
            : even(_even), odd(_odd) {}

        checker_texture(color c1, color c2)
            : even(make_shared<solid_color>(c1)) , odd(make_shared<solid_color>(c2)) {}

        virtual color value(double u, double v, const point3& p) const override {
            auto sines = sin(10*p.x())*sin(10*p.y())*sin(10*p.z());
            if (sines < 0)
                return odd->value(u, v, p);
            else
                return even->value(u, v, p);
        }

    public:
        shared_ptr<texture> odd;
        shared_ptr<texture> even;
};
```

这些奇偶指针可以指向一个静态纹理，也可以指向一些程序生成的纹理。

> 这是PatHanrahan在1980年代提出的着色器网络的核心思想。

如果把这个纹理贴在`random_scene()`函数里：

`RayTracing.cpp`

```c++
hittable_list random_scene() {
    hittable_list world;

    auto checker = make_shared<checker_texture>(color(0.2, 0.3, 0.1), color(0.9, 0.9, 0.9));
    world.add(make_shared<sphere>(point3(0,-1000,0), 1000, make_shared<lambertian>(checker)));

    for (int a = -11; a < 11; a++) {
        ...
```

得到结果：

<img src="./images/Spheres on checkered ground.png"  style="zoom:30%;" />

### 4.4 使用棋盘格纹理渲染一个场景

我们将要在程序中加入第二个场景，在之后的过程中会加入更多的场景。

为了实现这一点，我们将设置一个硬编码的`switch`语句来为给定的运行选择所需的场景。

`RayTracing.cpp`

```c++
hittable_list two_spheres() {
    hittable_list objects;

    auto checker = make_shared<checker_texture>(color(0.2, 0.3, 0.1), color(0.9, 0.9, 0.9));

    objects.add(make_shared<sphere>(point3(0,-10, 0), 10, make_shared<lambertian>(checker)));
    objects.add(make_shared<sphere>(point3(0, 10, 0), 10, make_shared<lambertian>(checker)));

    return objects;
}
```

`RayTracing.cpp`

```c++
// World

hittable_list world;

point3 lookfrom;
point3 lookat;
auto vfov = 40.0;
auto aperture = 0.0;

switch (0) {
    case 1:
        world = random_scene();
        lookfrom = point3(13,2,3);
        lookat = point3(0,0,0);
        vfov = 20.0;
        aperture = 0.1;
        break;

    default:
    case 2:
        world = two_spheres();
        lookfrom = point3(13,2,3);
        lookat = point3(0,0,0);
        vfov = 20.0;
        break;
}

// Camera

vec3 vup(0,1,0);
auto dist_to_focus = 10.0;
int image_height = static_cast<int>(image_width / aspect_ratio);

camera cam(lookfrom, lookat, vup, vfov, aspect_ratio, aperture, dist_to_focus, 0.0, 1.0);
...
```

得到结果：

<img src="./images/Checkered spheres.png"  style="zoom:30%;" />







