FROM million12/centos-supervisor:latest

MAINTAINER James Mathison <tkojames@gmail.com>


ADD asset/* /opt/

RUN yum -y update && yum install -y unzip \
    wget -y \
    yum clean all && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*



RUN wget --no-check-certificate \
      https://install.service-now.com/glide/distribution/builds/package/mid/2018/05/24/mid.kingston-10-17-2017__patch6-05-16-2018_05-24-2018_1317.linux.x86-64.zip \
      -O /tmp/mid.zip && \
    unzip -d /opt /tmp/mid.zip && \
    mv /opt/agent/config.xml /opt/ && \
    chmod 755 /opt/init && \
    rm -rf /tmp/*

EXPOSE 80 443

ENTRYPOINT ["/opt/init"]

CMD ["mid:start"]
