import os
import yaml
import argparse
from datetime import datetime
from unsloth import FastLanguageModel
from transformers import TrainingArguments
from unsloth import UnslothTrainer, UnslothTrainingArguments, is_bfloat16_supported

from transformers.utils import default_cache_path
default_cache_path = "YOUR DEFAULT CACHE PATH"

# cmdline args
parser = argparse.ArgumentParser(description="Training Script with Configurable Parameters")
parser.add_argument("--config_path", type=str, default="configs/config.yaml", help="Path to the YAML config file")
args = parser.parse_args()

# load config
with open(args.config_path, "r") as f:
    config = yaml.safe_load(f)

# model config
max_seq_length = config["model"].get("max_seq_length", 4096)
load_in_4bit = config["model"].get("load_in_4bit", True)
model_name = config["model"].get("model_name", "unsloth/gemma-2b-bnb-4bit")
use_rslora = config["model"].get("use_rslora", True)
r = config["model"].get("r", 128)
lora_alpha = config["model"].get("lora_alpha", 32)

dataset_name = config["dataset"].get("name", "mietic") # asclepius and mietic

# load model and tokenizer
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name=model_name,
    max_seq_length=max_seq_length,
    dtype=None,  # auto detect dtype
    load_in_4bit=load_in_4bit
)

# configure LoRA model
model = FastLanguageModel.get_peft_model(
    model,
    r=r,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_alpha=lora_alpha,
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",
    random_state=3407,
    use_rslora=use_rslora,
    loftq_config=None,
)

###################
# Prepare Dataset #
###################

alpaca_prompt = """Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
{}

### Input:
{}

### Response:
{}"""

EOS_TOKEN = tokenizer.eos_token

def formatting_prompts_func(examples):
    if dataset_name == "asclepius":
        instructions = examples["question"]
        inputs = examples["note"]
        outputs = examples["answer"]
    elif dataset_name == "mietic":
        instructions = examples["instruction"]
        inputs = examples["input"]
        outputs = examples["output"]
    texts = []
    for instruction, input, output in zip(instructions, inputs, outputs):
        text = alpaca_prompt.format(instruction, input, output) + EOS_TOKEN
        texts.append(text)
    return {"text": texts}

from datasets import load_dataset
from datasets import Dataset
if dataset_name == "CPT":
    # CPT DATASET PATH
    # The MIMIC-IV-Note dataset is not publicly available; 
    # it needs to be obtained from the official website.
    dataset = load_dataset("CPT DATASET PATH", split="train")
    dataset = dataset.map(formatting_prompts_func, batched=True)
elif dataset_name == "mietic":
    import pandas as pd
    df = pd.read_csv('triage_instruction_dataset_v1.csv')  
    # convert DataFrame to Hugging Face Dataset
    dataset = Dataset.from_pandas(df)
    dataset = dataset.map(formatting_prompts_func, batched=True)
###################
# Prepare Trainer #
###################

# Setting Output path
output_dir = config["trainer"].get("output_dir", "outputs")
timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
model_output_dir = os.path.join(output_dir, f"{model_name.replace('/', '-')}_{timestamp}")

# Trainer config
trainer_args = UnslothTrainingArguments(
    per_device_train_batch_size=config["trainer"].get("per_device_train_batch_size", 2),
    gradient_accumulation_steps=config["trainer"].get("gradient_accumulation_steps", 8),
    warmup_ratio=config["trainer"].get("warmup_ratio", 0.1),  #  warmup_ratio，default 0.1
    num_train_epochs=config["trainer"].get("num_train_epochs", 1),
    learning_rate=float(config["trainer"].get("learning_rate", 5e-5)),
    embedding_learning_rate=float(config["trainer"].get("embedding_learning_rate", 1e-5)),
    fp16=not is_bfloat16_supported(),
    bf16=is_bfloat16_supported(),
    logging_steps=1,
    optim="adamw_8bit",
    weight_decay=config["trainer"].get("weight_decay", 0.01),
    lr_scheduler_type="linear",
    seed=config["trainer"].get("seed", 42),
    output_dir=model_output_dir,
    report_to="none",
    save_strategy = "steps",
    save_steps = 10000,
)

trainer = UnslothTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    dataset_text_field="text",
    max_seq_length=max_seq_length,
    dataset_num_proc=config["trainer"].get("dataset_num_proc", 8),
    args=trainer_args,
)

# start training
trainer_stats = trainer.train()

# save model
model.save_pretrained(model_output_dir)
tokenizer.save_pretrained(model_output_dir)
print(f"Model and tokenizer saved to {model_output_dir}")