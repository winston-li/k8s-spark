# k8s-spark: spark cluster of DRAFT on Kubernetes
[![Docker Repository on Quay](https://quay.io/repository/draft/k8s-spark/status "Docker Repository on Quay")](https://quay.io/repository/draft/k8s-spark)

##### Steps:
* Build docker image via Quay.io
* Create kuberbetes pods & service

        kubectl create -f spark.yaml [--namespace=xxx]
* Teardown

        ./teardown.sh [--namespace=xxx]

-----
##### Notes:
* To run HA version, Zookeeper service is prerequisite. 
* Spark Master's "hostname" must be equal to the name of "Spark Master Service", otherwise AKKA at Spark Master will drop messages due to mismatched inbound addresses with its own. However, if we'd like to have better resilience of Master, we should create k8s Replication Controller for Master, rather than creating Master Pod by ourselves. Unfortunately, the hostname of container within a Pod created by Replication Controller would be randomized, which is impossible to match the predefined name of its corresponding k8s service. To resolve this, set SPARK_MASTER_IP (will be deprecated, use SPARK_MASTER_HOST instead) to the same name of Spark Master Service would make Spark Master pass it (instead of hostname) to AKKA for ensuing communications.
* To enable Spark run in Docker, set SPARK_LOCAL_HOSTNAME, which is then passed to AKKA for ensuing communications at Spark Workers. Refer to https://github.com/apache/spark/pull/3893 for SPARK_LOCAL_HOSTNAME. In Spark Master HA scenario, the new active master will contact each worker, so we set SPARK_LOCAL_HOSTNAME at each worker with pod IP, e.g. $(hostname -i) to make them reachable by new master(s). 
* For each Master, create a corresponding Service for cluster & client communication. The cluster WebUI (port 8080) of this Service is for being accessible from external browsers via [Vulcand][vd]. Set SPARK_PUBLIC_DNS with this URL SCHEME:
 
        Master: "spark-master-[1 or 2].[namespace].k8s"
        Worker: "spark-[hostname].[namespace].k8s" 
  Refer to [Kube2Vulcan][k2v] for details.
* Thanks to [Kubernetes Networking Model][knm], all nodes & containers can communicate without NAT. It relieves us from what described [here][spd] about Dockerize Spark.
* Use livenessProbe to restart master and/or worker pods. It can mitigate the bug of ["restarting leader zookeeper causes spark master to die when the spark master election is assigned to zookeeper"] [jira9438].
* Resilience verified OK: 
        
        (1) worker crash: container (docker kill), pod (kubectl stop pods), vm (reboot) 
        (2) master crash: container (docker kill), pod (kubectl stop pods), vm (reboot)

-----
##### TODO:
* ~~Kubernetes 1.0.x doesn't support emptyDir volumes for containers running as non-root (it's commit in master branch, not v1.0.0 branch, refer to https://github.com/kubernetes/kubernetes/pull/9384 & https://github.com/kubernetes/kubernetes/issues/12627). Use root rather than spark user instead at this moment.~~ (Done: It's verified OK that kubernetes 1.1.1 has supported this.) 
* Due to our startup script needs to modify /etc/hosts within Docker, so still using "root" rather than "spark user" for now. Wait for better support from containers in this regard in the future. (Addendum: set "spark user" by gosu after modified /etc/hosts in startup script)
* Workers report all CPU/RAM resources of the host to Master, rather than limitation specified in Pod spec. 
* Which is more appropriate in k8s? one spark master w/ zookeeper vs. two spark masters w/ zookeeper?
* According to Spark [Application Monitoring Guide][spm], there might be multiple consecutive ports used if multiple SparkContexts running on the same host (the SparkContexts might locate at worker nodes or driver nodes). Need a way to serve a range of ports for this at Vulcand. 
* Spark-submit workflows/mechanisms & verification & security, plan to support both client mode and cluster mode: 

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
[jira9438]: https://issues.apache.org/jira/browse/SPARK-9438
