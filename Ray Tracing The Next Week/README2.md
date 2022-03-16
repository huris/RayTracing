# Ray Tracing The Next Week

https://raytracing.github.io/books/RayTracingTheNextWeek.html



## 5 柏林噪声

为了得到一个看上去很cool的纹理，可以使用**柏林噪声（Perlin noise）**。

<img src="./images/white noise.jpg"  style="zoom:80%;" />

对噪声做一些模糊处理：

<img src="./images/white noise blurred.jpg"  style="zoom:80%;" />

柏林噪声最关键的特点是可复现性，**如果输入的是同一个三维空间中的点，它的输出值总是相同的**。

另一个特点是它实现起来**简单快捷**，因此通常拿柏林噪声来做一些hack的事情。

### 5.1 使用随机数字块

可以用一个随机生成的三维数组铺满整个空间，可以得到明显重复的区块：

<img src="./images/tile random.jpg"  style="zoom:80%;" />

不适用**瓷砖贴图**的方式，而是用hash表去完成它：

`perlin.h`

```c++
#ifndef THENEXTWEEK_PERLIN_H
#define THENEXTWEEK_PERLIN_H

#include "rtweekend.h"

class perlin{
public:
    perlin() {
        ranfloat = new double[point_count];
        for(int i = 0; i < point_count; ++i) ranfloat[i] = random_double();

        perm_x = perlin_generate_perm();
        perm_y = perlin_generate_perm();
        perm_z = perlin_generate_perm();
    }

    ~perlin() {
        delete[] ranfloat;
        delete[] perm_x;
        delete[] perm_y;
        delete[] perm_z;
    }

    double noise(const point3& p) const {
        auto i = static_cast<int>(4 * p.x()) & 255;
        auto j = static_cast<int>(4 * p.y()) & 255;
        auto k = static_cast<int>(4 * p.z()) & 255;

        return ranfloat[perm_x[i] ^ perm_y[j] ^ perm_z[k]];
    }

private:
    static const int point_count = 256;
    double* ranfloat;
    int* perm_x;
    int* perm_y;
    int* perm_z;

    static int* perlin_generate_perm() {
        auto p = new int[point_count];
        for(int i = 0; i < perlin::point_count; ++i) p[i] = i;

        permute(p, point_count);

        return p;
    }

    static void permute(int* p, int n) {
        for(int i = n - 1; i > 0; --i) {
            int target = random_int(0, i);
            std::swap(p[i], p[target]);
        }
    }
};

#endif //THENEXTWEEK_PERLIN_H
```

现在来生成一个纹理，使用范围为$[0,1]$的一个float变量来制造灰度图：

`texture.h`

```c++
#include "perlin.h"

class noise_texture : public texture {
    public:
        noise_texture() {}

        virtual color value(double u, double v, const point3& p) const override {
            return color(1,1,1) * noise.noise(p);
        }

    public:
        perlin noise;
};
```

可以在某些球上使用**柏林噪声纹理**：

`RayTracing.h`

```c++
hittable_list two_perlin_spheres() {
    hittable_list objects;

    auto pertext = make_shared<noise_texture>();
    objects.add(make_shared<sphere>(point3(0,-1000,0), 1000, make_shared<lambertian>(pertext)));
    objects.add(make_shared<sphere>(point3(0, 2, 0), 2, make_shared<lambertian>(pertext)));

    return objects;
}
```

`RayTracing.h`

```c++
int main() {
    ...
    switch (0) {
        ...
        case 2:
            ...
        default:
        case 3:
            world = two_perlin_spheres();
            lookfrom = point3(13,2,3);
            lookat = point3(0,0,0);
            vfov = 20.0;
            break;
    }
    ...
```

得到结果：

<img src="./images/Hashed random texture.png"  style="zoom:40%;" />

### 5.2 平滑结果

对其进行线性插值，进行平滑过渡：

`perlin.h`

