<<<<<<< HEAD
FROM million12/centos-supervisor:latest
=======
FROM ubuntu:16.04
>>>>>>> master

MAINTAINER James Mathison <tkojames@gmail.com>


ADD asset/* /opt/

RUN yum -y update && yum install -y unzip \
    wget -y \
    yum clean all && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*







RUN wget --no-check-certificate \
      https://install.service-now.com/glide/distribution/builds/package/mid/2018/01/03/mid.kingston-10-17-2017__patch1-12-12-2017_01-03-2018_0843.linux.x86-64.zip \
      -O /tmp/mid.zip && \
    unzip -d /opt /tmp/mid.zip && \
    mv /opt/agent/config.xml /opt/ && \
    chmod 755 /opt/init && \
    rm -rf /tmp/*

EXPOSE 80 443

ENTRYPOINT ["/opt/init"]

CMD ["mid:start"]
