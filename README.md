# Install Dnsmasq + SNI proxy

* 脚本默认自动配置`Netflix`解锁，前提是有一个能看`Netflix`的IP

* 如需添加更多解锁可手动编辑配置文件`/etc/dnsmasq.d/custom_netflix.conf`和`/etc/sniproxy.conf`

* 脚本支持系统：CentOS 6+, Debian8+, Ubuntu16+
    * CentOS6/7 测试成功
    * Debian8+, Ubuntu16+ 待测试

### 安装方法：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://github.com/myxuchangbin/dnsmasq_sniproxy_install/raw/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -i
```

### 卸载方法：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://github.com/myxuchangbin/dnsmasq_sniproxy_install/raw/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -u
```
