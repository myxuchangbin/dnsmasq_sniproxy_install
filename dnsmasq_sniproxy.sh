#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] 请使用root用户来执行脚本!" && exit 1

disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    echo ${IP}
}

check_ip(){
    local checkip=$1   
    local valid_check=$(echo $checkip|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')   
    if echo $checkip|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" >/dev/null; then   
        if [ ${valid_check:-no} == "yes" ]; then   
            return 0   
        else   
            echo -e "[${red}Error${plain}] IP $checkip not available!"   
            return 1   
        fi   
    else   
        echo -e "[${red}Error${plain}] IP format error!"   
        return 1   
    fi
}

download(){
    local filename=${1}
    echo -e "[${green}Info${plain}] ${filename} download configuration now..."
    wget --no-check-certificate -q -t3 -T60 -O ${1} ${2}
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Download ${filename} failed."
        exit 1
    fi
}

error_detect_depends(){
    local command=$1
    local depend=`echo "${command}" | awk '{print $4}'`
    echo -e "[${green}Info${plain}] Starting to install package ${depend}"
    ${command} > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Failed to install ${red}${depend}${plain}"
        exit 1
    fi
}

config_firewall(){
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            for port in ${ports}; do
                iptables -L -n | grep -i ${port} > /dev/null 2>&1
                if [ $? -ne 0 ]; then
                    iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${port} -j ACCEPT
                    if [ ${port} == "53" ]; then
                        iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${port} -j ACCEPT
                    fi
                else
                    echo -e "[${green}Info${plain}] port ${green}${port}${plain} already be enabled."
                fi
            done
            /etc/init.d/iptables save
            /etc/init.d/iptables restart
        else
            echo -e "[${yellow}Warning${plain}] iptables looks like not running or not installed, please enable port ${ports} manually if necessary."
        fi
    else
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            default_zone=$(firewall-cmd --get-default-zone)
            for port in ${ports}; do
                firewall-cmd --permanent --zone=${default_zone} --add-port=${port}/tcp
                if [ ${port} == "53" ]; then
                    firewall-cmd --permanent --zone=${default_zone} --add-port=${port}/udp
                fi
                firewall-cmd --reload
            done
        else
            echo -e "[${yellow}Warning${plain}] firewalld looks like not running or not installed, please enable port ${ports} manually if necessary."
        fi
    fi
}

install_dependencies(){
    echo "安装依赖软件..."
    if check_sys packageManager yum; then
        echo -e "[${green}Info${plain}] Checking the EPEL repository..."
        if [ ! -f /etc/yum.repos.d/epel.repo ]; then
            yum install -y epel-release > /dev/null 2>&1
        fi
        [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] Install EPEL repository failed, please check it." && exit 1
        [ ! "$(command -v yum-config-manager)" ] && yum install -y yum-utils > /dev/null 2>&1
        [ x"$(yum repolist epel | grep -w epel | awk '{print $NF}')" != x"enabled" ] && yum-config-manager --enable epel > /dev/null 2>&1
        echo -e "[${green}Info${plain}] Checking the EPEL repository complete..."

        if [[ ${fastmode} = "1" ]]; then
            yum_depends=(
                curl gettext-devel libev-devel pcre-devel perl udns-devel
            )
        else
            yum_depends=(
                autoconf automake curl gettext-devel libev-devel pcre-devel perl udns-devel
            )
        fi
        for depend in ${yum_depends[@]}; do
            error_detect_depends "yum -y install ${depend}"
        done
        if [[ ${fastmode} = "0" ]]; then
            if centosversion 6; then
                error_detect_depends "yum -y groupinstall development"
                error_detect_depends "yum -y install centos-release-scl"
                error_detect_depends "yum -y install devtoolset-6-gcc-c++"
            else
                yum config-manager --set-enabled powertools
                yum groups list development | grep Installed > /dev/null 2>&1
                if [[ $? -eq 0 ]]; then
                    yum groups mark remove development -y > /dev/null 2>&1
                fi
                error_detect_depends "yum -y groupinstall development"
            fi
        fi
    elif check_sys packageManager apt; then
        if [[ ${fastmode} = "1" ]]; then
            apt_depends=(
                curl gettext libev-dev libpcre3-dev libudns-dev
            )
        else
            apt_depends=(
                autotools-dev cdbs curl gettext libev-dev libpcre3-dev libudns-dev autoconf devscripts
            )
        fi
        apt-get -y update
        for depend in ${apt_depends[@]}; do
            error_detect_depends "apt-get -y install ${depend}"
        done
        if [[ ${fastmode} = "0" ]]; then
            error_detect_depends "apt-get -y install build-essential"
        fi
    fi
}

compile_dnsmasq(){
    if check_sys packageManager yum; then
        error_detect_depends "yum -y install epel-release"
        error_detect_depends "yum -y install make"
        error_detect_depends "yum -y install gcc-c++"
        error_detect_depends "yum -y install nettle-devel"
        error_detect_depends "yum -y install gettext"
        error_detect_depends "yum -y install libidn-devel"
        #error_detect_depends "yum -y install libidn2-devel"
        error_detect_depends "yum -y install libnetfilter_conntrack-devel"
        error_detect_depends "yum -y install dbus-devel"
    elif check_sys packageManager apt; then
        error_detect_depends "apt -y install make"
        error_detect_depends "apt -y install gcc"
        error_detect_depends "apt -y install g++"
        error_detect_depends "apt -y install pkg-config"
        error_detect_depends "apt -y install nettle-dev"
        error_detect_depends "apt -y install gettext"
        error_detect_depends "apt -y install libidn11-dev"
        #error_detect_depends "apt -y install libidn2-dev"
        error_detect_depends "apt -y install libnetfilter-conntrack-dev"
        error_detect_depends "apt -y install libdbus-1-dev"
    fi
    if [ -e /tmp/dnsmasq-2.91 ]; then
        rm -rf /tmp/dnsmasq-2.91
    fi
    cd /tmp/
    download dnsmasq-2.91.tar.gz https://thekelleys.org.uk/dnsmasq/dnsmasq-2.91.tar.gz
    tar -zxf dnsmasq-2.91.tar.gz
    cd dnsmasq-2.91
    make all-i18n V=s COPTS='-DHAVE_DNSSEC -DHAVE_IDN -DHAVE_CONNTRACK -DHAVE_DBUS'
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] dnsmasq upgrade failed."
        rm -rf /tmp/dnsmasq-2.91 /tmp/dnsmasq-2.91.tar.gz
        exit 1
    fi
}

