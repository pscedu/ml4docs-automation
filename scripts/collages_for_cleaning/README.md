* Make "collages" job

This folder serves to make a `.sbatch` file that starts a job of creating collage images, and submit it. 
It contains two files: `submit.sh` and `template.sbatch`.

Images with tiles ("collage") need to be uploaded to Labelme as the next step for cleaning. Several cleaning iterations may be done for every campaign, and will need to find a way to minimize the number oif these iterations.

- `template.sbatch` contains a sbatch template. The actual sbatch file will be made from it.
- `submit.sh` creates a batch file and submits it as a job. The batch file is created in `${DATABASES_DIR}/campaign${id}/batch_jobs/` folder for now. (This path probably needs to be revisited in the future.)
- `import.sh` should be called after the cleaning is done, and the results are donwloaded.