```c++
class perlin {
    public:
        ...
        double noise(point3 vec3& p) const {
            auto u = p.x() - floor(p.x());
            auto v = p.y() - floor(p.y());
            auto w = p.z() - floor(p.z());

            auto i = static_cast<int>(floor(p.x()));
            auto j = static_cast<int>(floor(p.y()));
            auto k = static_cast<int>(floor(p.z()));
            double c[2][2][2];

            for (int di=0; di < 2; di++)
                for (int dj=0; dj < 2; dj++)
                    for (int dk=0; dk < 2; dk++)
                        c[di][dj][dk] = ranfloat[
                            perm_x[(i+di) & 255] ^
                            perm_y[(j+dj) & 255] ^
                            perm_z[(k+dk) & 255]
                        ];

            return trilinear_interp(c, u, v, w);
        }
        ...
    private:
        ...
        static double trilinear_interp(double c[2][2][2], double u, double v, double w) {
            auto accum = 0.0;
            for (int i=0; i < 2; i++)
                for (int j=0; j < 2; j++)
                    for (int k=0; k < 2; k++)
                        accum += (i*u + (1-i)*(1-u))*
                                (j*v + (1-j)*(1-v))*
                                (k*w + (1-k)*(1-w))*c[i][j][k];

            return accum;
        }
    }
```

得到结果：

<img src="./images/Perlin texture with trilinear interpolation.png"  style="zoom:40%;" />

### 5.3 使用Hermitian光滑来提升效果

上图中的一部分有**马赫带（Mach bands）**，由于线性变化的颜色构成的有名的视觉感知效果。

这里使用**hermite cube来进行平滑插值**：

`perlin.h`

```c++
class perlin (
    public:
        ...
        double noise(const point3& p) const {
            auto u = p.x() - floor(p.x());
            auto v = p.y() - floor(p.y());
            auto w = p.z() - floor(p.z());
            u = u*u*(3-2*u);
            v = v*v*(3-2*v);
            w = w*w*(3-2*w);

            auto i = static_cast<int>(floor(p.x()));
            auto j = static_cast<int>(floor(p.y()));
            auto k = static_cast<int>(floor(p.z()));
            ...
```

得到结果：

<img src="./images/Perlin texture, trilinearly interpolated, smoothed.png"  style="zoom:40%;" />

### 5.4 调整频率

上面的图片看上去有一些低频，没有花纹，可以调整输入的点来是它有一个更快的频率：

`texture.h`

```c++
class noise_texture : public texture {
    public:
        noise_texture() {}
        noise_texture(double sc) : scale(sc) {}

        virtual color value(double u, double v, const point3& p) const override {
            return color(1,1,1) * noise.noise(scale * p);
        }

    public:
        perlin noise;
        double scale;
};
```

之后在`two_perlin_spheres()`场景中改变`scale`：

`RayTracing.cpp`

```c++
hittable_list two_perlin_spheres() {
    hittable_list objects;
    auto pertext = make_shared<noise_texture>(4);
    objects.add(make_shared<sphere>(point3(0,-1000,0), 1000, make_shared<lambertian>(pertext)));
    objects.add(make_shared<sphere>(point3(0, 2, 0), 2, make_shared<lambertian>(pertext)));

    return objects;
}
```

得到结果：

<img src="./images/Perlin texture, higher frequency.png"  style="zoom:40%;" />

### 5.5 在网格点上使用随机向量

现在看上去有一点格子的感觉，也许是因为这方法的最大值和最小值总是精确地落在整数$x/y/z$上。

Ken Perlin有一个十分聪明的而trick，在网格点使用随机的单位向量替代float（即梯度向量），用点乘将min和max值推离网格点。

这里首先把`random float`改成`random vectors`，这些梯度向量可以是任意合理的不规则方向的集合，所以干脆使用单位向量作为梯度向量：

`perlin.h`

