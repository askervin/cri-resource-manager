// Copyright 2022 Intel Corporation. All Rights Reserved.
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

package balloons

import (
	"fmt"
	"strconv"
	"strings"
)

// Limit is an integer where negative numbers have special meanings.
type Limit int

const (
	LimitNoLimit Limit = 0
)

var limitToString = map[Limit]string{
	LimitNoLimit: "unlimited",
}

// String stringifies a Limit
func (lm Limit) String() string {
	if lmStr, ok := limitToString[lm]; ok {
		return lmStr
	}
	return fmt.Sprintf("%d", int(lm))
}

// UnmarshalJSON unmarshals a JSON string to Limit
func (lm *Limit) UnmarshalJSON(b []byte) error {
	if len(b) == 0 {
		return fmt.Errorf("invalid limit")
	}
	if len(b) > 1 && b[0] == '"' && b[len(b)-1] == '"' {
		return lm.UnmarshalJSON(b[1 : len(b)-1])
	}
	if i, err := strconv.Atoi(string(b)); err == nil && i >= int(LimitNoLimit) {
		*lm = Limit(i)
		return nil
	}
	name := strings.ToLower(string(b))
	for lmConst, lmString := range limitToString {
		if lmString == name {
			*lm = lmConst
			return nil
		}
	}
	return fmt.Errorf("invalid limit %q", name)
}
