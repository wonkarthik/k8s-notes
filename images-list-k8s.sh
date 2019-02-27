#!/bin/bash
# list-all-running-container-images in Kubernetes Cluster
kubectl get pods --all-namespaces -o jsonpath="{..image}" |\
tr -s '[[:space:]]' '\n' |\
sort |\
uniq -c
