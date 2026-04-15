import os
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Bidirectional, Dense, Dropout
from tensorflow.keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
from tensorflow.keras.optimizers import Adam
import matplotlib.pyplot as plt
from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns

# Set random seeds for reproducibility
np.random.seed(42)
tf.random.set_seed(42)

def load_preprocessed_data(data_path):
    """Load preprocessed data from npz file."""
    print(f"Loading preprocessed data from {data_path}...")
    data = np.load(data_path)
    
    X_train = data['X_train']
    y_train = data['y_train']
    X_val = data['X_val']
    y_val = data['y_val']
    X_test = data['X_test']
    y_test = data['y_test']
    
    print(f"Train set: {X_train.shape}")
    print(f"Validation set: {X_val.shape}")
    print(f"Test set: {X_test.shape}")
    
    return X_train, y_train, X_val, y_val, X_test, y_test


def build_bilstm_model(n_timesteps, n_features):
    """
    Build Bidirectional LSTM model for fall risk prediction.
    
    Architecture:
        - Bidirectional LSTM (128 units) with return_sequences=True
        - Dropout (0.3)
        - Bidirectional LSTM (64 units)
        - Dropout (0.3)
        - Dense (32, relu)
        - Dense (1, sigmoid) - binary classification
    """
    model = Sequential([
        Bidirectional(
            LSTM(128, return_sequences=True),
            input_shape=(n_timesteps, n_features)
        ),
        Dropout(0.3),
        
        Bidirectional(LSTM(64, return_sequences=False)),
        Dropout(0.3),
        
        Dense(32, activation='relu'),
        Dropout(0.2),
        
        Dense(1, activation='sigmoid')
    ], name='BiLSTM_FallRisk')
    
    return model


def plot_training_history(history, save_path):
    """Plot and save training history."""
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    
    # Loss plot
    axes[0].plot(history.history['loss'], label='Train Loss', linewidth=2)
    axes[0].plot(history.history['val_loss'], label='Val Loss', linewidth=2)
    axes[0].set_xlabel('Epoch', fontsize=12)
    axes[0].set_ylabel('Loss', fontsize=12)
    axes[0].set_title('Model Loss', fontsize=14, fontweight='bold')
    axes[0].legend(fontsize=10)
    axes[0].grid(True, alpha=0.3)
    
    # Accuracy plot
    axes[1].plot(history.history['accuracy'], label='Train Accuracy', linewidth=2)
    axes[1].plot(history.history['val_accuracy'], label='Val Accuracy', linewidth=2)
    axes[1].set_xlabel('Epoch', fontsize=12)
    axes[1].set_ylabel('Accuracy', fontsize=12)
    axes[1].set_title('Model Accuracy', fontsize=14, fontweight='bold')
    axes[1].legend(fontsize=10)
    axes[1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"Training history plot saved to {save_path}")
    plt.close()


def plot_confusion_matrix(y_true, y_pred, save_path):
    """Plot and save confusion matrix."""
    cm = confusion_matrix(y_true, y_pred)
    
    plt.figure(figsize=(8, 6))
    sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
                xticklabels=['No Fall Risk', 'Fall Risk'],
                yticklabels=['No Fall Risk', 'Fall Risk'],
                cbar_kws={'label': 'Count'})
    plt.xlabel('Predicted', fontsize=12, fontweight='bold')
    plt.ylabel('Actual', fontsize=12, fontweight='bold')
    plt.title('Confusion Matrix - BiLSTM Model', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(save_path, dpi=300, bbox_inches='tight')
    print(f"Confusion matrix saved to {save_path}")
    plt.close()


if __name__ == "__main__":
    print("="*70)
    print("BiLSTM Model Training for Fall Risk Prediction")
    print("="*70)
    
    # Configuration
    DATA_PATH = "../model/processed_data.npz"
    MODEL_OUTPUT_DIR = "../model"
    MODEL_NAME = "bilstm_model.h5"
    EPOCHS = 100
    BATCH_SIZE = 32
    LEARNING_RATE = 0.001
    
    # Check if preprocessed data exists
    if not os.path.exists(DATA_PATH):
        print(f"\n❌ ERROR: Preprocessed data not found at {DATA_PATH}")
        print("Please run preprocess_lstm.py first!")
        exit(1)
    
    # Load data
    X_train, y_train, X_val, y_val, X_test, y_test = load_preprocessed_data(DATA_PATH)
    
    n_timesteps = X_train.shape[1]
    n_features = X_train.shape[2]
    
    print(f"\nModel input shape: ({n_timesteps} timesteps, {n_features} features)")
    print(f"Class distribution in training set: {np.bincount(y_train)}")
    
    # Build model
    print("\nBuilding BiLSTM model...")
    model = build_bilstm_model(n_timesteps, n_features)
    
    # Compile model
    optimizer = Adam(learning_rate=LEARNING_RATE)
    model.compile(
        optimizer=optimizer,
        loss='binary_crossentropy',
        metrics=['accuracy', tf.keras.metrics.Precision(), tf.keras.metrics.Recall()]
    )
    
    print("\nModel Summary:")
    model.summary()
    
    # Create output directory
    os.makedirs(MODEL_OUTPUT_DIR, exist_ok=True)
    
    # Callbacks
    model_path = os.path.join(MODEL_OUTPUT_DIR, MODEL_NAME)
    
    callbacks = [
        EarlyStopping(
            monitor='val_loss',
            patience=15,
            restore_best_weights=True,
            verbose=1
        ),
        ModelCheckpoint(
            model_path,
            monitor='val_accuracy',
            save_best_only=True,
            verbose=1
        ),
        ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-7,
            verbose=1
        )
    ]
    
    # Train model
    print("\n" + "="*70)
    print("Starting training...")
    print("="*70 + "\n")
    
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=callbacks,
        verbose=1
    )
    
    # Evaluate on test set
    print("\n" + "="*70)
    print("Evaluating on test set...")
    print("="*70)
    
    test_results = model.evaluate(X_test, y_test, verbose=0)
    print(f"\nTest Loss: {test_results[0]:.4f}")
    print(f"Test Accuracy: {test_results[1]:.4f}")
    print(f"Test Precision: {test_results[2]:.4f}")
    print(f"Test Recall: {test_results[3]:.4f}")
    
    # Generate predictions
    y_pred_proba = model.predict(X_test, verbose=0)
    y_pred = (y_pred_proba > 0.5).astype(int).flatten()
    
    # Classification report
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred, target_names=['No Fall Risk', 'Fall Risk']))
    
    # Plot training history
    history_plot_path = os.path.join(MODEL_OUTPUT_DIR, "bilstm_training_history.png")
    plot_training_history(history, history_plot_path)
    
    # Plot confusion matrix
    cm_plot_path = os.path.join(MODEL_OUTPUT_DIR, "bilstm_confusion_matrix.png")
    plot_confusion_matrix(y_test, y_pred, cm_plot_path)
    
    # Save final model (if not already saved by checkpoint)
    final_model_path = os.path.join(MODEL_OUTPUT_DIR, "bilstm_model_final.h5")
    model.save(final_model_path)
    
    print("\n" + "="*70)
    print("✅ Training Complete!")
    print("="*70)
    print(f"\nModel saved to:")
    print(f"  - {model_path} (best validation accuracy)")
    print(f"  - {final_model_path} (final epoch)")
    print(f"\nPlots saved:")
    print(f"  - {history_plot_path}")
    print(f"  - {cm_plot_path}")
    print(f"\nNext step: Update backend_fastapi/main.py to use the BiLSTM model")
