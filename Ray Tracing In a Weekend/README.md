# Ray Tracing in One Weekend

https://raytracing.github.io/books/RayTracingInOneWeekend.html



## 1. 概述

略。

## 2. 输出一张图像

### 2.1 PPM图像格式

开始渲染工作之前，需要有一种方式来查看你之后得到的渲染结果。

最直接的方式是将图像写入一个文件中。

有很多存储图像文件的方式，这里主要采用PPM格式，下面是它的维基介绍。

<img src="./images/PPM Example.png"  style="zoom:50%;" />

**【PPM介绍】**

**PPM（Portable PixMap）**是portable像素图片，由netpbm项目定义的一系列的portable图片格式中的一个。

这些图片格式**相对比较容易处理**，把每一个点的RGB分别保存下来（因此其没有压缩，导致文件较大），由于图片格式简单，一般作为图片处理的中间文件（不会丢失文件信息），或作为简单的图片格式保存。

**【PPM格式分析】**

netpbm几种图片格式通过其表示的颜色类型区分：

- PBM：位图，只有黑色和白色。
- PGM：灰度图。
- PPM：完整的RGB颜色。

PPM文件头由三部分组成：这几个部分之间用回车或换行分隔。

- 第一部分：**文件magic number**
    - 每一个netpbm图片由两个字节的magic number（ASCII）组成，用于识别**文件类型**（PBM/PGM/PPM）以及**文件编码**（ASCII/Binary）。
    - PPM格式的其实两个字节为**P3或P6**。
    - ASCII编码可读性好，可以直接打开读取其对应的图片的数据（比如RGB值），中间用空格回车隔开。
    - Binary格式的图片更快（不需要判断空格回车），图片尺寸较小，但可读性差。

- 第二部分：**图像宽度与高度**（空格隔开），用ASCII表示。
- 第三部分：**像素最大颜色组成**，允许描述超过一个字节（0-255）的颜色值。

在上述基础上，可以使用 `#` 进行注释，注释是 `#` 到行尾（回车或换行）部分。

```c++
#include "iostream"

int main(){

    // Image
    const int image_width = 256;
    const int image_height = 256;

    // Render
    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    for(int j = image_height - 1; j >= 0; --j) {
        for(int i = 0; i < image_width; ++i) {
            auto r = double(i) / (image_width - 1);
            auto g = double(j) / (image_height - 1);
            auto b = 0.25;

            int ir = static_cast<int>(255.999 * r);
            int ig = static_cast<int>(255.999 * g);
            int ib = static_cast<int>(255.999 * b);
            std::cout << ir << " " << ig << " " << ib << "\n";
        }
    }
    
    return 0;
}
```

注意点：

1. 像素从左到右，从上到下写。
2. 通常rgb的范围是[0, 1]，但之后需要将它们的范围扩展到[0, 255]

### 2.2 创建一个图像文件

可以使用**重定向命令**`>`将程序结果输出到文件中：

```shell
mkdir build
cd build
cmake ..
make -j4

inOneWeekend > image.ppm
```

之后可以看到结果：

<img src="./images/image.png"  style="zoom:20%;" />

用文本处理打开`image.ppm`，可以看到如下内容：

```tex
P3
256 256
255
0 255 63
1 255 63
2 255 63
3 255 63
4 255 63
...
```

### 2.3 添加一个进度指标

添加一个**渲染进度输出**，用于提醒当前渲染的进度（同时避免陷入死循环）。

```c++
for(int j = image_height - 1; j >= 0; --j) {
    std::cerr << "\nScanlines remaining: " << j << " " << std::flush;
    for(int i = 0; i < image_width; ++i) {
        auto r = double(i) / (image_width - 1);
        auto g = double(j) / (image_height - 1);
        auto b = 0.25;

        int ir = static_cast<int>(255.999 * r);
        int ig = static_cast<int>(255.999 * g);
        int ib = static_cast<int>(255.999 * b);
        std::cout << ir << " " << ig << " " << ib << "\n";
    }
}

std::cerr << "\nDone.\n";
```

