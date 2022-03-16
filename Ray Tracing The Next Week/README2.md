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



















