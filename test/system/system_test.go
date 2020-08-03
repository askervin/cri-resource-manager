// Copyright 2020 Intel Corporation. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// Tests for CRI-RM as part of full system.
//
// These tests execute cri-resource-manager/test/*/run.sh scripts
// that take care of virtual machines, Kubernetes setups, etc.
//
// Example: run all tests without timeout (setting up VMs is slow):
// $ go test -v -timeout=0
//
// Example: run only 3xcpu2mem2G... NUMA test:
// $ go test -v -timeout=0 -run TestExclusiveCPUs/3xcpu2mem2G

package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

type TestCommand struct {
	Command            exec.Cmd
	ExpectedSubstrings []string
	LogFilename        string
}

type NumaNodes []struct {
	CPU         int    `json:"cpu,omitempty"`
	Mem         string `json:"mem,omitempty"`
	Nvmem       string `json:"nvmem,omitempty"`
	Nodes       int    `json:"nodes,omitempty"`
	DistGroup   int    `json:"dist-group,omitempty"`
	DistToGroup int    `json:"dist-to-group,omitempty"`
	DistNode    int    `json:"dist-node,omitempty"`
	DistToNode  int    `json:"dist-to-node,omitempty"`
	Dist        int    `json:"dist,omitempty"`
}

const (
	testOutputDirPrefix = "/tmp/cri-rm-test"
	testVerdictPass     = "Test verdict: PASS"
	testVerdictFail     = "Test verdict: FAIL"
)

func lastCommands(outputDir string) string {
	commandsPattern := outputDir + "/commands/0*"
	matches, err := filepath.Glob(commandsPattern)
	if err != nil {
		return fmt.Sprintf("[error fetching commands %q: %s]", commandsPattern, err)
	}
	sort.Strings(matches)
	commandOutErr := "Last commands:"
	if len(matches) >= 2 {
		if content, err := ioutil.ReadFile(matches[len(matches)-2]); err == nil {
			commandOutErr = commandOutErr + "\n" + matches[len(matches)-2] + ":\n" + string(content)
		}
	}
	if len(matches) >= 1 {
		if content, err := ioutil.ReadFile(matches[len(matches)-1]); err == nil {
			commandOutErr = commandOutErr + "\n" + matches[len(matches)-1] + ":\n" + string(content)
		}
	}
	return commandOutErr
}

func runTestCommand(t *testing.T, tc TestCommand) {
	outputDir := filepath.Dir(tc.LogFilename) // TODO: This is ugly, use proper outputdir
	if err := os.MkdirAll(filepath.Dir(tc.LogFilename), 0775); err != nil {
		t.Errorf("cannot create test output directory for %q", tc.LogFilename)
		return
	}
	if f, err := os.OpenFile(tc.LogFilename, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0666); err == nil {
		fmt.Fprintf(f, "environ:\n")
		for _, envVar := range tc.Command.Env {
			fmt.Fprintf(f, "%s\n", envVar)
		}
		fmt.Fprintf(f, "\n")
		f.Close()
	} else {
		t.Errorf("cannot write test log to %q: %v", tc.LogFilename, err)
	}

	bOutErr, err := tc.Command.CombinedOutput()
	sOutErr := string(bOutErr)
	if err != nil {
		t.Errorf("failed to run %q: %v, log %q, %s", tc.Command.Args, err, tc.LogFilename, lastCommands(outputDir))
		return
	}
	if f, err := os.OpenFile(tc.LogFilename, os.O_WRONLY|os.O_APPEND, 0666); err == nil {
		fmt.Fprintf(f, sOutErr)
		f.Close()
	}
	if strings.Contains(sOutErr, testVerdictFail) {
		t.Errorf("run.sh reported %q. %s", testVerdictFail, lastCommands(outputDir))
	} else if strings.Contains(sOutErr, testVerdictPass) {
		t.Logf("run.sh reported %q", testVerdictPass)
	} else {
		t.Errorf("run.sh did not report %q. %s", testVerdictPass, lastCommands(outputDir))
	}
}

// TestBlockIO runs demo/blockio/run.sh.
func TestBlockIO(t *testing.T) {
	testOutputDir := testOutputDirPrefix + "/system/blockio"
	tc := TestCommand{
		Command: exec.Cmd{
			Path: "./run.sh",
			Args: []string{"./run.sh", "test"},
			Dir:  "../../demo/blockio",
			Env: append(os.Environ(),
				"vm=crirm-test-system-blockio",
				"binsrc=local",
				"cleanup=1",
				"speed=1000",
				"outdir="+testOutputDir,
			),
		},
		LogFilename: testOutputDir + "/run.log",
	}
	runTestCommand(t, tc)
}

// TestCritest runs test/critest/run.sh.
func TestCritest(t *testing.T) {
	testOutputDir := testOutputDirPrefix + "/system/critest"
	tc := TestCommand{
		Command: exec.Cmd{
			Path: "./run.sh",
			Args: []string{"./run.sh", "test"},
			Dir:  "../../test/critest",
			Env: append(os.Environ(),
				"vm=crirm-test-system-critest",
				"binsrc=local",
				"cleanup=1",
				"speed=1000",
				"outdir="+testOutputDir,
			),
		},
		LogFilename: testOutputDir + "/run.log",
	}
	runTestCommand(t, tc)
}

// TestExclusiveCPUs runs test/numa/run.sh with different NUMA configurations.
func TestExclusiveCPUs(t *testing.T) {
	// Common test command setup setup to all tests
	tc := TestCommand{
		Command: exec.Cmd{
			Path: "./run.sh",
			Args: []string{"./run.sh", "test"},
			Dir:  "../../test/numa",
			Env: append(os.Environ(),
				"vm=crirm-test-system-numa",
				"binsrc=local",
				"cleanup=1",
				"speed=1000",
			),
		},
	}
	// NUMA configurations.
	tests := []struct {
		name      string
		numanodes NumaNodes
	}{
		{
			name:      "1xcpu6mem12G",
			numanodes: NumaNodes{{CPU: 6, Mem: "12G"}},
		},
		{
			name:      "3xcpu2mem2G-nvmem6G",
			numanodes: NumaNodes{{CPU: 2, Mem: "2G", Nodes: 3}, {Nvmem: "6G"}},
		},
	}
	// Placeholders for testcase-specific environment variables in
	// the last two slice elements: outdir and numanodes
	tc.Command.Env = append(tc.Command.Env, "outdir=PLACEHOLDER")
	tc.Command.Env = append(tc.Command.Env, "numanodes=PLACEHOLDER")
	// Run the test in all NUMA configurations.
	for _, test := range tests {
		testOutputDir := testOutputDirPrefix + "/system/exclusivecpus/" + test.name
		tc.LogFilename = testOutputDir + "/run.log"
		numanodesJSON, err := json.Marshal(test.numanodes)
		if err != nil {
			panic(fmt.Sprintf("numanodes Marshal-to-JSON error: %v", err))
		}
		t.Run(test.name, func(t *testing.T) {
			tc.Command.Env[len(tc.Command.Env)-2] = "outdir=" + testOutputDir
			tc.Command.Env[len(tc.Command.Env)-1] = "numanodes=" + string(numanodesJSON)
			runTestCommand(t, tc)
		})
	}
}
