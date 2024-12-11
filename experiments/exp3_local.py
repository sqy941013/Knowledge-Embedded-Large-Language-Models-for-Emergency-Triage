import sys
import os
import datetime
import json
import argparse
import pandas as pd
import time
from tqdm import tqdm
from utils.openai_helper import DifyHelper, OpenaiHelper
import yaml
from dotenv import load_dotenv

# Ensure the required packages are installed
# pip install python-dotenv
# Load environment variables from .env file
load_dotenv()

# Read OpenAI base URL and API key from environment variables
openai_base_url = os.getenv("OPENAI_BASE_URL")
openai_apikey = os.getenv("OPENAI_APIKEY")

openai_helper = OpenaiHelper(api_key=openai_apikey, base_url=openai_base_url)


# Argument parser for command line arguments
def parse_args():
    parser = argparse.ArgumentParser(description="Triage prediction.")
    parser.add_argument(
        "--config",
        type=str,
        default="configs/dify_config.json",
        help="Path to the config file.",
    )
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


alpaca_prompt = """Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

### Instruction:
{}

### Input:
{}

### Response:
{}
    """


# Function to load config from JSON file
def load_config(config_path):
    with open(config_path, "r") as f:
        return json.load(f)


def load_model(model_config_path, model_name):
    with open(model_config_path, "r") as f:
        config = yaml.safe_load(f)
    max_seq_length = config["model"].get("max_seq_length", 4096)
    load_in_4bit = config["model"].get("load_in_4bit", True)
    # model_name = config["model"].get("model_name", "unsloth/gemma-2b-bnb-4bit")
    # model_name = args.model_name
    dtype = None

    from unsloth import FastLanguageModel

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=model_name,  # YOUR MODEL YOU USED FOR TRAINING
        max_seq_length=max_seq_length,
        dtype=dtype,
        load_in_4bit=load_in_4bit,
    )
    FastLanguageModel.for_inference(model)  # Enable native 2x faster inference

    return model, tokenizer


