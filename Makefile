CURDIR := $(shell pwd)

check-docker-username:
ifndef DOCKER_USERNAME
	$(error DOCKER_USERNAME is required)
endif

check-name:
ifndef NAME
	$(error NAME is required)
endif

check-tag:
ifndef TAG
	$(error TAG is required)
endif

check-token:
ifndef TOKEN
	$(error TOKEN is required)
endif

direnv/allow:
	direnv allow .

azure/setup: check-name
	bash build/azure-k8s-setup.sh $(NAME)

azure/teardown:
	bash build/azure-k8s-teardown.sh $(NAME)

azure/teardown/nowait:
	bash build/azure-k8s-teardown.sh $(NAME) no-wait

k8s/nodes/gpu:
	kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"

k8s/pods:
	kubectl -n kubeflow get pods

kubeflow/examples/download:
	git clone https://github.com/cybera/kubeflow-examples examples
	cd examples
	git checkout --track cybera-modifications

kubeflow/download:
	bash build/kubeflow-download.sh

kubeflow/setup:
	bash build/kubeflow-setup.sh

kubeflow/teardown:
	bash build/kubeflow-teardown.sh

forward/minio:
	kubectl -n kubeflow port-forward svc/minio-service 9000:9000

forward/dashboard:
	kubectl -n kubeflow port-forward svc/ambassador 8080:80

forward/argo:
	kubectl -n kubeflow port-forward svc/argo-ui 8080:80

example1/model/download: check-name
	PODNAME=$(shell kubectl get pods --namespace=kubeflow --selector="notebook-name=$(NAME)" --output=template --template="{{with index .items 0}}{{.metadata.name}}{{end}}") ; \
	cd $(CURDIR)/examples/github_issue_summarization/notebooks ; \
	echo $$PODNAME ; \
	kubectl --namespace=kubeflow cp $$PODNAME:/home/jovyan/examples/github_issue_summarization/notebooks/seq2seq_model_tutorial.h5 . ; \
	kubectl --namespace=kubeflow cp $$PODNAME:/home/jovyan/examples/github_issue_summarization/notebooks/body_pp.dpkl . ; \
	kubectl --namespace=kubeflow cp $$PODNAME:/home/jovyan/examples/github_issue_summarization/notebooks/title_pp.dpkl .

example1/model/build-image: check-docker-username check-tag
	cd $(CURDIR)/examples/github_issue_summarization/notebooks ; \
	make build-model-image PROJECT=$(DOCKER_USERNAME) TAG=$(TAG)

example1/model/push-image: check-docker-username check-tag
	docker push $(DOCKER_USERNAME)/issue-summarization-model:$(TAG)

example1/model/serve-image: check-docker-username check-tag
	cd $(CURDIR)/kf/ks_app ; \
	ks generate seldon-serve-simple-v1alpha2 issue-summarization-model --name=issue-summarization --image=$(DOCKER_USERNAME)/issue-summarization-model:$(TAG) --replicas=1 ; \
	ks apply default -c issue-summarization-model

example1/ui/build: check-token
	SERVER="$(shell grep server: kf/ks_app/app.yaml | sed -e 's/^[[:space:]]*//')"  ; \
	cd $(CURDIR)/examples/github_issue_summarization/docker ; \
	docker build -t jtopjian/issue-summarization-ui:0.1 . ; \
	docker push jtopjian/issue-summarization-ui:0.1 ; \
	cd ../ks_app ; \
	sed -i -e "s,server: .*,$$SERVER," app.yaml ; \
	ks param set ui github_token $(TOKEN) ; \
	ks param set ui modelUrl "http://issue-summarization.kubeflow.svc.cluster.local:8000/api/v0.1/predictions" ; \
	ks apply default -c ui
