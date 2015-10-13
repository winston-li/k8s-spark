#!/bin/bash

if [ "${ROLE}" == "MASTER" ]; then
  # assure zookeeper services have been created
  while IFS=',' read -ra ZK; do
    for i in "${ZK[@]}"; do 
      read ZK_HOST ZK_PORT <<< $(echo $i | sed 's/\(.*\):\([0-9]*\)/\1 \2/')
      if [ ${ZK_HOST} == "" ] || [ ${ZK_PORT} == "" ]; then
        echo "zookeeper service must be created before starting pods..."
        sleep 30 # To postpone pod restart
        exit 1
      fi
    done
  done <<< "$ZOOKEEPER_CONNECT"

  echo "Starting Master ${MASTER_ID}..."
  # spark-master k8s service redefined SPARK_MASTER_PORT, which is incompatible with Spark. Redefine it here.
  MASTER_SVC_PORT=SPARK_MASTER_${MASTER_ID}_SERVICE_PORT 
  export SPARK_MASTER_PORT=${!MASTER_SVC_PORT:-7077}
  export SPARK_MASTER_WEBUI_PORT=${WEBUI_PORT:-8080}
  export SPARK_MASTER_IP="spark-master-${MASTER_ID}"
  export SPARK_PUBLIC_DNS="spark-master-${MASTER_ID}.${POD_NAMESPACE}.k8s"
  echo "" >> /opt/spark/conf/spark-env.sh
  echo "# Options set by config-and-run.sh" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_MASTER_IP=${SPARK_MASTER_IP}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_MASTER_HOST=${SPARK_MASTER_IP}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_MASTER_PORT=${SPARK_MASTER_PORT}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_MASTER_WEBUI_PORT=${SPARK_MASTER_WEBUI_PORT}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_PUBLIC_DNS=${SPARK_PUBLIC_DNS}" >> /opt/spark/conf/spark-env.sh
  echo "$(hostname -i) ${SPARK_MASTER_IP}" >> /etc/hosts
  /opt/spark/sbin/start-master.sh
else
  # assure all spark master k8s services have been created
  MASTER_LIST=$(echo $MASTER_CONNECT | sed 's#spark://###')
  while IFS=',' read -ra MASTER; do
    for i in "${MASTER[@]}"; do
      # get spark_master_host, spark_master_port, and spark_master_service
      MASTER_HOST=$(echo $i | sed 's/\(.*\):[0-9]*/\1/')
      read MASTER_SVC MASTER_PORT <<< $(echo $i | sed 's/-/_/g' | sed 's/\(.*\):\([0-9]*\)/\U\1_SERVICE_HOST \2/')
      if [[ ${!MASTER_SVC} == "" ]]; then
        echo "${MASTER_HOST} service must be created before starting pods..."
        sleep 30 # To postpone pod restart
        exit 1 
      fi

      # wait until master pods ready
      # curl error code 52(Empty reply) here is expected for an alive master pod  
      # -m: max operation timeout; -Ss: hide progress meter but show error; --stderr -: redirect all writes to stdout
      RET=$(curl -m 2 -Ss --stderr - ${MASTER_HOST}:${MASTER_PORT} | sed 's/.*curl: (\([0-9]*\)).*/\1/')
      while [ ${RET} != 52 ]; do
        echo "${MASTER_HOST} Pod is not ready...(RET=${RET})"
        sleep 2
        RET=$(curl -m 2 -Ss --stderr - ${MASTER_HOST}:${MASTER_PORT} | sed 's/.*curl: (\([0-9]*\)).*/\1/')
      done
      echo "${MASTER_HOST} Pod has been ready!"
             
      echo "${!MASTER_SVC} ${MASTER_HOST}" >> /etc/hosts
    done
  done <<< "$MASTER_LIST"

  export SPARK_LOCAL_HOSTNAME=$(hostname -i)
  export SPARK_PUBLIC_DNS="spark.$(hostname).${POD_NAMESPACE}.k8s"
  echo "" >> /opt/spark/conf/spark-env.sh
  echo "# Options set by config-and-run.sh" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_LOCAL_HOSTNAME=${SPARK_LOCAL_HOSTNAME}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_PUBLIC_DNS=${SPARK_PUBLIC_DNS}" >> /opt/spark/conf/spark-env.sh

  if [ "${ROLE}" == "WORKER" ]; then
    echo "Starting Worker..."
    export SPARK_WORKER_WEBUI_PORT=${WEBUI_PORT:-8080}
    echo "SPARK_WORKER_WEBUI_PORT=${SPARK_WORKER_WEBUI_PORT}" >> /opt/spark/conf/spark-env.sh
    /opt/spark/sbin/start-slave.sh ${MASTER_CONNECT}
  elif [ "${ROLE}" == "DRIVER" ]; then
    echo "Starting Driver..."
    echo "MASTER=${MASTER_CONNECT}" >> /opt/spark/conf/spark-env.sh
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