install_dnsmasq(){
    netstat -a -n -p | grep LISTEN | grep -P "\d+\.\d+\.\d+\.\d+:53\s+" > /dev/null && echo -e "[${red}Error${plain}] required port 53 already in use\n" && exit 1
    echo "安装Dnsmasq..."
    if check_sys packageManager yum; then
        error_detect_depends "yum -y install dnsmasq"
        if centosversion 6; then
            compile_dnsmasq
            yes|cp -f /tmp/dnsmasq-2.91/src/dnsmasq /usr/sbin/dnsmasq && chmod +x /usr/sbin/dnsmasq
        fi
    elif check_sys packageManager apt; then
        error_detect_depends "apt -y install dnsmasq"
    fi
    if [[ ${fastmode} = "0" ]]; then
        compile_dnsmasq
        yes|cp -f /tmp/dnsmasq-2.91/src/dnsmasq /usr/sbin/dnsmasq && chmod +x /usr/sbin/dnsmasq
    fi
    [ ! -f /usr/sbin/dnsmasq ] && echo -e "[${red}Error${plain}] 安装dnsmasq出现问题，请检查." && exit 1
    download /etc/dnsmasq.d/custom_netflix.conf https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/dnsmasq.conf
    download /tmp/proxy-domains.txt https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/proxy-domains.txt
    for domain in $(cat /tmp/proxy-domains.txt); do
        printf "address=/${domain}/${publicip}\n"\
        | tee -a /etc/dnsmasq.d/custom_netflix.conf > /dev/null 2>&1
    done
    [ "$(grep -x -E "(conf-dir=/etc/dnsmasq.d|conf-dir=/etc/dnsmasq.d,.bak|conf-dir=/etc/dnsmasq.d/,\*.conf|conf-dir=/etc/dnsmasq.d,.rpmnew,.rpmsave,.rpmorig)" /etc/dnsmasq.conf)" ] || echo -e "\nconf-dir=/etc/dnsmasq.d" >> /etc/dnsmasq.conf
    echo "启动 Dnsmasq 服务..."
    if check_sys packageManager yum; then
        if centosversion 6; then
            chkconfig dnsmasq on
            service dnsmasq start
        else
            systemctl enable dnsmasq
            systemctl start dnsmasq
        fi
    elif check_sys packageManager apt; then
        if grep -q "^#IGNORE_RESOLVCONF=yes" /etc/default/dnsmasq; then
            sed -i 's/^#IGNORE_RESOLVCONF=yes/IGNORE_RESOLVCONF=yes/' /etc/default/dnsmasq
        elif ! grep -q "^IGNORE_RESOLVCONF=yes" /etc/default/dnsmasq; then
            echo "IGNORE_RESOLVCONF=yes" >> /etc/default/dnsmasq
        fi
        systemctl enable dnsmasq
        systemctl restart dnsmasq
    fi
    cd /tmp
    rm -rf /tmp/dnsmasq-2.91 /tmp/dnsmasq-2.91.tar.gz /tmp/proxy-domains.txt
    echo -e "[${green}Info${plain}] dnsmasq install complete..."
}

