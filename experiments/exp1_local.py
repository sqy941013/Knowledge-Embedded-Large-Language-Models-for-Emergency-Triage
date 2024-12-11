import sys
import os
import datetime
import json
import argparse
import pandas as pd
import time
from tqdm import tqdm
from utils.openai_helper import OpenaiHelper
import yaml
from dotenv import load_dotenv

# Dependencies required:
# pip install python-dotenv

# Load environment variables from .env file
load_dotenv()

# Read OpenAI configuration from environment variables
openai_base_url = os.getenv("OPENAI_BASE_URL")
openai_apikey = os.getenv("OPENAI_APIKEY")

# Initialize OpenAI helper with configuration
# OpenAI Model is used to determine the final prediction
# You can use your own local model as well
openai_helper = OpenaiHelper(api_key=openai_apikey, base_url=openai_base_url)


def parse_args():
    """Parse command line arguments for triage prediction."""
    parser = argparse.ArgumentParser(description="ESI Triage Level Prediction")
    parser.add_argument(
        "--dataset",
        type=str,
        default="datasets/mimiciv-triage-eval-dataset-v1.csv",
        help="Path to the dataset CSV.",
    )
    parser.add_argument(
        "--model_name",
        type=str,
        default="phi3_5",
        help="Model name to use for saving results.",
    )
    parser.add_argument("--model_config", type=str)
    return parser.parse_args()


# Template for Alpaca-style prompting
alpaca_prompt = """Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
{}

### Input:
{}

### Response:
{}
    """


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

    from unsloth import FastLanguageModel

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=model_name,
        max_seq_length=max_seq_length,
        dtype=dtype,
        load_in_4bit=load_in_4bit,
    )
    FastLanguageModel.for_inference(model)  # Enable native 2x faster inference

    return model, tokenizer


def model_inference(model, tokenizer, instruction, input):
    """Perform model inference using the given instruction and input.
    
    Args:
        model: The language model
        tokenizer: The tokenizer
        instruction: The instruction text
        input: The input text
        
    Returns:
        str: Generated output text
    """
    inputs = tokenizer(
        [
            alpaca_prompt.format(
                instruction,
                input,
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


# Single instruction for ESI level determination
esi_instruction = """Analyze the patient's condition and determine their Emergency Severity Index (ESI) level from 1 to 5 based on the following criteria:

ESI Level 1: Requires immediate life-saving intervention
ESI Level 2: High risk situation, confused/lethargic/disoriented, or severe pain/distress
ESI Level 3: Many resources needed (labs, ECG, X-rays, CT, specialists, etc.)
ESI Level 4: One resource needed
ESI Level 5: No resources needed

Provide your assessment and reasoning, then clearly state the ESI level (1-5) at the end."""


def get_esi_level(response_text):
    """Extract ESI level from model response.
    
    Args:
        response_text: The model's response text
        
    Returns:
        int: ESI level (1-5) or -1 if not found
    """
    # Look for the ESI level number at the end of the text
    try:
        # First try to find "ESI level: X" or "ESI: X" pattern
        if "ESI level:" in response_text.lower():
            level = int(response_text.lower().split("ESI level:")[-1].strip()[0])
        elif "ESI:" in response_text.lower():
            level = int(response_text.lower().split("ESI:")[-1].strip()[0])
        else:
            # Look for the last number (1-5) in the text
            import re
            numbers = re.findall(r'[1-5]', response_text)
            if numbers:
                level = int(numbers[-1])
            else:
                level = -1
        
        # Validate the level
        if 1 <= level <= 5:
            return level
        return -1
    except:
        return -1


def main():
    """Main execution function for triage prediction."""
    args = parse_args()

    # Initialize model
    model, tokenizer = load_model(args.model_config, args.model_name)

    # Load and prepare dataset
    df = pd.read_csv(args.dataset)

    # Initialize new columns
    df["model_response"] = None
    df["esi_prediction"] = None

    # Process each row in the dataset
    for index, row in tqdm(df.iterrows(), total=df.shape[0]):
        max_retries = 5  # Maximum number of retry attempts
        for attempt in range(1, max_retries + 1):
            try:
                # Get response from model
                model_response = model_inference(
                    model, tokenizer, esi_instruction, row["triage_text"]
                )
                
                # Extract ESI level from response
                esi_level = get_esi_level(model_response)
                
                # Store results in DataFrame
                df.at[index, "model_response"] = model_response
                df.at[index, "esi_prediction"] = esi_level
                break  # Successful processing, exit retry loop

            except Exception as e:
                # If an error occurs, print the error and wait
                print(f"Error at row {index}, attempt {attempt}: {e}")
                if attempt == max_retries:
                    print(f"Max retries reached for row {index}.")
                    # Store error data if all attempts fail
                    df.at[index, "model_response"] = None
                    df.at[index, "esi_prediction"] = -1
                else:
                    # Wait before retrying
                    wait_time = 30 * attempt
                    print(f"Retrying row {index} in {wait_time} seconds...")
                    time.sleep(wait_time)

    # Generate the filename with the current timestamp
    timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    # Extract the model name from the path
    save_model_name = os.path.basename(args.model_name)

    # Generate the full file path
    filename = f"results/{save_model_name}_{timestamp}.csv"

    # Ensure the output directory exists
    output_dir = os.path.dirname(filename)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Save the DataFrame to a CSV file
    df.to_csv(filename, index=False)
    print(f"DataFrame saved to {filename}")


if __name__ == "__main__":
    main()
