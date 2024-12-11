# Knowledge-Embedded Large Language Models for Emergency Triage

## Abstract
This is a repository for our research on knowledge-embedded large language models for emergency triage.
Emergency departments (EDs) are crucial to healthcare but face persistent overcrowding, which compromises patient safety and care quality. The Emergency Severity Index (ESI) triage system is vital for prioritizing patients based on acuity and resource needs but relies heavily on the subjective judgment of medical staff, leading to inconsistencies, especially during high-stress periods. This study presents the Sequential Domain and Task Adaptation (SDTA) framework for enhancing ED triage accuracy and consistency using Large Language Models (LLMs). By training LLMs on clinical data and ESI-specific tasks, we significantly improve their performance over traditional prompt-engineered models, achieving accuracy levels comparable to or exceeding those of experienced emergency physicians. Notably, the fine-tuned models attained high accuracy and perfect recall for high-risk cases, surpassing human expert benchmarks. These findings highlight the potential of adapted LLMs to standardize triage decisions, reduce variability, and optimize resource allocation in EDs, offering a scalable solution to alleviate overcrowding and enhance patient care outcomes.

## Project Structure

```
.
├── configs/                  # Configuration files for experiments
│   └── *.yaml               # YAML config files for different models and experiments
├── datasets/                # Dataset processing and preparation scripts
├── evaluations/            # Evaluation results and analysis
├── experiments/            # Main experiment scripts
│   ├── exp1_local.py      # Local inference with base models
    ...
│   └── exp5_local.py      # Local inference with SDTA approaches
├── finetune/               # Fine-tuning related files
│   ├── configs/           # Configuration files for fine-tuning
│   └── scripts/           # Fine-tuning scripts
├── prompts/                # Prompt templates and examples
│   └── *.txt              # Different prompt formats for experiments
├── results/               # Experimental results and outputs
├── sqls/                  # SQL queries for QC
│   └── *.sql             # SQL scripts for QC
├── utils/                 # Utility functions and helper scripts
├── eval.py               # Evaluation script for model performance
├── run_eval.sh           # Shell script for batch evaluation
└── .env.example          # Example environment variables file
```

### Directory Details

- `configs/`: Contains YAML configuration files for different experiments, specifying model parameters, data paths, and other settings.
- `datasets/`: Scripts for processing and preparing the MIMIC-IV dataset for training and evaluation.
- `evaluations/`: Stores evaluation results, metrics, and analysis outputs.
- `experiments/`: Main experimental scripts implementing different approaches:
  - Base model inference
  - Domain adaptation
  - Instruction tuning
  - Sequential adaptation
  - Combined approaches
- `finetune/`: Contains scripts and configurations for model fine-tuning procedures.
- `prompts/`: Collection of prompt templates used in different experiments.
- `results/`: Stores experimental outputs and results for analysis.
- `sqls/`: SQL queries for extracting relevant data from the MIMIC-IV database.
- `utils/`: Helper functions and utility scripts used across the project.

## Requirements
- Python 3.8+
- Dependencies listed in `requirements.txt`

## Installation
```bash
git clone https://github.com/[username]/Knowledge-Embedded-Large-Language-Models-for-Emergency-Triage.git
cd Knowledge-Embedded-Large-Language-Models-for-Emergency-Triage
pip install -r requirements.txt
```

## Experiments

### Experiment 1: Zero-Shot Prompt
Zero-shot Prompt used in this study is as following:
```text
Analyze the patient's condition and determine their Emergency Severity Index (ESI) level from 1 to 5 based on the following criteria:

ESI Level 1: Requires immediate life-saving intervention
ESI Level 2: High risk situation, confused/lethargic/disoriented, or severe pain/distress
ESI Level 3: Many resources needed (labs, ECG, X-rays, CT, specialists, etc.)
ESI Level 4: One resource needed
ESI Level 5: No resources needed

Provide your assessment and reasoning, then clearly state the ESI level (1-5) at the end.
```

For the local models, invoke `exp1.py` from the `experiments` directory. Use the command line `python exp1_local.py --dataset PATH_TO_DATASET --model_config PATH_TO_MODEL_CONFIG --model_name MODEL_NAME` and fill in the options as needed based on the actual requirements.

For example, `python exp1_local.py --dataset datasets/mimiciv-triage-eval-dataset-v1.csv --model_config configs/Qwen2_5-72B.yaml --model_name exp1_qwen2_5-72b`

For LLMs like OpenAI's GPT-4o-240806, we use dify to get the results. Use the command line `python exp1_dify.py --config PATH_TO_CONFIG --dataset PATH_TO_DATASET --config PATH_TO_CONFIG --model_name MODEL_NAME` and fill in the options as needed based on the actual requirements.

