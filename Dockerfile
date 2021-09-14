# syntax=docker/dockerfile:1
FROM fedora:33 AS builder
MAINTAINER Dan Bryant (daniel.bryant@linux.com)

ENV TZ=Europe/London

# install basic dependencies for Linux build
RUN dnf update -y
RUN dnf install -y nano

# install Linux tools required to build Windows packages
RUN dnf install -y cmake gcc make ninja-build zip
RUN dnf upgrade -y

# enable cygwin COPR
RUN dnf install -y dnf-plugins-core
RUN dnf copr enable -y yselkowitz/cygwin
RUN dnf update -y
RUN dnf install -y cygwin-binutils cygwin-filesystem-base cygwin64-gcc cygwin-gcc-common cygwin64-w32api-headers \
	cygwin64-w32api-runtime cygwin64-zlib cygwin64-zlib-static cygwin64-pkg-config cygwin64-gcc-c++
RUN dnf install -y findutils xz
RUN dnf install -y cygwin64-libiconv-static 
RUN dnf download -y --source cygwin-libiconv
RUN rpm -ivh cygwin-libiconv*.src.rpm
RUN rm -f cygwin-libiconv*.src.rpm
RUN dnf install -y perl
RUN dnf install -y byacc flex
RUN dnf install -y git file zip patch
RUN dnf install -y libpng libjpeg-turbo-devel jasper-libs autoconf automake

# we put the utilities here
RUN mkdir /opt/ziproxy

# get libgif v4 - required for ziproxy - and compile in Cygwin
RUN curl -o /usr/local/src/giflib-4.1.6.tar.gz 'https://phoenixnap.dl.sourceforge.net/project/giflib/giflib-4.x/giflib-4.1.6/giflib-4.1.6.tar.gz'
RUN tar -xf /usr/local/src/giflib-4.1.6.tar.gz -C /usr/local/src
RUN rm -f /usr/local/src/giflib-4.1.6.tar.gz
RUN cd /usr/local/src/giflib-4.1.6 && ./configure --help
RUN cd /usr/local/src/giflib-4.1.6 && CC=x86_64-pc-cygwin-gcc HOSTCC=gcc ./configure --prefix=/usr/x86_64-pc-cygwin --build=x86_64-pc-cygwin \
	--host=x86_64-pc-linux-gnu --bindir=/tmp/bin --sbindir=/tmp/sbin --datarootdir=/tmp/share
RUN cd /usr/local/src/giflib-4.1.6 && make
RUN cd /usr/local/src/giflib-4.1.6 && make install

# get libjpeg - required for ziproxy - and compile in Cygwin
RUN curl -o /usr/local/src/jpeg-9d.tar.gz 'https://ijg.org/files/jpegsrc.v9d.tar.gz'
RUN tar -xf /usr/local/src/jpeg-9d.tar.gz -C /usr/local/src
RUN rm -f /usr/local/src/jpeg-9d.tar.gz
RUN cd /usr/local/src/jpeg-9d && ./configure --help
RUN cd /usr/local/src/jpeg-9d && CC=x86_64-pc-cygwin-gcc HOSTCC=gcc ./configure --prefix=/usr/x86_64-pc-cygwin --build=x86_64-pc-cygwin \
	--host=x86_64-pc-linux-gnu --bindir=/tmp/bin --sbindir=/tmp/sbin --datarootdir=/tmp/share
RUN cd /usr/local/src/jpeg-9d && make
RUN cd /usr/local/src/jpeg-9d && make install

# get libpng - required for ziproxy - and compile in Cygwin
RUN curl -o /usr/local/src/libpng-1.6.37.tar.gz 'https://phoenixnap.dl.sourceforge.net/project/libpng/libpng16/1.6.37/libpng-1.6.37.tar.gz'
RUN tar -xf /usr/local/src/libpng-1.6.37.tar.gz -C /usr/local/src
RUN rm -f /usr/local/src/libpng-1.6.37.tar.gz
RUN cd /usr/local/src/libpng-1.6.37 && ./configure --help
RUN cd /usr/local/src/libpng-1.6.37 && CC=x86_64-pc-cygwin-gcc HOSTCC=gcc ./configure --prefix=/usr/x86_64-pc-cygwin --build=x86_64-pc-cygwin \
	--host=x86_64-pc-linux-gnu --bindir=/tmp/bin --sbindir=/tmp/sbin --datarootdir=/tmp/share
RUN cd /usr/local/src/libpng-1.6.37 && make
RUN cd /usr/local/src/libpng-1.6.37 && make install

# clone ziproxy 3.3.2
RUN cd /usr/local/src && git clone --branch upstream/3.3.2 https://salsa.debian.org/debian/ziproxy.git
RUN cd /usr/local/src/ziproxy && ./configure --help
# avoid errors about programs being out-of-date
RUN cd /usr/local/src/ziproxy && autoreconf -f -i
ARG LDFLAGS="-static-libgcc -static-libstdc++ -static -Wl,--verbose"
RUN cd /usr/local/src/ziproxy && CC=x86_64-pc-cygwin-gcc HOSTCC=gcc ./configure --prefix=/opt/ziproxy --enable-static --disable-shared --build=x86_64-pc-cygwin \
	--host=x86_64-pc-linux-gnu --without-jasper --without-sasl2
RUN cd /usr/local/src/ziproxy && make
RUN cd /usr/local/src/ziproxy && make install

# make sure to package the cygwin DLLs as well
# we only need cygwin1.dll, cygcrypto-3.dll and cygssl-3.dll
RUN cp /usr/x86_64-pc-cygwin/sys-root/usr/bin/cygwin1.dll /opt/ziproxy/bin

# package the ZIP files
RUN cd /opt && zip -r ziproxy.zip ziproxy

FROM scratch AS export
COPY --from=builder /opt/ziproxy.zip .
