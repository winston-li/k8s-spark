#!/bin/bash

if [ ! -z "$MASTER_ROLE" ]; then
  echo "Starting Master..."
  # spark-master k8s service redefined this variable, which is incompatible with Spark. Redefine it here. 
  export SPARK_MASTER_PORT=${SPARK_MASTER_SERVICE_PORT_CLUSTER_CMD:-7077}
  export SPARK_MASTER_IP="spark-master"
  export SPARK_PUBLIC_DNS="spark-master.${POD_NAMESPACE}.k8s"
  echo "SPARK_MASTER_HOST=${SPARK_MASTER_IP}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_PUBLIC_DNS=${SPARK_PUBLIC_DNS}" >> /opt/spark/conf/spark-env.sh
  echo "$(hostname -i) ${SPARK_MASTER_IP}" >> /etc/hosts
  /opt/spark/sbin/start-master.sh
else
  echo "Starting Worker..."
  if [[ ${SPARK_MASTER_SERVICE_HOST} == "" ]]; then
    echo "Spark Master service must be created before starting any workers"
    sleep 30 # To postpone pod restart
    exit 1
  fi
  export SPARK_MASTER_PORT=${SPARK_MASTER_SERVICE_PORT_CLUSTER_CMD:-7077}
  export SPARK_LOCAL_HOSTNAME=$(hostname)
  #export SPARK_PUBLIC_DNS="spark-$(echo $(hostname -i) | sed 's/\./-/g').${POD_NAMESPACE}.k8s"
  export SPARK_PUBLIC_DNS="spark.$(hostname).${POD_NAMESPACE}.k8s"
  echo "SPARK_PUBLIC_DNS=${SPARK_PUBLIC_DNS}" >> /opt/spark/conf/spark-env.sh
  echo "${SPARK_MASTER_SERVICE_HOST} spark-master" >> /etc/hosts
  /opt/spark/sbin/start-slave.sh spark://spark-master:${SPARK_MASTER_PORT}
fi

tail -F /spark_data/log/*
