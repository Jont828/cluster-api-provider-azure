/*
Copyright 2021 The Kubernetes Authors.

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

package v1alpha4

import (
	apiconversion "k8s.io/apimachinery/pkg/conversion"
	expv1beta1 "sigs.k8s.io/cluster-api-provider-azure/exp/api/v1beta1"
	utilconversion "sigs.k8s.io/cluster-api/util/conversion"
	"sigs.k8s.io/controller-runtime/pkg/conversion"
)

// ConvertTo converts this AzureManagedMachinePool to the Hub version (v1beta1).
func (src *AzureManagedMachinePool) ConvertTo(dstRaw conversion.Hub) error {
	dst := dstRaw.(*expv1beta1.AzureManagedMachinePool)

	if err := Convert_v1alpha4_AzureManagedMachinePool_To_v1beta1_AzureManagedMachinePool(src, dst, nil); err != nil {
		return err
	}

	// Manually restore data.
	restored := &expv1beta1.AzureManagedMachinePool{}
	if ok, err := utilconversion.UnmarshalData(src, restored); err != nil || !ok {
		return err
	}
	dst.Spec.Scaling = restored.Spec.Scaling
	return Convert_v1alpha4_AzureManagedMachinePool_To_v1beta1_AzureManagedMachinePool(src, dst, nil)
}

// ConvertFrom converts from the Hub version (v1beta1) to this version.
func (dst *AzureManagedMachinePool) ConvertFrom(srcRaw conversion.Hub) error {
	src := srcRaw.(*expv1beta1.AzureManagedMachinePool)

	if err := Convert_v1beta1_AzureManagedMachinePool_To_v1alpha4_AzureManagedMachinePool(src, dst, nil); err != nil {
		return err
	}

	// Preserve Hub data on down-conversion.
	if err := utilconversion.MarshalData(src, dst); err != nil {
		return err
	}

	return nil
}

func Convert_v1beta1_AzureManagedMachinePoolSpec_To_v1alpha4_AzureManagedMachinePoolSpec(in *expv1beta1.AzureManagedMachinePoolSpec, out *AzureManagedMachinePoolSpec, s apiconversion.Scope) error {
	return autoConvert_v1beta1_AzureManagedMachinePoolSpec_To_v1alpha4_AzureManagedMachinePoolSpec(in, out, s)
}