## 3. vec3 类

几乎所有的图形程序都有一些**存储向量和颜色的类**。

多数系统的向量是**4维**的（3维的齐次坐标，RGBA）。

本文主要用**3维**来进行处理颜色，坐标，方向，偏移等（主要为了减少代码量）。

### 3.1 变量与方法

`vec3`类：

```c++
#ifndef INONEWEEKEND_VEC3_H
#define INONEWEEKEND_VEC3_H

#include "cmath"
#include "iostream"

using std::sqrt;

class vec3 {
public:
    vec3(): e{0, 0, 0}{}
    vec3(double e0, double e1, double e2): e{e0, e1, e2} {}

    double x() const {return e[0];}
    double y() const {return e[1];}
    double z() const {return e[2];}

    vec3 operator -() const {return vec3(-e[0], -e[1], -e[2]);}
    double operator[](int i) const {return e[i];}
    double& operator[](int i) {return e[i];}

    vec3& operator += (const vec3 &v){
        e[0] += v.e[0];
        e[1] += v.e[1];
        e[2] += v.e[2];
        return *this;
    }

    vec3& operator *= (const double t){
        e[0] *= t;
        e[1] *= t;
        e[2] *= t;
        return *this;
    }

    vec3& operator /= (const double t){
        return *this *= 1 / t;
    }

    double length() const {
        return sqrt(lenth_squared());
    }

    double lenth_squared() const {
        return e[0] * e[0] + e[1] * e[1] + e[2] * e[2];
    }

public:
    double e[3];
};

// Type aliases for vec3
using point3 = vec3;    // 3D point
using color = vec3;     // RGB color

#endif //INONEWEEKEND_VEC3_H
```

### 3.2 vec3工具函数

```c++
// vec3 Utility Functions

inline std::ostream& operator<<(std::ostream &out, const vec3 &v) {
    return out << v.e[0] << " " << v.e[1] << " " << v.e[2];
}

inline vec3 operator+(const vec3 &u, const vec3 &v) {
    return vec3(u.e[0] + v.e[0], u.e[1] + v.e[1], u.e[2] + v.e[2]);
}

inline vec3 operator-(const vec3 &u, const vec3 &v) {
    return vec3(u.e[0] - v.e[0], u.e[1] - v.e[1], u.e[2] - v.e[2]);
}

inline vec3 operator*(const vec3 &u, const vec3 &v) {
    return vec3(u.e[0] * v.e[0], u.e[1] * v.e[1], u.e[2] * v.e[2]);
}

inline vec3 operator*(double t, const vec3 &v) {
    return vec3(t * v.e[0], t * v.e[1], t * v.e[2]);
}

inline vec3 operator*(const vec3 &v, double t) {
    return t * v;
}

inline vec3 operator/(vec3 v, double t) {
    return (1/t) * v;
}

inline double dot(const vec3 &u, const vec3 &v) {
    return u.e[0] * v.e[0] + u.e[1] * v.e[1] + u.e[2] * v.e[2];
}

inline vec3 cross(const vec3 &u, const vec3 &v) {
    return vec3(u.e[1] * v.e[2] - u.e[2] * v.e[1],
                u.e[2] * v.e[0] - u.e[0] * v.e[2],
                u.e[0] * v.e[1] - u.e[1] * v.e[0]);
}

inline vec3 unit_vector(vec3 v) {
    return v / v.length();
}
```

### 3.3 颜色工具函数

```c++
#ifndef INONEWEEKEND_COLOR_H
#define INONEWEEKEND_COLOR_H

#include "vec3.h"

#include "iostream"

void write_color(std::ostream &out, color pixel_color) {
    // Write the translated [0,255] value of each color component.
    out << static_cast<int>(255.999 * pixel_color.x()) << " "
        << static_cast<int>(255.999 * pixel_color.y()) << " "
        << static_cast<int>(255.999 * pixel_color.z()) << "\n";
}

#endif //INONEWEEKEND_COLOR_H
```

`main函数`中进行测试：

