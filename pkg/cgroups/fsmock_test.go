package cgroups

import (
	_ "fmt"
	"os"
	"path/filepath"
	"sort"
	"testing"
)

var fsMockUtFiles map[string]mockFile = map[string]mockFile{
	"/my/emptyfile": {},
	"/my/emptydir": {
		info: &mockFileInfo{mode: os.ModeDir},
	},
	"/my/dir/data0": {data: []byte("abc")},
	"/my/dir/data1": {data: []byte("xyz")},
}

func TestWalk(t *testing.T) {
	fs := NewFSMock(fsMockUtFiles)
	foundNotInMyDir := []string{}
	fs.Walk("/", func(path string, info os.FileInfo, err error) error {
		if filepath.Base(path) == "dir" {
			return filepath.SkipDir
		}
		foundNotInMyDir = append(foundNotInMyDir, path)
		return nil
	})
	sort.Strings(foundNotInMyDir)
	validateStrings(t, []string{"/", "/my", "/my/emptydir", "/my/emptyfile"}, foundNotInMyDir)
}

func TestReadWrite(t *testing.T) {
	fs := NewFSMock(fsMockUtFiles)
	f, err := fs.OpenFile("/my/dir/data0", os.O_WRONLY, 0)
	validateError(t, "", err)
	f.Write([]byte{})
	f.Write([]byte("01"))
	info, err := fs.Lstat("/my/dir/data0")
	if info.Size() != 3 {
		t.Errorf("expected file size %d, got %d", 3, info.Size())
	}
	f.Write([]byte("23"))
	if info.Size() != 4 {
		t.Errorf("expected file size %d, got %d", 4, info.Size())
	}
	f.Close()
	f, err = fs.OpenFile("/my/dir/data0", os.O_RDONLY, 0)
	validateError(t, "", err)
	buf := make([]byte, 10, 10)
	bytes, err := f.Read(buf)
	validateError(t, "", err)
	if bytes != 4 {
		t.Errorf("expected to read %d bytes, Read returned %d", 4, bytes)
	}
	validateStrings(t, []string{"0123"}, []string{string(buf[:bytes])})
}
