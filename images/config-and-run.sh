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
  export SPARK_PUBLIC_DNS="spark-master-${MASTER_ID}.${POD_NAMESPACE}.${DOMAIN_NAME}"
  echo "" >> /opt/spark/conf/spark-env.sh
  echo "# Options set by config-and-run.sh" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_MASTER_IP=${SPARK_MASTER_IP}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_MASTER_HOST=${SPARK_MASTER_IP}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_MASTER_PORT=${SPARK_MASTER_PORT}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_MASTER_WEBUI_PORT=${SPARK_MASTER_WEBUI_PORT}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_PUBLIC_DNS=${SPARK_PUBLIC_DNS}" >> /opt/spark/conf/spark-env.sh
  echo "$(hostname -i) ${SPARK_MASTER_IP}" >> /etc/hosts
  gosu spark /opt/spark/sbin/start-master.sh
else
  # assure all spark master k8s services have been created
  MASTER_LIST=$(echo $MASTER_CONNECT | sed 's#spark://###')
  while IFS=',' read -ra MASTER; do
    for i in "${MASTER[@]}"; do
      # (1) get spark_master_host, spark_master_port, and spark_master_service for spark versions earlier than 1.6.0
      # (2) get spark_master_host, spark_master_ui_port, and spark_master_service for spark v1.6.0+
      MASTER_HOST=$(echo $i | sed 's/\(.*\):[0-9]*/\1/')
      #read MASTER_SVC MASTER_PORT <<< $(echo $i | sed 's/-/_/g' | sed 's/\(.*\):\([0-9]*\)/\U\1_SERVICE_HOST \2/')
      read MASTER_SVC MASTER_UI_PORT <<< $(echo $i | sed 's/-/_/g' | sed 's/\(.*\):\([0-9]*\)/\U\1_SERVICE_HOST \1_SERVICE_PORT_CLUSTER_UI/')
      if [[ ${!MASTER_SVC} == "" ]]; then
        echo "${MASTER_HOST} service must be created before starting pods..."
        sleep 30 # To postpone pod restart
        exit 1 
      fi

      # wait until master pods ready
      # (1) curl error code 52(Empty reply) here is expected for an alive master pod for spark versions earlier than 1.6.0
      # (2) curl -I -L to get http response code. 200 is expected for an alive master pod for spark v1.6.0+
      # -m: max operation timeout; -Ss: hide progress meter but show error; --stderr -: redirect all writes to stdout
      # RET=$(curl -m 2 -Ss --stderr - ${MASTER_HOST}:${MASTER_PORT} | sed 's/.*curl: (\([0-9]*\)).*/\1/')
      RET=$(curl -m 3 -I -L -Ss --stderr - ${MASTER_HOST}:${!MASTER_UI_PORT} | head -n 1 | cut -d$' ' -f2)
      while [ ${RET} != 200 ]; do
        echo "${MASTER_HOST} Pod is not ready...(RET=${RET})"
        sleep 3
        RET=$(curl -m 3 -I -L -Ss --stderr - ${MASTER_HOST}:${!MASTER_UI_PORT} | head -n 1 | cut -d$' ' -f2)
      done
      echo "${MASTER_HOST} Pod has been ready!"
    done
  done <<< "$MASTER_LIST"

  export SPARK_LOCAL_HOSTNAME=$(hostname -i)
  export SPARK_PUBLIC_DNS="spark.$(hostname).${POD_NAMESPACE}.${DOMAIN_NAME}"
  echo "" >> /opt/spark/conf/spark-env.sh
  echo "# Options set by config-and-run.sh" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_LOCAL_HOSTNAME=${SPARK_LOCAL_HOSTNAME}" >> /opt/spark/conf/spark-env.sh
  echo "SPARK_PUBLIC_DNS=${SPARK_PUBLIC_DNS}" >> /opt/spark/conf/spark-env.sh

  if [ "${ROLE}" == "WORKER" ]; then
    echo "Starting Worker..."
    export SPARK_WORKER_WEBUI_PORT=${WEBUI_PORT:-8080}
    echo "SPARK_WORKER_WEBUI_PORT=${SPARK_WORKER_WEBUI_PORT}" >> /opt/spark/conf/spark-env.sh
    gosu spark /opt/spark/sbin/start-slave.sh ${MASTER_CONNECT}
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

exec gosu spark tail -F /spark_data/log/*