# k8s-spark: spark cluster of DRAFT on Kubernetes
##### Steps:
* Build docker image via Quay.io
* Create kuberbetes pods & service

        kubectl create -f spark.yaml [--namespace=xxx]
        OR
        kubectl create -f spark-ha.yaml [--namespace=xxx]
* Teardown

        ./teardown.sh [--namespace=xxx]
        OR
        ./teardown-ha.sh [--namespace=xxx]

-----
##### Notes:
* To run HA version, Zookeeper service is prerequisite. 
* Spark Master's "hostname" must be equal to the name of "Spark Master Service", otherwise AKKA at Spark Master will drop messages due to mismatched inbound addresses with its own. However, if we'd like to have better resilience of Master, we should create k8s Replication Controller for Master, rather than creating Master Pod by ourselves. Unfortunately, the hostname of container within a Pod created by Replication Controller would be randomized, which is impossible to match the predefined name of its corresponding k8s service. To resolve this, set SPARK_MASTER_IP (will be deprecated, use SPARK_MASTER_HOST instead) to the same name of Spark Master Service would make Spark Master pass it (instead of hostname) to AKKA for ensuing communications.
* To enable Spark run in Docker, set SPARK_LOCAL_HOSTNAME, which is then passed to AKKA for ensuing communications at Spark Workers. Refer to https://github.com/apache/spark/pull/3893 for SPARK_LOCAL_HOSTNAME
* For each Master, create a corresponding Service for cluster communication. For the whole Spark cluster, create a specific Service for cluster WebUI (port 8080), so that they are accessible from external browsers via [Vulcand][vd]. Set SPARK_PUBLIC_DNS with this URL SCHEME:
 
        Master: "spark-master.[namespace].k8s"
        Worker: "spark-[hostname].[namespace].k8s" 
  Refer to [Kube2Vulcan][k2v] for details.
* Thanks to [Kubernetes Networking Model][knm], all nodes & containers can communicate without NAT. It relieves us from what described [here][spd] about Dockerize Spark.

-----
##### TODO:
* Kubernetes 1.0.x doesn't support emptyDir volumes for containers running as non-root (it's commit in master branch, not v1.0.0 branch, refer to https://github.com/kubernetes/kubernetes/pull/9384 & https://github.com/kubernetes/kubernetes/issues/12627). Use root rather than spark user instead at this moment.
* Workers report all CPU/RAM resources of the host to Master, rather than limitation specified in Pod spec. 
* Master HA version verification
* According to Spark [Application Monitoring Guide][spm], there might be multiple consecutive ports used if multiple SparkContexts running on the same host (the SparkContexts might locate at worker nodes or driver nodes). Need a way to serve a range of ports for this at Vulcand. 
* Spark-submit workflows/mechanisms & verification, plan to support both client mode and cluster mode: 

      * Client mode
          * Want to get a job result (dynamic analysis)
          * Easier for developing/debugging
          * Control where your Driver Program is running
          * Always up application: expose your Spark job launcher as REST service or a Web UI
      * Cluster mode
          * Easier for resource allocation (let the master decide): Fire and forget
          * Monitor your Driver Program from Master Web UI like other workers
          * Stop at the end: one job is finished, allocated resources a freed

[vd]: https://github.com/mailgun/vulcand
[k2v]: https://github.com/rainbean/Kube2Vulcan
[spm]: http://spark.apache.org/docs/latest/monitoring.html
[knm]: https://github.com/kubernetes/kubernetes/blob/master/docs/admin/networking.md
[spd]: http://sometechshit.blogspot.ru/2015/04/running-spark-standalone-cluster-in.html
