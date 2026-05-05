/// Data model for a processed medical report.
class MedicalReport {
  final String id;
  final String filename;
  final String uploadTime;
  final String status;
  final String? rawText;
  final StructuredData? structuredData;
  final bool userVerified;

  MedicalReport({
    required this.id,
    required this.filename,
    required this.uploadTime,
    required this.status,
    this.rawText,
    this.structuredData,
    this.userVerified = false,
  });

  factory MedicalReport.fromJson(Map<String, dynamic> json) {
    return MedicalReport(
      id: json['id'] as String,
      filename: json['filename'] as String,
      uploadTime: json['upload_time'] as String,
      status: json['status'] as String,
      rawText: json['raw_text'] as String?,
      structuredData: json['structured_data'] != null
          ? StructuredData.fromJson(json['structured_data'] as Map<String, dynamic>)
          : null,
      userVerified: json['user_verified'] as bool? ?? false,
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
    };
  }
}

/// Structured data extracted from a medical report.
class StructuredData {
  String? patientName;
  String? patientId;
  String? date;
  String? testName;
  String? doctorName;
  String? hospitalName;
  List<TestResult> results;
  String? notes;

  StructuredData({
    this.patientName,
    this.patientId,
    this.date,
    this.testName,
    this.doctorName,
    this.hospitalName,
    this.results = const [],
    this.notes,
  });

  factory StructuredData.fromJson(Map<String, dynamic> json) {
    return StructuredData(
      patientName: json['patient_name'] as String?,
      patientId: json['patient_id'] as String?,
      date: json['date'] as String?,
      testName: json['test_name'] as String?,
      doctorName: json['doctor_name'] as String?,
      hospitalName: json['hospital_name'] as String?,
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
      'date': date,
      'test_name': testName,
      'doctor_name': doctorName,
      'hospital_name': hospitalName,
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

  TestResult({
    required this.testItem,
    required this.value,
    this.unit,
    this.referenceRange,
  });

  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      testItem: json['test_item'] as String? ?? '',
      value: json['value'] as String? ?? '',
      unit: json['unit'] as String?,
      referenceRange: json['reference_range'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'test_item': testItem,
      'value': value,
      'unit': unit,
      'reference_range': referenceRange,
    };
  }
}
