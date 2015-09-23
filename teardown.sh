#!/bin/bash

kubectl delete service spark-master "$@"
kubectl delete rc spark-master-rc "$@"
kubectl delete rc spark-worker-rc "$@"

