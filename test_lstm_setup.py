#!/usr/bin/env python3
"""
Test script to verify LSTM model setup and backend integration.
Run this after training to ensure everything is configured correctly.
"""

import os
import sys
from pathlib import Path

def check_file(filepath, description):
    """Check if a file exists."""
    if os.path.exists(filepath):
        size = os.path.getsize(filepath)
        size_mb = size / (1024 * 1024)
        print(f"  ✅ {description}: {filepath} ({size_mb:.2f} MB)")
        return True
    else:
        print(f"  ❌ {description}: {filepath} NOT FOUND")
        return False

def check_imports():
    """Check if required packages are installed."""
    print("\n" + "="*70)
    print("Checking Python packages...")
    print("="*70)
    
    packages = {
        'tensorflow': 'TensorFlow',
        'numpy': 'NumPy',
        'pandas': 'Pandas',
        'sklearn': 'scikit-learn',
        'joblib': 'Joblib',
        'fastapi': 'FastAPI',
    }
    
    all_ok = True
    for package, name in packages.items():
        try:
            if package == 'sklearn':
                import sklearn
                version = sklearn.__version__
            else:
                mod = __import__(package)
                version = mod.__version__
            print(f"  ✅ {name}: {version}")
        except ImportError:
            print(f"  ❌ {name}: NOT INSTALLED")
            all_ok = False
    
    return all_ok

def check_model_files():
    """Check if model files exist."""
    print("\n" + "="*70)
    print("Checking model files...")
    print("="*70)
    
    files = {
        'model/bilstm_model.h5': 'BiLSTM model',
        'model/scaler.pkl': 'Feature scaler',
        'model/processed_data.npz': 'Preprocessed data',
    }
    
    all_ok = True
    for filepath, description in files.items():
        if not check_file(filepath, description):
            all_ok = False
    
    return all_ok

def check_training_outputs():
    """Check if training outputs exist."""
    print("\n" + "="*70)
    print("Checking training outputs...")
    print("="*70)
    
    files = {
        'model/bilstm_training_history.png': 'Training history plot',
        'model/bilstm_confusion_matrix.png': 'Confusion matrix',
    }
    
    for filepath, description in files.items():
        check_file(filepath, description)

def test_model_loading():
    """Test if model can be loaded."""
    print("\n" + "="*70)
    print("Testing model loading...")
    print("="*70)
    
    try:
        import tensorflow as tf
        import joblib
        import numpy as np
        
        # Load model
        print("  Loading BiLSTM model...")
        model = tf.keras.models.load_model('model/bilstm_model.h5')
        print(f"  ✅ Model loaded successfully")
        print(f"     Input shape: {model.input_shape}")
        print(f"     Output shape: {model.output_shape}")
        
        # Load scaler
        print("  Loading scaler...")
        scaler = joblib.load('model/scaler.pkl')
        print(f"  ✅ Scaler loaded successfully")
        print(f"     Features: {len(scaler.mean_)}")
        
        # Test prediction
        print("  Testing prediction...")
        n_timesteps = model.input_shape[1]
        n_features = model.input_shape[2]
        
        # Create dummy input
        dummy_input = np.random.randn(1, n_timesteps, n_features).astype(np.float32)
        prediction = model.predict(dummy_input, verbose=0)
        
        print(f"  ✅ Prediction successful")
        print(f"     Input shape: {dummy_input.shape}")
        print(f"     Output: {prediction[0][0]:.4f}")
        
        return True
        
    except Exception as e:
        print(f"  ❌ Error: {e}")
        return False

def check_data_files():
    """Check if data files exist."""
    print("\n" + "="*70)
    print("Checking data files...")
    print("="*70)
    
    files = {
        'data/train.csv': 'Training data',
        'data/realtime_data.csv': 'Realtime data',
    }
    
    for filepath, description in files.items():
        check_file(filepath, description)

def check_backend_files():
    """Check if backend files exist."""
    print("\n" + "="*70)
    print("Checking backend files...")
    print("="*70)
    
    files = {
        'backend_fastapi/main.py': 'Backend main file',
        'backend_fastapi/requirements.txt': 'Backend requirements',
    }
    
    all_ok = True
    for filepath, description in files.items():
        if not check_file(filepath, description):
            all_ok = False
    
    return all_ok

def print_next_steps(all_checks_passed):
    """Print next steps based on check results."""
    print("\n" + "="*70)
    if all_checks_passed:
        print("✅ ALL CHECKS PASSED!")
        print("="*70)
        print("\nYour LSTM setup is complete and ready to use!")
        print("\nNext steps:")
        print("  1. Start the backend:")
        print("     cd backend_fastapi")
        print("     uvicorn main:app --host 0.0.0.0 --port 8002 --reload")
        print("\n  2. Test the API:")
        print("     curl -X POST http://localhost:8002/predict \\")
        print("       -H 'Content-Type: application/json' \\")
        print("       -d '{\"chest_acc_x\":0.05,\"chest_acc_y\":0.02,\"chest_acc_z\":1.01,")
        print("            \"wrist_acc_x\":0.03,\"wrist_acc_y\":0.01,\"wrist_acc_z\":1.04,")
        print("            \"heart_rate\":75,\"body_posture\":2,\"uid\":\"test_user\"}'")
        print("\n  3. Run the Flutter app:")
        print("     cd fall_prevention_app")
        print("     flutter run")
    else:
        print("⚠️  SOME CHECKS FAILED")
        print("="*70)
        print("\nPlease fix the issues above before proceeding.")
        print("\nCommon solutions:")
        print("  - Missing packages: pip install -r backend_fastapi/requirements.txt")
        print("  - Missing model: cd training && python run_training_pipeline.py")
        print("  - Missing data: Ensure data/train.csv exists")
    print("\n" + "="*70)

def main():
    print("="*70)
    print("LSTM Setup Verification")
    print("="*70)
    print("\nThis script checks if your LSTM model is properly set up.")
    
    checks = []
    
    # Run all checks
    checks.append(("Packages", check_imports()))
    checks.append(("Model files", check_model_files()))
    checks.append(("Backend files", check_backend_files()))
    check_training_outputs()  # Optional
    check_data_files()  # Optional
    checks.append(("Model loading", test_model_loading()))
    
    # Summary
    all_passed = all(result for _, result in checks)
    
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    for name, result in checks:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {status}: {name}")
    
    print_next_steps(all_passed)
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n\nInterrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n\nUnexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
