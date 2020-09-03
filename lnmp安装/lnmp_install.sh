#软件版本号
nginx_version="nginx-quic"
php_version="php-7.4.10"

#软件下载地址
nginx_download_url="http://hg.nginx.org/nginx-quic/archive/tip.tar.gz"
php_download_url="https://github.com/php/php-src/archive/php-7.4.10.tar.gz"

#软件安装地址
nginx_install_path="/usr/local/nginx"
php_install_path="/usr/local/php"

#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
export PATH

# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: 请用root权限运行脚本"
    exit 1
fi

echo "创建相关目录"
mkdir -p $nginx_install_path
mkdir -p $php_install_path
mkdir -p /root/src


echo "安装依赖及工具"
yum -y install git wget gcc gcc-c++ lrzsz ntp unzip libunwind-devel golang pcre-devel

#同步时间
echo "同步系统时间"
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
ntpdate us.pool.ntp.org

echo "创建相关用户"
groupadd www
useradd -s /sbin/nologin -g www www

echo "下载相关软件包"
cd /root/src
wget $nginx_download_url
wget $php_download_url

echo "编译boringssl密码库"
export GOPROXY=https://goproxy.io
export GO111MODULE=on
git clone https://github.com/google/boringssl.git
cd boringssl
mkdir -p build .openssl/lib .openssl/include
ln -sf /root/src/boringssl/include/openssl /root/src/boringssl/.openssl/include/openssl
touch /root/src/boringssl/.openssl/include/openssl/ssl.h
cmake -B/root/src/boringssl/build -H/root/src/boringssl
make -C /root/src/boringssl/build
cp /root/src/boringssl/build/crypto/libcrypto.a /root/src/boringssl/build/ssl/libssl.a /root/src/boringssl/.openssl/lib

echo "下载nginx第三方库"
cd /root/src
git clone https://gitee.com/zach/zlib.git zlib-cf
cd zlib-cf
make -f Makefile.in distclean
cd /root/src
git clone https://gitee.com/zach/ngx_brotli.git
cd ngx_brotli
git submodule update --init --recursive
cd /root/src


echo "开始安装nginx..........."
echo 
chown www.www /var/log/nginx

tar zxvf nginx-quic-*.tar.gz
cd nginx-quic-*/
sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' auto/cc/gcc
./auto/configure --prefix=/usr/local/nginx --user=www --group=www --with-http_stub_status_module --with-http_v2_module --with-http_ssl_module --with-http_gzip_static_module --with-http_realip_module --with-http_flv_module --with-http_mp4_module --with-pcre --with-pcre-jit --with-zlib=../zlib-cf  --add-module=../ngx_brotli --with-ld-opt='-ljemalloc' --with-debug --with-http_v3_module --with-cc-opt="-I../boringssl/include" --with-ld-opt="-L../boringssl/build/ssl -L../boringssl/build/crypto" --with-http_quic_module --with-stream_quic_module
make && make install

cd /roo/src
mv /usr/local/nginx/conf /usr/local/nginx/conf.bak
cp -r nginx-conf /usr/local/nginx/conf
cp nginx.service /lib/systemd/system/
chmod +x  /lib/systemd/system/nginx.service
systemctl enable nginx
mkdir -p /data/wwwlogs/
mkdir -p /data/wwwlogs/
mkdir -p /data/wwwroot/default
mkdir -p /usr/local/nginx/conf/vhost
touch /data/wwwlogs/access_nginx.log
systemctl start nginx
echo "nginx安装完成"

echo "预备安装PHP"
#安装基础库
yum install autoconf automake bison libxml2 libxml2 openssl-devel sqlite-devel libcurl-devel libpng-devel libjpeg-devel freetype-devel libicu-devel  libsodium-devel argon2 libargon2-devel libxslt-devel libzip-devel
dnf --enablerepo=PowerTools install oniguruma-devel
yum -y install git automake gcc gcc-c++ libtool
cd /root/src
#安装re2c
git clone https://github.com/skvadrik/re2c.git re2c
cd re2c
mkdir -p m4
./autogen.sh && ./configure 
make && make install

tar zvxf php-7.4.10.tar.gz
cd php-7.4.10
./configure --prefix=/usr/local/php \
--with-config-file-path=/usr/local/php/etc \
--with-config-file-scan-dir=/usr/local/php/etc/php.d \
--with-fpm-user=www \
--with-fpm-group=www \
--enable-mbstring  \
--enable-ftp  \
--enable-gd   \
--enable-opcache   \
--enable-gd-jis-conv \
--enable-mysqlnd \
--enable-pdo   \
--enable-sockets   \
--enable-fpm   \
--enable-xml  \
--enable-soap  \
--enable-pcntl   \
--enable-cli   \
--with-freetype   \
--with-jpeg \
--with-openssl  \
--with-mysqli=mysqlnd   \
--with-pdo-mysql=mysqlnd   \
--with-pear   \
--with-zlib  \
--with-iconv \
--with-curl \
--enable-bcmath \
--enable-shmop \
--enable-exif  \
--enable-sysvsem \
--enable-mbregex \
--with-password-argon2 \
--with-sodium=/usr/local \
--with-mhash \
--enable-ftp \
--enable-intl \
--with-xsl \
--with-gettext \
--with-zip \
--disable-debug  \
PKG_CONFIG_PATH=/usr/local/lib/pkgconfig/: 
make && make install
mv /usr/local/php/etc /usr/local/php/etc.bak
cp -r  php-etc /usr/local/php/etc
cp php-fpm.service /lib/systemd/system/
chmod +x  /lib/systemd/system/php-fpm.service
systemctl enable php-fpm.service
service php-fpm status
echo "PHP安装完成"
