#!/usr/bin/env python3
"""
Quick start script to run the complete LSTM training pipeline.
This script runs preprocessing and training in sequence.
"""

import os
import sys
import subprocess

def run_command(command, description):
    """Run a command and handle errors."""
    print("\n" + "="*70)
    print(f"🚀 {description}")
    print("="*70)
    
    result = subprocess.run(command, shell=True)
    
    if result.returncode != 0:
        print(f"\n❌ Error: {description} failed!")
        sys.exit(1)
    
    print(f"\n✅ {description} completed successfully!")
    return True

def check_data_exists():
    """Check if training data exists."""
    data_path = "../data/train.csv"
    if not os.path.exists(data_path):
        print(f"❌ Error: Training data not found at {data_path}")
        print("Please ensure train.csv exists in the data/ directory")
        sys.exit(1)
    print(f"✅ Found training data at {data_path}")

def main():
    print("="*70)
    print("LSTM Training Pipeline - Quick Start")
    print("="*70)
    print("\nThis script will:")
    print("  1. Preprocess data (create sequences)")
    print("  2. Train BiLSTM model")
    print("  3. Generate evaluation plots")
    print("\nEstimated time: 10-30 minutes (depending on dataset size)")
    
    # Check prerequisites
    print("\n" + "="*70)
    print("Checking prerequisites...")
    print("="*70)
    check_data_exists()
    
    # Step 1: Preprocess data
    run_command(
        "python preprocess_lstm.py",
        "Step 1/2: Preprocessing data"
    )
    
    # Step 2: Train model
    run_command(
        "python train_bilstm.py",
        "Step 2/2: Training BiLSTM model"
    )
    
    # Success message
    print("\n" + "="*70)
    print("🎉 TRAINING PIPELINE COMPLETE!")
    print("="*70)
    print("\nGenerated files:")
    print("  📁 model/processed_data.npz - Preprocessed sequences")
    print("  📁 model/scaler.pkl - Feature scaler")
    print("  📁 model/bilstm_model.h5 - Trained BiLSTM model")
    print("  📁 model/bilstm_training_history.png - Training plots")
    print("  📁 model/bilstm_confusion_matrix.png - Confusion matrix")
    print("\nNext steps:")
    print("  1. Review the training plots in model/ directory")
    print("  2. Start the backend: cd ../backend_fastapi && uvicorn main:app --reload")
    print("  3. Test the API: curl -X POST http://localhost:8000/predict ...")
    print("\n" + "="*70)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Training interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Unexpected error: {e}")
        sys.exit(1)
