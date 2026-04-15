import os
import numpy as np
import pandas as pd
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
import joblib

def load_and_prepare_data(csv_path, window_size=20, step_size=1):
    """
    Load CSV data and create sequences for LSTM training.
    
    Args:
        csv_path: Path to train.csv
        window_size: Number of timesteps in each sequence
        step_size: Sliding window step size
    
    Returns:
        X_sequences: numpy array of shape (n_samples, window_size, n_features)
        y_labels: numpy array of shape (n_samples,)
    """
    print(f"Loading data from {csv_path}...")
    df = pd.read_csv(csv_path)
    
    # Features used in the model
    feature_columns = [
        "chest_acc_x", "chest_acc_y", "chest_acc_z",
        "wrist_acc_x", "wrist_acc_y", "wrist_acc_z",
        "heart_rate", "body_posture"
    ]
    
    target_column = "fall_risk"
    
    print(f"Dataset shape: {df.shape}")
    print(f"Features: {feature_columns}")
    print(f"Target distribution:\n{df[target_column].value_counts()}")
    
    # Group by subject_id to maintain temporal continuity
    X_sequences = []
    y_labels = []
    
    if 'subject_id' in df.columns:
        print("\nCreating sequences grouped by subject_id...")
        subjects = df['subject_id'].unique()
        
        for subject in subjects:
            subject_data = df[df['subject_id'] == subject].sort_index()
            
            if len(subject_data) < window_size:
                print(f"  Skipping subject {subject}: only {len(subject_data)} samples")
                continue
            
            features = subject_data[feature_columns].values
            labels = subject_data[target_column].values
            
            # Create sliding windows
            for i in range(0, len(features) - window_size + 1, step_size):
                window = features[i:i + window_size]
                # Use the label of the last timestep in the window
                label = labels[i + window_size - 1]
                
                X_sequences.append(window)
                y_labels.append(label)
            
            if len(subject_data) >= window_size:
                print(f"  Subject {subject}: {len(subject_data)} samples -> {(len(subject_data) - window_size) // step_size + 1} windows")
    else:
        print("\nNo subject_id found. Creating sequences from entire dataset...")
        features = df[feature_columns].values
        labels = df[target_column].values
        
        for i in range(0, len(features) - window_size + 1, step_size):
            window = features[i:i + window_size]
            label = labels[i + window_size - 1]
            
            X_sequences.append(window)
            y_labels.append(label)
    
    X_sequences = np.array(X_sequences, dtype=np.float32)
    y_labels = np.array(y_labels, dtype=np.int32)
    
    print(f"\nTotal sequences created: {len(X_sequences)}")
    print(f"Sequence shape: {X_sequences.shape}")
    print(f"Label distribution: {np.bincount(y_labels)}")
    
    return X_sequences, y_labels


def normalize_sequences(X_train, X_val, X_test):
    """
    Normalize sequences using StandardScaler.
    Fits on training data and transforms all sets.
    """
    print("\nNormalizing data...")
    
    # Reshape to 2D for scaling
    n_train_samples, n_timesteps, n_features = X_train.shape
    X_train_flat = X_train.reshape(-1, n_features)
    X_val_flat = X_val.reshape(-1, n_features)
    X_test_flat = X_test.reshape(-1, n_features)
    
    # Fit scaler on training data only
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train_flat)
    X_val_scaled = scaler.transform(X_val_flat)
    X_test_scaled = scaler.transform(X_test_flat)
    
    # Reshape back to 3D
    X_train_scaled = X_train_scaled.reshape(X_train.shape)
    X_val_scaled = X_val_scaled.reshape(X_val.shape)
    X_test_scaled = X_test_scaled.reshape(X_test.shape)
    
    print(f"Scaler fitted. Mean: {scaler.mean_[:3]}... Std: {scaler.scale_[:3]}...")
    
    return X_train_scaled, X_val_scaled, X_test_scaled, scaler


if __name__ == "__main__":
    # Configuration
    DATA_PATH = "../data/train.csv"
    WINDOW_SIZE = 20  # Number of timesteps
    STEP_SIZE = 5     # Sliding window step (5 = 75% overlap)
    TEST_SIZE = 0.2
    VAL_SIZE = 0.2    # 20% of remaining data after test split
    RANDOM_STATE = 42
    
    print("="*60)
    print("LSTM Data Preprocessing Pipeline")
    print("="*60)
    
    # Check if data file exists
    if not os.path.exists(DATA_PATH):
        print(f"ERROR: Data file not found at {DATA_PATH}")
        print("Please ensure train.csv exists in the data/ directory")
        exit(1)
    
    # Load and create sequences
    X, y = load_and_prepare_data(DATA_PATH, window_size=WINDOW_SIZE, step_size=STEP_SIZE)
    
    if len(X) == 0:
        print("ERROR: No sequences created. Check your data.")
        exit(1)
    
    # Split into train, validation, and test sets
    print("\nSplitting data...")
    X_train, X_temp, y_train, y_temp = train_test_split(
        X, y, test_size=TEST_SIZE, random_state=RANDOM_STATE, stratify=y
    )
    
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp, test_size=0.5, random_state=RANDOM_STATE, stratify=y_temp
    )
    
    print(f"Train set: {X_train.shape[0]} samples")
    print(f"Validation set: {X_val.shape[0]} samples")
    print(f"Test set: {X_test.shape[0]} samples")
    
    # Normalize
    X_train, X_val, X_test, scaler = normalize_sequences(X_train, X_val, X_test)
    
    # Save preprocessed data
    output_dir = "../model"
    os.makedirs(output_dir, exist_ok=True)
    
    output_file = os.path.join(output_dir, "processed_data.npz")
    scaler_file = os.path.join(output_dir, "scaler.pkl")
    
    print(f"\nSaving preprocessed data to {output_file}...")
    np.savez_compressed(
        output_file,
        X_train=X_train, y_train=y_train,
        X_val=X_val, y_val=y_val,
        X_test=X_test, y_test=y_test
    )
    
    print(f"Saving scaler to {scaler_file}...")
    joblib.dump(scaler, scaler_file)
    
    print("\n" + "="*60)
    print("✅ Preprocessing complete!")
    print("="*60)
    print(f"Output files:")
    print(f"  - {output_file}")
    print(f"  - {scaler_file}")
    print(f"\nNext step: Run train_bilstm.py to train the model")
