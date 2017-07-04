# luci-app-kcptun
Luci support for kcptun

OpenWrt/LEDE 上的 Kcptun Luci 支持界面

## 编译说明

由于目录结构原因，无法使用 OpenWrt/LEDE 的 SDK 直接编译。
需要下载 OpenWrt/LEDE 的完整源码 https://github.com/lede-project/source
并将 luci-app-kcptun 放入 ```feeds/luci/applications/``` 目录下。

```
cd openwrt
git clone https://github.com/kuoruan/luci-app-kcptun.git feeds/luci/applications/luci-app-kcptun
rm -rf tmp/

./scripts/feeds update luci
./scripts/feeds install luci

make menuconfig
make package/luci-app-kcptun/compile V=s
```

如果需要在 SDK 上编译，需要自行修改目录结构。参考：https://github.com/shadowsocks/luci-app-shadowsocks

## 安装说明

1. 到 [release](https://github.com/kuoruan/luci-app-kcptun/releases) 页面下载最新版 luci-app-kcptun 和 luci-i18n-kcptun-zh-cn (简体中文翻译文件)
2. 将下载好的 ipk 文件上传到路由器任意目录下, 如 /tmp
3. 先安装 luci-app-kcptun 再安装 luci-i18n-kcptun-zh-cn

```
opkg install luci-app-kcptun_*.ipk
opkg install luci-i18n-kcptun-zh-cn_*.ipk
```

安装好 LuCI 之后需要下载路由器对应版本的 Kcptun 客户端文件, 上传到路由器上任意目录 (如: /usr/bin/kcptun)

下载地址: https://github.com/xtaci/kcptun/releases

之后到 LuCI 中配置好客户端或路径即可使用, 若提示不是 Kcptun 文件, 说明所下载的客户端文件不适合当前路由器, 请重新下载

## 卸载说明

卸载时需要先卸载 luci-i18n-kcptun-zh-cn, 再卸载 luci-app-kcptun

```
opkg remove luci-i18n-kcptun-zh-cn
opkg remove luci-app-kcptun
```
