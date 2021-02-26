package cgroups

import (
	"os"
	"path/filepath"
)

type fsOs struct{}

type osFile struct {
	file *os.File
}

func (fsOs) OpenFile(name string, flag int, perm os.FileMode) (fileIface, error) {
	f, err := os.OpenFile(name, flag, perm)
	return osFile{f}, err
}

func (fsOs) Open(name string) (fileIface, error) {
	f, err := os.Open(name)
	return osFile{f}, err
}

func (fsOs) Lstat(name string) (os.FileInfo, error) {
	return os.Lstat(name)
}

func (fsOs) Walk(root string, walkFn filepath.WalkFunc) error {
	return filepath.Walk(root, walkFn)
}

func (osf osFile) Write(b []byte) (n int, err error) {
	return osf.file.Write(b)
}

func (osf osFile) Read(b []byte) (n int, err error) {
	return osf.file.Read(b)
}

func (osf osFile) Close() error {
	return osf.file.Close()
}
