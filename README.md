# Install Dnsmasq + SNI proxy

* 脚本默认配置`Netflix`解锁，前提是能看`Netflix`的IP

* 添加更多解锁需要手动编辑配置文件`/etc/dnsmasq.d/custom_netflix.conf`和`/etc/sniproxy.conf`

* 脚本支持系统：CentOS 6+, Debian8+, Ubuntu16+
    * CentOS6/7 测试成功
    * Debian8+, Ubuntu16+ 测试成功
    * 如果脚本最后显示的IP和实际IP不相符，请手动修改一下文件`/etc/sniproxy.conf`中的IP地址

### 安装方法：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://github.com/myxuchangbin/dnsmasq_sniproxy_install/raw/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -i
```

### 卸载方法：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://github.com/myxuchangbin/dnsmasq_sniproxy_install/raw/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -u
```

### 使用方法
将代理vps的DNS地址修改为这个主机的IP即可，如果不能用，只保留一个DNS试一下。

为防止滥用，建议不要随意公布IP地址；或者使用防火墙来限制外部IP访问。

---
___本脚本只用作解锁流媒体使用，不能用来FQ。___
