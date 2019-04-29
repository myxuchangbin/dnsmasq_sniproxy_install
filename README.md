# Install Dnsmasq + SNI proxy

* 脚本默认配置`Netflix`解锁，前提是能看`Netflix`的IP

* 添加更多解锁需要手动编辑配置文件`/etc/dnsmasq.d/custom_netflix.conf`和`/etc/sniproxy.conf`

* 脚本支持系统：CentOS 6+, Debian8+, Ubuntu16+
    * CentOS6/7 测试成功
    * Debian8+, Ubuntu16+ 测试成功

### 安装方法：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://github.com/myxuchangbin/dnsmasq_sniproxy_install/raw/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -i
```

### 卸载方法：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://github.com/myxuchangbin/dnsmasq_sniproxy_install/raw/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -u
```

### 使用方法
修改DNS地址修改为这个主机的IP，建议只保留一个DNS地址


___本脚本只用作解锁流媒体使用，不可用于FQ___