# test deploy of bastion VM

- wait for pipeline to produce test image and check it in the Azure portal
- update `parameters.json` (e.g. change image version)
- do `az login --use-device-code`
- run `deploy.bat`

WARNING: do not forget to delete the VM after the test