install_sniproxy(){
    for aport in 80 443; do
        netstat -a -n -p | grep LISTEN | grep -P "\d+\.\d+\.\d+\.\d+:${aport}\s+" > /dev/null && echo -e "[${red}Error${plain}] required port ${aport} already in use\n" && exit 1
    done
    install_dependencies
    echo "安装SNI Proxy..."
    if check_sys packageManager yum; then
        rpm -qa | grep sniproxy >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            rpm -e sniproxy
        fi
    elif check_sys packageManager apt; then
        dpkg -s sniproxy >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            dpkg -r sniproxy
        fi
    fi
    bit=`uname -m`
    cd /tmp
    if [[ ${fastmode} = "0" ]]; then
        if [ -e sniproxy-0.6.1 ]; then
            rm -rf sniproxy-0.6.1
        fi
        download /tmp/sniproxy-0.6.1.tar.gz https://github.com/dlundquist/sniproxy/archive/refs/tags/0.6.1.tar.gz
        tar -zxf sniproxy-0.6.1.tar.gz
        cd sniproxy-0.6.1
    fi
    if check_sys packageManager yum; then
        if [[ ${fastmode} = "1" ]]; then
            if [[ ${bit} = "x86_64" ]]; then
                download /tmp/sniproxy-0.6.1-1.el8.x86_64.rpm https://github.com/myxuchangbin/dnsmasq_sniproxy_install/raw/master/sniproxy/sniproxy-0.6.1-1.el8.x86_64.rpm
                error_detect_depends "yum -y install /tmp/sniproxy-0.6.1-1.el8.x86_64.rpm"
                rm -f /tmp/sniproxy-0.6.1-1.el8.x86_64.rpm
            else
                echo -e "${red}暂不支持${bit}内核，请使用编译模式安装！${plain}" && exit 1
            fi
        else
            if centosversion 6; then
                ./autogen.sh && ./configure && make dist
                scl enable devtoolset-6 'rpmbuild --define "_sourcedir `pwd`" --define "_topdir /tmp/sniproxy/rpmbuild" --define "debug_package %{nil}" -ba redhat/sniproxy.spec'
                error_detect_depends "yum -y install /tmp/sniproxy/rpmbuild/RPMS/x86_64/sniproxy-*.rpm"
            else
                ./autogen.sh && ./configure --prefix=/usr && make && make install
            fi
        fi
        if centosversion 6; then
            download /etc/init.d/sniproxy https://raw.githubusercontent.com/dlundquist/sniproxy/master/redhat/sniproxy.init && chmod +x /etc/init.d/sniproxy
            [ ! -f /etc/init.d/sniproxy ] && echo -e "[${red}Error${plain}] 下载Sniproxy启动文件出现问题，请检查." && exit 1
        else
            download /etc/systemd/system/sniproxy.service https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/sniproxy.service
            systemctl daemon-reload
            [ ! -f /etc/systemd/system/sniproxy.service ] && echo -e "[${red}Error${plain}] 下载Sniproxy启动文件出现问题，请检查." && exit 1
        fi
    elif check_sys packageManager apt; then
        if [[ ${fastmode} = "1" ]]; then
            if [[ ${bit} = "x86_64" ]]; then
                download /tmp/sniproxy_0.6.1_amd64.deb https://github.com/myxuchangbin/dnsmasq_sniproxy_install/raw/master/sniproxy/sniproxy_0.6.1_amd64.deb
                error_detect_depends "dpkg -i --no-debsig /tmp/sniproxy_0.6.1_amd64.deb"
                rm -f /tmp/sniproxy_0.6.1_amd64.deb
            else
                echo -e "${red}暂不支持${bit}内核，请使用编译模式安装！${plain}" && exit 1
            fi
        else
            env NAME="sniproxy" DEBFULLNAME="sniproxy" DEBEMAIL="sniproxy@example.com" EMAIL="sniproxy@example.com" ./autogen.sh && ./configure --prefix=/usr && make && make install
        fi  
        download /etc/systemd/system/sniproxy.service https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/sniproxy.service
        systemctl daemon-reload
        [ ! -f /etc/systemd/system/sniproxy.service ] && echo -e "[${red}Error${plain}] 下载Sniproxy启动文件出现问题，请检查." && exit 1
    fi
    [ ! -f /usr/sbin/sniproxy ] && echo -e "[${red}Error${plain}] 安装Sniproxy出现问题，请检查." && exit 1
    download /etc/sniproxy.conf https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/sniproxy.conf
    download /tmp/sniproxy-domains.txt https://raw.githubusercontent.com/myxuchangbin/dnsmasq_sniproxy_install/master/proxy-domains.txt
    sed -i -e 's/\./\\\./g' -e 's/^/    \.\*/' -e 's/$/\$ \*/' /tmp/sniproxy-domains.txt || (echo -e "[${red}Error:${plain}] Failed to configuration sniproxy." && exit 1)
    sed -i '/table {/r /tmp/sniproxy-domains.txt' /etc/sniproxy.conf || (echo -e "[${red}Error:${plain}] Failed to configuration sniproxy." && exit 1)
    if [ ! -e /var/log/sniproxy ]; then
        mkdir /var/log/sniproxy
    fi
    echo "启动 SNI Proxy 服务..."
    if check_sys packageManager yum; then
        if centosversion 6; then
            chkconfig sniproxy on > /dev/null 2>&1
            service sniproxy start || (echo -e "[${red}Error:${plain}] Failed to start sniproxy." && exit 1)
        else
            systemctl enable sniproxy > /dev/null 2>&1
            systemctl start sniproxy || (echo -e "[${red}Error:${plain}] Failed to start sniproxy." && exit 1)
        fi
    elif check_sys packageManager apt; then
        systemctl enable sniproxy > /dev/null 2>&1
        systemctl restart sniproxy || (echo -e "[${red}Error:${plain}] Failed to start sniproxy." && exit 1)
    fi
    cd /tmp
    rm -rf /tmp/sniproxy-0.6.1/
    rm -rf /tmp/sniproxy-domains.txt
    echo -e "[${green}Info${plain}] sniproxy install complete..."
}

