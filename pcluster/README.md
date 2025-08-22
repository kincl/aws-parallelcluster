# cluster

```
pcluster create-cluster --cluster-name cluster --cluster-configuration cluster-config.yaml
watch pcluster describe-cluster --cluster-name cluster
pcluster ssh --cluster-name cluster
pcluster delete-cluster --cluster-name cluster
```

# image build

```
aws s3 cp post_install.sh s3://jkincl-pcluster/

# if needed
# pcluster delete-image -i my-centos7
pcluster build-image -c imagebuilder.yaml -i my-centos7 -r us-east-2
watch pcluster describe-image -i my-centos7 -r us-east-2
```