```c++
#ifndef THENEXTWEEK_PERLIN_H
#define THENEXTWEEK_PERLIN_H

#include "rtweekend.h"

class perlin{
public:
    perlin() {
        ranvec = new vec3[point_count];
        for(int i = 0; i < point_count; ++i) ranvec[i] = unit_vector(vec3::random(-1, 1));

        perm_x = perlin_generate_perm();
        perm_y = perlin_generate_perm();
        perm_z = perlin_generate_perm();
    }

    ~perlin() {
        delete[] ranvec;
        delete[] perm_x;
        delete[] perm_y;
        delete[] perm_z;
    }

    double noise(const vec3& p) const {
        auto u = p.x() - floor(p.x());
        auto v = p.y() - floor(p.y());
        auto w = p.z() - floor(p.z());

        auto i = static_cast<int>(floor((p.x())));
        auto j = static_cast<int>(floor((p.y())));
        auto k = static_cast<int>(floor((p.z())));

        vec3 c[2][2][2];

        for(int di = 0; di < 2; ++di){
            for(int dj = 0; dj < 2; ++dj){
                for(int dk = 0; dk < 2; ++dk){
                    c[di][dj][dk] = ranvec[
                                perm_x[(i + di) & 255] ^
                                perm_y[(j + dj) & 255] ^
                                perm_z[(k + dk) & 255]
                            ];
                }
            }
        }

        return triliner_interp(c, u, v, w);
    }

private:
    static const int point_count = 256;
    vec3* ranvec;
    int* perm_x;
    int* perm_y;
    int* perm_z;

    static int* perlin_generate_perm() {
        auto p = new int[point_count];
        for(int i = 0; i < perlin::point_count; ++i) p[i] = i;

        permute(p, point_count);

        return p;
    }

    static void permute(int* p, int n) {
        for(int i = n - 1; i > 0; --i) {
            int target = random_int(0, i);
            std::swap(p[i], p[target]);
        }
    }

    static double triliner_interp(vec3 c[2][2][2], double u, double v, double w) {
        auto uu = u * u * (3 - 2 * u);
        auto vv = v * v * (3 - 2 * v);
        auto ww = w * w * (3 - 2 * w);
        auto accum = 0.0;

        for(int i = 0; i < 2; ++i){
            for(int j = 0; j < 2; ++j){
                for(int k = 0; k < 2; ++k){
                    vec3 weight_v(u - i, v - j, w - k);
                    accum += (i * uu + (1 - i) * (1 - uu)) *
                             (j * vv + (1 - j) * (1 - vv)) *
                             (k * ww + (1 - k) * (1 - ww)) *
                             dot(c[i][j][k], weight_v);
                }
            }
        }
        return accum;
    }
};

#endif //THENEXTWEEK_PERLIN_H
```

**柏林插值**的输出结果可能是负数，这些负数在gamma校正时经过开平方根`sqrt()`可能会变成NaN。

因此我们需要将结果映射到$[0,1]$：

`texture.h`

```c++
class noise_texture : public texture {
    public:
        noise_texture() {}
        noise_texture(double sc) : scale(sc) {}

        virtual color value(double u, double v, const point3& p) const override {
            return color(1,1,1) * 0.5 * (1.0 + noise.noise(scale * p));
        }

    public:
        perlin noise;
        double scale;
};
```

最后可以得出如下的结果：

<img src="./images/Perlin texture, shifted off integer values.png"  style="zoom:40%;" />

### 5.6 介绍扰动

使用多个频率相加得到复合噪声是一种很常见的做法，称之为**扰动（turbulence）**。

`perlin.h`

```c++
class perlin {
    ...
    public:
        ...
        double turb(const point3& p, int depth=7) const {
            auto accum = 0.0;
            auto temp_p = p;
            auto weight = 1.0;

            for (int i = 0; i < depth; i++) {
                accum += weight*noise(temp_p);
                weight *= 0.5;
                temp_p *= 2;
            }

            return fabs(accum);
        }
        ...
```

`texture.h`

