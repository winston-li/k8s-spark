#!/bin/bash

kubectl delete service spark-master-1 "$@"
kubectl delete service spark-master-2 "$@"
kubectl delete rc spark-master-1-rc "$@"
kubectl delete rc spark-master-2-rc "$@"
kubectl delete rc spark-worker-rc "$@"
kubectl delete rc spark-driver-rc "$@"