For example, `python exp1_dify.py --config configs/GPT4o_240806_dify.json --dataset datasets/mimiciv-triage-eval-dataset-v1.csv --model_name exp1_gpt-4o-240806`

After running the experiment, the results will be saved in the `results` directory. You can find the results in the `results` directory.

You can create corresponding configs for any LLMs available on Huggingface, find more models here: https://huggingface.co/unsloth

### Experiment 2: Engineered Prompt
In this experiment, we use a series of engineered prompts to analyze emergency cases through multiple perspectives. The process involves three sequential analyses using specialized prompts for different ESI levels:

1. ESI-1 Analysis: Focuses on identifying immediate life-threatening conditions
2. ESI-2 Analysis: Evaluates high-risk situations and severe symptoms
3. ESI-3 Analysis: Assesses resource needs and moderate conditions

Each analysis is followed by a formatting step to standardize the output. The prompts are stored in the `prompts` directory:
- Analysis prompts: `ESI-1-Analysis.txt`, `ESI-2-Analysis.txt`, `ESI-3-Analysis.txt`
- Format prompts: `ESI-1-Format.txt`, `ESI-2-Format.txt`, `ESI-3-Format.txt`

For local models, use the command:
```bash
python exp2_local.py --dataset PATH_TO_DATASET --model_config PATH_TO_CONFIG --model_name MODEL_NAME
```

For example:
```bash
python exp2_local.py --dataset datasets/mimiciv-triage-eval-dataset-v1.csv --model_config configs/Qwen2_5-72B.yaml --model_name exp2_qwen2_5-72b
```

For cloud-based LLMs like GPT-4, use the Dify interface:
```bash
python exp2_dify.py --config PATH_TO_CONFIG --dataset PATH_TO_DATASET --model_name MODEL_NAME
```

For example:
```bash
python exp2_dify.py --config configs/GPT4o_240806_dify.json --dataset datasets/mimiciv-triage-eval-dataset-v1.csv --model_name exp2_gpt-4o-240806
```

Results will be saved in the `results` directory with timestamps and model names. The final prediction is determined by a majority voting system among the three analyses.

### Experiment 3: Continued Pretraining

