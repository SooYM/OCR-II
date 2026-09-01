/// Clinical Report Domain Models.
///
/// This module provides strong typing for digitized medical laboratory reports,
/// parsed demographic headers, and extracted clinical biomarker measurements.
///
/// ### Simple Example:
/// ```dart
/// // Deserializing a report from backend API JSON response
/// final report = MedicalReport.fromJson(jsonResponse);
/// print('Report ID: ${report.id}, Patient: ${report.structuredData?.patientName}');
/// ```
///
/// ### Advanced Example:
/// ```dart
/// // Iterating over extracted clinical parameters
/// for (final result in report.structuredData?.results ?? []) {
///   print('${result.testItem}: ${result.value} ${result.unit ?? ""}');
/// }
/// ```
library report_model;

/// Top-level model representing a complete digitized medical laboratory document.
///
/// Encapsulates server metadata, processing lifecycle flags, OCR validation results,
/// and the nested [StructuredData] clinical payload.
class MedicalReport {
  /// Unique identifier assigned to the report record (UUID).
  final String id;

  /// Original uploaded filename(s) (comma-separated for multi-page documents).
  final String filename;

  /// ISO 8601 timestamp string when the file was ingested.
  final String uploadTime;

  /// Processing status string (e.g. `'completed'`, `'processing'`, `'name_mismatch'`).
  final String status;

  /// Raw text or OCR execution summary.
  final String? rawText;

  /// Structured demographic metadata and parsed clinical biomarker measurements.
  final StructuredData? structuredData;

  /// Whether the report has been reviewed and finalized by the user.
  bool userVerified;

  /// Flag set to true if the backend duplicate engine detected overlapping records.
  final bool isDuplicate;

  /// Flag set to true if extracted patient name deviates from registered user profile.
  final bool isNameMismatch;

  /// Flag set to true if extracted gender conflicts with registered user profile.
  final bool isGenderMismatch;

  /// Flag set to true if extracted DOB or age conflicts with registered user profile.
  final bool isAgeMismatch;

  /// Flag set to true if the uploaded document was rejected as non-medical text.
  final bool isNotMedicalReport;

  /// Constructs a new [MedicalReport] instance.
  MedicalReport({
    required this.id,
    this.filename = '',
    this.uploadTime = '',
    this.status = '',
    this.rawText,
    this.structuredData,
    this.userVerified = false,
    this.isDuplicate = false,
    this.isNameMismatch = false,
    this.isGenderMismatch = false,
    this.isAgeMismatch = false,
    this.isNotMedicalReport = false,
  });

  /// Factory constructor to deserialize a [MedicalReport] from a JSON map.
  ///
  /// * [json]: A decoded JSON map matching the backend `/api/upload` schema.
  /// * Returns: A typed [MedicalReport] object with safe default fallbacks.
  factory MedicalReport.fromJson(Map<String, dynamic> json) {
    return MedicalReport(
      id: json['id'] as String,
      filename: json['filename'] as String? ?? '',
      uploadTime: json['upload_time'] as String? ?? '',
      status: json['status'] as String? ?? '',
      rawText: json['raw_text'] as String?,
      structuredData: json['structured_data'] != null
          ? StructuredData.fromJson(json['structured_data'] as Map<String, dynamic>)
          : null,
      userVerified: json['user_verified'] as bool? ?? false,
      isDuplicate: json['is_duplicate'] as bool? ?? false,
      isNameMismatch: json['is_name_mismatch'] as bool? ?? false,
      isGenderMismatch: json['is_gender_mismatch'] as bool? ?? false,
      isAgeMismatch: json['is_age_mismatch'] as bool? ?? false,
      isNotMedicalReport: json['is_not_medical_report'] as bool? ?? false,
    );
  }

