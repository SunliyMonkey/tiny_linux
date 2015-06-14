#tiny_linux

tiny_linux是高级操作系统要求完成的作品，这里记录了作品完成的过程以及自己的心得，希望对大家有用。

PS： 关于根文件的制作部分，对当初小白的我，感谢[杨海宇同学](https://github.com/ir193/tiny_linux/blob/master/NOTE.md)的付出，让自己能够快速入门。

###目标
>1. 制作一个精简的linux内核，要求在大小尽可能小的情况下，能够支持TCP/IP进行数据传输，需要对内核所需模块进行定制。

>2. 采用busybox制作根文件系统，利用kernel mode linux补丁，使busybox运行在内核态。

###成果
    平台 ：  X86_64
    linux:   4.0.4
    优化前:　bzImage＝6.5M　内存＝35M
    优化后:　bzImage＝931K　内存＝22M

===

##Section 1：生成bzImage
>**背景: [Linux内核的启动过程](http://book.51cto.com/art/201405/438671.htm)**<br/>
>Linux内核本身的启动又分为压缩内核和非压缩两种。从Linux内核程序的结构上，具有如下的特点：
压缩内核 = 解压缩程序 + 压缩后的内核映像
当压缩内核运行后，将运行一段解压缩程序，得到真正的内核映像，然后跳转到内核映像运行。此时，Linux进入非压缩内核的入口，在非压缩的内核入口中，系统完成各种初始化任务后，跳转到C语言的入口处运行。

这一步主要是通过编译linux内核，获取linux的压缩内核镜像**bzImage**

1. 下载linux内核代码
    
        mkdir tiny_linux
        cd tiny_linux
        curl https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.0.4.tar.xz | tar xJf
    
    
2. 编译linux内核

在内核代码根目录的Makefile当中，可以发现有如下文字描述：

    >**背景：Makefile Line: 98**
    \# kbuild supports saving output files in a separate directory.
    \# To locate output files in a separate directory two syntaxes are supported.
    \# In both cases the working directory must be the root of the kernel src.
    \# 1) O=
    \# Use "make O=dir/to/store/output/files/"

利用`make O=dir/to/store/output/files/`使输出文件与源代码文件进行分离，这样做的好处，使得我们能够建立不同的输出文件，每个独立的输出文件都能够有自己专属的设置。

    
    cd tiny_linux
    mkdir obj
    cd linux-4.0.4
    make O=../obj/linux_0 x86_64_defconfig
    


>**背景：内核默认配置文件**
内核为很多平台附带了默认配置文件，保存在arch/<arch>/configs目录下，其中<arch>对应具体的架构，如x86、arm或者mips等。比如，对于x86架构，内核分别提供了32位和64位的配置文件，即i386_defconfig和x86_64_defconfig；对于arm架构，内核提供了如NVIDA的Tegra平台的默认配置tegra_defconfig，Samsung的S5PV210平台的默认配置s5pv210_defconfig等。

在`linux_0`目录下，执行`make menuconfig`，就能够对内核进行配置。目前先对默认配置进行编译，执行`make -jN`，可以设定不同线程数量进行编译，`N`最好为机器支持的最大线程？？


    cd tiny_linux/obj/linux_0
    make -j32 #依自己机器设定

如果编译成功，你将看见如下信息：

    Setup is 13932 bytes (padded to 14336 bytes).
    System is 6588 kB
    CRC 6a1e6d04
    Kernel: arch/x86/boot/bzImage is ready  (#1)

而这个bzImage正是我们需要的，此时bzImage大小6.5M

    ls -lh arch/x86/boot/bzImage 
    -rw-r--r-- 1 root root 6.5M Jun 14 10:28 arch/x86/boot/bzImage

在section 3我将详细讲述，优化配置的过程，经过优化配置后，bzImage的大小将降低到931K。

---

##Section 2： 制作根文件系统
