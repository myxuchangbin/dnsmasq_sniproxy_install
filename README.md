# Dnsmasq SNIproxy One-click Install

### 脚本说明：

* 原理简述：使用[Dnsmasq](http://thekelleys.org.uk/dnsmasq/doc.html)的DNS将网站解析劫持到[SNI proxy](https://github.com/dlundquist/sniproxy)反向代理的页面上。

* 用途：让不能看流媒体的VPS看上流媒体（前提：VPS中要有一个是能看流媒体的）。

* 特性：脚本默认解锁`Netflix Hulu HBO`[等](https://github.com/myxuchangbin/dnsmasq_sniproxy_install/blob/master/proxy-domains.txt)，如需增删流媒体域名请编辑文件`/etc/dnsmasq.d/custom_netflix.conf`和`/etc/sniproxy.conf`

* 脚本支持系统：CentOS6+, Debian8+, Ubuntu16+
    * CentOS6/7， Debian8/9/10, Ubuntu16/18 已测试成功
	* 理论上不限虚拟化类型，如有问题请反馈
    * 如果脚本最后显示的IP和实际公网IP不相符，请修改一下文件`/etc/sniproxy.conf`中的IP地址

### 安装方法：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/wulimaxh/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -i
```

### 卸载方法：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/wulimaxh/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -u
```

### 使用方法：
将代理VPS的DNS地址修改为这个主机的IP就可以了，如果不能用，记得只保留一个DNS地址试一下。

防止滥用，建议不要随意公布IP地址，或使用防火墙做好限制工作。

---

___本脚本仅限解锁流媒体使用___
