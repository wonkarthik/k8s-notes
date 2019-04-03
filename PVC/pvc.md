Kubernetes Storage
Kubernetes storages can be broadly divided into local storage and network-attached storage. Local storage is located inside the cluster node where the Kubernetes Pod is running while network attached storage are centralised on the network (see kubernetes architecture here). Local storages has the advantage of being fast and can be used for things like scratch space but are ephemeral. At best a local storage only exists for as long as the pod is alive. Once the pod is deleted the local storage gets deleted as well. For most applications like databases, this is not a desirable feature since preserving the state of the database is important. In Kubernetes databases are implemented as StatefulSets.

Applications like StatefulSets are dependent on persistent storage and cannot work without them. An opensource storage backend that works quite well and widely deployed is Ceph. Ceph is a unified, distributed storage system designed for excellent performance, reliability and scalability. However, setting up a storage infrastructures like Ceph is often complex  and this is where Rook comes in to help. You deploy Rook and then Rook becomes the operator managing the Ceph cluster on your behalf. Rook integrates deeply into cloud native environments leveraging extension points and providing a seamless experience for scheduling, lifecycle management, resource management, security, monitoring, and user experience.

StorageClasses, Persistent Volumes (PV) and Persistent Volume Claims (PVC)
To use a volume in Kubernetes first requires creating a storageclass to connect to a backend storage. For example, to use a Ceph cluster created through Rook, you would create a storage class pointing to Ceph, referred to as the provisioner in the yaml file below. The manifest file to create the storage class would look like the following:

apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  replicated:
    size: 3

---

apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: rook-ceph-block
provisioner: ceph.rook.io/block
parameters:
  blockPool: replicapool
  clusterNamespace: rook-ceph
  # Specify the filesystem type of the volume. If not specified, it will use `ext4`.
  fstype: xfs
Once the storage class has been created, here is a summary of the steps required to connect a Pod to a persistent volume.

A cluster administrator creates a PersistentVolume that is backed by physical storage.
A cluster user creates a PersistentVolumeClaim, which gets automatically bound to a suitable PersistentVolume.
The user creates a Pod that uses the PersistentVolumeClaim as storage.
Step 1: Create a Persistent Volume (PV)
After the storage class has been created the cluster administrator has the option to provision a persistent volume statically or automatically. Static storage provisioning is a manual process where the Cluster administrator creates volumes of different sizes and make them available for the cluster users (e.g. developers) to use in their applications. One of the problems with this method is that if a user requires a certain volume which is not provisioned by the Administrator, PV will assign the next available storage volume to the user, leading to waste.

In dynamic volume creation, when none of the static PVs the administrator created matches a user’s PersistentVolumeClaim, the cluster may try to dynamically provision a volume to meet the request of the PVC provided the administrator has created a StorageClasses. A PVC must request a specific storage class except a default is made available. Without a storage class, dynamic provisioning cannot occur.
To enable dynamic storage provisioning based on storage class, the cluster administrator need to enable the DefaultStorageClass admission controller on the API server by passing DefaultStorageClass in a comma-delimited, ordered list of values for the –enable-admission-plugins flag of the API server component.

The syntax of a persistent volumes looks like below:

kind: PersistentVolume
apiVersion: v1
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/mnt/data"
Step 2: Create a Persistent Volume Claim (PVC)
A PVC is required to bind to a PV. Pods use PersistentVolumeClaims to request physical storage.  A PVC can specify a label selector to further filter the set of volumes. Only the volumes whose labels match the selector can be bound to the claim. Here is an example of a PVC.

kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: task-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
Step 3: Create a Pod to use PVC
The next step is to create a Pod that uses your PersistentVolumeClaim  to   mount a volume  at a specified mount point.

kind: Pod
apiVersion: v1
metadata:
  name: task-pv-pod
