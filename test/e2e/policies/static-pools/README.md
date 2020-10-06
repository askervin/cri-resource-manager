# E2E static-pools policy test

## Requirements

This test requires `containerd` version v1.4 or later. Earlier
versions fail to mount container images built on top of clear linux
base image. That includes mounting cri-resmgr-webhook.

`cri-resmgr-webhook` image must be present on host (`make
images`). The latest image will be installed on VM.

## Test structure

Kubernetes is installed on VM when `cri-resmgr` is running the `none`
policy.

Tests start by relaunching `cri-resmgr` in `static-pools` policy. At
that point it is possible to change command line arguments via
`cri_resmgr_extra_args`.
