#!/usr/bin/env python3
"""
JARVIS Fine-Tuning Script
Dataset: data/finetune_FINAL_v1.jsonl (499 exemplos)
Modelo alvo: gpt-4o-mini ou groq
"""
import sys, os, json, requests, time
sys.path.insert(0,'/Users/jarvis001/Library/Python/3.9/lib/python/site-packages')
from dotenv import load_dotenv
load_dotenv("/Users/jarvis001/jarvis/.env")

DATASET = "/Users/jarvis001/jarvis/data/finetune_FINAL_v1.jsonl"
API_KEY = os.getenv("OPENAI_API_KEY","")

if not API_KEY:
    print("Configure OPENAI_API_KEY no .env")
    sys.exit(1)

print(f"Dataset: {DATASET}")
with open(DATASET) as f:
    count = sum(1 for l in f if l.strip())
print(f"Exemplos: {count}")

# Upload
print("\nFazendo upload...")
with open(DATASET,"rb") as f:
    r = requests.post(
        "https://api.openai.com/v1/files",
        headers={"Authorization": f"Bearer {API_KEY}"},
        files={"file": ("finetune_jarvis.jsonl", f, "application/jsonl")},
        data={"purpose": "fine-tune"},
        timeout=120)

if r.status_code != 200:
    print(f"Upload falhou: {r.text}")
    sys.exit(1)

file_id = r.json()["id"]
print(f"Upload OK: {file_id}")

# Cria job
print("\nCriando job de fine-tuning...")
r2 = requests.post(
    "https://api.openai.com/v1/fine_tuning/jobs",
    headers={"Authorization": f"Bearer {API_KEY}",
             "Content-Type": "application/json"},
    json={"training_file": file_id,
          "model": "gpt-4o-mini-2024-07-18",
          "hyperparameters": {"n_epochs": 3}},
    timeout=30)

if r2.status_code != 200:
    print(f"Job falhou: {r2.text}")
    sys.exit(1)

job = r2.json()
job_id = job["id"]
print(f"Job criado: {job_id}")
print(f"Status: {job['status']}")
print(f"\nMonitora em: https://platform.openai.com/finetune/{job_id}")
print("\nAguarda conclusao (pode levar 30-60min)...")

# Monitora
while True:
    time.sleep(60)
    r3 = requests.get(
        f"https://api.openai.com/v1/fine_tuning/jobs/{job_id}",
        headers={"Authorization": f"Bearer {API_KEY}"})
    status = r3.json().get("status","?")
    model  = r3.json().get("fine_tuned_model","")
    print(f"Status: {status} | Modelo: {model or 'aguardando'}")
    if status in ["succeeded","failed","cancelled"]:
        break

if status == "succeeded":
    print(f"\nFINE-TUNING CONCLUIDO!")
    print(f"Modelo: {model}")
    print(f"Adiciona ao .env: OPENAI_FINETUNED_MODEL={model}")
else:
    print(f"Fine-tuning {status}")
