# CRI Resource Manager - NUMA node tests

## Usage

```
[VAR=VALUE...] ./run.sh MODE
```

Get help with `./run.sh`.

## Two modes: `test` and `play`

`test` mode runs fast and, by default, cleans up everything after test
run: the virtual machine with the contents will be lost.

`play` mode runs slower and, by default, leaves the virtual machine
running.

## Examples

### Make local build and run tests against it
```
cri-resource-manager$ make
cri-resource-manager$ cd test/numa
numa$ reinstall_cri_resmgr=1 ./run.sh play
```

### Run tests against the cri-resmgr built from the GitHub master branch
```
numa$ reinstall_cri_resmgr=1 binsrc=github ./run.sh play
```

`cri-resource-manager` project is cloned and built inside the VM. This does
not affect the local `git` repository.

### Run tests in a VM with two NUMA nodes, 4 CPUs and 4G RAM in each node
```
numa$ vm=my2x4 numanodes='[{"cpu":4,"mem":"4G","nodes":2}]' ./run.sh play
```
