name=k8s-1
if [[ -n $1 ]]; then
  name=$1-k8s-1
fi

nowait=
if [[ $2 == "no-wait" ]]; then
  nowait="--no-wait"
fi


az group delete -y -n $name $nowait
rm ~/.kube/config || true
