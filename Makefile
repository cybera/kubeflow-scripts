CURDIR := $(shell pwd)

check-checkpoint:
ifndef CHECKPOINT
	$(error CHECKPOINT is required)
endif

check-docker-username:
ifndef DOCKER_USERNAME
	$(error DOCKER_USERNAME is required)
endif

check-model-path:
ifndef MODEL_PATH
	$(error MODEL_PATH is required)
endif

check-name:
ifndef NAME
	$(error NAME is required)
endif

check-pvc:
ifndef PVC
	$(error PVC is required)
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

k8s/logs: check-name
	kubectl -n kubeflow logs $(NAME)

k8s/jobs:
	kubectl -n kubeflow get jobs

k8s/nodes/gpu:
	kubectl get nodes "-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"

k8s/pod: check-name
	kubectl -n kubeflow describe pod $(NAME)

k8s/pods:
	kubectl -n kubeflow get pods

k8s/tfjob: check-name
	kubectl -n kubeflow describe tfjobs $(NAME)

k8s/tfjobs:
	kubectl -n kubeflow get tfjobs

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

forward/tf: check-name
	kubectl -n kubeflow port-forward svc/$(NAME) 8000:8000

tf/serve: check-name check-model-path check-pvc
	cd $(CURDIR)/kf/ks_app ; \
	ks generate tf-serving $(NAME) --name $(NAME) ; \
	ks param set $(NAME) modelPath "/mnt/$(MODEL_PATH)" ; \
	ks param set $(NAME) modelStorageType "nfs" ; \
	ks param set $(NAME) numGpus 1  ; \
	ks param set $(NAME) nfsPVC $(PVC) ; \
	ks param set $(NAME) deployHttpProxy true
	ks apply default -c $(NAME)

github/model/download: check-name
	PODNAME=$(shell kubectl get pods --namespace=kubeflow --selector="notebook-name=$(NAME)" --output=template --template="{{with index .items 0}}{{.metadata.name}}{{end}}") ; \
	cd $(CURDIR)/examples/github_issue_summarization/notebooks ; \
	echo $$PODNAME ; \
	kubectl --namespace=kubeflow cp $$PODNAME:/home/jovyan/examples/github_issue_summarization/notebooks/seq2seq_model_tutorial.h5 . ; \
	kubectl --namespace=kubeflow cp $$PODNAME:/home/jovyan/examples/github_issue_summarization/notebooks/body_pp.dpkl . ; \
	kubectl --namespace=kubeflow cp $$PODNAME:/home/jovyan/examples/github_issue_summarization/notebooks/title_pp.dpkl .

github/model/build-image: check-docker-username check-tag
	cd $(CURDIR)/examples/github_issue_summarization/notebooks ; \
	make build-model-image PROJECT=$(DOCKER_USERNAME) TAG=$(TAG)

github/model/push-image: check-docker-username check-tag
	docker push $(DOCKER_USERNAME)/issue-summarization-model:$(TAG)

github/model/serve-image: check-docker-username check-tag
	cd $(CURDIR)/kf/ks_app ; \
	ks generate seldon-serve-simple-v1alpha2 issue-summarization-model --name=issue-summarization --image=$(DOCKER_USERNAME)/issue-summarization-model:$(TAG) --replicas=1 ; \
	ks apply default -c issue-summarization-model

github/ui/build: check-token check-docker-username
	cd $(CURDIR)/examples/github_issue_summarization/docker ; \
	docker build -t $(DOCKER_USERNAME)/issue-summarization-ui:0.1 . ; \
	docker push $(DOCKER_USERNAME)/issue-summarization-ui:0.1 ; \
	cd ../ks_app ; \
	ks env add default --context=$(kubectl config current-context) ; \
	ks env set default --namespace kubeflow ; \
	ks param set ui github_token $(TOKEN) ; \
	ks param set ui modelUrl "http://issue-summarization.kubeflow.svc.cluster.local:8000/api/v0.1/predictions" ; \
	ks apply default -c ui

pets/pvc/create:
	cd $(CURDIR)/examples/object_detection/ks-app ; \
	ks env add default --context=$(kubectl config current-context) ; \
	ks env set default --namespace kubeflow ; \
	ks param set pets-pvc accessMode "ReadWriteMany" ; \
	ks param set pets-pvc storage "21Gi" ; \
	ks apply default -c pets-pvc

