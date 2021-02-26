package cgroups

import (
	"io"
	"strings"
	"syscall"
	"testing"
)

func validateStrings(t *testing.T, expected []string, got []string) bool {
	if len(expected) != len(got) {
		t.Errorf("Expected string slice of length %d, got %d", len(expected), len(got))
		return false
	}
	for i, es := range expected {
		if es != got[i] {
			t.Errorf("Slices differ: expected[%d]=%q, got[%d]=%q", i, es, i, got[i])
			return false
		}
	}
	return true
}

func validateError(t *testing.T, expectedError string, err error) bool {
	if expectedError != "" {
		if err == nil {
			t.Errorf("Expected error containing %q, did not get any error", expectedError)
			return false
		} else if !strings.Contains(err.Error(), expectedError) {
			t.Errorf("Expected error containing %q, but got %q", expectedError, err.Error())
			return false
		}
	} else {
		if err != nil {
			t.Errorf("Unexpected error %s", err)
			return false
		}
	}
	return true
}

var cpuacctMyGroupTasks string = ""
var testfiles fsiIface = NewFSMock(map[string]mockFile{
	"/sys/fs/cgroup/blkio/kubepods/tasks": {
		data: []byte("1\n23\n4567890\n"),
	},
	"/sys/fs/cgroup/cpu/open/permission/denied/cgroup.procs": {
		// simulate open permission denied
		open: func(string) (fileIface, error) {
			return nil, syscall.EACCES
		},
	},
	"/sys/fs/cgroup/cpuacct/store/all/writes/tasks": {
		// everything that is written can be read
		// (no overwrite / truncate)
		write: func(b []byte) (int, error) {
			cpuacctMyGroupTasks = cpuacctMyGroupTasks + string(b) + "\n"
			return len(b), nil
		},
		read: func(b []byte) (int, error) {
			if len(cpuacctMyGroupTasks) == 0 {
				return 0, io.EOF
			}
			bytes := len(cpuacctMyGroupTasks)
			copy(b, []byte(cpuacctMyGroupTasks))
			cpuacctMyGroupTasks = ""
			return bytes, nil
		},
	},
	"/sys/fs/cgroup/cpuset/read/io/error/tasks": {
		// every read causes I/O error
		read: func(b []byte) (int, error) {
			return 0, syscall.EIO
		},
	},
	"/sys/fs/cgroup/devices/write/io/error/cgroup.procs": {
		// every write causes I/O error
		write: func(b []byte) (int, error) {
			return 0, syscall.EIO
		},
	},
})

func TestGetTasks(t *testing.T) {
	fsi = testfiles
	tasks, err := Blkio.Group("kubepods").GetTasks()
	validateError(t, "", err)
	validateStrings(t, []string{"1", "23", "4567890"}, tasks)
}

func TestGetProcesses(t *testing.T) {
	fsi = testfiles
	_, err := Cpu.Group("open/permission/denied").GetProcesses()
	validateError(t, "permission denied", err)
}

func TestAddTasks(t *testing.T) {
	fsi = testfiles
	if err := Cpuacct.Group("store/all/writes").AddTasks("0", "987654321"); !validateError(t, "", err) {
		return
	}
	if err := Cpuacct.Group("store/all/writes").AddTasks(); !validateError(t, "", err) {
		return
	}
	if err := Cpuacct.Group("store/all/writes").AddTasks("12"); !validateError(t, "", err) {
		return
	}
	tasks, err := Cpuacct.Group("store/all/writes").GetTasks()
	validateError(t, "", err)
	validateStrings(t, []string{"0", "987654321", "12"}, tasks)
}

func TestAddProcesses(t *testing.T) {
	fsi = testfiles
	err := Devices.Group("write/io/error").AddProcesses("1")
	validateError(t, "input/output error", err)
	err = Freezer.Group("file/not/found").AddProcesses("1")
	validateError(t, "file not found", err)
}

func TestAsGroup(t *testing.T) {
	memGroupIn := Memory.Group("my/memory")
	memGroupOut := AsGroup(string(memGroupIn))
	validateStrings(t, []string{string(memGroupIn)}, []string{string(memGroupOut)})
}

func TestGroupToController(t *testing.T) {
	c := Hugetlb.Group("my/group").Controller()
	validateStrings(t, []string{"hugetlb"}, []string{c.String()})
}

func TestRelPath(t *testing.T) {
	relPath := NetCls.RelPath()
	validateStrings(t, []string{"net_cls"}, []string{relPath})
}
