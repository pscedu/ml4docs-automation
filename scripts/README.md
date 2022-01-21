* Scripts

Scripts in this folder are the building blocks of processing a campaign.
Each folder and/or script here is responsible for one piece of the pipeline.
On a high level:

- `detection_inference` has a script that starts a job that runs inference on a detection model. It is used to generate machine detections before a campaign starts.
- `collages_for_cleaning` has 1) a script that starts a job to generate "collages" that are then uploaded to LabelMe for cleaning, and 2) a script that takes cleaned collages from Labelme and back-imports it to the source database.
- `detection_training_yolov5_jobs` has 1) a script that starts a bunch of jobs to train detection models with different hyperparameters, and 2) a script that reads the results are prints out the performance of different hyperparamaters.
- `crop_stamps_job` has a script that starts a job of cropping stamps as saving the crops as images. They are further used to publish a dataset, or to train a classifier.
- `resize_dataset.sbatch` is a job that was done once at the very beginning to resize the original dataset to 1800x1200.

The code in this folder is aware of the organization of databases into campaigns,
however, it does not know anything about which database names (versions) are
inputs and outputs. Scripts in the `pipiline` folder takes care of database
file names for each step.
