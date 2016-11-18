# luci-app-kcptun
Luci support for kcptun

OpenWrt 上的 Kcptun Luci 支持界面

## 编译说明

```
cd openwrt
git clone https://github.com/kuoruan/luci-app-kcptun.git feeds/luci/applications/luci-app-kcptun
rm -rf tmp/

./scripts/feeds update -a
./scripts/feeds install -a

make menuconfig
make package/luci-app-kcptun/compile
```

## 安装说明

1. 根据 OpenWrt 固件版本下载 luci-app-kcptun 和 luci-i18n-kcptun-zh-cn (如果你不清楚你的 OpenWrt 固件版本, 请统一下载 chaos-calmer 版)
2. 将下载好的 ipk 文件上传到 OpenWrt 目录下, 如 /tmp 目录
3. 使用 shell 登陆路由器, 切换到上传目录下, 先安装 luci-app-kcptun 再安装 luci-i18n-kcptun-zh-cn

```
opkg install luci-app-kcptun_*.ipk
opkg install luci-i18n-kcptun-zh-cn_*.ipk
```

安装好 luci 之后需要下载路由器对应版本的 Kcptun 客户端文件, 下载之后上传到路由器上任意目录(如: /usr/bin/kcptun)

之后到 luci 中配置好客户端或路径即可使用, 若提示不是 Kcptun 文件, 说明所下载的客户端文件不适合当前路由器, 请重新下载

## Kcptun 客户端

下载地址: https://github.com/xtaci/kcptun/releases

ar71xx ramips 可以到这里下载 https://github.com/bettermanbao/openwrt-kcptun/releases

## 卸载说明

卸载时需要先卸载 luci-i18n-kcptun-zh-cn, 再卸载 luci-app-kcptun

```
opkg remove luci-i18n-kcptun-zh-cn
opkg remove luci-app-kcptun
```

## 错误说明

由于 designated-driver 版中使用了一个新的 post 函数, 可能会出现找不到该函数而报错：

```
/usr/lib/lua/luci/controller/kcptun.lua:41: attempt to call global 'post' (a nil value)
stack traceback:
	/usr/lib/lua/luci/controller/kcptun.lua:41: in function 'e'
	/usr/lib/lua/luci/dispatcher.lua:444: in function 'createtree'
	/usr/lib/lua/luci/dispatcher.lua:160: in function 'dispatch'
	/usr/lib/lua/luci/dispatcher.lua:135: in function </usr/lib/lua/luci/dispatcher.lua:134>
```

出现这种情况时，先卸载掉 designated-driver 版, 下载 chaos-calmer 版重新安装

截图：[https://blog.kuoruan.com/113.html](https://blog.kuoruan.com/113.html)
