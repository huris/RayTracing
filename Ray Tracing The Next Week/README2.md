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