```c++
#include "color.h"
#include "vec3.h"

#include "iostream"

int main(){

    // Image
    const int image_width = 256;
    const int image_height = 256;

    // Render
    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    for(int j = image_height - 1; j >= 0; --j) {
        std::cerr << "\nScanlines remaining: " << j << " " << std::flush;
        for(int i = 0; i < image_width; ++i) {
            color pixel_color(double(i) / (image_width - 1), double(j) / (image_height - 1), 0.25);
            write_color(std::cout, pixel_color);
        }
    }

    std::cerr << "\nDone.\n";

    return 0;
}
```

## 4. 光线/简单摄像头/背景

### 4.1 光线类

所有的光线追踪都有一个**光线类**，同时沿着这根光线**计算所看到的颜色**。

光线函数：$P(t)=A+tb$，其中$P$是$t$时刻光线的3维位置，$A$是光线原点，$b$是光线方向。

当$t$的范围为$[-\infty, \infty]$时，可以选择这条三维直线上的任何位置。

<img src="./images/Linear interpolation.jpg"  style="zoom:50%;" />

函数$P(t)$可以通过`ray::at(t)`函数调用：

```c++
#ifndef INONEWEEKEND_RAY_H
#define INONEWEEKEND_RAY_H

#include "vec3.h"

class ray {
public:
    ray(){}
    ray(const point3& origin, const vec3& direction): orig(origin), dir(direction){}

    point3 origin() const {return orig;}
    vec3 direction() const {return dir;}

    point3 at(double t) const {
        return orig + t * dir;
    }
    
public:
    point3 orig;
    point3 dir;
};

#endif //INONEWEEKEND_RAY_H
```

### 4.2 向场景中发出射线

射线穿过不同的像素，计算这些射线方向看到的颜色。

分为如下几个步骤：

1. 计算从摄像机到像素的射线。
2. 判断射线与哪个物体相交。
3. 计算交点的颜色。

注意：这里采用**长宽比16:9**（防止对方形的长宽搞混淆）。

摄像机放在$(0,0,0)$点，y轴在上，x轴在右，摄像机朝向z轴负方向（遵循**右手螺旋定则**）。

从上到下，从左到右遍历屏幕像素。

<img src="./images/Camera geometry.jpg"  style="zoom:50%;" />

下面的代码中，光线`r`近似到像素中心（不用担心准确度，之后会进行反走样）

```c++
#include "color.h"
#include "vec3.h"
#include "ray.h"

#include "iostream"

color ray_color(const ray& r) {
    vec3 unit_direction = unit_vector(r.direction());
    auto t = 0.5 * (unit_direction.y() + 1.0);
    return (1.0 - t) * color(1.0, 1.0, 1.0) + t * color(0.5, 0.7, 1.0);
}

int main(){

    // Image
    const auto aspect_ratio = 16.0 / 9.0;
    const int image_width = 400;
    const int image_height = static_cast<int>(image_width / aspect_ratio);

    // Camera
    auto viewport_height = 2.0;
    auto viewport_width = aspect_ratio * viewport_height;
    auto focal_length = 1.0;

    auto origin = point3(0, 0, 0);
    auto horizontal = vec3(viewport_width, 0, 0);
    auto vertical = vec3(0, viewport_height, 0);
    auto lower_left_corner = origin - horizontal / 2 - vertical / 2 - vec3(0, 0, focal_length);


    // Render
    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    for(int j = image_height - 1; j >= 0; --j) {
        std::cerr << "\nScanlines remaining: " << j << " " << std::flush;
        for(int i = 0; i < image_width; ++i) {
            auto u = double(i) / (image_width - 1);
            auto v = double(j) / (image_height - 1);
            ray r(origin, lower_left_corner + u * horizontal + v * vertical - origin);
            color pixel_color = ray_color(r);
            write_color(std::cout, pixel_color);
        }
    }

    std::cerr << "\nDone.\n";

    return 0;
}
```

`ray_color(ray)`函数线性变化白色和蓝色（取决于y轴的高度，$-1.0<y<1.0$）。

