
nodeName:
we can schedule the pods by selecting nodeName: <Node_name> in deployment it will schedule the pods on particular node


nodeselector:
scheduling the pods on particular node with matching  labels



Defining Affinity and anti-affinity 
Affinity: the pod's scheduling constraints

NodeAffinity	Describes node affinity scheduling rules for the pod.

PodAffinity	Describes pod affinity scheduling rules (e.g. co-locate this pod in the same node, zone, etc. as some other pod(s)).

PodAntiAffinity	Describes pod anti-affinity scheduling rules (e.g. avoid putting this pod in the same node, zone, etc. as some other pod(s)).

nodeAffinity:
 scheduling pods on node by Matchexpressions and labels
podAffinity:
 

Taints and Tolerations:
Taints and tolerations work together to ensure that pods are not scheduled onto inappropriate nodes

One or more taints are applied to a node; this marks that the node should not accept any pods that do not tolerate the taints. 

Tolerations are applied to pods, and allow (but do not require) the pods to schedule onto nodes with matching taints on nodes which applied..

kubectl taint nodes node1 key1=value1:NoSchedule
kubectl taint nodes node1 key1=value1:NoExecute
kubectl taint nodes node1 key2=value2:NoSchedule

Taint Node
kubectl taint node node2 dedicated=worker:NoExecute

Untaint Node
kubectl taint node worker-node2 dedicated:NoExecute-

liveness Probe:
Liveness probe checks the status of the pod(whether it is running or not). If livenessProbe fails, then the pod is subjected to its restart policy. The default state of livenessProbe is Success

Readiness Probe: 
Readiness probe checks whether your application is ready to serve the requests. When the readiness probe fails, the pod's IP is removed from the end point list of the service. The default state of readinessProbe is Success.
