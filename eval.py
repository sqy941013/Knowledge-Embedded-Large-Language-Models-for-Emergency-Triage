import pandas as pd
import os
import sys
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score

# Read the file path from the command line
if len(sys.argv) < 2:
    print("Please provide the experiment result file path (exp_result)")
    sys.exit(1)

file_path = sys.argv[1]
data = pd.read_csv(file_path)

# Create output directory
output_dir = os.path.join("evaluations", os.path.splitext(os.path.basename(file_path))[0])
os.makedirs(output_dir, exist_ok=True)

# Filter samples with valid predictions (final_pred not equal to -1)
data_filtered = data[data['final_pred'] != -1]

# Define y_true and y_pred
y_true = data_filtered['acuity']
y_pred = data_filtered['final_pred']

# Calculate basic evaluation metrics
accuracy = accuracy_score(y_true, y_pred)
precision = precision_score(y_true, y_pred, average='macro', zero_division=0)
recall = recall_score(y_true, y_pred, average='macro', zero_division=0)
f1 = f1_score(y_true, y_pred, average='macro', zero_division=0)

# High-risk identification (combined category of ESI-1 and ESI-2) - Recall
high_risk_true = data_filtered[y_true.isin([1, 2])]
tp_1_2 = len(high_risk_true[high_risk_true['final_pred'].isin([1, 2])])
fn_1_2 = len(high_risk_true[~high_risk_true['final_pred'].isin([1, 2])])
recall_high_risk = tp_1_2 / (tp_1_2 + fn_1_2) if (tp_1_2 + fn_1_2) > 0 else 0

# Moderate acuity classification (ESI-3) - F1 Score
moderate_true = data_filtered[y_true == 3]
tp_3 = len(moderate_true[moderate_true['final_pred'] == 3])
fp_3 = len(data_filtered[(y_pred == 3) & (y_true != 3)])
fn_3 = len(moderate_true[moderate_true['final_pred'] != 3])
precision_moderate = tp_3 / (tp_3 + fp_3) if (tp_3 + fp_3) > 0 else 0
recall_moderate = tp_3 / (tp_3 + fn_3) if (tp_3 + fn_3) > 0 else 0
f1_moderate = (2 * precision_moderate * recall_moderate) / (precision_moderate + recall_moderate) if (precision_moderate + recall_moderate) > 0 else 0

# Non-urgent classification (combined category of ESI-4 and ESI-5) - Precision
non_urgent_true = data_filtered[y_true.isin([4, 5])]
tp_4_5 = len(non_urgent_true[non_urgent_true['final_pred'].isin([4, 5])])
fp_4_5 = len(data_filtered[(y_pred.isin([4, 5])) & (~y_true.isin([4, 5]))])
precision_non_urgent = tp_4_5 / (tp_4_5 + fp_4_5) if (tp_4_5 + fp_4_5) > 0 else 0

# Number of failed predictions
failed_predictions = data[data['final_pred'] == -1].shape[0]

# Calculate over-triage and under-triage rates
# Over-triage: cases where the predicted level is higher than the actual level
over_triage_count = data_filtered[data_filtered['final_pred'] < data_filtered['acuity']].shape[0]
over_triage_rate = over_triage_count / len(data_filtered) if len(data_filtered) > 0 else 0

# Under-triage: cases where the predicted level is lower than the actual level
under_triage_count = data_filtered[data_filtered['final_pred'] > data_filtered['acuity']].shape[0]
under_triage_rate = under_triage_count / len(data_filtered) if len(data_filtered) > 0 else 0

# Store all evaluation results in a dictionary
evaluation_results = {
    "Overall Accuracy": [accuracy],
    "Macro Precision": [precision],
    "Macro Recall": [recall],
    "Macro F1 Score": [f1],
    "Recall for High-Risk (ESI-1 & ESI-2)": [recall_high_risk],
    "F1 for Moderate (ESI-3)": [f1_moderate],
    "Precision for Non-Urgent (ESI-4 & ESI-5)": [precision_non_urgent],
    "Failed Predictions Count": [failed_predictions],
    "Over-Triage Rate": [over_triage_rate],
    "Under-Triage Rate": [under_triage_rate],
    "Over-Triage Count": [over_triage_count],
    "Under-Triage Count": [under_triage_count]
}

# Save the results as a CSV file
evaluation_df = pd.DataFrame(evaluation_results)
output_file = os.path.join(output_dir, "evaluation_results.csv")
evaluation_df.to_csv(output_file, index=False)

print(f"Evaluation results have been saved to {output_file}")
