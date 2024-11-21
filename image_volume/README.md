# Using ImageVolume (OCI Artifact) Volumes in Kubernetes

- To use Kubernetes 1.31 (find tags @ https://hub.docker.com/r/rancher/k3s)
- https://kubernetes.io/blog/2024/08/16/kubernetes-1-31-image-volume-source/
- https://github.com/k3d-io/k3d/blob/main/docs/faq/faq.md#passing-additional-argumentsflags-to-k3s-and-on-to-eg-the-kube-apiserver

```shell
k3d cluster create playground \
  --image rancher/k3s:v1.31.2-k3s1 \
  --k3s-arg '--kube-apiserver-arg=feature-gates=ImageVolume=true@server:*' \
  --k3s-arg '--kubelet-arg=feature-gates=ImageVolume=true@server:*'

#  --k3s-arg '--kubelet-arg=feature-gates=ImageVolume=true@agent:*'

kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: readonly-oci-volume-pod
spec:
  containers:
    - name: test
      image: registry.k8s.io/e2e-test-images/echoserver:2.3
      volumeMounts:
        - name: volume
          mountPath: /volume
  volumes:
    - name: volume
      image:
        reference: busybox:latest
        pullPolicy: IfNotPresent
EOF

```
