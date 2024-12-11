import sys
import os
import datetime
import json
import argparse
import pandas as pd
import time
from tqdm import tqdm
import yaml
from dotenv import load_dotenv
from unsloth import FastLanguageModel

# Load environment variables from .env file
load_dotenv()

# Read OpenAI configuration from environment variables
openai_base_url = os.getenv("OPENAI_BASE_URL")
openai_apikey = os.getenv("OPENAI_APIKEY")

# Template for Alpaca-style prompting
alpaca_prompt = """Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
{0}

### Input:
{1}

### Response:
{2}"""

def load_prompt(prompt_path):
    with open(prompt_path, "r", encoding="utf-8") as f:
        return f.read()

def load_model(model_config_path, model_name):
    """Load and configure the language model for inference.
    
    Args:
        model_config_path: Path to model configuration file
        model_name: Name of the model to load
        
    Returns:
        tuple: (model, tokenizer) for inference
    """
    with open(model_config_path, "r") as f:
        config = yaml.safe_load(f)
    
    # Model configuration parameters
    max_seq_length = config["model"].get("max_seq_length", 4096)
    load_in_4bit = config["model"].get("load_in_4bit", True)
    dtype = None

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=model_name,
        max_seq_length=max_seq_length,
        dtype=dtype,
        load_in_4bit=load_in_4bit,
    )
    FastLanguageModel.for_inference(model)  # Enable native 2x faster inference

    return model, tokenizer

def model_inference(model, tokenizer, instruction, input_text):
    """Perform model inference using the given instruction and input.
    
    Args:
        model: The language model
        tokenizer: The tokenizer
        instruction: The instruction text
        input_text: The input text
        
    Returns:
        str: Generated output text
    """
    inputs = tokenizer(
        [
            alpaca_prompt.format(
                instruction,
                input_text,
                "",  # Empty output for generation
            ),
        ],
        return_tensors="pt",
    ).to("cuda")
    
    model_resp = model.generate(
        **inputs,
        max_new_tokens=1024,
        repetition_penalty=1,
        pad_token_id=tokenizer.eos_token_id,
    )
    
    # Flatten 2D token list to 1D
    flat_model_resp = [token for sublist in model_resp for token in sublist]
    # Decode tokens to text
    output_text = tokenizer.decode(flat_model_resp, skip_special_tokens=True)
    return output_text

# Argument parser for command line arguments
def parse_args():
    parser = argparse.ArgumentParser(description="Triage prediction using local models.")
    parser.add_argument("--dataset", type=str, default="datasets/mimiciv-triage-eval-dataset-v1.csv", help="Path to the dataset CSV.")
    parser.add_argument("--model_name", type=str, default="phi3_5", help="Model name to use for saving results.")
    parser.add_argument("--model_config", type=str, help="Path to model configuration file")
    return parser.parse_args()

# Main function
def main():
    args = parse_args()

    # Load model and tokenizer
    model, tokenizer = load_model(args.model_config, args.model_name)

    # Load prompts
    analysis_prompts = {
        "ESI-1": load_prompt("prompts/ESI-1-Analysis.txt"),
        "ESI-2": load_prompt("prompts/ESI-2-Analysis.txt"),
        "ESI-3": load_prompt("prompts/ESI-3-Analysis.txt")
    }
    
    format_prompts = {
        "ESI-1": load_prompt("prompts/ESI-1-Format.txt"),
        "ESI-2": load_prompt("prompts/ESI-2-Format.txt"),
        "ESI-3": load_prompt("prompts/ESI-3-Format.txt")
    }

    # Load dataset
    df = pd.read_csv(args.dataset)
    
    new_columns = [
        "final_pred", "llm1_resp", "llm2_resp", "llm3_resp",
        "llm1_result", "llm2_result", "llm3_result",
    ]
    
    # Ensure new columns exist in the DataFrame
    for col in new_columns:
        if col not in df.columns:
            df[col] = None

    # Create results directory if it doesn't exist
    os.makedirs("results", exist_ok=True)

    # Iterate through the dataset and make predictions
    for index, row in tqdm(df.iterrows(), total=df.shape[0]):
        max_retries = 5  # max retries
        for attempt in range(1, max_retries + 1):
            try:
                if pd.isna(row["llm1_resp"]):
                    # ESI-1 Analysis using local model
                    llm1_resp = model_inference(model, tokenizer, analysis_prompts["ESI-1"], row["case"])
                    df.at[index, "llm1_resp"] = llm1_resp

                    # ESI-1 Format using local model
                    llm1_result = model_inference(model, tokenizer, format_prompts["ESI-1"], llm1_resp)
                    df.at[index, "llm1_result"] = llm1_result

                if pd.isna(row["llm2_resp"]):
                    # ESI-2 Analysis using local model
                    llm2_resp = model_inference(model, tokenizer, analysis_prompts["ESI-2"], row["case"])
                    df.at[index, "llm2_resp"] = llm2_resp

                    # ESI-2 Format using local model
                    llm2_result = model_inference(model, tokenizer, format_prompts["ESI-2"], llm2_resp)
                    df.at[index, "llm2_result"] = llm2_result

                if pd.isna(row["llm3_resp"]):
                    # ESI-3 Analysis using local model
                    llm3_resp = model_inference(model, tokenizer, analysis_prompts["ESI-3"], row["case"])
                    df.at[index, "llm3_resp"] = llm3_resp

                    # ESI-3 Format using local model
                    llm3_result = model_inference(model, tokenizer, format_prompts["ESI-3"], llm3_resp)
                    df.at[index, "llm3_result"] = llm3_result

                # Determine final prediction based on results
                results = [
                    df.at[index, "llm1_result"],
                    df.at[index, "llm2_result"],
                    df.at[index, "llm3_result"]
                ]
                results = [r for r in results if r is not None]
                
                if results:
                    # Count occurrences of each result
                    result_counts = {}
                    for r in results:
                        result_counts[r] = result_counts.get(r, 0) + 1
                    
                    # Get the most common result
                    final_pred = max(result_counts.items(), key=lambda x: x[1])[0]
                    df.at[index, "final_pred"] = final_pred

                # Save results after each case
                timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                output_file = f"results/exp2_local_{args.model_name}_{timestamp}.csv"
                df.to_csv(output_file, index=False)
                break  # Exit the loop if prediction is determined
                
            except Exception as e:
                print(f"Error on row {index}, attempt {attempt}: {str(e)}")
                if attempt == max_retries:
                    print(f"Max retries reached for row {index}, moving to next row")
                time.sleep(5)  # Wait before retrying

if __name__ == "__main__":
    main()