spec:
  volumes:
    - name: task-pv-storage
      persistentVolumeClaim:
       claimName: task-pv-claim
  containers:
    - name: task-pv-container
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: task-pv-storage
Deploy ROOK with a Ceph Cluster Backend
Now that we know what Rook is all about and some knowledge of how to connect your Pod to a persistent volume, let us create a Rook cluster with a Ceph backend. We will test the Rook deployment with 2 sample applications that  creates PV, PVC and some pods.  Let us follow the following plan:

 Deploy Rook Operator
 Create a Rook Cluster
Add Block Storage to Ceph
Verify Block Storage Operation
Step 1: Deploy Rook Operator
Remember that you need a working Kubernetes cluster to follow this tutorial. This tutorial uses a Kubernetes cluster of 1 Master node and 2 Worker Nodes, making a 3-node cluster.

On your master node:

$ git clone https://github.com/rook/rook.git
$ cd rook/cluster/examples/kubernetes/ceph
Deploy the Rook Operator
$ kubectl create -f operator.yaml
Verify Rook Operator
Check that the following pods are in Running state before proceeding:

rook-ceph-operator
rook-ceph-agent
rook-discover
$ kubectl get pods -n rook-ceph-system | grep Running
NAME READY STATUS RESTARTS AGE

rook-ceph-agent-btzrg 1/1 Running 11 9d
rook-ceph-agent-nhs6l 1/1 Running 11 9d
rook-ceph-operator-b996864dd-2rptc 1/1 Running 9 8d
rook-discover-7j78x 1/1 Running 7 9d
rook-discover-zfvkx 1/1 Running 8 9d
Step 2: Create a Rook Cluster
Open cluster.yaml and edit the file to use filestore instead of bluestore:

$ vi cluster.yaml
storage: # cluster level storage configuration and selection
    useAllNodes: true
    useAllDevices: false
    deviceFilter:
    location:
    config:
      # The default and recommended storeType is dynamically set to bluestore for devices and filestore for directories.
      # Set the storeType explicitly only if it is required not to use the default.
      # storeType: bluestore
      storeType: filestore

Create the storage cluster:
$ kubectl create -f cluster.yaml
Verify Rook Cluster
To see the list of running pods, use kubectl in the rook-ceph namespace. The number of object storage daemon(OSD) pods (refer to Ceph block architecture)  will depend on the number of nodes in the cluster and the number of devices and directories configured. To fully understand the roles performed by the pods, you will need an understanding of CEPH and how it works., which is not covered in this blog.

$ kubectl get pods -n rook-ceph | grep Running

NAME READY STATUS RESTARTS AGE
rook-ceph rook-ceph-mgr-a-7fcd6b6449-fljkt 1/1 Running 2 8d
rook-ceph rook-ceph-mon-g-565ff8cdf7-8fh4d 1/1 Running 2 8d
rook-ceph rook-ceph-mon-h-86f66b897-7fgjf 1/1 Running 2 8d
rook-ceph rook-ceph-mon-i-867d64c849-xp272 1/1 Running 2 8d
rook-ceph rook-ceph-osd-0-6495594f8d-2pf2z 1/1 Running 2 7d23h
rook-ceph rook-ceph-osd-1-7d694d4f5-thptb 1/1 Running 2 8d
rook-ceph rook-ceph-tools-76c7d559b6-gzpkz 1/1 Running 2 8d
Step 3: Add Block Storage
Now that Rook is up and running connected to a Ceph cluster backend, let us configure a storageclass to use the Block storage of Ceph. Block storage provides a traditional block storage device — like a hard drive – over the network. With the storage class created, one can provision a block storage device of any size and attach it to a pod. Once attached, it is treated like a normal hard disk. To make it ready for use, you need to format it with a filesystem of choice like Ext4, XFS or BtrFS. If desired, block volumes can combine multiple devices into a RAID array, or configure a database to write directly to the block device, avoiding filesystem overhead entirely.

Provision Storage
Open the file and make the following edit: size: 3 as shown below

