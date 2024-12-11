import sys
import os
import datetime
import json
import argparse
import pandas as pd
import time
from tqdm import tqdm
from utils.openai_helper import DifyHelper

# Argument parser for command line arguments
def parse_args():
    parser = argparse.ArgumentParser(description="Triage prediction using Dify.")
    parser.add_argument("--config", type=str, default="configs/dify_config.json", help="Path to the config file.")
    parser.add_argument("--dataset", type=str, default="datasets/mimiciv-triage-eval-dataset-v1.csv", help="Path to the dataset CSV.")
    parser.add_argument("--model_name", type=str, default="phi3_5", help="Model name to use for saving results.")
    return parser.parse_args()

# Function to load config from JSON file
def load_config(config_path):
    with open(config_path, "r") as f:
        return json.load(f)

# Main function
def main():
    args = parse_args()

    # Load config from JSON
    config = load_config(args.config)

    # Initialize dify helpers based on the config
    difys = {name: DifyHelper(api_base=cfg["api_base"], api_key=cfg["api_key"]) for name, cfg in config.items()}

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

    # Iterate through the dataset and make predictions
    for index, row in tqdm(df.iterrows(), total=df.shape[0]):
        max_retries = 5  # max retries
        for attempt in range(1, max_retries + 1):
            try:
                # Make API calls to get responses
                llm1_resp = difys["LLM1Prompt"].chat_messages(query=row["triage_text"])
                llm2_resp = difys["LLM2Prompt"].chat_messages(query=row["triage_text"])
                llm3_resp = difys["LLM3Prompt"].chat_messages(query=row["triage_text"])

                # Store responses in the DataFrame
                df.at[index, "llm1_resp"] = llm1_resp
                df.at[index, "llm2_resp"] = llm2_resp
                df.at[index, "llm3_resp"] = llm3_resp

                # Format results
                llm1_result = json.loads(difys["LLM1Format"].chat_messages(query=llm1_resp))["result"]
                llm2_result = json.loads(difys["LLM2Format"].chat_messages(query=llm2_resp))["result"]
                llm3_result = json.loads(difys["LLM3Format"].chat_messages(query=llm3_resp))

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
                break  # Exit the loop if prediction is determined

            except Exception as e:
                # If an error occurs, print the error and wait
                print(f"Error at row {index}, attempt {attempt}: {e}")
                if attempt == max_retries:
                    print(f"Max retries reached for row {index}.")
                    # Store error data if all attempts fail
                    df.at[index, "llm1_resp"] = llm1_resp if 'llm1_resp' in locals() else None
                    df.at[index, "llm2_resp"] = llm2_resp if 'llm2_resp' in locals() else None
                    df.at[index, "llm3_resp"] = llm3_resp if 'llm3_resp' in locals() else None
                    df.at[index, "llm1_result"] = llm1_result if 'llm1_result' in locals() else None
                    df.at[index, "llm2_result"] = llm2_result if 'llm2_result' in locals() else None
                    df.at[index, "llm3_result"] = llm3_result if 'llm3_result' in locals() else None
                    df.at[index, "final_pred"] = -1
                else:
                    # Wait before retrying
                    wait_time = 30 * attempt
                    print(f"Retrying row {index} in {wait_time} seconds...")
                    time.sleep(wait_time)

    # Generate the filename with the current timestamp
    timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    filename = f"experiments/{args.model_name}_{timestamp}.csv"

    # Save the DataFrame to a CSV file
    df.to_csv(filename, index=False)
    print(f"DataFrame saved to {filename}")

if __name__ == "__main__":
    main()