```c++
class noise_texture : public texture {
    public:
        noise_texture() {}
        noise_texture(double sc) : scale(sc) {}

        virtual color value(double u, double v, const point3& p) const override {
            return color(1,1,1) * noise.turb(scale * p);
        }

    public:
        perlin noise;
        double scale;
};
```

直接使用`turb`函数来产生纹理，会得到一个看上去像伪装网一样的东西：

<img src="./images/Perlin texture with turbulence.png"  style="zoom:40%;" />

### 5.7 调整参数

通常扰动函数是间接使用的，在程序生成纹理这方面的`hello world`是一个类似大理石的纹理。

基本思路：让颜色与`sin`函数的值成比例，并使用扰动函数去调整相位（平移`sin(x)`中的$x$），使得带状条纹起伏波荡。

修正之前直接使用扰动`turb`或者噪声`noise`给颜色赋值的方法，得到一个类似于大理石的纹理：

`texture.h`

```c++
class noise_texture : public texture {
    public:
        noise_texture() {}
        noise_texture(double sc) : scale(sc) {}

        virtual color value(double u, double v, const point3& p) const override {
            return color(1,1,1) * 0.5 * (1 + sin(scale*p.z() + 10*noise.turb(p)));
        }

    public:
        perlin noise;
        double scale;
};
```

得到如下结果：

<img src="./images/Perlin noise, marbled texture.png"  style="zoom:40%;" />

## 6. 图片纹理映射

可以使用射入点$p$来映射类似大理石那样程序生成的纹理，也可以读取一张图片，并将一个2维$(u,v)$坐标系映射在图片上。

使用$(u,v)$坐标的一个直接想法是将$u$与$v$调整比例后取整，然后将其对应到像素坐标$(i,j)$上。但是这个方法很糟糕，因为每次照片分辨率发生变化时，都需要修改代码。

图形学一般采用纹理坐标系代替图像坐标系，即使用$[0,1]$之间的小数来表示图像中的位置。

例如，对于一张宽度为$N_x$高度为$N_y$的图像中的像素$(i,j)$，其像素坐标系下的坐标为：$u=\frac{i}{N_x-1},v=\frac{j}{N_y-1}$

对于`hattable`来说，需要在`hit_record`中加入$u$和$v$的记录。

### 6.1 存储图片纹理数据