这里有一个加权分配情况，当$t=1.0$时，显示白色，当$t=0.0$时，显示蓝色，中间是线性渐变。

$blendedValue=(1-t)\cdot startValue+t\cdot endValue$

<img src="./images/A blue-to-white gradient depending on ray Y coordinate.png"  style="zoom:30%;" />

## 5. 添加一个球体

通常使用一个球体来作为碰撞检测，因为比较容易计算。

### 5.1 光线与球体相交

球体公式：$x^2+y^2+z^2=R^2$

- 当$x^2+y^2+z^2=R^2$时，点$(x,y,z)$在球体表面上。
- 当$x^2+y^2+z^2<R^2$时，点$(x,y,z)$在球内。
- 当$x^2+y^2+z^2>R^2$时，点$(x,y,z)$在球外。

如果球心在$(C_x,C_y,C_z)$上，公式变为：$(x-C_x)^2+(y-C_y)^2+(z-C_z)^2=r^2$

从点$C=(C_x,C_y,C_z)$到点$P=(x,y,z)$的向量$(P-C)=(x-C_x, y-C_y, z-C_z)$

光线$P(t)=A+tb$与球体交点：$(P(t)-C)\cdot(P(t)-C)=(A+tb-C)\cdot(A+tb-C)=r^2$

对上式进行化简：$t^2b\cdot b+2tb\cdot(A-C)+(A-C)\cdot(A-C)-r^2=0$

其中只有$t$是未知量，一元二次方程，可以用求根公式计算，根的分布情况如下：

<img src="./images/Ray-sphere intersection results.jpg"  style="zoom:70%;" />

### 5.2 创建第一个光线追踪图像

在z轴-1的位置放置一个红色球体，测试光线是否能够打到球体。

```c++
bool hit_sphere(const point3& center, double radius, const ray& r){
    vec3 oc = r.origin() - center;
    auto a = dot(r.direction(), r.direction());
    auto b = 2.0 * dot(oc, r.direction());
    auto c = dot(oc, oc) - radius * radius;

    auto discriminant = b * b - 4 * a * c;

    return (discriminant > 0);
}

color ray_color(const ray& r) {
    if(hit_sphere(point3(0, 0, -1), 0.5, r)) return color(1, 0, 0);

    vec3 unit_direction = unit_vector(r.direction());
    auto t = 0.5 * (unit_direction.y() + 1.0);
    return (1.0 - t) * color(1.0, 1.0, 1.0) + t * color(0.5, 0.7, 1.0);
}
```

如果代码正确，可以得到如下结果：

<img src="./images/A simple red sphere.png"  style="zoom:30%;" />

此时还缺少一些东西（例如着色，反射光线，多个物体等）。

同时这里有个bug，就是如果把球体放在z轴的+1上，则会得到同样的结果，但是这是在你的后方，应该不显示才对，下面对其进行处理。

## 6. 表面法线和多物体

### 6.1 表面法线着色

首先，要获取表面法线，这样才能进行着色。

表面法线是一个与表面呈90度的向量。

**法线满足**：单位长度，方便后续着色。

- 对于一个球体，法线是球心与该点连线方向。

<img src="./images/Sphere surface-normal geometry.jpg"  style="zoom:70%;" />

由于没有光源，因此采用**颜色图**来可视化法向量。

```c++
double hit_sphere(const point3& center, double radius, const ray& r){
    vec3 oc = r.origin() - center;
    auto a = dot(r.direction(), r.direction());
    auto b = 2.0 * dot(oc, r.direction());
    auto c = dot(oc, oc) - radius * radius;

    auto discriminant = b * b - 4 * a * c;

    if(discriminant < 0) {
        return -1.0;
    } else {
        return (-b - sqrt(discriminant)) / (2.0 * a);
    }
}

color ray_color(const ray& r) {
    auto t = hit_sphere(point3(0, 0, -1), 0.5, r);
    if(t > 0.0) {
        vec3 N = unit_vector(r.at(t) - vec3(0, 0, -1));
        return 0.5 * color(N.x() + 1, N.y() + 1, N.z() + 1);
    }

    vec3 unit_direction = unit_vector(r.direction());
    t = 0.5 * (unit_direction.y() + 1.0);
    return (1.0 - t) * color(1.0, 1.0, 1.0) + t * color(0.5, 0.7, 1.0);
}
```

