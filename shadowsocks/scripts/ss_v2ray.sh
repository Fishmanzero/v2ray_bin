#!/bin/sh

# shadowsocks script for AM380 merlin firmware
# by sadog (sadoneli@gmail.com) from koolshare.cn

eval `dbus export ss`
source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
V2RAY_CONFIG_FILE="/koolshare/ss/v2ray.json"
#url_main="https://raw.githubusercontent.com/hq450/fancyss/master/v2ray_binary"
url_main="https://raw.githubusercontent.com/cary-sas/v2ray_bin/main/380_armv5/v2ray"
url_back=""
socksopen_b=`netstat -nlp|grep -w 23456|grep -E "local|v2ray|xray|trojan-go"`
if [ -n "$socksopen_b" ] && [ "$ss_basic_online_links_goss" == "1" ];then
	echo_date "代理有开启，将使用代理网络..."
	alias curlxx='curl --connect-timeout 8  --socks5-hostname 127.0.0.1:23456 '
else
	echo_date "使用常规网络下载..."
	alias curlxx='curl --connect-timeout 8 '
fi

get_latest_version(){
	rm -rf /tmp/v2ray_latest_info.txt
	echo_date "检测V2Ray最新版本..."
	curlxx $url_main/latest.txt > /tmp/v2ray_latest_info.txt
	if [ "$?" == "0" ];then
		if [ -z "`cat /tmp/v2ray_latest_info.txt`" ];then
			echo_date "获取V2Ray最新版本信息失败！使用备用服务器检测！"
			get_latest_version_backup
		fi
		if [ -n "`cat /tmp/v2ray_latest_info.txt|grep "404"`" ];then
			echo_date "获取V2Ray最新版本信息失败！使用备用服务器检测！"
			get_latest_version_backup
		fi
		V2VERSION=`cat /tmp/v2ray_latest_info.txt | sed 's/v//g'` || 0
		echo_date "检测到V2Ray最新版本：v$V2VERSION"
		if [ ! -f "/koolshare/bin/v2ray"  ];then
			echo_date "v2ray安装文件丢失！重新下载！"
			CUR_VER="0"
		else
			CUR_VER=`v2ray -version 2>/dev/null | head -n 1 | cut -d " " -f2 | sed 's/v//g'` || 0
			echo_date "当前已安装V2Ray版本：v$CUR_VER"
		fi
		COMP=`versioncmp $CUR_VER $V2VERSION`
		if [ "$COMP" == "1" ];then
			[ "$CUR_VER" != "0" ] && echo_date "V2Ray已安装版本号低于最新版本，开始更新程序..."
			update_now v$V2VERSION
		else
			V2RAY_LOCAL_VER=`/koolshare/bin/v2ray -version 2>/dev/null | head -n 1 | cut -d " " -f2`
			V2RAY_LOCAL_DATE=`/koolshare/bin/v2ray -version 2>/dev/null | head -n 1 | cut -d " " -f5`
			[ -n "$V2RAY_LOCAL_VER" ] && dbus set ss_basic_v2ray_version="$V2RAY_LOCAL_VER"
			[ -n "$V2RAY_LOCAL_DATE" ] && dbus set ss_basic_v2ray_date="$V2RAY_LOCAL_DATE"
			echo_date "V2Ray已安装版本已经是最新，退出更新程序!"
		fi
		rm -rf /tmp/v2ray
	else
		echo_date "获取V2Ray最新版本信息失败！使用备用服务器检测！"
		get_latest_version_backup
	fi
	rm -rf /tmp/v2ray_latest_info.txt
}

get_latest_version_backup(){
	echo_date "目前还没有任何备用服务器！"
	echo_date "获取V2Ray最新版本信息失败！请检查到你的网络！"
	echo_date "==================================================================="
	echo XU6J03M6
	exit 1
}

