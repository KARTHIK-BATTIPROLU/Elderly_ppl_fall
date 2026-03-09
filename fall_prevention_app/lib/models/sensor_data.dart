class SensorData {
  final double chestAccX;
  final double chestAccY;
  final double chestAccZ;
  final double wristAccX;
  final double wristAccY;
  final double wristAccZ;
  final int heartRate;
  final int bodyPosture;

  SensorData({
    required this.chestAccX,
    required this.chestAccY,
    required this.chestAccZ,
    required this.wristAccX,
    required this.wristAccY,
    required this.wristAccZ,
    required this.heartRate,
    required this.bodyPosture,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      chestAccX: (json['chest_acc_x'] as num).toDouble(),
      chestAccY: (json['chest_acc_y'] as num).toDouble(),
      chestAccZ: (json['chest_acc_z'] as num).toDouble(),
      wristAccX: (json['wrist_acc_x'] as num).toDouble(),
      wristAccY: (json['wrist_acc_y'] as num).toDouble(),
      wristAccZ: (json['wrist_acc_z'] as num).toDouble(),
      heartRate: (json['heart_rate'] as num).toInt(),
      bodyPosture: (json['body_posture'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chest_acc_x': chestAccX,
      'chest_acc_y': chestAccY,
      'chest_acc_z': chestAccZ,
      'wrist_acc_x': wristAccX,
      'wrist_acc_y': wristAccY,
      'wrist_acc_z': wristAccZ,
      'heart_rate': heartRate,
      'body_posture': bodyPosture,
    };
  }

  String get postureLabel {
    switch (bodyPosture) {
      case 0:
        return 'Lying Down';
      case 1:
        return 'Sitting';
      case 2:
        return 'Standing';
      case 3:
        return 'Walking';
      case 4:
        return 'Running';
      default:
        return 'Unknown';
    }
  }
}