install_check(){
    if check_sys packageManager yum || check_sys packageManager apt; then
        if centosversion 5; then
            return 1
        fi
        return 0
    else
        return 1
    fi
}

ready_install(){
    echo "检测您的系统..."
    if ! install_check; then
        echo -e "[${red}Error${plain}] Your OS is not supported to run it!"
        echo -e "Please change to CentOS 6+/Debian 8+/Ubuntu 16+ and try again."
        exit 1
    fi
    if check_sys packageManager yum; then
        yum makecache
        error_detect_depends "yum -y install net-tools"
        error_detect_depends "yum -y install wget"
    elif check_sys packageManager apt; then
        apt update
        error_detect_depends "apt-get -y install net-tools"
        error_detect_depends "apt-get -y install wget"
    fi
    disable_selinux
    if check_sys packageManager yum; then
        config_firewall
    fi
    echo -e "[${green}Info${plain}] Checking the system complete..."
}

hello(){
    echo ""
    echo -e "${yellow}Dnsmasq + SNI Proxy自助安装脚本${plain}"
    echo -e "${yellow}支持系统:  CentOS 6+, Debian8+, Ubuntu16+${plain}"
    echo ""
}

help(){
    hello
    echo "使用方法：bash $0 [-h] [-i] [-f] [-id] [-fd] [-is] [-fs] [-u] [-ud] [-us]"
    echo ""
    echo "  -h , --help                显示帮助信息"
    echo "  -i , --install             安装 Dnsmasq + SNI Proxy"
    echo "  -f , --fastinstall         快速安装 Dnsmasq + SNI Proxy"
    echo "  -id, --installdnsmasq      仅安装 Dnsmasq"
    echo "  -id, --installdnsmasq      快速安装 Dnsmasq"
    echo "  -is, --installsniproxy     仅安装 SNI Proxy"
    echo "  -fs, --fastinstallsniproxy 快速安装 SNI Proxy"
    echo "  -u , --uninstall           卸载 Dnsmasq + SNI Proxy"
    echo "  -ud, --undnsmasq           卸载 Dnsmasq"
    echo "  -us, --unsniproxy          卸载 SNI Proxy"
    echo ""
}