  /// Serializes the [MedicalReport] instance into a JSON-compatible map.
  ///
  /// * Returns: A [Map] containing all fields formatted for API payloads.
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
      'is_name_mismatch': isNameMismatch,
      'is_gender_mismatch': isGenderMismatch,
      'is_age_mismatch': isAgeMismatch,
      'is_not_medical_report': isNotMedicalReport,
    };
  }
}

/// Structured medical data extracted from laboratory reports.
///
/// Contains administrative header information (patient ID, clinic, doctor, sample timestamps)
/// and a list of extracted [TestResult] items.
class StructuredData {
  /// Extracted patient full name.
  String? patientName;

  /// Extracted patient identifier or hospital MRN.
  String? patientId;

  /// Biological sex of the patient (`'Male'` or `'Female'`).
  String? gender;

  /// Primary report date string (`YYYY-MM-DD`).
  String? date;

  /// Specimen collection time (`HH:MM:SS`).
  String? time;

  /// Name of the primary laboratory profile or test panel.
  String? testName;

  /// Name of the ordering physician or pathologist.
  String? doctorName;

  /// Issuing hospital, clinic, or diagnostic laboratory center.
  String? hospitalName;

  /// Normalized collection date string (`YYYY-MM-DD`).
  String? collected;

  /// Laboratory specimen tube barcode or sample reference identifier.
  String? labreference;

  /// Accession number or printed report episode number.
  String? reportReference;

  /// List of individual clinical biomarker measurements.
  List<TestResult> results;

  /// Clinical interpretations or pathologist notes.
  String? notes;

  /// Extracted patient age.
  String? age;

  /// Extracted patient date of birth (`YYYY-MM-DD`).
  String? dob;

  /// Malaysian NRIC or Passport identification number.
  String? icNumber;

  /// Constructs a new [StructuredData] container.
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
    this.reportReference,
    this.results = const [],
    this.notes,
    this.age,
    this.dob,
    this.icNumber,
  });

  /// Factory constructor to deserialize [StructuredData] from a JSON map.
  ///
  /// * [json]: A decoded map matching the structured extraction schema.
  /// * Returns: An initialized [StructuredData] object.
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
      reportReference: json['report_reference'] as String?,
      results: (json['results'] as List<dynamic>?)
              ?.map((r) => TestResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'] as String?,
      age: json['age']?.toString(),
      dob: json['dob'] as String?,
      icNumber: json['ic_number'] as String?,
    );
  }

  /// Serializes the [StructuredData] instance into a JSON-compatible map.
  ///
  /// * Returns: Decoded map for PUT update payloads.
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
      'report_reference': reportReference,
      'results': results.map((r) => r.toJson()).toList(),
      'notes': notes,
      'age': age,
      'dob': dob,
      'ic_number': icNumber,
    };
  }
}

/// An individual clinical biomarker measurement entry.
///
/// Represents a single row in a laboratory table (e.g., Hemoglobin, Fasting Glucose).
class TestResult {
  /// Display name of the test parameter (e.g. `'Total Cholesterol'`).
  String testItem;

  /// Measured value as string (e.g. `'195'` or `'Negative'`).
  String value;

  /// Extracted measurement unit (e.g. `'mg/dL'`, `'mmol/L'`).
  String? unit;

  /// Biological reference range string (e.g. `'< 200 mg/dL'`).
  String? referenceRange;

  /// Target database staging column key (e.g. `'total_cholesterol_mg_dl'`).
  String? key;

  /// Constructs a new [TestResult] parameter measurement.
  TestResult({
    required this.testItem,
    required this.value,
    this.unit,
    this.referenceRange,
    this.key,
  });

  /// Factory constructor to deserialize [TestResult] from JSON.
  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      testItem: json['test_item'] as String? ?? '',
      value: json['value'] as String? ?? '',
      unit: json['unit'] as String?,
      referenceRange: json['reference_range'] as String?,
      key: json['key'] as String?,
    );
  }

  /// Serializes the [TestResult] into a JSON map.
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
