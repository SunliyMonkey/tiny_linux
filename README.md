#tiny_linux

tiny_linux是高级操作系统课上要求完成的作品，要求实现以下两点：

1. 制作一个精简的linux内核，要求在大小尽可能小的情况下，能够支持TCP/IP进行数据传输，需要对内核所需模块进行定制。

2. 采用busybox制作根文件系统，利用kernel mode linux补丁，使busybox运行在内核态。

在这里记录了我完成该作品的过程，希望对大家有用。

>PS： 关于根文件的制作部分，对当初小白的我，非常感谢[杨海宇同学](https://github.com/ir193/tiny_linux/blob/master/NOTE.md)的付出，让自己能够快速入门。

**成果**

    平台 ：  X86_64
    linux:   4.0.4
    优化前:　bzImage＝6.5M　内存＝35M
    优化后:　bzImage＝931K　内存＝22M

===

##Section 1：linux内核镜像文件
>**背景: [Linux内核的启动过程](http://book.51cto.com/art/201405/438671.htm)**<br/>
>Linux内核本身的启动又分为压缩内核和非压缩两种。从Linux内核程序的结构上，具有如下的特点：
压缩内核 = 解压缩程序 + 压缩后的内核映像
当压缩内核运行后，将运行一段解压缩程序，得到真正的内核映像，然后跳转到内核映像运行。此时，Linux进入非压缩内核的入口，在非压缩的内核入口中，系统完成各种初始化任务后，跳转到C语言的入口处运行。

这一步主要是通过编译linux内核，获取linux的压缩内核镜像**bzImage**

1. 下载linux内核代码
    
        mkdir tiny_linux
        cd tiny_linux
        curl https://www.kernel.org/pub/linux/kernel/v4.x/linux-4.0.4.tar.xz | tar xJf -
    
    
2. 编译linux内核

在内核代码根目录的Makefile当中，可以发现有如下文字描述：

 >背景：Makefile Line 98
    # kbuild supports saving output files in a separate directory.
    # To locate output files in a separate directory two syntaxes are supported.
    # In both cases the working directory must be the root of the kernel src.
    # 1) O=
    # Use "make O=dir/to/store/output/files/"

利用`make O=`命令，可以使输出文件与源代码文件分离，这样使得我们能够建立不同的输出文件，每个独立的输出文件都可以有自己的专属配置，这个在后期精简config的过程当中，特别有用。

        cd tiny_linux
        mkdir obj
        cd linux-4.0.4
        make O=../obj/linux_0 x86_64_defconfig
    
>**背景：内核默认配置文件**
内核为很多平台附带了默认配置文件，保存在arch/<arch>/configs目录下，其中<arch>对应具体的架构，如x86、arm或者mips等。比如，对于x86架构，内核分别提供了32位和64位的配置文件，即i386_defconfig和x86_64_defconfig；对于arm架构，内核提供了如NVIDA的Tegra平台的默认配置tegra_defconfig，Samsung的S5PV210平台的默认配置s5pv210_defconfig等。

在`linux_0`目录下，执行`make menuconfig`，就能够对内核进行配置，执行`make -jN`，可以指定编译过程中使用的线程数，`N`最好为机器并行支持的最大线程数


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

在section 3我将详细讲述，如何精简配置，精简后的配置，可以使bzImage的大小降低到931K。

---

##Section 2：根文件系统镜像文件

>背景: 根文件系统
>根文件系统首先是一种文件系统，但是相对于普通的文件系统，它的特殊之处在于，它是内核启动时所mount的第一个文件系统，内核代码映像文件保存在根文件系统中，而系统引导启动程序会在根文件系统挂载之后从中把一些基本的初始化脚本和服务等加载到内存中去运行。

### 构建busybox

>BusyBox是一个集成了一百多个最常用linux命令和工具的软件。BusyBox 包含了一些简单的工具，例如ls、cat和echo等等，还包含了一些更大、更复杂的工具，例grep、find、mount以及telnet。有些人将 BusyBox 称为 Linux 工具里的瑞士军刀。简单的说BusyBox就好像是个大工具箱，它集成压缩了 Linux的许多工具和命令，也包含了 Android 系统的自带的shell。


下载busybox源码，进行配置编译
        
        cd tiny_linux
        curl http://busybox.net/downloads/busybox-1.23.2.tar.bz2 | tar xjf -
        mkdir obj/busybox
        cd busybox-1.23.2
        make O=../obj/busybox defconfig
        cd ../obj/busybox
        make menuconfig

修改配置，使用静态编译，如果不使用静态编译，程序运行期间需要进行动态加载，则需在根文件系统中提供其所需的共享库。
    
    Location:                                                           
    -> Busybox Settings                                        
       -> Build Options     
          [*] Build BusyBox as a static binary (no shared libs)         
使用`make`进行编译，对于一些机器，可能会报如下的错误：

    networking/lib.a(inetd.o): In function `unregister_rpc':
    inetd.c:(.text.unregister_rpc+0x17): undefined reference to `pmap_unset'
    networking/lib.a(inetd.o): In function `register_rpc':
    inetd.c:(.text.register_rpc+0x56): undefined reference to `pmap_unset'
    inetd.c:(.text.register_rpc+0x72): undefined reference to `pmap_set'
    networking/lib.a(inetd.o): In function `prepare_socket_fd':
    inetd.c:(.text.prepare_socket_fd+0x7f): undefined reference to `bindresvport'
    collect2: ld returned 1 exit status
    make[2]: *** [busybox_unstripped] Error 1
    make[1]: *** [_all] Error 2
    make: *** [all] Error 2


观察上面的错误，可以发现问题出在`inetd.c`中有未定义的引用，在网上搜索一下答案，关闭配置当中的`inet`选项即可忽略该问题

        Location:                 
        -> Networking Utilities 
           [ ] inetd  
            
这时再执行`make`，就能生成`busybox`，执行`make install`生成`_install`目录
  
### 根文件系统制作

>**背景: [inittab相关知识](http://blog.csdn.net/kernel_32/article/details/3860756)**<br/>
>init进程是系统中所有进程的父进程，init进程繁衍出完成通常操作所需的子进程，这些操作包括:设置机器名、检查和安装磁盘及文件系统、启动系统日志、配置网络接口并启动网络和邮件服务，启动打印服务等。Solaris中init进程的主要任务是按照inittab文件所提供的信息创建进程，由于进行系统初始化的那些进程都由init创建，所以init进程也称为系统初始化进程。

拷贝`busybox/_install`中的内容，到`ramdisk`目录

    cd tiny_linux
    mkdir obj/ramdisk
    cd ramdisk
    cp -r ../busybox/_install/* ./

此时`ls -l`,我们可以看见如下的内容：

    total 12
    drwxr-xr-x 2 root root 4096 Jun 14 12:32 bin
    lrwxrwxrwx 1 root root   11 Jun 14 12:32 linuxrc -> bin/busybox
    drwxr-xr-x 2 root root 4096 Jun 14 12:32 sbin
    drwxr-xr-x 4 root root 4096 Jun 14 12:32 usr

是否发现它有点像linux系统的根目录，事实上他们就是一样的，因此我们需要补充上未创建的文件目录
    
    mkdir -pv {etc,proc,sys,dev}

>**背景: [inittab相关知识](http://blog.csdn.net/kernel_32/article/details/3860756)**<br/>
>init进程是系统中所有进程的父进程，init进程繁衍出完成通常操作所需的子进程，这些操作包括:设置机器名、检查和安装磁盘及文件系统、启动系统日志、配置网络接口并启动网络和邮件服务，启动打印服务等。由于进行系统初始化的那些进程都由init创建，所以init进程也称为系统初始化进程。

创建inittab
    
    cd ramdisk/etc
    vim inittab
    
在inittab进行如下配置：
    
    ::sysinit:/etc/init.d/rcS
    ::askfirst:-/bin/sh
    ::restart:/sbin/init
    ::ctrlaltdel:/sbin/reboot
    ::shutdown:/bin/umount -a -r
    ::shutdown:/sbin/swapoff -a

创建rcS

    cd ramdisk/etc
    mkdir init.d
    vim rcs

在rcS进行如下配置：
    
    #!/bin/sh
    mount proc
    mount -o remount,rw /
    mount -a
    
    clear                               
    echo "Booting Tiny Linux"
    
为rcS分配执行权限
    
    chmod +x rcS

创建fstab

    cd ramdisk/etc
    vim fstab
    
在fstab进行如下配置：

    # /etc/fstab
    proc            /proc        proc    defaults          0       0
    sysfs           /sys         sysfs   defaults          0       0
    devtmpfs        /dev         devtmpfs  defaults        0       0

生成ramdisk的镜像文件`initramfs.cpio.gz`

    cd ramdisk
    find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../obj/initramfs.cpio.gz

到目前为止，我们就可以使用qemu进行模拟运行了
    
    cd tiny_linux/obj
    qemu-system-x86_64 -kernel bzImage -initrd initramfs.cpio.gz

其中使用`-append "console=ttyS0" -nographic`能够让其在在文字模式下进行运行，`ctrl+a, x`退出qemu。

在虚拟的linux当中，你可以执行大部分常见的命令，比如：`ls`, `top`。当然也能创建文件等，`不过在你退出qemu的时候，这些改变并不会写回到根文件系统镜像当中`，原因很简单，运行的时候，只是将该镜像加载到内存当中运行，而这些所谓的改变，只是针对内存中已加载的根文件系统进行的修改操作，而这些并不会影响保留在磁盘上的内核镜像。
    
###网络配置及测试
在etc/rcS当中，增加如下配置：

    /sbin/ifconfig lo 127.0.0.1 up
    /sbin/route add 127.0.0.1 lo &
    ifconfig eth0 up
    ip addr add 10.0.2.15/24 dev eth0
    ip route add default via 10.0.2.2

通过该配置，就给模拟的linux设置IP地址等,使得tiny_linux与Host OS能够进行通信了。查看Qemu官方文档

>[Qemu Networking官方说明文档](http://wiki.qemu.org/Documentation/Networking)<br/>
Note - if you are using the (default) SLiRP user networking, then **ping (ICMP) will not work**, though TCP and UDP will. Don't try to use ping to test your QEMU network configuration!

这里是讲，如果使用qemu默认的网络，将无法使用`ping`进行网络测试，因此我们采用`wget`进行网络测试，以百度网页测试为例：
    
    / # wget www.baidu.com
    wget: bad address 'www.baidu.com'

发现无法解析域名，估计是DNS没有设置，为了简便，直接网上搜索百度的IP地址进行测试：`202.108.22.5`

    / # wget 202.108.22.5
    Connecting to 202.108.22.5 (202.108.22.5:80)
    index.html      100% |*******************************| 92768   0:00:00 ETA

下载网页成功，为确保下载的是百度搜索的首页，可以使用`vi index.html`，查看该html文件，你将发现有很多关键字`baidu`

由于采用这种方式，并不太直观，我们可以在Host OS中搭建一个http服务器，然后使用相同方式连接

    #创建http服务
    python2 -m SimpleHTTPServer
    
    #通过8000端口，下载host主机上的文件
    wget host_ip:8000/file

到这里，我们已经成功制作了根文件系统内核镜像，并且能够保证网络通信。

##Section 3：精简bzImage
    
在前面两个板块当中，我们分别制作了bzImage以及根文件系统镜像，这个版块，主要讲述我对bzImage精简的过程。在[杨海宇同学](https://github.com/ir193/tiny_linux/blob/master/NOTE.md)的文档中，他提供了x86的配置选项，而在使用的过程当中，发现无法启动，因此自己一步步对x86_64_defconfig进行了裁剪。

###编译选项优化
    
gcc在编译的过程当中，我们知道有`O1,O2,O3`等优化，能够一定程度的缩减程序最终的大小，因此，第一个想法是，从编译选项上进行优化，那么如何下手呢？最简单暴力的方式，在Makefile当中搜索'-O'选项，查看linux内核编译使用的如何优化的等级，然后你会发现：

    ifdef CONFIG_CC_OPTIMIZE_FOR_SIZE
    KBUILD_CFLAGS   += -Os $(call cc-disable-warning,maybe-uninitialized,)
    else
    KBUILD_CFLAGS   += -O2
    endif
    
原来config当中已经提供了该编译优化选项，在`make menuconfig`当中搜索一下：`optimize`

    Symbol: CC_OPTIMIZE_FOR_SIZE [=n]                            
    Type  : boolean                                              
    Prompt: Optimize for size                                    
    Location:                                                    
        (1) -> General setup       
    Defined at init/Kconfig:1290     

发现默认情况下，该优化选项是关闭的，果断开启这个选项。
bzImage的大小将从`6.5M`缩减为`5.1M`


### 步步精简config

看着config当中各种各样的选项，想必你与我一样，没有想到linux内核当中竟然有这么多可以配置的选项，而且对这些配置，都没有太多的概念，当时我采用的方式：一个大块大块的关闭，简单来说，在顶层配置当中，有诸如以下的选项：

     Processor type and features  --->
     Power management and ACPI options  --->
     Bus options (PCI etc.)  --->
     Executable file formats / Emulations  --->
     
稍微理解下表层的含义，关于处理器的配置，电源管理配置，总线配置等，对于感觉能够一定关闭的，通通进行关闭。然后进行编译，测试是否能够启动，能够正确进行网络通信。

最终你会发现，以下是你需要留下的选项，而其余模块的选项，都能通通关闭。
      
      [*] 64-bit kernel  
      General setup  --->      
      Bus options (PCI etc.)  ---> 
      [*] Networking support  --->
      Device Drivers  --->   

接下来就是进一步精简该选项当中的配置，围绕着`网络驱动，TCP/IP通信支持`，能够在网络设置、驱动设置当中去掉绝大部分的选项。

 >1. 在开启某一选项的过程中，会出现一些自动打开的选项，对于这些选项，也可以选择性进行关闭。


>2. 对于allnoconfig默认开启配置选项，也可以选择性进行关闭。

### 最小配置

**General setup**
 
    [*] Initial RAM filesystem and RAM disk (initramfs/initrd) support
        [*]   Support initial ramdisks compressed using gzip
    [*] Optimize for size 
    [*] Configure standard kernel features (expert users)  --->   


**Bus options**

    [*] PCI support  

**Networking support**

    [*] TCP/IP networking    

 **Device Drivers**
    
    [*] Network device support  --->  
        [*] Ethernet driver support  --->   
             [*] Intel devices
             [*] Intel(R) PRO/1000 Gigabit Ethernet support

     Character devices  ---> 
        [*] Enable TTY 
            Serial drivers  ---> 
            [*] 8250/16550 and compatible serial support
            [*]   Support 8250_core.* kernel options (DEPRECATED)
            [*]   Console on 8250/16550 and compatible serial port
            [*]   8250/16550 PCI device support
            (4)   Maximum number of 8250/16550 serial ports       
            (4)   Number of 8250/16550 serial ports to register at runtime 

具体可以参考`tiny_linx/configs/config_931K`,通过该配置，编译出来的bzImage大小只有931K，使用qemu启动的时候，注意需要采用`-append "console=ttyS0" -nographic`方式，才能正常加载。

##Section 4：Kernel Mode Linux
    
>Kernel Mode Linux 是一个让用户程序运行在内核模式下的技术。运行于内核模式下的应用可直接访问内核地址空间，与内核模块不同的是，用户程序跟一个正常进程一样，可像一般应用一样执行调度和paging。虽然看似危险，为确保内核的安全性，可通过静态类型检查，软件故障隔离等方法来防范。

###KML Patch
Kernel Mode Linux(KML)官网提供了KML的patch，通过给内核源码打上KML补丁，开启Kernel Mode Linux选项，重新编译内核，即可实现将用户进程在内核态进行执行。

下载KML Patch，更新内核源码，如果对patch的使用不熟悉，可以参考这篇文章[补丁(patch)的制作与应用](http://linux-wiki.cn/wiki/zh-hans/%E8%A1%A5%E4%B8%81%28patch%29%E7%9A%84%E5%88%B6%E4%BD%9C%E4%B8%8E%E5%BA%94%E7%94%A8)
    
    cd tiny_linux
    curl http://web.yl.is.s.u-tokyo.ac.jp/~tosh/kml/kml/for4.x/kml_4.0_001.diff.gz | gunzip > kml.patch
    cd linux-4.0.4
    patch -p1 < ../kml.patch
    
会出现如下错误提示：

    patching file CREDITS
    patching file Documentation/00-INDEX
    patching file Documentation/kml.txt
    patching file MAINTAINERS
    patching file Makefile
    Hunk #1 FAILED at 1.
    1 out of 1 hunk FAILED -- saving rejects to file Makefile.rej

查看`Makefile.rej`

    --- Makefile
    +++ Makefile
    @@ -1,7 +1,7 @@
     VERSION = 4
     PATCHLEVEL = 0
     SUBLEVEL = 0
    -EXTRAVERSION =
    +EXTRAVERSION = -kml
     NAME = Hurr durr I'ma sheep
    
     # *DOCUMENTATION*

在比对内核源码当中的`Makefile`文件,发现出现了版本号不匹配的问题，一种方式是修改Makefile，将SUBLEVEl修改为0，另一种方式修改kml.patch，将SUBLEVEL修改为4。

    patch -R -p1 < ../kml.patch   #取消之前打过的补丁
    patch -p1    < ../kml.patch
    
执行`make menuconfig`， 勾选上对应的选项
     
    Kernel Mode Linux  --->
    [*] Kernel Mode Linux           
    [*]   Check for chroot (NEW)      
        *** Safety check have not been implemented *** 

最后重新编译内核即可。


### 内核态运行busybox

根据KML的使用说明，只需创建`/trusted`目录，将需要执行的程序放在该目录下即可，因此我们需要对之前制作的ramdisk进行修改:
    
    cd ramdisk
    mkdir trusted
    mv bin/busybox /trusted
    ln -s /trusted/busybox /bin/busybox
    
因为`bin`目录下的其他命令均是符号链接在`bin/busybox`上，因此通过在`bin`目录下创建链接到`/trusted/busybox`的符号链接`busybox`,以最小的修改代价，完成了ramdisk的制作。
    
 

##参考资料

QEMU Networking
https://en.wikibooks.org/wiki/QEMU/Networking  

http://wiki.qemu.org/Documentation/Networking
