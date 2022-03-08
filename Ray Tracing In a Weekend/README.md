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



