<img src="./images/A sphere colored according to its normal vectors.png"  style="zoom:30%;" />

### 6.2 简化光线相交代码

原来的：

```c++
double hit_sphere(const point3& center, double radius, const ray& r){
    vec3 oc = r.origin() - center;
    auto a = dot(r.direction(), r.direction());
    auto b = 2.0 * dot(oc, r.direction());
    auto c = dot(oc, oc) - radius * radius;

    auto discriminant = b * b - 4 * a * c;

    if(discriminant < 0) {
        return -1.0;
    } else {
        return (-b - sqrt(discriminant)) / (2.0 * a);
    }
}
```

两个优化：

- 向量自身点乘等于该向量模的平方，对$a$来说。
- 令$b=2h$，去掉系数。

$$
\frac{-b\pm\sqrt{b^2-4ac}}{2a}=\frac{-2h\pm\sqrt{(2h)^2-4ac}}{2a} =\frac{-2h\pm2\sqrt{h^2-ac}}{2a}=\frac{-h\pm\sqrt{h^2-ac}}{a} \tag{6.1}
$$

化简相交函数：

```c++
double hit_sphere(const point3& center, double radius, const ray& r){
    vec3 oc = r.origin() - center;
    auto a = r.direction().lenth_squared();
    auto half_b = dot(oc, r.direction());
    auto c = oc.lenth_squared() - radius * radius;
    auto discriminant = half_b * half_b - a * c;

    if(discriminant < 0) {
        return -1.0;
    } else {
        return (-half_b - sqrt(discriminant)) / a;
    }
}
```

### 6.3 碰撞物体抽象类

对于一些物体的碰撞，需要定义一个碰撞的抽象类。

**碰撞抽象类**中有一个碰撞函数`hit`，设定一个有效间隔$t_{min}$和$t_{max}$，当$t_{min}<t
<t_{max}$时，则发生碰撞。

```c++
#ifndef INONEWEEKEND_HITTABLE_H
#define INONEWEEKEND_HITTABLE_H

#include "ray.h"

struct hit_record{
    point3 p;
    vec3 normal;
    double t;
};

class hittable {
public:
    virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const = 0;
};

#endif //INONEWEEKEND_HITTABLE_H
```

创建一个球体类：

```c++
#ifndef INONEWEEKEND_SPHERE_H
#define INONEWEEKEND_SPHERE_H

#include "hittable.h"
#include "vec3.h"

class sphere: public hittable {
public:
    sphere(){}
    sphere(point3 cen, double r): center(cen), radius(r){};

    virtual bool hit(
            const ray& r, double t_min, double t_max, hit_record& rec)const override;

public:
    point3 center;
    double radius;
};

bool sphere::hit(const ray &r, double t_min, double t_max, hit_record &rec) const {
    vec3 oc = r.origin() - center;
    auto a = r.direction().lenth_squared();
    auto half_b = dot(oc, r.direction());
    auto c = oc.lenth_squared() - radius * radius;

    auto discriminant = half_b * half_b - a * c;
    if(discriminant < 0) return false;

    auto sqrtd = sqrt(discriminant);

    // Find the nearest root that lies in the acceptable range
    auto root = (-half_b - sqrtd) / a;
    if(root < t_min || root > t_max) {
        root = (-half_b + sqrtd) / a;
        if(root < t_min || root > t_max) {
            return false;
        }
    }

    rec.t = root;
    rec.p = r.at(rec.t);
    rec.normal = (rec.p - center) / radius;

    return true;
}

#endif //INONEWEEKEND_SPHERE_H
```

### 6.4 前表面 VS 后表面

需要判断光线与物体的交点，之后**光线朝物体内打还是物体外打**。