vi storageclass.yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  replicated:
    size: 3
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: rook-ceph-block
provisioner: ceph.rook.io/block
parameters:
  blockPool: replicapool
  # Specify the namespace of the rook cluster from which to create volumes.
  # If not specified, it will use `rook` as the default namespace of the cluster.
  # This is also the namespace where the cluster will be
  clusterNamespace: rook-ceph
  # Specify the filesystem type of the volume. If not specified, it will use `ext4`.
  fstype: xfs
Create the storage class:
cd rook/cluster/examples/kubernetes/ceph
kubectl create -f storageclass.yaml
pool.ceph.rook.io/replicapool created
storageclass.storage.k8s.io/rook-ceph-block created
Step 4: Verify Block Storage Operation
Example 1: StatefulSets
Let us verify the configuration by creating a statefulset. The manifest file for a statefulset is below:

apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  selector:
    matchLabels:
      app: nginx # has to match .spec.template.metadata.labels
  serviceName: "nginx"
  replicas: 3 # by default is 1
  template:
    metadata:
      labels:
        app: nginx # has to match .spec.selector.matchLabels
    spec:
      terminationGracePeriodSeconds: 10
      containers:
      - name: nginx
        image: k8s.gcr.io/nginx-slim:0.8
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www 
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "rook-ceph-block"
      resources:
        requests:
          storage: 1Gi
kubectl create -f statefulsets.yaml
Kubectl get pods
NAME READY STATUS RESTARTS AGE
web-0 1/1 Running 1 3d
web-1 1/1 Running 1 3d
web-2 1/1 Running 1 3d
Example 2: WordPress and MySQL
In the rook folder you will find 2 yaml files for testing. One of them is mysql.yaml and the other one is wordpress.yaml. We want to ensure that the WordPress service is running on NodePort so let’s edit WordPress.yaml file and change the service type from
type: LoadBalancer to type: NodePort

apiVersion: v1
kind: Service
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  ports:
  - port: 80
  selector:
    app: wordpress
    tier: frontend
  type: NodePort
Let us create them

cd /root/rook/cluster/examples/kubernetes
kubectl create -f mysql.yaml
kubectl create -f wordpress.yaml

service/wordpress created
persistentvolumeclaim/wp-pv-claim created
deployment.apps/wordpress created

Kubectl get pods
wordpress-7b6c4c79bb-wj7l4 1/1 Running 0 6m45s
wordpress-mysql-6887bf844f-rxsbj 1/1 Running 0 7m4s
Based on the results of running the yaml files in examples 1 and  2 above, we have several persistent volumes (PV) and several persistent volume claims (PVC) created. All the yaml files have their corresponding PVC sections while the PVs were created automatically. A snippet is shown below for wordpress.yaml

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wp-pv-claim
  labels:
    app: wordpress
spec:
  storageClassName: rook-ceph-block
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
kubectl get pv
NAME CAPACITY ACCESS MODES RECLAIM POLICY STATUS CLAIM STORAGECLASS REASON AGE
pvc-8d2874c3-4607-11e9-af13-02d2ebb64d8b 20Gi RWO Delete Bound default/mysql-pv-claim  rook-ceph-block 8d 
pvc-d8867ba3-4dad-11e9-b844-02d2ebb64d8b 20Gi RWO Delete Bound default/wp-pv-claim rook-ceph-block 8d 
pvc-3922fb62-4754-11e9-a461-02d2ebb64d8b 1Gi RWO Delete Bound default/www-web-1 rook-ceph-block 8d
pvc-42f62b50-4754-11e9-a461-02d2ebb64d8b 1Gi RWO Delete Bound default/www-web-2 rook-ceph-block 8d
pvc-63779225-4752-11e9-a461-02d2ebb64d8b 1Gi RWO Delete Bound default/www-web-0 rook-ceph-block 8d

kubectl get pvc

