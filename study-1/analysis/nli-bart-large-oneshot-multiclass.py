import pandas as pd
import numpy as np
from transformers import pipeline

# specify task version and read in data 
task_ver = 'causal-attr-pe2-3'
n_blocks = 3
valences = ["neg", "pos"]
df = pd.read_csv('analysis/'+task_ver+'-free-text-descriptions.csv')

# specify pre-trained classifier and candidate labels
classifier = pipeline("zero-shot-classification", model="facebook/bart-large-mnli", multi_label=True)
candidate_labels_1 = ["myself", "other people", "in general", "specific situations"]

# get classifier results for each participant and scenario
for p in range(0, df.shape[0]):
    for s in range(0, n_blocks):
        for v in valences:
            # get free text description
            text_to_classify = df['descrip_block'+str(s+1)+'_'+v][p]
            print(text_to_classify)
            # classify
            res_1 = classifier(text_to_classify, candidate_labels_1)
            print(res_1)
            # add results to df
            for index, label in enumerate(res_1['labels']):
                df.at[p,'scenario'+str(s+1)+'_'+v+'_classifier1_'+str(label)+'_score'] = res_1['scores'][index] 

# write new df with labels
print(df)
df.to_csv('analysis/'+task_ver+'-free-text-descriptions-classified4-nme.csv')