<img src="./images/Possible directions for sphere surface-normal geometry.jpg"  style="zoom:70%;" />

如果假定法向量总是指向物体外，之后需要**判断哪一边需要进行着色**。

可以计算光线与法向量的点积来确定哪一边：

- 如果光线与法向量在相同方向，则光线在物体内。
- 如果光线与法向量在相反方向，则光线在物体外。

可以**设置法向量总是指向表面外，或总是与入射光线相反**。

```c++
bool front_face;
if (dot(ray_direction, outward_normal) > 0.0) {
    // ray is inside the sphere
    normal = -outward_normal;
    front_face = false;
} else {
    // ray is outside the sphere
    normal = outward_normal;
    front_face = true;
}
```

在`hit_record`结构体中加入`front_fase`的判断：

```c++
struct hit_record{
    point3 p;
    vec3 normal;
    double t;
    bool front_face;

    inline void set_face_normal(const ray& r, const vec3& outward_normal) {
        front_face = dot(r.direction(), outward_normal) < 0;
        normal = front_face? outward_normal: -outward_normal;
    }
};
```

之后在`sphere::hit`函数中加入表面边判断：

```c++
bool sphere::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    ...

    rec.t = root;
    rec.p = r.at(rec.t);
    vec3 outward_normal = (rec.p - center) / radius;
    rec.set_face_normal(r, outward_normal);

    return true;
}
```

### 6.5 碰撞物体列表

增加一个碰撞物体类：

```c++
#ifndef INONEWEEKEND_HITTABLE_LIST_H
#define INONEWEEKEND_HITTABLE_LIST_H

#include "hittable.h"

#include "memory"
#include "vector"

using std::shared_ptr;
using std::make_shared;

class hittable_list: public hittable {
public:
    hittable_list(){}
    hittable_list(shared_ptr<hittable> object) {add(object);}

    void clear() {objects.clear();}
    void add(shared_ptr<hittable> object) {objects.push_back(object);}

    virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override;

public:
    std::vector<shared_ptr<hittable>> objects;
};

bool hittable_list::hit(const ray &r, double t_min, double t_max, hit_record &rec) const {
    hit_record temp_rec;
    bool hit_anything = false;
    auto closest_so_far = t_max;

    for(const auto& object: objects) {
        if(object->hit(r, t_min, closest_so_far, temp_rec)) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }
    return hit_anything;
}

#endif //INONEWEEKEND_HITTABLE_LIST_H
```

### 6.6 一些新的C++特性

`shared_ptr<type>`是**智能指针**，用一个引用计数来定义。

- 每次将它的值指向另一个共享指针，则它的引用数会加1
- 当共享指针结束它的生命周期，则引用数会减1

一旦引用数变为0，则对象被删除。

**智能指针初始化：**

```c++
shared_ptr<double> double_ptr = make_shared<double>(0.37);
shared_ptr<vec3>   vec3_ptr   = make_shared<vec3>(1.414214, 2.718281, 1.618034);
shared_ptr<sphere> sphere_ptr = make_shared<sphere>(point3(0,0,0), 1.0);
```

`make_shared<thing>(thing_constructor_params ...)`使用构造参数定义`thing`实例，返回一个`shared_ptr<thing>`。

由于类别可以被**return类型自动判断**，因此可以用`auto`简写：

```c++
auto double_ptr = make_shared<double>(0.37);
auto vec3_ptr   = make_shared<vec3>(1.414214, 2.718281, 1.618034);
auto sphere_ptr = make_shared<sphere>(point3(0,0,0), 1.0);
```

本文中会使用大量的智能指针，因为它可以**允许多个物体共享一个实例**（例如多个球体共享一个纹理），同时它也可以自动化方便管理内存。

`std::shared_ptr`在`<memory>`头文件中。

### 6.7 常量及工具函数

一些**数学常量**：

```c++
#ifndef INONEWEEKEND_RTWEEKEND_H
#define INONEWEEKEND_RTWEEKEND_H

#include "cmath"
#include "limits"
#include "memory"

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

// Common Headers
#include "ray.h"
#include "vec3.h"

#endif //INONEWEEKEND_RTWEEKEND_H
```

