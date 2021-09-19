The following are the steps that will be added in the notebook.

All compute-intensive steps are run via a batch job, because it is assumed that many image may be in a campaign.

* Select a new campaign from unlabeled images.
* Detect stamps using the best stamp detector (maybe via a job).
* Detect pages using the best page detector (maybe via a job).
* Crop out stamps to run the classification (maybe via a job).
* Run classification (maybe via a job).
* Import the classification results.
* Visualize the result.
* Export to labelme.
* Upload to the labelme server.
* Download from the labelme server.
* Import from labelme.
* Visualize the results.
* Analyze how many stamps detected and classified stamps are correct.
* Cleaning. Repeat the steps below.
    * Export for cleaning to labelme.
    * Upload to the labelme server.
    * Download from the labelme server.
    * Import from cleaning.
    * Apply special rules: change all names from X to Y, etc.
    * Display statistics.
    * Promote cleaning iteration as final.
* Start stamp detection training (start a job).
* Start page detection training (start a job).
* Crop out stamps to prepare for the classification training (maybe via a job).
* Start classification training.
* Check if all jobs are completed.
* Finalize (promote the best model, clean the rest, and visualize) stamp detection training.
* Finalize (promote the best model, clean the rest, and visualize) page detection training.
* Evaluate detector trained on previous campaigns on this campaign.
* Finalize (promote the best model, clean the rest, and visualize) stamp classification training.
* Make a release of the new version of the dataset.
