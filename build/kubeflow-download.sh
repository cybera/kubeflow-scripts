KUBEFLOW_VERSION="master"

rm -rf kubeflow || true
git clone https://github.com/kubeflow/kubeflow/
cd kubeflow
git checkout $KUBEFLOW_VERSION