install_all(){
    ports="53 80 443"
    publicip=$(get_ip)
    hello
    ready_install
    install_dnsmasq
    install_sniproxy
    echo ""
    echo -e "${yellow}Dnsmasq + SNI Proxy 已完成安装！${plain}"
    echo ""
    echo -e "${yellow}将您的DNS更改为 $(get_ip) 即可以观看Netflix节目了。${plain}"
    echo ""
}

only_dnsmasq(){
    ports="53"
    hello
    ready_install
    inputipcount=1
    echo -e "请输入SNIProxy服务器的IP地址"
    read -e -p "(为空则自动获取公网IP): " inputip
    while true; do
        if [ "${inputipcount}" == 3 ]; then
            echo -e "[${red}Error:${plain}] IP输入错误次数过多，请重新执行脚本。"
            exit 1
        fi
        if [ -z ${inputip} ]; then
            publicip=$(get_ip)
            break
        else
            check_ip ${inputip}
            if [ $? -eq 0 ]; then
                publicip=${inputip}
                break
            else
                echo -e "请重新输入SNIProxy服务器的IP地址"
                read -e -p "(为空则自动获取公网IP): " inputip
            fi
        fi
        inputipcount=`expr ${inputipcount} + 1`
    done
    install_dnsmasq
    echo ""
    echo -e "${yellow}Dnsmasq 已完成安装！${plain}"
    echo ""
    echo -e "${yellow}将您的DNS更改为 $(get_ip) 即可以观看Netflix节目了。${plain}"
    echo ""
}

only_sniproxy(){
    ports="80 443"
    hello
    ready_install
    install_sniproxy
    echo ""
    echo -e "${yellow}SNI Proxy 已完成安装！${plain}"
    echo ""
    echo -e "${yellow}将Netflix的相关域名解析到 $(get_ip) 即可以观看Netflix节目了。${plain}"
    echo ""
}

