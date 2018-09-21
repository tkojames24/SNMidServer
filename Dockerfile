FROM million12/centos-supervisor:latest

MAINTAINER James Mathison <tkojames@gmail.com>
RUN yum -y update 
RUN yum -y install jre 
RUN yum -y install sysvinit-tools

COPY asset/  /opt/
COPY agent/  /opt/agent/



RUN  mv /opt/agent/config.xml /opt  
RUN  chmod 775 /opt/init
    

EXPOSE 80 443

ENTRYPOINT ["/opt/init"]

CMD ["mid:start"]
