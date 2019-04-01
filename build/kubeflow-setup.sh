set -x

KUBEFLOW_SRC=$(pwd)/kubeflow

# Initialize a kubeflow app
KFAPP=kf
${KUBEFLOW_SRC}/scripts/kfctl.sh init ${KFAPP} --platform none

# Generate kubeflow app
cd ${KFAPP}
${KUBEFLOW_SRC}/scripts/kfctl.sh generate platform

# Deploy Kubeflow app
${KUBEFLOW_SRC}/scripts/kfctl.sh generate k8s
${KUBEFLOW_SRC}/scripts/kfctl.sh apply k8s

# Customize Kubeflow
cd ks_app

# Delete spartakus
ks delete default -c spartakus
kubectl -n kubeflow delete deploy -l app=spartakus
ks component rm spartakus

# Delete openvino
#ks delete default -c openvino
#kubectl -n kubeflow delete deploy -l app=openvino
#ks component rm openvino

# Install seldon
ks pkg install kubeflow/seldon
ks generate seldon seldon
ks apply default -c seldon

# Configure PVC
kubectl -n kubeflow create -f ${KUBEFLOW_SRC}/../build/storage/azurefile.yml

kubectl -n kubeflow create secret generic minio-creds --from-literal=accesskey=minio --from-literal=secretkey=minio123
