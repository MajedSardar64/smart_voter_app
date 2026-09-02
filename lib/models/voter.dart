class Voter {
  final int id;
  final String serialNo;
  final String voterNo;
  final String name;
  final String gender;
  final String dob;
  final String fatherOrHusband;
  final String mother;
  final String occupation;
  final String address;
  final String area;
  final String unionOrWardId; // union_or_ward_id
  final String unionWardId; // union_ward_id
  final String unionOrWardName; // union_or_ward_name
  final String unionWardName; // union_ward_name
  final String ward; // সার্ভারের মূল নাম
  final String centerName;
  final bool isMigrated;

  Voter({
    required this.id,
    required this.serialNo,
    required this.voterNo,
    required this.name,
    required this.gender,
    required this.dob,
    required this.fatherOrHusband,
    required this.mother,
    required this.occupation,
    required this.address,
    required this.area,
    this.unionOrWardId = '',
    this.unionWardId = '',
    this.unionOrWardName = '',
    this.unionWardName = '',
    required this.ward,
    required this.centerName,
    this.isMigrated = false,
  });

  // ভোটারের তথ্য স্লিপে দেখানোর জন্য অটো-ওয়ার্ড ডিটেকশন
  String get displayWard {
    if (unionWardName.trim().isNotEmpty && unionWardName != '0') {
      return unionWardName; // ইউনিয়ন পরিষদ হলে নিজস্ব ওয়ার্ড নম্বর (যেমন: ১ নং ওয়ার্ড)
    }
    return ward.isNotEmpty
        ? ward
        : unionOrWardName; // পৌরসভা বা সিটি কর্পোরেশন হলে মূল ওয়ার্ড
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id == 0 ? null : id,
      'serialNo': serialNo,
      'voterNo': voterNo,
      'name': name,
      'gender': gender,
      'dob': dob,
      'fatherOrHusband': fatherOrHusband,
      'mother': mother,
      'occupation': occupation,
      'address': address,
      'area': area,
      'union_or_ward_id': unionOrWardId,
      'union_ward_id': unionWardId,
      'union_or_ward_name': unionOrWardName,
      'union_ward_name': unionWardName,
      'ward': ward,
      'centerName': centerName,
      'isMigrated': isMigrated ? 1 : 0,
    };
  }

  factory Voter.fromMap(Map<String, dynamic> map) {
    return Voter(
      id: map['id'] ?? 0,
      serialNo: map['serialNo']?.toString() ?? '',
      voterNo: map['voterNo']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      gender: map['gender']?.toString() ?? 'পুরুষ',
      dob: map['dob']?.toString() ?? '',
      fatherOrHusband: map['fatherOrHusband']?.toString() ?? '',
      mother: map['mother']?.toString() ?? '',
      occupation:
          (map['occupation'] != null &&
              map['occupation'].toString().trim().isNotEmpty)
          ? map['occupation'].toString().trim()
          : 'প্রযোজ্য নয়',
      address: map['address']?.toString() ?? '',
      area: map['area']?.toString() ?? '',
      unionOrWardId: map['union_or_ward_id']?.toString() ?? '',
      unionWardId: map['union_ward_id']?.toString() ?? '',
      unionOrWardName: map['union_or_ward_name']?.toString() ?? '',
      unionWardName: map['union_ward_name']?.toString() ?? '',
      ward: map['ward']?.toString() ?? '',
      centerName: map['centerName']?.toString() ?? '',
      isMigrated: map['isMigrated'] == 1,
    );
  }
}