def model_inference(model, tokenizer, instruction, input):
    inputs = tokenizer(
        [
            alpaca_prompt.format(
                instruction,  # instruction
                input,  # input
                "",  # output - leave this blank for generation!
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
    # print(model_resp)
    flat_model_resp = [token for sublist in model_resp for token in sublist]
    # 解码
    output_text = tokenizer.decode(flat_model_resp, skip_special_tokens=True)
    return output_text


llm1_instruction = "Analyze the patient’s condition and assess if they require immediate life-saving interventions. Focus on identifying critical needs in airway, breathing, circulation, or severe physiological instability. Provide specific reasons for your assessment."
llm2_instruction = "Analyze the patient’s condition based on the provided input. Determine if the patient meets ESI Level 2 criteria by assessing for high-risk situations, new onset of confusion, lethargy, or disorientation, and severe pain or distress. Provide your reasoning, referencing relevant examples from the ESI Level 2 guidelines."
llm3_instruction = "Analyze the patient's condition and predict the number of resources likely required for their ED visit to reach a disposition. List only the essential resources, providing brief reasoning for each."


def get_text_from_file(file_path):
    with open(file_path, "r") as file:
        return file.read()


llm1_format_prompt = get_text_from_file("prompts/ESI-1-Format.txt")
llm2_format_prompt = get_text_from_file("prompts/ESI-2-Format.txt")
llm3_format_prompt = get_text_from_file("prompts/ESI-3-Format.txt")


# Main function
def main():
    # Openai Test
    resp = openai_helper.get_response(
        system_prompt="You are a helpful assistant!",
        user_input="Hello! Are you ready to start?",
    )
    print(llm1_format_prompt)
    print(llm2_format_prompt)
    print(llm3_format_prompt)
    print(resp)

    args = parse_args()

    # Load config from JSON
    config = load_config(args.config)

    model, tokenizer = load_model(args.model_config, args.model_name)

    # Initialize dify helpers based on the config
    difys = {
        name: DifyHelper(api_base=cfg["api_base"], api_key=cfg["api_key"])
        for name, cfg in config.items()
    }

    # Load dataset
    df = pd.read_csv(args.dataset)

    new_columns = [
        "final_pred",
        "llm1_resp",
        "llm2_resp",
        "llm3_resp",
        "llm1_result",
        "llm2_result",
        "llm3_result",
    ]

    # Ensure new columns exist in the DataFrame
    for col in new_columns:
        if col not in df.columns:
            df[col] = None

    # Iterate through the dataset and make predictions
    for index, row in tqdm(df.iterrows(), total=df.shape[0]):
        max_retries = 5  
        for attempt in range(1, max_retries + 1):
            try:
                # Use finetuned model to get responses
                llm1_resp = model_inference(
                    model, tokenizer, llm1_instruction, row["triage_text"]
                )
                # print(llm1_resp)
                llm2_resp = model_inference(
                    model, tokenizer, llm2_instruction, row["triage_text"]
                )
                # print(llm2_resp)
                llm3_resp = model_inference(
                    model, tokenizer, llm3_instruction, row["triage_text"]
                )
                # print(llm3_resp)
                # Store responses in the DataFrame
                df.at[index, "llm1_resp"] = llm1_resp
                df.at[index, "llm2_resp"] = llm2_resp
                df.at[index, "llm3_resp"] = llm3_resp

                llm1_format_resp = openai_helper.get_response(
                    system_prompt=llm1_format_prompt,
                    user_input=llm1_resp,
                )
                print(llm1_format_resp)
                if llm1_format_resp == "True":
                    llm1_result = True
                else:
                    llm1_result = False

                llm2_format_resp = openai_helper.get_response(
                    system_prompt=llm2_format_prompt,
                    user_input=llm2_resp,
                )
                print(llm2_format_resp)
                if llm2_format_resp == "True":
                    llm2_result = True
                else:
                    llm2_result = False

                llm3_result = json.loads(
                    openai_helper.get_response(
                        system_prompt=llm3_format_prompt,
                        user_input=llm3_resp,
                    )
                )

                # Store results in the DataFrame
                df.at[index, "llm1_result"] = llm1_result
                df.at[index, "llm2_result"] = llm2_result
                df.at[index, "llm3_result"] = llm3_result

                # Determine final prediction
                if llm1_result is True:
                    final_pred = 1
                elif llm2_result is True:
                    final_pred = 2
                elif llm3_result > 1:
                    final_pred = 3
                elif llm3_result == 1:
                    final_pred = 4
                else:
                    final_pred = 5

                # Store final prediction in the DataFrame
                df.at[index, "final_pred"] = final_pred
                break  

            except Exception as e:
                # If an error occurs, print the error and wait
                print(f"Error at row {index}, attempt {attempt}: {e}")
                if attempt == max_retries:
                    print(f"Max retries reached for row {index}.")
                    # Store error data if all attempts fail
                    df.at[index, "llm1_resp"] = (
                        llm1_resp if "llm1_resp" in locals() else None
                    )
                    df.at[index, "llm2_resp"] = (
                        llm2_resp if "llm2_resp" in locals() else None
                    )
                    df.at[index, "llm3_resp"] = (
                        llm3_resp if "llm3_resp" in locals() else None
                    )
                    df.at[index, "llm1_result"] = (
                        llm1_result if "llm1_result" in locals() else None
                    )
                    df.at[index, "llm2_result"] = (
                        llm2_result if "llm2_result" in locals() else None
                    )
                    df.at[index, "llm3_result"] = (
                        llm3_result if "llm3_result" in locals() else None
                    )
                    df.at[index, "final_pred"] = -1
                else:
                    # Wait before retrying
                    wait_time = 30 * attempt
                    print(f"Retrying row {index} in {wait_time} seconds...")
                    time.sleep(wait_time)

    # Generate the filename with the current timestamp
    timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
   
    save_model_name = os.path.basename(args.model_name)


    filename = f"results/{save_model_name}_{timestamp}.csv"


    output_dir = os.path.dirname(filename)
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)


    df.to_csv(filename, index=False)
    print(f"DataFrame saved to {filename}")


if __name__ == "__main__":
    main()
