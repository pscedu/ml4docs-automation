# ml4docs-automation

The repo implements a workflow for iteratively labeling stamps. 
On every iteration called a "campaign", all scripts from `pipeline` folder are 
run by user. `pipeline/README.md` specifies the order (WIP).

The general workflow is the following.

1. Pick new images to label.
2. Detect pages, detect and classify stamps using previously trained models.
3. Send the ML-labeled images to LabelMeAnnotationTool for the expert labeling.
4. Send the expert-labeled stamps, grouped by name, to LabelMeAnnotationTool for cleaning.
5. Repeat cleaning if needed. Can be made for this or for all campaigns.
6. Postprocess, visualize, generate statistics, publish the dataset.
7. Re-train all ML models.

Repo structure:

- `pipeline` have high level scripts. This is what a user should execute.
- `scripts` workhorse helper scripts. Used for debuging and experimenting.
- `constants.sh` contains various repo-wide anme and path conventions.
