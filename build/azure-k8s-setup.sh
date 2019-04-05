name=k8s-1
if [[ -n $1 ]]; then
  name=$1-k8s-1
fi

az group create -n $name -l westus2
az aks create --node-vm-size Standard_NC6 --resource-group $name --name $name --node-count 3 --location "West US 2" --generate-ssh-keys
rm ~/.kube/config || true
az aks get-credentials --name $name --resource-group $name
kubectl apply -f https://raw.githubusercontent.com/nvidia/k8s-device-plugin/v1.12/nvidia-device-plugin.yml
kubectl create -f build/rbac/helm.yml
helm init --service-account tiller

# Pre-pull Tensorflow Images
kubectl apply -f build/ds/images.yml

sleep 30

ready=
while [[ -z $ready ]]; do
  kubectl get pods | grep -q Init
  if [[ $? == 1 ]]; then
    ready=1
  else
    echo "Images are still downloading..."
  fi
  sleep 10
done
