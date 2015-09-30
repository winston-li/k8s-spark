#!/bin/bash

if [ "$ROLE" = "MASTER" ]; then
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
  if [[ ${SPARK_MASTER_SERVICE_HOST} == "" ]]; then
    echo "Spark Master service must be created before starting any others"
    sleep 30 # To postpone pod restart
    exit 1
  fi
  export SPARK_MASTER_PORT=${SPARK_MASTER_SERVICE_PORT_CLUSTER_CMD:-7077}
  export SPARK_LOCAL_HOSTNAME=$(hostname)
  #export SPARK_PUBLIC_DNS="spark-$(echo $(hostname -i) | sed 's/\./-/g').${POD_NAMESPACE}.k8s"
  export SPARK_PUBLIC_DNS="spark.$(hostname).${POD_NAMESPACE}.k8s"
  echo "SPARK_PUBLIC_DNS=${SPARK_PUBLIC_DNS}" >> /opt/spark/conf/spark-env.sh
  echo "${SPARK_MASTER_SERVICE_HOST} spark-master" >> /etc/hosts
  
  # wait until master pod ready  
  KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  while [ $(curl -k https://${KUBERNETES_SERVICE_HOST}/api/v1/namespaces/${POD_NAMESPACE}/endpoints/spark-master -H "Authorization: Bearer ${KUBE_TOKEN}" | jq -r '.subsets[0].addresses[0].ip == null') == true ]; do
    echo "Spark Master Pod is not ready..."
    sleep 2
  done
  echo "Spark Master Pod has been ready!" 

  if [ "$ROLE" = "WORKER" ]; then
    echo "Starting Worker..."
    /opt/spark/sbin/start-slave.sh spark://spark-master:${SPARK_MASTER_PORT}
  elif [ "$ROLE" = "DRIVER" ]; then
    echo "Starting Driver..."
    echo "MASTER=spark://spark-master:$SPARK_MASTER_PORT" >> /opt/spark/conf/spark-env.sh
    echo "Use kubectl exec spark-driver -it bash to invoke commands"
    while true; do
      sleep 100
    done
  else
    echo "Environment variable ROLE must be defined (MASTER, WORKER, DRIVER)!"
    sleep 30 # To postpone pod restart
    exit 1
  fi
fi

tail -F /spark_data/log/*
