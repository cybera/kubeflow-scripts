# Kubeflow Scripts

These are a handful of scripts and commands for using testing Kubeflow internally. Not suitable for general purpose.

## Requirements

You'll need a handful of other commands installed:

* `make`
* A Docker hub account with Docker installed on your workstation

And also the following:

```
brew update && brew install azure-cli
brew install source-to-image
brew install ksonnet/tap/ks
brew install kubernetes-cli
brew install kubernetes-helm
pip3 install https://storage.googleapis.com/ml-pipeline/release/0.1.12/kfp.tar.gz --upgrade
```

Next, make sure you have logged in to Azure by doing:

```
az login
```

And to Docker, too:

```
docker login
```

Next, do:

```
make kubeflow/examples/download
make kubeflow/download
```

## Deploying a GPU-enabled Kubernetes cluster in Azure

Run:

```
make azure/setup NAME=jdoe
```

## Deploying Kubeflow

Run:

```
make kubeflow/setup
```

## Tearing things down - DO NOT FORGET TO DO THIS!!

When you are finished, make sure you tear down your environment as to not incur excessive charges:

```
make kubeflow/teardown
make azure/teardown NAME=jdoe
```

## Next

* [Github Summarization exercise](https://github.com/cybera/kubeflow-examples/blob/cybera-modifications/github_issue_summarization/01_setup_a_kubeflow_cluster.md)
* [Object Detection exercise](https://github.com/cybera/kubeflow-examples/blob/cybera-modifications/object_detection/setup.md)