undnsmasq(){
    echo -e "[${green}Info${plain}] Stoping dnsmasq services."
    if check_sys packageManager yum; then
        if centosversion 6; then
            chkconfig dnsmasq off > /dev/null 2>&1
            service dnsmasq stop || echo -e "[${red}Error:${plain}] Failed to stop dnsmasq."
        else
            systemctl disable dnsmasq > /dev/null 2>&1
            systemctl stop dnsmasq || echo -e "[${red}Error:${plain}] Failed to stop dnsmasq."
        fi
    elif check_sys packageManager apt; then
        systemctl disable dnsmasq > /dev/null 2>&1
        systemctl stop dnsmasq || echo -e "[${red}Error:${plain}] Failed to stop dnsmasq."
    fi
    echo -e "[${green}Info${plain}] Starting to uninstall dnsmasq services."
    if check_sys packageManager yum; then
        yum remove dnsmasq -y > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] Failed to uninstall ${red}dnsmasq${plain}"
        fi
    elif check_sys packageManager apt; then
        apt-get remove dnsmasq -y > /dev/null 2>&1
        apt-get remove dnsmasq-base -y > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] Failed to uninstall ${red}dnsmasq${plain}"
        fi
    fi
    rm -rf /etc/dnsmasq.d/custom_netflix.conf
    echo -e "[${green}Info${plain}] services uninstall dnsmasq complete..."
}

unsniproxy(){
    echo -e "[${green}Info${plain}] Stoping sniproxy services."
    if check_sys packageManager yum; then
        if centosversion 6; then
            chkconfig sniproxy off > /dev/null 2>&1
            service sniproxy stop || echo -e "[${red}Error:${plain}] Failed to stop sniproxy."
        else
            systemctl disable sniproxy > /dev/null 2>&1
            systemctl stop sniproxy || echo -e "[${red}Error:${plain}] Failed to stop sniproxy."
        fi
    elif check_sys packageManager apt; then
        systemctl disable sniproxy > /dev/null 2>&1
        systemctl stop sniproxy || echo -e "[${red}Error:${plain}] Failed to stop sniproxy."
    fi
    echo -e "[${green}Info${plain}] Starting to uninstall sniproxy services."
    if check_sys packageManager yum; then
        yum remove sniproxy -y > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] Failed to uninstall ${red}sniproxy${plain}"
        fi
    elif check_sys packageManager apt; then
        apt-get remove sniproxy -y > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] Failed to uninstall ${red}sniproxy${plain}"
        fi
    fi
    rm -rf /etc/sniproxy.conf
    echo -e "[${green}Info${plain}] services uninstall sniproxy complete..."
}

confirm(){
    echo -e "${yellow}是否继续执行?(n:取消/y:继续)${plain}"
    read -e -p "(默认:取消): " selection
    [ -z "${selection}" ] && selection="n"
    if [ ${selection} != "y" ]; then
        exit 0
    fi
}

if [[ $# = 1 ]];then
    key="$1"
    case $key in
        -i|--install)
        fastmode=0
        install_all
        ;;
        -f|--fastinstall)
        fastmode=1
        install_all
        ;;
        -id|--installdnsmasq)
        fastmode=0
        only_dnsmasq
        ;;
        -fd|--fastinstalldnsmasq)
        fastmode=1
        only_dnsmasq
        ;;
        -is|--installsniproxy)
        fastmode=0
        only_sniproxy
        ;;
        -fs|--fastinstallsniproxy)
        fastmode=1
        only_sniproxy
        ;;
        -u|--uninstall)
        hello
        echo -e "${yellow}正在执行卸载Dnsmasq和SNI Proxy.${plain}"
        confirm
        undnsmasq
        unsniproxy
        ;;
        -ud|--undnsmasq)
        hello
        echo -e "${yellow}正在执行卸载Dnsmasq.${plain}"
        confirm
        undnsmasq
        ;;
        -us|--unsniproxy)
        hello
        echo -e "${yellow}正在执行卸载SNI Proxy.${plain}"
        confirm
        unsniproxy
        ;;
        -h|--help|*)
        help
        ;;
    esac
else
    help
fi
