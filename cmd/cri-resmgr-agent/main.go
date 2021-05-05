/*
Copyright 2019 Intel Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package main

import (
	"flag"

	"github.com/intel/cri-resource-manager/pkg/agent"
	"github.com/intel/cri-resource-manager/pkg/log"
)

func main() {
	// Disable buffering and make sure that all messages have been emitted at
	// program exit
	log.Flush()
	defer log.Flush()

	flag.Parse()

	a, err := agent.NewResourceManagerAgent()
	if err != nil {
		log.Fatalf("failed to create resource manager agent instance: %v", err)
	}

	if err := a.Run(); err != nil {
		log.Fatalf("%v", err)
	}
}