修改`main函数`：

```c++
#include "rtweekend.h"

#include "color.h"
#include "hittable_list.h"
#include "sphere.h"

#include "iostream"

color ray_color(const ray& r, const hittable& world) {
    hit_record rec;

    if(world.hit(r, 0, infinity, rec)) {
        return 0.5 * (rec.normal + color(1, 1, 1));
    }

    vec3 unit_direction = unit_vector(r.direction());
    auto t = 0.5 * (unit_direction.y() + 1.0);
    return (1.0 - t) * color(1.0, 1.0, 1.0) + t * color(0.5, 0.7, 1.0);
}

int main(){

    // Image
    const auto aspect_ratio = 16.0 / 9.0;
    const int image_width = 400;
    const int image_height = static_cast<int>(image_width / aspect_ratio);

    // World
    hittable_list world;
    world.add(make_shared<sphere>(point3(0, 0, -1), 0.5));
    world.add(make_shared<sphere>(point3(0, -100.5, -1), 100));

    // Camera
    auto viewport_height = 2.0;
    auto viewport_width = aspect_ratio * viewport_height;
    auto focal_length = 1.0;

    auto origin = point3(0, 0, 0);
    auto horizontal = vec3(viewport_width, 0, 0);
    auto vertical = vec3(0, viewport_height, 0);
    auto lower_left_corner = origin - horizontal / 2 - vertical / 2 - vec3(0, 0, focal_length);


    // Render
    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    for(int j = image_height - 1; j >= 0; --j) {
        std::cerr << "\nScanlines remaining: " << j << " " << std::flush;
        for(int i = 0; i < image_width; ++i) {
            auto u = double(i) / (image_width - 1);
            auto v = double(j) / (image_height - 1);
            ray r(origin, lower_left_corner + u * horizontal + v * vertical - origin);
            color pixel_color = ray_color(r, world);
            write_color(std::cout, pixel_color);
        }
    }

    std::cerr << "\nDone.\n";

    return 0;
}
```

<img src="./images/Resulting render of normals-colored sphere with ground.png"  style="zoom:30%;" />

## 7. 反走样

当真实的摄像机拍一张照片，通常在边缘没有锯齿，因为**边缘像素是前景与背景的混合**。

我们可以将一簇像素值进行平均来得到相似的结果。

### 7.1 一些随机数工具

使用`<cstdlib>`头文件中的`rand()`函数来进行随机生成，这个函数返回`[0, RAND_MAX]`之间的任意值，这里我们返回`[0,1)`或`[MIN,MAX)`之间的值。

在`rtweekend.h`中加入如下代码：

```c++
#include "cstdlib"
...
    
// Utility Functions
...
    
inline double random_double() {
    // Returns a random real in [0, 1)
    return rand() / (RAND_MAX + 1.0);
}

inline double random_double(double MIN, double MAX{
    // Returns a random real in [min, max)
    return MIN + (MAX - MIN) * random_double();
}
```

C++旧版本一个标准的随机数生成器，但是新版本中`<random>`头文件解决了这个问题。

```c++
#include "random"
...
    
// Utility Functions
...

inline double random_double() {
    // Returns a random real in [0, 1)
    static std::uniform_real_distribution<double> distribution(0.0, 1.0);
    static std::mt19937 generator;

    return distribution(generator);
}

inline double random_double(double MIN, double MAX){
    // Returns a random real in [min, max)
    return MIN + (MAX - MIN) * random_double();
}
```

### 7.2 多次采样形成像素

在一个给定的像素里进行多次采样，在每个采样点发射光线，之后将这些光线平均：

<img src="./images/Pixel samples.jpg"  style="zoom:70%;" />

新建一个`camera`类，管理虚拟摄像机以及相关场景的扫描任务：

