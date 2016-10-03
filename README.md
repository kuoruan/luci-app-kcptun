# luci-app-kcptun
Luci support for kcptun

OpenWrt 上的 Kcptun Luci 支持界面

## 编译说明

```
cd openwrt
rm -rf tmp/
cd feeds/luci/application
git clone https://github.com/kuoruan/luci-app-kcptun.git

cd -
./scripts/feeds update -a
./scripts/feeds install -a
make menuconfig
make package/luci-app-kcptun/compile
```

截图：[https://blog.kuoruan.com/113.html](https://blog.kuoruan.com/113.html)