pets/data/create:
	cd $(CURDIR)/examples/object_detection/ks-app ; \
	ks param set get-data-job mountPath "/pets_data" ; \
	ks param set get-data-job pvc "pets-pvc" ; \
	ks param set get-data-job urlData "http://www.robots.ox.ac.uk/~vgg/data/pets/data/images.tar.gz" ; \
	ks param set get-data-job urlAnnotations "http://www.robots.ox.ac.uk/~vgg/data/pets/data/annotations.tar.gz" ; \
	ks param set get-data-job urlModel "http://download.tensorflow.org/models/object_detection/faster_rcnn_resnet101_coco_2018_01_28.tar.gz" ; \
	ks param set get-data-job urlPipelineConfig "https://raw.githubusercontent.com/kubeflow/examples/master/object_detection/conf/faster_rcnn_resnet101_pets.config" ; \
	ks apply default -c get-data-job

pets/data/decompress:
	cd $(CURDIR)/examples/object_detection/ks-app ; \
	ks param set decompress-data-job mountPath "/pets_data" ; \
	ks param set decompress-data-job pvc "pets-pvc" ; \
	ks param set decompress-data-job pathToAnnotations "/pets_data/annotations.tar.gz" ; \
	ks param set decompress-data-job pathToDataset "/pets_data/images.tar.gz" ; \
	ks param set decompress-data-job pathToModel "/pets_data/faster_rcnn_resnet101_coco_2018_01_28.tar.gz" ; \
	ks apply default -c decompress-data-job

pets/data/record:
	cd $(CURDIR)/examples/object_detection/ks-app ; \
	ks param set create-pet-record-job image "lcastell/pets_object_detection" ; \
	ks param set create-pet-record-job dataDirPath "/pets_data" ; \
	ks param set create-pet-record-job outputDirPath "/pets_data" ; \
	ks param set create-pet-record-job mountPath "/pets_data" ; \
	ks param set create-pet-record-job pvc "pets-pvc" ; \
	ks apply default -c create-pet-record-job

pets/tf/image: check-docker-username
	cd $(CURDIR)/examples/object_detection/docker ; \
	docker build --pull -t $(DOCKER_USERNAME)/pets_object_detection -f ./Dockerfile.training . ; \
	docker push $(DOCKER_USERNAME)/pets_object_detection

pets/tf/deploy:
	cd $(CURDIR)/examples/object_detection/ks-app ; \
	ks param set tf-training-job image "lcastell/pets_object_detection" ; \
	ks param set tf-training-job mountPath "/pets_data" ; \
	ks param set tf-training-job pvc "pets-pvc" ; \
	ks param set tf-training-job numPs 1 ; \
	ks param set tf-training-job numWorkers 1 ; \
	ks param set tf-training-job pipelineConfigPath "/pets_data/faster_rcnn_resnet101_pets.config" ; \
	ks param set tf-training-job trainDir "/pets_data/train" ; \
	ks param set tf-training-job numGpu 1 ; \
	ks apply default -c tf-training-job

pets/tf/delete:
	cd $(CURDIR)/examples/object_detection/ks-app ; \
	ks delete default -c tf-training-job

pets/model/export: check-checkpoint
	cd $(CURDIR)/examples/object_detection/ks-app ; \
	ks param set export-tf-graph-job mountPath "/pets_data" ; \
	ks param set export-tf-graph-job pvc "pets-pvc" ; \
	ks param set export-tf-graph-job image "lcastell/pets_object_detection" ; \
	ks param set export-tf-graph-job pipelineConfigPath "/pets_data/faster_rcnn_resnet101_pets.config" ; \
	ks param set export-tf-graph-job trainedCheckpoint "/pets_data/train/$(CHECKPOINT)" ; \
	ks param set export-tf-graph-job outputDir "/pets_data/exported_graphs/1" ; \
	ks param set export-tf-graph-job inputType "image_tensor" ; \
	ks apply default -c export-tf-graph-job

pets/model/predict: check-name
	cd $(CURDIR)/examples/object_detection/serving_script ; \
		python predict.py --url=