update_now(){
	rm -rf /tmp/v2ray
	mkdir -p /tmp/v2ray && cd /tmp/v2ray

	echo_date "开始下载校验文件：md5sum.txt"
	#wget --no-check-certificate --timeout=20 -qO - $url_main/$1/md5sum.txt > /tmp/v2ray/md5sum.txt
	curlxx  $url_main/$1/md5sum.txt > /tmp/v2ray/md5sum.txt
	if [ "$?" != "0" ];then
		echo_date "md5sum.txt下载失败！"
		md5sum_ok=0
	else
		md5sum_ok=1
		echo_date "md5sum.txt下载成功..."
	fi
	
	echo_date "开始下载v2ray程序"
	#wget --no-check-certificate --timeout=20 --tries=1 $url_main/$1/v2ray
	curlxx -o /tmp/v2ray/v2ray $url_main/$1/v2ray
	if [ "$?" != "0" ];then
		echo_date "v2ray下载失败！"
		v2ray_ok=0
	else
		v2ray_ok=1
		echo_date "v2ray程序下载成功..."
	fi

	if [ "$md5sum_ok=1" ] && [ "$v2ray_ok=1" ];then
		check_md5sum
	else
		echo_date "下载失败，请检查你的网络！"
		echo_date "==================================================================="
		echo XU6J03M6
		exit 1
	fi
}


check_md5sum(){
	cd /tmp/v2ray
	echo_date "校验下载的文件!"
	V2RAY_LOCAL_MD5=`md5sum v2ray|awk '{print $1}'`
	V2RAY_ONLINE_MD5=`cat md5sum.txt|grep -w v2ray|awk '{print $1}'`
	if [ "$V2RAY_LOCAL_MD5"x = "$V2RAY_ONLINE_MD5"x ];then
		echo_date "文件校验通过!"
		install_binary
	else
		echo_date "校验未通过，可能是下载过程出现了什么问题，请检查你的网络！"
		echo_date "==================================================================="
		echo XU6J03M6
		exit 1
	fi
}

install_binary(){
	echo_date "开始覆盖最新二进制!"
	if [ "`pidof v2ray`" ];then
		echo_date "为了保证更新正确，先关闭v2ray主进程... "
		killall v2ray >/dev/null 2>&1
		move_binary
		sleep 1
		start_v2ray
	else
		move_binary
	fi
}

move_binary(){
	echo_date "开始替换v2ray二进制文件... "
	mv /tmp/v2ray/v2ray /koolshare/bin/v2ray
	chmod +x /koolshare/bin/v2*
	V2RAY_LOCAL_VER=`/koolshare/bin/v2ray -version 2>/dev/null | head -n 1 | cut -d " " -f2`
	V2RAY_LOCAL_DATE=`/koolshare/bin/v2ray -version 2>/dev/null | head -n 1 | cut -d " " -f5`
	[ -n "$V2RAY_LOCAL_VER" ] && dbus set ss_basic_v2ray_version="$V2RAY_LOCAL_VER"
	[ -n "$V2RAY_LOCAL_DATE" ] && dbus set ss_basic_v2ray_date="$V2RAY_LOCAL_DATE"
	echo_date "v2ray二进制文件替换成功... "
}

start_v2ray(){
	echo_date "开启v2ray进程... "
	cd /koolshare/bin
	export GOGC=30
	v2ray --config=/koolshare/ss/v2ray.json >/dev/null 2>&1 &
	
	local i=10
	until [ -n "$V2PID" ]
	do
		i=$(($i-1))
		V2PID=`pidof v2ray`
		if [ "$i" -lt 1 ];then
			echo_date "v2ray进程启动失败！"
			close_in_five
		fi
		sleep 1
	done
	echo_date v2ray启动成功，pid：$V2PID
}

close_in_five(){
	echo_date "插件将在5秒后自动关闭！！"
	sleep 1
	echo_date 5
	sleep 1
	echo_date 4
	sleep 1
	echo_date 3
	sleep 1
	echo_date 2
	sleep 1
	echo_date 1
	sleep 1
	echo_date 0
	dbus set ss_basic_enable="0"
	#disable_ss >/dev/null
	#echo_date "插件已关闭！！"
	#echo_date ======================= 梅林固件 - 【科学上网】 ========================
	#unset_lock
	exit
}

echo_date "==================================================================="
echo_date "                v2ray程序更新(Shell by sadog)"
echo_date "==================================================================="
get_latest_version
echo_date "==================================================================="