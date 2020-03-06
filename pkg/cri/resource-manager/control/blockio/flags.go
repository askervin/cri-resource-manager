// Copyright 2019 Intel Corporation. All Rights Reserved.
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

package blockio

import (
	"github.com/intel/cri-resource-manager/pkg/config"
)

// options captures our configurable parameters.
//
// This is the user-friendly configuration interface, example:
// resource-manager:
//   blockio:
//     Classes:
//       BestEffort:
//         # Default configuration for all virtio and scsi block devices.
//         - Devices:
//             - /dev/vd*
//             - /dev/sd*
//           ThrottleReadBps: 50M   # max read bytes per second
//           ThrottleWriteBps: 10M  # max write bytes per second
//           ThrottleReadIOPS: 10k  # max read io operations per second
//           ThrottleWriteIOPS: 5k  # max write io operations per second
//           Weight: 50             # io-scheduler (cfq/bfq) weight.
//                                  # Devices are defined for this weight, so
//                                  # this is written to cgroups(.bfq).weight_device
//         # Configuration for SSD devices (overrides /dev/sd* for SSD disks)
//         - Devices:
//             - /dev/disk/by-id/*SSD*
//           ThrottleReadBps: 100M
//           ThrottleWriteBps: 40M
//           # Leaving Throttle*IOPS out means no throttling on those.
//           Weight: 50
//       Guaranteed:
//         # When Devices are not mentioned in the list item, only Weight,
//         # Weight is written to cgroups(.bfq).weight.
//         - Weight: 400
//       # Default for any other BlockIO/QOS class (e.g. Burstable)
//       Default:
//         - Weight: 100

// options captures our configurable parameters.
type options struct {
	// Classes assigned to actual blockio classes, for example Guaranteed -> NoLimits.
	Classes map[string]string `json:",omitempty"`
}

// Our runtime configuration.
var opt = defaultOptions().(*options)

// defaultOptions returns a new options instance, all initialized to defaults.
func defaultOptions() interface{} {
	return &options{
		Classes: make(map[string]string),
	}
}

// Register us for configuration handling.
func init() {
	config.Register("resource-manager.blockio", configHelp, opt, defaultOptions,
		config.WithNotify(getBlockIOController().(*blockio).configNotify))
}
