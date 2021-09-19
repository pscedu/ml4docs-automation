# ml4docs-automation

## For Classification model (OLTR)
### Training

<code> ./pipeline/start_classification_training.sh --campaign_id CAMPAIGN_ID </code>

where CAMPAIGN_ID is the campaign you are trying to train.

The training proceeds and saved the logs here: <code> /ocean/projects/hum180001p/shared/classification/campaignCAMPAIGN_ID/models/stamps </code>

### Inference

<code> ./scripts/inference_classification/submit.sh --campaign_id CAMPAIGN_ID </code>