NAME STATUS VOLUME CAPACITY ACCESS MODES STORAGECLASS AGE
mysql-pv-claim Bound pvc-8d2874c3-4607-11e9-af13-02d2ebb64d8b 20Gi RWO rook-ceph-block 9d
wp-pv-claim Bound pvc-d8867ba3-4dad-11e9-b844-02d2ebb64d8b 20Gi RWO rook-ceph-block 66s
www-web-0 Bound pvc-63779225-4752-11e9-a461-02d2ebb64d8b 1Gi RWO rook-ceph-block 8d
www-web-1 Bound pvc-3922fb62-4754-11e9-a461-02d2ebb64d8b 1Gi RWO rook-ceph-block 8d
www-web-2 Bound pvc-42f62b50-4754-11e9-a461-02d2ebb64d8b 1Gi RWO rook-ceph-block 8d
Now that WordPress and mysql have been deployed, let us attempt to configure WordPress. Since we run the service as a NodePort, we can access  WordPress  with 192.168.205.12:30704  where 192.168.205.12 is the IP address of one of the cluster nodes (can be any worker node)  and 30704 is the NodePort assigned to the WordPress service.

To obtain the NodePort, let us view the WordPress service.

kubectl get svc wordpress
wordpress NodePort 10.99.137.116 80:30704/TCP 10m
wordpress-mysql ClusterIP None 3306/TCP 9d

Putting this on the browser will start the WordPress installation/configuration:  192.168.205.12:30704


The Rook Toolbox Pod
The Rook toolbox is a container with common tools used for Rook debugging and testing.

cd root/rook/cluster/examples/kubernetes/ceph
kubectl apply -f toolbox.yaml

kubectl  get pods -n rook-ceph | grep tool
rook-ceph-tools-76c7d559b6-gzpkz         1/1     Running     2          8d
 

Once the rook-ceph-tools pod is running, you can connect to it with:

 
kubectl exec -it rook-ceph-tools-76c7d559b6-gzpkz -n rook-ceph /bin/bash
 

Available tools in the toolbox are ready for your troubleshooting needs.

ceph status,
ceph osd  status
ceph df
rados df
[root@k8s-node-1 /]# ceph status
  cluster:
    id:     1b6005ac-ff2f-49b3-86eb-0b986a0d5b40
    health: HEALTH_WARN
            Degraded data redundancy: 147/441 objects degraded (33.333%), 70 pgs degraded, 100 pgs undersized
            mons m,n,o are low on available space
 
  services:
    mon: 3 daemons, quorum n,m,o
    mgr: a(active)
    osd: 2 osds: 2 up, 2 in
 
  data:
    pools:   1 pools, 100 pgs
    objects: 147  objects, 271 MiB
    usage:   15 GiB used, 4.2 GiB / 19 GiB avail
    pgs:     147/441 objects degraded (33.333%)
             70 active+undersized+degraded
             30 active+undersized
[root@k8s-node-1 /]# ceph osd status
+----+------------+-------+-------+--------+---------+--------+---------+-----------+
| id |    host    |  used | avail | wr ops | wr data | rd ops | rd data |   state   |
+----+------------+-------+-------+--------+---------+--------+---------+-----------+
| 0  | k8s-node-1 | 8170M | 1691M |    0   |     0   |    0   |     0   | exists,up |
| 1  | k8s-node-2 | 7218M | 2643M |    0   |     0   |    0   |     0   | exists,up |
+----+------------+-------+-------+--------+---------+--------+---------+-----------+
[root@k8s-node-1 /]# ceph df
GLOBAL:
    SIZE       AVAIL       RAW USED     %RAW USED 
    19 GiB     4.2 GiB       15 GiB         78.01 
POOLS:
    NAME            ID     USED        %USED     MAX AVAIL     OBJECTS 
    replicapool     1      271 MiB     18.39       800 MiB         147 

[root@k8s-node-1 /]# rados df
POOL_NAME      USED OBJECTS CLONES COPIES MISSING_ON_PRIMARY UNFOUND DEGRADED RD_OPS     RD WR_OPS      WR 
replicapool 271 MiB     147      0    441                  0       0      147   4251 40 MiB   4169 379 MiB 

total_objects    147
total_used       15 GiB
total_avail      4.2 GiB
total_space      19 GiB

