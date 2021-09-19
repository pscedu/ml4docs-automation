* Crop objects.

This folder serves to make a `.sbatch` file that starts a job of CROPPING STAMPS, and submit it.
It contains two files: `submit.sh` and `template.sbatch`.

Cropped stamps may be used to:
- publish a version of MiikeMineStamps dataset.
- generate training images for classifier.

- `template.sbatch` contains a sbatch template. The actual sbatch file will be made from it.
- `submit.sh` creates a batch file and submits it as a job. The batch file is created in `${DATABASES_DIR}/campaign${id}/batch_jobs/` folder for now. (This path probably needs to be revisited in the future.)
