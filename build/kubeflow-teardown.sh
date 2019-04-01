KUBEFLOW_SRC=$(pwd)/kubeflow
KFAPP=kf

# Delete Kubeflow app
cd ${KFAPP}
${KUBEFLOW_SRC}/scripts/kfctl.sh delete k8s
cd ..
rm -rf ${KFAPP}

kubectl delete crd --all
