# 1. Validate the AWS layer with `terraform test` and mock providers, not LocalStack

**Status:** Accepted · **Phase:** 1

## Context

The AWS layer has to be shown to work without an AWS account and without spending money. The two
candidates were LocalStack and `terraform test` with `mock_provider`.

## Decision

Validate with `terraform fmt`, `validate`, `tflint`, `checkov` and `terraform test` against mock
providers. Never apply against LocalStack.

LocalStack outside its Pro tier does not emulate EKS, ELBv2 or Multi-AZ RDS — precisely the
components this design rests on. A plan that succeeds against a thin emulation of those services
proves that the emulation accepted the request, which is not a fact about AWS.

## Consequences

Module composition, variable contracts and policy compliance are proven, and they are the parts
most likely to be wrong in a repository this size.

**Cost:** AWS *behaviour* is not proven and must never be claimed. Subnet discovery tags, VPC CNI
IP exhaustion, IRSA trust policies and Multi-AZ failover are all things this repository can explain
but has not reproduced. The honest sentence is "designed for AWS, validated with mocks, run on
k3d", and it has to be said before someone asks.
