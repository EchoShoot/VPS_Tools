# Tools

One of the easiest way to install SSR(ShadowsocksR) or WG(WireGuard) on your VPS.

SSR Client
------
SSR Client
* [download for Windows](https://github.com/EchoShoot/tools/releases/download/v1.0/ShadowsocksR-4.7.0-win.7z)
* [download for Android](https://github.com/EchoShoot/tools/releases/download/v1.0/shadowsocksr-release.apk)
* [download for MacOS](https://github.com/EchoShoot/tools/releases/download/v1.0/ShadowsocksX-NG-R8.dmg)

WG Client (Platform: OSX)
```Shell
$ /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
$ brew install wireguard-tools
$ mkdir /usr/local/etc/wireguard/
$ cat > /usr/local/etc/wireguard/wg0.conf << !
  heredoc> {please run "cat /etc/wireguard/client.conf" on your vps and copy to here, AFTER "wg.sh" was installed}
  heredoc> !
$ sudo wg-quick up wg0
```

VPS Script
------
* [wg.sh](#wgsh) - auto install WireGuard
* [ssr.sh](#ssrsh) - auto install ShadowsocksR
* [bbr.sh](#bbrsh) - auto install TCP BBR

wg.sh
------
Auto Install WireGuard Server only for Debian 9

Easy way:
```Shell
  $ bash <(wget -O- http://tools.tisrop.com/wg.sh)
```

Or by this way:
```Shell
  $ bash <(curl http://tools.tisrop.com/wg.sh)
```

ssr.sh
------
Auto Install ShadowsocksR Server for CentOS/Debian/Ubuntu

Easy way:
```Shell
  $ bash <(wget -O- http://tools.tisrop.com/ssr.sh)
```

Or by this way:
```Shell
  $ bash <(curl http://tools.tisrop.com/ssr.sh)
```

bbr.sh
------
Auto install latest kernel for TCP BBR (It is default supported on Debian 9.0+)

Easy way:
```Shell
  $ bash <(wget -O- http://tools.tisrop.com/bbr.sh)
```

Or by this way:
```Shell
  $ bash <(curl http://tools.tisrop.com/bbr.sh)
```