In this experiment, we explore improving the performance of Large Language Models (LLMs) on emergency triage tasks through Continued Pretraining. Due to the nature of the MIMIC-IV database being a **Credentialed Access Dataset**, users must register on the official [PhysioNet](https://physionet.org) website, complete required training, and obtain certification to access the database.

#### Accessing MIMIC-IV Database

To use the MIMIC-IV database, ensure compliance with the following rules:
1. **Complete Official Training**: Pass the online courses and certification provided by PhysioNet.
2. **Declare Data Usage**: Use the dataset exclusively for research purposes; commercial use is prohibited.
3. **Adhere to Privacy and Ethics Rules**: Protect patient confidentiality and avoid attempts to identify individuals or disclose sensitive information.

As these restrictions apply, the MIMIC-IV-Note database required for Continued Pretraining is not directly provided in this repository. However, you can follow the steps below to conduct the experiment independently. After you finished processing the CPT dataset, save it to datasets/ folder in csv format.

#### Continued Pretraining Procedure

Fine-tuning models in this repository is straightforward. All you need to do is create a YAML configuration file. The code for fine-tuning is located in the `finetune/` directory, and the corresponding model configuration files are in the `finetune/configs` directory.

##### Example: Continued Pretraining on the Qwen2.5 72B Model

The configuration file for continued pretraining on the Qwen2.5 72B model looks as follows:

```yaml
model:
  max_seq_length: 4096
  load_in_4bit: True
  model_name: "unsloth/Qwen2.5-72B-Instruct-bnb-4bit"
  use_rslora: True
  r: 128
  lora_alpha: 32

trainer:
  dataset_num_proc: 8
  per_device_train_batch_size: 4
  gradient_accumulation_steps: 8
  num_train_epochs: 5
  warmup_ratio: 0.03
  learning_rate: 5e-5
  embedding_learning_rate: 1e-5
  weight_decay: 0.01
  seed: 42
  output_dir: "outputs/Qwen2_5-72B-CPT"

dataset:
  name: "CPT"
```

##### Explanation of the Configuration File

- **model**: 
  - `max_seq_length`: Sets the maximum sequence length for the model during training.
  - `load_in_4bit`: Enables 4-bit loading to reduce memory usage.
  - `model_name`: Specifies the pre-trained model name to be fine-tuned.
  - `use_rslora`: Indicates the use of low-rank adapters (LoRA) for efficient fine-tuning.
  - `r` and `lora_alpha`: Configures LoRA hyperparameters.

- **trainer**: 
  - `dataset_num_proc`: Number of processes to use for dataset preprocessing.
  - `per_device_train_batch_size`: Batch size per GPU/TPU during training.
  - `gradient_accumulation_steps`: Number of gradient accumulation steps to simulate larger batch sizes.
  - `num_train_epochs`: Total number of training epochs.
  - `warmup_ratio`: Ratio of training steps used for learning rate warmup.
  - `learning_rate`: Main learning rate for the model.
  - `embedding_learning_rate`: Learning rate for embedding layers.
  - `weight_decay`: Regularization parameter to prevent overfitting.
  - `seed`: Seed for reproducibility.
  - `output_dir`: Directory where outputs (e.g., checkpoints and logs) will be saved.

- **dataset**: 
  - `name`: Name of the dataset used for continued pretraining.

##### Running the Training

Run the following command to start the training:

```bash
python model_train.py --config configs/CPT-Qwen2_5-72B.yaml
```

It is recommended to use **tmux** or **screen** to keep the session active for long-running processes. After execution, the model will be trained and saved in the directory specified in `output_dir`.

##### Note on Total Batch Size

The total batch size is calculated as:

**Total Batch Size = per_device_train_batch_size × gradient_accumulation_steps**

For example, if `per_device_train_batch_size` is 4 and `gradient_accumulation_steps` is 8, the total batch size is **4 × 8 = 32**.

#### Running Inference with Continued Pretrained Models

After training the model, you can inference the model using the `exp3_local.py` script. 

To run inference:

```bash
python exp3_local.py --dataset PATH_TO_DATASET --model_name PATH_TO_MODEL --model_config PATH_TO_CONFIG
```

For example:
```bash
python exp3_local.py --dataset datasets/mimiciv-triage-eval-dataset-v1.csv --model_name exp3_Qwen2_5-72B-CPT --model_config configs/exp3_Qwen2_5-72B.yaml
```

### Experiment 4: Instruction Tuning on MIETIC Dataset

In this experiment, we perform **Instruction Tuning** on the MIETIC dataset. Similar to Continued Pretraining, the process involves defining a configuration file and running the training script. The configuration file for this experiment is `IT-Qwen2_5-72B.yaml`.

#### Configuration File Example: Instruction Tuning on Qwen2.5 72B Model

```yaml
model:
  max_seq_length: 4096
  load_in_4bit: True
  model_name: "unsloth/Qwen2.5-72B-Instruct-bnb-4bit"
  use_rslora: True
  r: 128
  lora_alpha: 32

trainer:
  dataset_num_proc: 8
  per_device_train_batch_size: 4
  gradient_accumulation_steps: 8
  num_train_epochs: 1
  warmup_ratio: 0.03
  learning_rate: 3e-5
  embedding_learning_rate: 1e-5
  weight_decay: 0.01
  seed: 42
  output_dir: "outputs/Qwen2_5-72B-IT"

dataset:
  name: "mietic"
```

#### Running the Training

To start instruction tuning, use the following command:

```bash
python model_train.py --config configs/IT-Qwen2_5-72B.yaml
```

This setup uses the MIETIC dataset and performs fine-tuning for one epoch with a batch size of **4 × 8 = 32**. The results, including trained models and logs, will be saved in the directory specified by `output_dir` (`outputs/Qwen2_5-72B-IT`).

It is recommended to use **tmux** or **screen** to keep the session running for extended durations.

#### Running Inference with Instruction Tuned Models

Once training is complete, you can run inference using the tuned model with the `exp4_local.py` script:

```bash
python exp4_local.py --dataset PATH_TO_DATASET --model_name PATH_TO_MODEL --model_config PATH_TO_CONFIG
```

For example:
```bash
python exp4_local.py --dataset datasets/mimiciv-triage-eval-dataset-v1.csv --model_name exp4_Qwen2_5-72B-IT --model_config configs/exp4_Qwen2_5-72B.yaml
```

### Experiment 5: Sequential Domain and Task Adaptation (SDTA)

This experiment focuses on Sequential Domain and Task Adaptation (SDTA) to further fine-tune models for emergency triage tasks. The training builds on a model previously trained during Continued Pretraining (CPT). The configuration file for this experiment is `SDTA-Qwen2_5-72B.yaml`.

#### Configuration File Example: SDTA on Qwen2.5 72B Model

```yaml
model:
  max_seq_length: 4096
  load_in_4bit: True
  model_name: "CHANGE THIS TO CPT TRAINED MODEL PATH"
  use_rslora: True
  r: 128
  lora_alpha: 32

trainer:
  dataset_num_proc: 8
  per_device_train_batch_size: 4
  gradient_accumulation_steps: 8
  num_train_epochs: 1
  warmup_ratio: 0.03
  learning_rate: 3e-5
  embedding_learning_rate: 1e-5
  weight_decay: 0.01
  seed: 42
  output_dir: "outputs/Qwen2_5-72B-SDTA"

dataset:
  name: "mietic"
```

#### Running the Training

To perform SDTA, use the following command:

```bash
python model_train.py --config configs/SDTA-Qwen2_5-72B.yaml
```

Make sure to replace `model_name` in the configuration file with the path to the CPT-trained model (from Experiment 3). The training uses the MIETIC dataset and saves the results to `outputs/Qwen2_5-72B-SDTA`.

#### Running Inference with SDTA Tuned Models

Once training is complete, use the `exp5_local.py` script for inference:

```bash
python exp5_local.py --dataset PATH_TO_DATASET --model_name PATH_TO_MODEL --model_config PATH_TO_CONFIG
```

For example:
```bash
python exp5_local.py --dataset datasets/mimiciv-triage-eval-dataset-v1.csv --model_name exp5_Qwen2_5-72B-SDTA --model_config configs/exp5_Qwen2_5-72B.yaml
```

This experiment represents the final stage of model adaptation, leveraging both domain-specific pretraining and task-specific fine-tuning to optimize performance on emergency triage tasks.


## Evaluation

The evaluation process analyzes the performance of models across different experiments. We provide two ways to evaluate the results:

### Single Result Evaluation

To evaluate a single experiment result:

```bash
python eval.py PATH_TO_RESULT_FILE
```

For example:
```bash
python eval.py results/exp3_Qwen2_5-72B-CPT_20241211.csv
```

### Batch Evaluation

To evaluate multiple experiment results at once, use the provided shell script:

```bash
bash run_eval.sh
```

This script will:
1. Process all experiment result files in the `results` directory
2. Generate evaluation metrics for each file
3. Save results in the `evaluations` directory

### Evaluation Metrics

The evaluation script calculates several key metrics:

1. **Overall Performance**
   - Accuracy
   - Macro Precision
   - Macro Recall
   - Macro F1 Score

2. **Risk-Level Specific Metrics**
   - High-Risk Cases (ESI-1 & ESI-2): Recall
   - Moderate Cases (ESI-3): F1 Score
   - Non-Urgent Cases (ESI-4 & ESI-5): Precision

3. **Clinical Safety Metrics**
   - Over-Triage Rate: Percentage of cases assigned a more urgent level than necessary
   - Under-Triage Rate: Percentage of cases assigned a less urgent level than necessary
   - Failed Predictions Count: Number of cases where the model failed to make a prediction

The results are saved in CSV format with detailed metrics for further analysis. Each evaluation generates a separate directory under `evaluations/` named after the input file, containing:
- `evaluation_results.csv`: Comprehensive metrics report


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<!-- ## Citations

If you use this work in your research, please cite our repository along with the following resources that made this work possible: -->

## References

[1] Johnson, A.E.W., Bulgarelli, L., Shen, L., et al. (2023). MIMIC-IV, a freely accessible electronic health record dataset. Scientific Data, 10(1), 1. https://doi.org/10.1038/s41597-022-01899-x

[2] Johnson, A., Bulgarelli, L., Pollard, T., Gow, B., Moody, B., Horng, S., Celi, L. A., & Mark, R. (2024). MIMIC-IV (version 3.1). PhysioNet. https://doi.org/10.13026/kpb9-mt58

[3] Johnson, A., Pollard, T., Horng, S., Celi, L. A., & Mark, R. (2023). MIMIC-IV-Note: Deidentified free-text clinical notes (version 2.2). PhysioNet. https://doi.org/10.13026/1n74-ne17

[4] Johnson, A., Bulgarelli, L., Pollard, T., Celi, L. A., Mark, R., & Horng, S. (2023). MIMIC-IV-ED (version 2.2). PhysioNet. https://doi.org/10.13026/5ntk-km72

[5] Goldberger, A., Amaral, L., Glass, L., Hausdorff, J., Ivanov, P. C., Mark, R., ... & Stanley, H. E. (2000). PhysioBank, PhysioToolkit, and PhysioNet: Components of a new research resource for complex physiologic signals. Circulation [Online]. 101(23), pp. e215–e220.

[6] Han, D., Han, M., & Unsloth team. (2023). Unsloth: Efficient Fine-tuning Framework for Large Language Models. GitHub. http://github.com/unslothai/unsloth