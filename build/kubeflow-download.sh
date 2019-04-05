KUBEFLOW_VERSION="v0.4.1"

rm -rf kubeflow || true
git clone https://github.com/kubeflow/kubeflow/
cd kubeflow
git checkout $KUBEFLOW_VERSION
