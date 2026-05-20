/// Data model for a processed medical report.
class MedicalReport {
  final String id;
  final String filename;
  final String uploadTime;
  final String status;
  final String? rawText;
  final StructuredData? structuredData;
  bool userVerified;
  final bool isDuplicate;

  MedicalReport({
    required this.id,
    this.filename = '',
    this.uploadTime = '',
    this.status = '',
    this.rawText,
    this.structuredData,
    this.userVerified = false,
    this.isDuplicate = false,
  });

  factory MedicalReport.fromJson(Map<String, dynamic> json) {
    return MedicalReport(
      id: json['id'] as String,
      uploadTime: json['upload_time'] as String,
      status: json['status'] as String,
      rawText: json['raw_text'] as String?,
      structuredData: json['structured_data'] != null
          ? StructuredData.fromJson(json['structured_data'] as Map<String, dynamic>)
          : null,
      userVerified: json['user_verified'] as bool? ?? false,
      isDuplicate: json['is_duplicate'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'upload_time': uploadTime,
      'status': status,
      'raw_text': rawText,
      'structured_data': structuredData?.toJson(),
      'user_verified': userVerified,
      'is_duplicate': isDuplicate,
    };
  }
}

/// Structured data extracted from a medical report.
class StructuredData {
  String? patientName;
  String? patientId;
  String? gender;
  String? date;
  String? time;
  String? testName;
  String? doctorName;
  String? hospitalName;
  String? collected;
  String? labreference;
  List<TestResult> results;
  String? notes;

  StructuredData({
    this.patientName,
    this.patientId,
    this.gender,
    this.date,
    this.time,
    this.testName,
    this.doctorName,
    this.hospitalName,
    this.collected,
    this.labreference,
    this.results = const [],
    this.notes,
  });

  factory StructuredData.fromJson(Map<String, dynamic> json) {
    return StructuredData(
      patientName: json['patient_name'] as String?,
      patientId: json['patient_id'] as String?,
      gender: json['gender'] as String?,
      date: json['date'] as String?,
      time: json['time'] as String?,
      testName: json['test_name'] as String?,
      doctorName: json['doctor_name'] as String?,
      hospitalName: json['hospital_name'] as String?,
      collected: json['collected'] as String?,
      labreference: json['labreference'] as String?,
      results: (json['results'] as List<dynamic>?)
              ?.map((r) => TestResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patient_name': patientName,
      'patient_id': patientId,
      'gender': gender,
      'date': date,
      'time': time,
      'test_name': testName,
      'doctor_name': doctorName,
      'hospital_name': hospitalName,
      'collected': collected,
      'labreference': labreference,
      'results': results.map((r) => r.toJson()).toList(),
      'notes': notes,
    };
  }
}

/// Individual test result entry within a medical report.
class TestResult {
  String testItem;
  String value;
  String? unit;
  String? referenceRange;
  String? key; // Original database column key

  TestResult({
    required this.testItem,
    required this.value,
    this.unit,
    this.referenceRange,
    this.key,
  });

  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      testItem: json['test_item'] as String? ?? '',
      value: json['value'] as String? ?? '',
      unit: json['unit'] as String?,
      referenceRange: json['reference_range'] as String?,
      key: json['key'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'test_item': testItem,
      'value': value,
      'unit': unit,
      'reference_range': referenceRange,
      'key': key,
    };
  }
}
