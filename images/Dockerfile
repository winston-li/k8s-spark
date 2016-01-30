FROM centos:7

ENV SPARK_VERSION 1.5.2
ENV HADOOP_VERSION 2.6
EXPOSE 8080 4040 7077 6066


RUN yum update -y
RUN rpm --rebuilddb && yum install -y install wget tar && yum clean all \
    && wget -q -O - --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/7u51-b13/jre-7u51-linux-x64.tar.gz" | tar -xzf - -C /opt \
    && wget -q -O - http://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz | tar -xzf - -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark
RUN alternatives --install /usr/bin/java java /opt/jre1.7.0_51/bin/java 1
RUN gpg --keyserver pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/1.7/gosu-amd64" \
    && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/1.7/gosu-amd64.asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && rm -r /root/.gnupg/ \
    && chmod +x /usr/local/bin/gosu

ENV PATH /opt/spark/bin:$PATH
WORKDIR /opt/spark

COPY config-and-run.sh ./bin/
COPY log4j.properties ./conf/
COPY spark-env.sh ./conf/

RUN groupadd spark && \
    useradd -g spark spark

RUN chmod a+x ./bin/config-and-run.sh && \
    mkdir -p /spark_data/{data,log,work} && \
    chown -R spark.spark /opt/spark /spark_data && \
    chmod o+w -R /opt/spark /spark_data

VOLUME ["/spark_data/data","/spark_data/log","/spark_data/work"]   

RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

#USER spark

CMD ["/opt/spark/bin/config-and-run.sh"]
