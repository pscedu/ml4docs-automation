The following steps are run for every campaign. The are mostly sequenctial, but starting some jobs can be done in parallel.

All compute-intensive steps are run via a batch job, because it is assumed that many images may be in a campaign.

* `select_new_campaign` Select a new campaign from unlabeled images.
* `start_stamp_detection_inference` Start a job to detect stamps using the best stamp detector.
* `start_page_detection_inference` Start a job to detect pages using the best page detector.
* **TODO** `finalize_all_detection_inference` Make video, classify pages.
* `start_cropping_for_classification_inference.sh` Start a cropping job in order to classify stamps.
* `start_classification_inference.sh` Start a job to classify stamps using the best model.
* `finalize_classification_inference.sh` Import the classification results and make a video.
* `display_statistics.sh` Display info about this campaign.
* `export_to_labelme.sh` Filter out low confidence classification and export to labelme.
* **TODO** `upload_to_labelme_server.sh` Upload to the labelme server.
* **TODO** `download_from_labelme_server.sh` Download from the labelme server.
* `import_from_labelme.sh` Import from labelme, make all sizes and merge with previous campagins.
* `display_statistics.sh` Display info about this campaign.
* `display_statistics.sh` Display info about all campaigns.
* **TODO** Analyze how many stamps detected and classified stamps are correct.
* Cleaning. Repeat the steps below. A cleaning can be done for only this or all campaigns.
    * `export_to_labelme_cleaning.sh` Export for cleaning to labelme.
    * **TODO** `upload_to_labelme_server.sh` Upload to the labelme server.
    * **TODO** `upload_to_labelme_server.sh` Download from the labelme server.
    * `import_after_labelme_cleaning.sh` Import from cleaning.
    * **TODO** Apply special rules: change all names from X to Y, etc.
    * `display_statistics.sh` Display info about this or all campaign.
    * `finalize_labelme_cleaning.sh` Promote cleaning iteration as final.
* **TODO for YoloV5** `start_page_detection_training.sh` Start a jpb of stamp detection training.
* **TODO for YoloV5** `start_page_detection_training.sh` Start a jpb of page detection training.
* `start_cropping_for_classification_training.sh` Start a job of cropping out stamps to prepare for the classification training.
* **WIP** `start_classification_training.sh` Start a job of classification training.
* `finalize_stamp_detection_training.sh` Finalize (promote the best model, clean the rest, and visualize) stamp detection training.
* `finalize_page_detection_training.sh` Finalize (promote the best model, clean the rest, and visualize) page detection training.
* **TODO** Evaluate detector trained on previous campaigns on this campaign.
* **TODO** Finalize (promote the best model, clean the rest, and visualize) stamp classification training.
* **TODO** Make a release of the new version of the dataset.
