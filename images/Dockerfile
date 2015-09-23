FROM centos:latest

ENV SPARK_VERSION 1.4.0
ENV HADOOP_VERSION 2.6
EXPOSE 8000 4040 7077 6066


RUN yum update -y
RUN rpm --rebuilddb && yum install -y install wget tar && yum clean all \
    && wget -q -O - --no-cookies --no-check-certificate --header "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/7u51-b13/jre-7u51-linux-x64.tar.gz" | tar -xzf - -C /opt \
    && wget -q -O - http://apache.mirrors.pair.com/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz | tar -xzf - -C /opt \
    && mv /opt/spark-${SPARK_VERSION}-bin-hadoop${HADOOP_VERSION} /opt/spark
RUN alternatives --install /usr/bin/java java /opt/jre1.7.0_51/bin/java 1


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

#USER spark

CMD ["/opt/spark/bin/config-and-run.sh"]
