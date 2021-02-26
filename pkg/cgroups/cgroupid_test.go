package cgroups

import (
	"os"
	"testing"
)

var cgroupidTestFS = NewFSMock(map[string]mockFile{
	"/imaginary/sys/fs/cgroup/unified/cgroup.controllers": {}, // empty file
	"/imaginary/sys/fs/cgroup/systemd/kubepods": { // empty directory
		info: &mockFileInfo{
			mode: os.ModeDir,
		},
	},
})

func TestFind(t *testing.T) {
	fsi = cgroupidTestFS
	cgid := NewCgroupID("/")
	_, err := cgid.Find(404)
	validateError(t, "cgroupid 404 not found", err)
}
