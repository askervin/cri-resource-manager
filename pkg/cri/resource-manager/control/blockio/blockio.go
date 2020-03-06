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
	"fmt"

	"github.com/intel/cri-resource-manager/pkg/blockio"
	"github.com/intel/cri-resource-manager/pkg/config"
	"github.com/intel/cri-resource-manager/pkg/cri/client"
	"github.com/intel/cri-resource-manager/pkg/cri/resource-manager/cache"
	"github.com/intel/cri-resource-manager/pkg/cri/resource-manager/control"
	logger "github.com/intel/cri-resource-manager/pkg/log"
)

const (
	// BlockIOController is the name of the block I/O controller.
	BlockIOController = cache.BlockIO
)

// blockio encapsulates the runtime state of our block I/O enforcement/controller.
type blockioctl struct {
	cache cache.Cache // resource manager cache
}

// Our logger instance.
var log logger.Logger = logger.NewLogger(BlockIOController)

// Our singleton block I/O controller instance.
var singleton *blockioctl

// getBlockIOController returns our singleton block I/O controller instance.
func getBlockIOController() control.Controller {
	if singleton == nil {
		singleton = &blockioctl{}
	}
	return singleton
}

// Start initializes the controller for enforcing decisions.
func (ctl *blockioctl) Start(cache cache.Cache, client client.Client) error {
	ctl.cache = cache
	return nil
}

// Stop shuts down the controller.
func (ctl *blockioctl) Stop() {
}

// PreCreateHook is the block I/O controller pre-create hook.
func (ctl *blockioctl) PreCreateHook(c cache.Container) error {
	return nil
}

// PreStartHook is the block I/O controller pre-start hook.
func (ctl *blockioctl) PreStartHook(c cache.Container) error {
	return nil
}

// PostStartHook is the block I/O controller post-start hook.
func (ctl *blockioctl) PostStartHook(c cache.Container) error {
	// Notes:
	//   Unlike in our PostUpdateHook, we don't bail out here if
	//   there are no pending block I/O changes for the container.
	//   We might be configured to fall back to assign the class
	//   based on pod/container QoS class in which case there is
	//   no pending marker on the container.
	if err := ctl.assign(c, ctl.BlockIOClass(c)); err != nil {
		return err
	}
	c.ClearPending(BlockIOController)
	return nil
}

// PostUpdateHook is the block I/O controller post-update hook.
func (ctl *blockioctl) PostUpdateHook(c cache.Container) error {
	if !c.HasPending(BlockIOController) {
		return nil
	}
	if err := ctl.assign(c, ctl.BlockIOClass(c)); err != nil {
		return err
	}
	c.ClearPending(BlockIOController)
	return nil
}

// PostStop is the block I/O controller post-stop hook.
func (ctl *blockioctl) PostStopHook(c cache.Container) error {
	return nil
}

// assign assigns the container to the given block I/O class.
func (ctl *blockioctl) assign(c cache.Container, class string) error {
	if class == "" {
		log.Debug("skip handling container %s: no matching block I/O class", c.PrettyName())
		return nil
	}

	if err := blockio.SetContainerClass(c, class); err != nil {
		return blockioError("assigning container %v to class %#v failed: %w", c.PrettyName(), class, err)
	}

	log.Info("container %s assigned to class %s", c.PrettyName(), class)
	return nil
}

// BlockIOClass determines the effective block I/O class for a container.
func (ctl *blockioctl) BlockIOClass(c cache.Container) string {
	cclass := c.GetBlockIOClass()
	if cclass == "" {
		cclass = string(c.GetQOSClass())
	}
	_, ok := opt.Classes[cclass]
	if !ok {
		if _, ok = opt.Classes["Default"]; ok {
			cclass = "Default"
		} else {
			cclass = ""
		}
	}

	log.Debug("BlockIO class for %s: %s", c.PrettyName(), cclass)

	return cclass
}

// configNotify is our runtime configuration notification callback.
func (ctl *blockioctl) configNotify(event config.Event, source config.Source) error {
	currentIOSchedulers, ioSchedulerDetectionError := getCurrentIOSchedulers()
	if ioSchedulerDetectionError != nil {
		log.Warn("configuration validation partly disabled due to IO scheduler detection error %#v", ioSchedulerDetectionError.Error())
	}

	// Create static OCI BlockIO structures for each I/O or QOS
	// class from new configuration
	for class := range opt.Classes {
		ociBlockIO, err := devicesParametersToOci(opt.Classes[class], currentIOSchedulers)
		if err != nil {
			if event == "update" {
				// Report errors only if they appear on update.
				return err
			}
			// Use whatever is possible on rollback.
			log.Error("ignoring parts of rollback configuration due to errors: %w", err)
		}
		// Handle all configurations as static for now. That
		// is, the list of block devices matching Devices
		// wildcards will not be updated without new
		// configNotify(). class.DynamicDevices not supported
		// yet.
		staticOciBlockIO[class] = ociBlockIO
	}
	log.Info("configuration updated")
	return nil
}

// blockioError creates a block I/O-controller-specific formatted error message.
func blockioError(format string, args ...interface{}) error {
	return fmt.Errorf("blockio: "+format, args...)
}

// Register us as a controller.
func init() {
	currentPlatform = defaultPlatform{}
	control.Register(BlockIOController, "Block I/O controller", getBlockIOController())
}