```c++
#ifndef INONEWEEKEND_CAMERA_H
#define INONEWEEKEND_CAMERA_H

#include "rtweekend.h"

class camera {
public:
    camera() {
        auto aspect_ratio = 16.0 / 9.0;
        auto viewport_height = 2.0;
        auto viewport_width = aspect_ratio * viewport_height;
        auto focal_length = 1.0;

        auto origin = point3(0, 0, 0);
        auto horizontal = vec3(viewport_width, 0.0, 0.0);
        auto vertical = vec3(0.0, viewport_height, 0.0);
        auto lower_left_corner = origin - horizontal / 2 - vertical / 2 - vec3(0, 0, focal_length);
    }

    ray get_ray(double u, double v) const {
        return ray(origin, lower_left_corner + u * horizontal + v * vertical - origin);
    }

private:
    point3 origin;
    point3 lower_left_corner;
    vec3 horizontal;
    vec3 vertical;
};

#endif //INONEWEEKEND_CAMERA_H
```

为了处理多个采样的颜色计算，需要更新`color.h`中的`write_color`函数，需要除以采样数`samples_per_pixel`，另外需要在`rtweenkend.h`中添加一个`clamp(x,MIN,MAX)`函数，将`x`的值固定在`[MIN,MAX]`之间。

```c++
inline double clamp(double x, double MIN, double MAX) {
    if(x < MIN) return MIN;
    if(x > MAX) return MAX;
    return x;
}
```

```c++
#ifndef INONEWEEKEND_COLOR_H
#define INONEWEEKEND_COLOR_H

#include "vec3.h"

#include "iostream"

void write_color(std::ostream &out, color pixel_color, int samples_per_pixel) {
    auto r = pixel_color.x();
    auto g = pixel_color.y();
    auto b = pixel_color.z();

    // Divide the color by the number of samples.
    auto scale = 1.0 / samples_per_pixel;
    r *= scale;
    g *= scale;
    b *= scale;

    // Write the translated [0,255] value of each color component.
    out << static_cast<int>(256 * clamp(r, 0.0, 0.999)) << " "
        << static_cast<int>(256 * clamp(g, 0.0, 0.999)) << " "
        << static_cast<int>(256 * clamp(b, 0.0, 0.999)) << "\n";
}

#endif //INONEWEEKEND_COLOR_H
```

同时需要修改`main函数`：

```c++
#include "rtweekend.h"

#include "color.h"
#include "hittable_list.h"
#include "sphere.h"
#include "camera.h"

#include "iostream"

color ray_color(const ray& r, const hittable& world) {
    hit_record rec;

    if(world.hit(r, 0, infinity, rec)) {
        return 0.5 * (rec.normal + color(1, 1, 1));
    }

    vec3 unit_direction = unit_vector(r.direction());
    auto t = 0.5 * (unit_direction.y() + 1.0);
    return (1.0 - t) * color(1.0, 1.0, 1.0) + t * color(0.5, 0.7, 1.0);
}

int main(){

    // Image
    const auto aspect_ratio = 16.0 / 9.0;
    const int image_width = 400;
    const int image_height = static_cast<int>(image_width / aspect_ratio);
    const int samples_per_pixel = 100;

    // World
    hittable_list world;
    world.add(make_shared<sphere>(point3(0, 0, -1), 0.5));
    world.add(make_shared<sphere>(point3(0, -100.5, -1), 100));

    // Camera
    camera cam;

    // Render
    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";

    for(int j = image_height - 1; j >= 0; --j) {
        std::cerr << "\nScanlines remaining: " << j << " " << std::flush;
        for(int i = 0; i < image_width; ++i) {
            color pixel_color(0, 0, 0);
            for(int s = 0; s < samples_per_pixel; ++s) {
                auto u = (i + random_double()) / (image_width - 1);
                auto v = (j + random_double()) / (image_height - 1);
                ray r = cam.get_ray(u, v);
                pixel_color += ray_color(r, world);
            }
            write_color(std::cout, pixel_color, samples_per_pixel);
        }
    }

    std::cerr << "\nDone.\n";

    return 0;
}
```

之后可以看到反走样的效果：



















