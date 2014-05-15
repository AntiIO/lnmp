#!/bin/sh

#安装bison
echo "正在安装bison******************"
cd /root/download/
tar xf bison-3.0.tar.gz
cd bison-3.0
./configure 
make && make install

#安装ncurses
echo "正在安装ncurses******************"
cd /root/download/
tar xf ncurses-5.8.tar.gz
cd ncurses-5.8
./configure 
make && make install

#安装CMAKE
echo "正在安装CMAKE******************"
cd /root/download/
tar xf cmake-2.8.12.2.tar.gz
cd cmake-2.8.12.2
./configure 
gmake && make install

#安装mysql
echo "正在安装mysql******************"
cd /root/download/
tar xf mysql-5.6.17.tar.gz
cd mysql-5.6.17
cmake ./ -DCMAKE_INSTALL_PREFIX=/usr/local/mysql -DMYSQL_DATADIR=/usr/local/mysql/data -Wno-dev
make && make install

#添加用户和用户组
echo "正在添加用户和用户组******************"
groupadd mysql  
useradd mysql -g mysql -M -s /sbin/nologin
#增加一个名为CentOS Mysql的用户。
#-g：指定新用户所属的用户组(group)
#-M：不建立根目录
#-s：定义其使用的shell，/sbin/nologin代表用户不能登录系统。

#初始化数据库
echo "正在初始化数据库******************"
cd /usr/local/mysql
chown -R mysql:mysql . #(为了安全安装完成后请修改权限给root用户)
scripts/mysql_install_db --user=mysql #(先进行这一步再做如下权限的修改)
chown -R root:mysql .  #(将权限设置给root用户，并设置给mysql组， 取消其他用户的读写执行权限，仅留给mysql "rx"读执行权限，其他用户无任何权限)
chown -R mysql:mysql ./data   #(给数据库存放目录设置成mysql用户mysql组，并赋予chmod -R ug+rwx  读写执行权限，其他用户权限一律删除仅给mysql用户权限)

#配置文件和启动脚本
echo "正在配置mysql******************"
cp support-files/my-default.cnf  /etc/my.cnf  #(并给/etc/my.cnf +x权限 同时删除 其他用户的写权限，仅仅留给root 和工作组 rx权限,其他一律删除连rx权限都删除)
#将mysql的启动服务添加到系统服务中  
cp support-files/mysql.server /etc/init.d/mysql
chmod +x /etc/init.d/mysql
#让mysql服务开机启动
chkconfig --add mysql
#启动mysql
service mysql start

#修改mysql root登录的密码(mysql必须先启动了才行哦)
cd /usr/local/mysql
./bin/mysqladmin -u root password '123456'
#./bin/mysqladmin -u root -h web-mysql password '123456' #没执行成功。

#如mysql需要远程访问，还要配置防火墙开启3306端口
/etc/sysconfig/iptables
#/sbin/iptables -A INPUT m state --state NEW m tcp p dport 3306 j ACCEPT
/sbin/iptables -I INPUT -p tcp --dport 3306 -j ACCEPT
service iptables restart
#还要配置数据库中的用户权限，准许远程登录访问。
#删除密码为空的用户
delete from user where password="";
#准许root用户远程登录
update user set host = '%' where user = 'root';
#重启mysql生效
/etc/init.d/mysql restart