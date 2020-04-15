# Dnsmasq SNIproxy One-click Install

### 脚本说明：

* 原理简述：使用[Dnsmasq](http://thekelleys.org.uk/dnsmasq/doc.html)的DNS将网站解析劫持到[SNI proxy](https://github.com/dlundquist/sniproxy)反向代理的页面上。

* 用途：让无法观看流媒体的VPS可以观看（前提：VPS中要有一个是能观看流媒体的）。

* 特性：脚本默认解锁`Netflix Hulu HBO`[等](https://github.com/myxuchangbin/dnsmasq_sniproxy_install/blob/master/proxy-domains.txt)，如需增删流媒体域名请编辑文件`/etc/dnsmasq.d/custom_netflix.conf`和`/etc/sniproxy.conf`

* 脚本支持系统：CentOS6+, Debian8+, Ubuntu16+
    * CentOS6/7/8， Debian8/9/10, Ubuntu16/18 已测试成功
    * 理论上不限虚拟化类型，如有问题请反馈
    * 如果脚本最后显示的IP和实际公网IP不相符，请修改一下文件`/etc/sniproxy.conf`中的IP地址

### 脚本用法：

  bash dnsmasq_sniproxy.sh [-h] [-i] [-f] [-id] [-is] [-fs] [-u] [-ud] [-us]
    -h , --help                显示帮助信息
    -i , --install             安装 Dnsmasq + SNI Proxy
    -f , --fastinstall         快速安装 Dnsmasq + SNI Proxy
    -id, --installdnsmasq      仅安装 Dnsmasq
    -is, --installsniproxy     仅安装 SNI Proxy
    -fs, --fastinstallsniproxy 快速安装 SNI Proxy
    -u , --uninstall           卸载 Dnsmasq + SNI Proxy
    -ud, --undnsmasq           卸载 Dnsmasq
    -us, --unsniproxy          卸载 SNI Proxy

### 快速安装（推荐）：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -f
```

### 普通安装：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -i
```

### 卸载方法：
``` Bash
wget --no-check-certificate -O dnsmasq_sniproxy.sh https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/dnsmasq_sniproxy.sh && bash dnsmasq_sniproxy.sh -u
```

### 使用方法：
将代理VPS的DNS地址修改为这个主机的IP就可以了，如果不能用，记得只保留一个DNS地址试一下。

防止滥用，建议不要随意公布IP地址，或使用防火墙做好限制工作。

### 调试排错：
- 确认sniproxy有效运行

  查看sni状态：systemctl status sniproxy

  如果sni不在运行，检查一下是否有其他服务占用80,443端口，以防端口冲突，可将其其他服务更改一下监听端口，查看：netstat -tlunp|grep 443

- 确认防火墙放行80,443,53

  调试可直接关闭防火墙 systemctl stop firewalld.service

  阿里云/谷歌云/AWS等运营商安全组端口同样需要放行
  可通过其他服务器 telnet vpsip 53 以及 telnet vpsip 443 进行测试

- 解析域名

  尝试用其他服务器配置完毕dns后，解析域名：nslookup netflix.com 判断IP是否是NETFLIX代理机器IP
  如果不存在nslookup命令，CENTOS安装：yum install -y bind-utils DEBIAN安装：apt-get -y install dnsutils

---

___本脚本仅限解锁流媒体使用___
