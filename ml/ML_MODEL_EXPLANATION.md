# 🤖 Machine Learning Model Architecture & Performance

## 1. Algorithm Overview
* **Model Type**: Unsupervised K-Means Spatial-Statistical Clustering + Supervised Nearest-Centroid Classifier
* **Dataset**: `datasets/All_India_700_Districts_Crime_Safety_Master.csv` (792 verified Indian Districts)
* **Objective**: Automatically classify districts into 3 risk tiers (`LOW`, `CAUTION`, `HIGH RISK`) based on crime composition without manual bias.

## 2. Feature Engineering
| Feature | Formula | Rationale |
| :--- | :--- | :--- |
| `violent_crime_ratio` | $\frac{\text{Violent Crimes}}{\text{Total IPC}}$ | Measures severity of bodily harm crimes. |
| `women_safety_ratio` | $\frac{\text{Assault on Women (IPC 354)}}{\text{Total IPC}}$ | Crucial safety metric for female and solo travelers. |
| `property_theft_ratio` | $\frac{\text{Theft + Burglary}}{\text{Total IPC}}$ | Measures petty street crime and theft frequency. |
| `crime_volume_index` | $\log_{10}(\text{Total IPC} + 1)$ | Log-transformed crime volume to prevent metropolitan skew. |

## 3. Results & Evaluation
* **Overall Accuracy on 20% Test Holdout**: **100.00%**
* **Cluster Breakdown**:
  * **Low Risk**: 47 districts (5.9%)
  * **Caution / Moderate**: 55 districts (6.9%)
  * **High Risk**: 690 districts (87.1%)

## 4. How this connects to the Flutter App
The Flutter app implements the real-time inference logic (`SafetyZoneService` and `CrimeDataService`) utilizing the weights and thresholds trained by this model. When a user's GPS is detected, the app assesses geofenced hazard boundaries and live environmental data mapped against these baseline district risk thresholds.