现在需要新建一个texture类来存放图片，这里使用图片工具库[stb_image](https://github.com/nothings/stb)，下载`stb_image.h`后放入`external`文件夹。

它将图片信息读入一个无符号字符类型（unsigned char）的大数组中，将RGB值规定在范围$[0,255]$，从全黑到全白。

`texture.h`

```c++
#include "rtweekend.h"
#include "rtw_stb_image.h"
#include "perlin.h"

#include <iostream>

...

class image_texture : public texture {
    public:
        const static int bytes_per_pixel = 3;

        image_texture()
          : data(nullptr), width(0), height(0), bytes_per_scanline(0) {}

        image_texture(const char* filename) {
            auto components_per_pixel = bytes_per_pixel;

            data = stbi_load(
                filename, &width, &height, &components_per_pixel, components_per_pixel);

            if (!data) {
                std::cerr << "ERROR: Could not load texture image file '" << filename << "'.\n";
                width = height = 0;
            }

            bytes_per_scanline = bytes_per_pixel * width;
        }

        ~image_texture() {
            delete data;
        }

        virtual color value(double u, double v, const vec3& p) const override {
            // If we have no texture data, then return solid cyan as a debugging aid.
            if (data == nullptr)
                return color(0,1,1);

            // Clamp input texture coordinates to [0,1] x [1,0]
            u = clamp(u, 0.0, 1.0);
            v = 1.0 - clamp(v, 0.0, 1.0);  // Flip V to image coordinates

            auto i = static_cast<int>(u * width);
            auto j = static_cast<int>(v * height);

            // Clamp integer mapping, since actual coordinates should be less than 1.0
            if (i >= width)  i = width-1;
            if (j >= height) j = height-1;

            const auto color_scale = 1.0 / 255.0;
            auto pixel = data + j*bytes_per_scanline + i*bytes_per_pixel;

            return color(color_scale*pixel[0], color_scale*pixel[1], color_scale*pixel[2]);
        }

    private:
        unsigned char *data;
        int width, height;
        int bytes_per_scanline;
};
```

`rtw_stb_image.h`

```c++
#ifndef RTWEEKEND_STB_IMAGE_H
#define RTWEEKEND_STB_IMAGE_H

// Disable pedantic warnings for this external library.
#ifdef _MSC_VER
    // Microsoft Visual C++ Compiler
    #pragma warning (push, 0)
#endif

#define STB_IMAGE_IMPLEMENTATION
#include "external/stb_image.h"

// Restore warning levels.
#ifdef _MSC_VER
    // Microsoft Visual C++ Compiler
    #pragma warning (pop)
#endif

#endif
```

### 6.2 使用图片纹理

这里选用一张地球的纹理：

<img src="./images/earthmap.jpg"  style="zoom:60%;" />

修改代码，读取一张图片并将其指定为漫反射材质。

`RayTracing.cpp`

```c++
hittable_list earth() {
    auto earth_texture = make_shared<image_texture>("earthmap.jpg");
    auto earth_surface = make_shared<lambertian>(earth_texture);
    auto globe = make_shared<sphere>(point3(0,0,0), 2, earth_surface);

    return hittable_list(globe);
}
```

这里可以感受一下texture类的魅力，可以将任意一种类的纹理（贴图）运用到lambertian材质上，同时这里lambertian材质不需要关心其输入的是图片还是其他。

`RayTracing.cpp`

```c++
int main() {
    ...
    switch (0) {
        ...
        default:
        case 3:
            ...
        default:
        case 4:
            world = earth();
            lookfrom = point3(13,2,3);
            lookat = point3(0,0,0);
            vfov = 20.0;
            break;
    }
    ...
```

如果生成的图片是一张青色的球体图，则说明`stb_image`没有加载`earthmap.jpg`，

确保将`earthmap.jpg`的路径设置正确（mac系统可能要设置成完整路径）。

<img src="./images/Earth-mapped sphere.png"  style="zoom:40%;" />

## 7. 矩形和光源

**光源**是光线追踪里的一个关键组件。

早期简单的光线追踪器使用抽象的光源，例如空间中点光源或直接光照。

**现代方法更多的采用基于物理的光源，有位置和大小**。

为了创建这样的光源，我们需要能够将任何常规的物体转换成在场景中发出光的东西。

### 7.1 发光材质

首先，需要制作一个发光材质，需要增加一个发光函数。

`material.h`

```c++
class diffuse_light : public material  {
    public:
        diffuse_light(shared_ptr<texture> a) : emit(a) {}
        diffuse_light(color c) : emit(make_shared<solid_color>(c)) {}

        virtual bool scatter(
            const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
        ) const override {
            return false;
        }

        virtual color emitted(double u, double v, const point3& p) const override {
            return emit->value(u, v, p);
        }

    public:
        shared_ptr<texture> emit;
};
```

为了不去给每个不是光源的材质实现`emitted()`函数，这里并不使用纯虚函数，让函数默认返回黑色：

`material.h`

```c++
class material {
    public:
        virtual color emitted(double u, double v, const point3& p) const {
            return color(0,0,0);
        }
        virtual bool scatter(
            const ray& r_in, const hit_record& rec, color& attenuation, ray& scattered
        ) const = 0;
};
```

### 7.2 对光线颜色函数增加背景色

接下来需要一个纯黑的背景，并让所有光线都来自光源材质。

要想实现它，需要在`ray_color`函数中加入一个背景色变量，然后由`emitted`函数产生新的颜色值。

`RayTracing.cpp`

```c++
color ray_color(const ray& r, const color& background, const hittable& world, int depth) {
    hit_record rec;

    // If we've exceeded the ray bounce limit, no more light is gathered.
    if (depth <= 0)
        return color(0,0,0);

    // If the ray hits nothing, return the background color.
    if (!world.hit(r, 0.001, infinity, rec))
        return background;

    ray scattered;
    color attenuation;
    color emitted = rec.mat_ptr->emitted(rec.u, rec.v, rec.p);

    if (!rec.mat_ptr->scatter(r, rec, attenuation, scattered))
        return emitted;

    return emitted + attenuation * ray_color(scattered, background, world, depth-1);
}
...

int main() {
    ...

    point3 lookfrom;
    point3 lookat;
    auto vfov = 40.0;
    auto aperture = 0.0;
    color background(0,0,0);

    switch (0) {
        case 1:
            world = random_scene();
            background = color(0.70, 0.80, 1.00);
            lookfrom = point3(13,2,3);
            lookat = point3(0,0,0);
            vfov = 20.0;
            aperture = 0.1;
            break;

        case 2:
            world = two_spheres();
            background = color(0.70, 0.80, 1.00);
            lookfrom = point3(13,2,3);
            lookat = point3(0,0,0);
            vfov = 20.0;
            break;

        case 3:
            world = two_perlin_spheres();
            background = color(0.70, 0.80, 1.00);
            lookfrom = point3(13,2,3);
            lookat = point3(0,0,0);
            vfov = 20.0;
            break;

        default:
        case 4:
            world = earth();
            background = color(0.70, 0.80, 1.00);
            lookfrom = point3(13,2,3);
            lookat = point3(0,0,0);
            vfov = 20.0;
            break;

        default:
        case 5:
            background = color(0.0, 0.0, 0.0);
            break;
    }

    ...
                pixel_color += ray_color(r, background, world, max_depth);
    ...
}
```

由于删除了用于确定光线击中天空时的颜色代码，所以需要**为旧场景传如一个新的颜色值**（这里选择整个天空使用平坦的蓝白色），可以使用一个bool值来切换之前的天空框代码和新的纯色背景。

### 7.3 创建矩形对象

现在，可以加入一些矩形，矩形在人为建模环境时很方便使用（例如轴对齐的矩形）。

首先有一个xy平面的矩形，这个平面根据它的z值来定义（例如$z=k$），一个轴对齐的矩形可以通过如下方式来进行定义（$x=x_0,x=x_1,y=y_0,y=y_1$）。

<img src="./images/Ray rectangle intersection.jpg"  style="zoom:40%;" />

为了检测是否有光线与这个矩形相交，首先需要判断光线与这个平面的交点。

对于一条射线：$P(t)=A+tb$，当$z$值确定后，可以写为：$P_z(t)=A_z+tb_z$，解出：$t=\frac{k-A_z}{b_z}$

一旦确定了$t$，可以将其带入$x$和$y$的方程：$x=A_x+tb_x,y=A_y+tb_y$

当且仅当：$x_0<x<x_1, y_0<y<y_1$时，发生相交。

由于矩形是**轴对齐的**，它们的边界框将有一个无限薄的边，当使用轴对齐的包围盒来划分它们时，会有精度问题。

为了解决这个问题，需要对所有命中的对象都设置一个边界框，**在每个维度上都有一个有限的宽度**。

因此，对于上面的矩形，**需要在无限薄的边填充一些盒子**。

`aarect.h`

```c++
#ifndef AARECT_H
#define AARECT_H

#include "rtweekend.h"

#include "hittable.h"

class xy_rect : public hittable {
    public:
        xy_rect() {}

        xy_rect(double _x0, double _x1, double _y0, double _y1, double _k, 
            shared_ptr<material> mat)
            : x0(_x0), x1(_x1), y0(_y0), y1(_y1), k(_k), mp(mat) {};

        virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override;

        virtual bool bounding_box(double time0, double time1, aabb& output_box) const override {
            // The bounding box must have non-zero width in each dimension, so pad the Z
            // dimension a small amount.
            output_box = aabb(point3(x0,y0, k-0.0001), point3(x1, y1, k+0.0001));
            return true;
        }

    public:
        shared_ptr<material> mp;
        double x0, x1, y0, y1, k;
};

#endif
```

相交函数：

`aarect.h`

```c++
bool xy_rect::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    auto t = (k-r.origin().z()) / r.direction().z();
    if (t < t_min || t > t_max)
        return false;
    auto x = r.origin().x() + t*r.direction().x();
    auto y = r.origin().y() + t*r.direction().y();
    if (x < x0 || x > x1 || y < y0 || y > y1)
        return false;
    rec.u = (x-x0)/(x1-x0);
    rec.v = (y-y0)/(y1-y0);
    rec.t = t;
    auto outward_normal = vec3(0, 0, 1);
    rec.set_face_normal(r, outward_normal);
    rec.mat_ptr = mp;
    rec.p = r.at(t);
    return true;
}
```

### 7.4 将物体变成光源

设置一个矩形为光源：

`RayTracing.cpp`

```c++
hittable_list simple_light() {
    hittable_list objects;

    auto pertext = make_shared<noise_texture>(4);
    objects.add(make_shared<sphere>(point3(0,-1000,0), 1000, make_shared<lambertian>(pertext)));
    objects.add(make_shared<sphere>(point3(0,2,0), 2, make_shared<lambertian>(pertext)));

    auto difflight = make_shared<diffuse_light>(color(4,4,4));
    objects.add(make_shared<xy_rect>(3, 5, 1, 3, -2, difflight));

    return objects;
}
```

新建一个场景，注意要设置背景为黑色：

`RayTracing.cpp`

```c++
#include "rtweekend.h"

#include "camera.h"
#include "color.h"
#include "hittable_list.h"
#include "material.h"
#include "moving_sphere.h"
#include "sphere.h"
#include "aarect.h"

#include <iostream>
...
int main() {
    ...
    switch (0) {
        ...
        default:
        case 5:
            world = simple_light();
            samples_per_pixel = 400;
            background = color(0,0,0);
            lookfrom = point3(26,3,6);
            lookat = point3(0,2,0);
            vfov = 20.0;
            break;
    }
    ...
```

得到结果：

<img src="./images/Scene with rectangle light source.png"  style="zoom:40%;" />

注意现在的光比$(1,1,1)$要亮，所以这个亮度足够它去照亮其他东西了。

同样的方法，也可做一个圆形的光源：

`RayTracing.cpp`

```c++
hittable_list simple_light() {
    hittable_list objects;

    auto pertext = make_shared<noise_texture>(4);
    objects.add(make_shared<sphere>(point3(0, -1000, 0), 1000, make_shared<lambertian>(pertext)));
    objects.add(make_shared<sphere>(point3(0, 2, 0), 2, make_shared<lambertian>(pertext)));

    auto difflight = make_shared<diffuse_light>(color(4, 4, 4));
    objects.add(make_shared<xy_rect>(3, 5, 1, 3, -2, difflight));
    objects.add(make_shared<sphere>(point3(0, 2, 3), 2, difflight));

    return objects;
}
```

<img src="./images/Scene with rectangle and sphere light sources.png"  style="zoom:40%;" />

### 7.5 更多轴对齐的矩形

增加另外两个轴，然后形成一个**Cornell盒子**。

`arrect.h`

```c++
class xz_rect : public hittable {
public:
    xz_rect() {}

    xz_rect(double _x0, double _x1, double _z0, double _z1, double _k, shared_ptr<material> mat)
            : x0(_x0), x1(_x1), z0(_z0), z1(_z1), k(_k), mp(mat) {};

    virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override;

    virtual bool bounding_box(double time0, double time1, aabb& output_box) const override {
        // The bounding box must have non-zero width in each dimension, so pad the Y
        // dimension a small amount.
        output_box = aabb(point3(x0,k-0.0001,z0), point3(x1, k+0.0001, z1));
        return true;
    }

public:
    shared_ptr<material> mp;
    double x0, x1, z0, z1, k;
};

bool xz_rect::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    auto t = (k - r.origin().y()) / r.direction().y();
    if (t < t_min || t > t_max) return false;

    auto x = r.origin().x() + t * r.direction().x();
    auto z = r.origin().z() + t * r.direction().z();
    if (x < x0 || x > x1 || z < z0 || z > z1) return false;

    rec.u = (x - x0) / (x1 - x0);
    rec.v = (z - z0) / (z1 - z0);
    rec.t = t;

    auto outward_normal = vec3(0, 1, 0);
    rec.set_face_normal(r, outward_normal);
    rec.mat_ptr = mp;
    rec.p = r.at(t);

    return true;
}


class yz_rect : public hittable {
public:
    yz_rect() {}

    yz_rect(double _y0, double _y1, double _z0, double _z1, double _k, shared_ptr<material> mat)
            : y0(_y0), y1(_y1), z0(_z0), z1(_z1), k(_k), mp(mat) {};

    virtual bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override;

    virtual bool bounding_box(double time0, double time1, aabb& output_box) const override {
        // The bounding box must have non-zero width in each dimension, so pad the X
        // dimension a small amount.
        output_box = aabb(point3(k-0.0001, y0, z0), point3(k+0.0001, y1, z1));
        return true;
    }

public:
    shared_ptr<material> mp;
    double y0, y1, z0, z1, k;
};

bool yz_rect::hit(const ray& r, double t_min, double t_max, hit_record& rec) const {
    auto t = (k - r.origin().x()) / r.direction().x();
    if (t < t_min || t > t_max) return false;

    auto y = r.origin().y() + t * r.direction().y();
    auto z = r.origin().z() + t * r.direction().z();
    if (y < y0 || y > y1 || z < z0 || z > z1) return false;

    rec.u = (y - y0) / (y1 - y0);
    rec.v = (z - z0) / (z1 - z0);
    rec.t = t;

    auto outward_normal = vec3(1, 0, 0);
    rec.set_face_normal(r, outward_normal);
    rec.mat_ptr = mp;
    rec.p = r.at(t);
    
    return true;
}
```

### 7.6 创建一个空的Cornell盒子

`RayTracing.cpp`

```c++
hittable_list cornell_box() {
    hittable_list objects;

    auto red   = make_shared<lambertian>(color(.65, .05, .05));
    auto white = make_shared<lambertian>(color(.73, .73, .73));
    auto green = make_shared<lambertian>(color(.12, .45, .15));
    auto light = make_shared<diffuse_light>(color(15, 15, 15));

    objects.add(make_shared<yz_rect>(0, 555, 0, 555, 555, green));
    objects.add(make_shared<yz_rect>(0, 555, 0, 555, 0, red));
    objects.add(make_shared<xz_rect>(213, 343, 227, 332, 554, light));
    objects.add(make_shared<xz_rect>(0, 555, 0, 555, 0, white));
    objects.add(make_shared<xz_rect>(0, 555, 0, 555, 555, white));
    objects.add(make_shared<xy_rect>(0, 555, 0, 555, 555, white));

    return objects;
}
```

`RayTracing.cpp`

```c++
int main() {
    ...
    switch (0) {
        ...
        default:
        case 5:
            ...
            break;

        default:
        case 6:
            world = cornell_box();
            aspect_ratio = 1.0;
            image_width = 600;
            samples_per_pixel = 200;
            background = color(0,0,0);
            lookfrom = point3(278, 278, -800);
            lookat = point3(278, 278, 0);
            vfov = 40.0;
            break;
    }
    ...
```

得到结果：

<img src="./images/Empty Cornell box.png"  style="zoom:40%;" />

这张图片有很多噪声，因为光源很小。

















