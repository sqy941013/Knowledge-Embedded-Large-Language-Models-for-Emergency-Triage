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
        "final_pred", "llm_resp"
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
                llm_resp = difys["BasicPrompt"].chat_messages(query=row["triage_text"])

                # Store responses in the DataFrame
                df.at[index, "llm_resp"] = llm_resp


                # Format results
                final_pred = json.loads(difys["BasicFormat"].chat_messages(query=llm_resp))

                # Store results in the DataFrame
                df.at[index, "final_pred"] = final_pred
                
                break  # break loop


            except Exception as e:
                # If an error occurs, print the error and wait
                print(f"Error at row {index}, attempt {attempt}: {e}")
                if attempt == max_retries:
                    print(f"Max retries reached for row {index}.")
                    # Store error data if all attempts fail
                    df.at[index, "llm_resp"] = llm_resp if 'llm1_resp' in locals() else None
                    df.at[index, "final_pred"] = -1
                else:
                    # Wait before retrying
                    wait_time = 30 * attempt
                    print(f"Retrying row {index} in {wait_time} seconds...")
                    time.sleep(wait_time)

    # Generate the filename with the current timestamp
    timestamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
    filename = f"results/exp1_{args.model_name}_{timestamp}.csv"

    # Save the DataFrame to a CSV file
    df.to_csv(filename, index=False)
    print(f"DataFrame saved to {filename}")

if __name__ == "__main__":
    main()