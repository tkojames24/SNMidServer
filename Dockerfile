FROM million12/centos-supervisor:latest

MAINTAINER James Mathison <tkojames@gmail.com>


ADD asset/* /opt/

RUN yum -y update && yum install -y unzip \
    wget -y \
    yum clean all && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/*



RUN wget --no-check-certificate \
      https://install.service-now.com/glide/distribution/builds/package/mid-upgrade/2018/08/22/mid-upgrade.london-06-27-2018__patch1-08-15-2018_08-22-2018_1559.universal.universal.zip \
      -O /tmp/mid.zip && \
    unzip -d /opt /tmp/mid.zip && \
    mv /opt/agent2/config.xml /opt/ && \
    chmod 755 /opt/init && \
    rm -rf /tmp/*

EXPOSE 80 443

ENTRYPOINT ["/opt/init"]

CMD ["mid:start"]
