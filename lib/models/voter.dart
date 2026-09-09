import '../utils/bangla_helper.dart';

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
  final String unionOrWardId;
  final String unionWardId;
  final String unionOrWardName;
  final String unionWardName;
  final String ward;
  final String centerName;
  final String centerNo;
  final String centerSerial;
  final String boothsCount;
  final String centerGenderLabel;
  final int pollingCenterId;
  final bool isMigrated;
  final String publicationDate; // 🔴 নতুন যুক্ত হওয়া ফিল্ড

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
    this.centerNo = '',
    this.centerSerial = '',
    this.boothsCount = '',
    this.centerGenderLabel = '',
    this.pollingCenterId = 0,
    this.isMigrated = false,
    this.publicationDate = '',
  });

  String get displayWard {
    if (unionWardName.trim().isNotEmpty && unionWardName != '0') {
      return unionWardName;
    }
    return ward.isNotEmpty ? ward : unionOrWardName;
  }

  String get fullCenterInfo {
    List<String> parts = [];
    if (centerName.isNotEmpty) parts.add(centerName);
    if (boothsCount.isNotEmpty) {
      parts.add('[বুথ: ${BanglaHelper.toBanglaDigits(boothsCount)}]');
    }
    return parts.join(' ');
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
      'centerNo': centerNo,
      'centerSerial': centerSerial,
      'boothsCount': boothsCount,
      'centerGenderLabel': centerGenderLabel,
      'pollingCenterId': pollingCenterId,
      'isMigrated': isMigrated ? 1 : 0,
      'publication_date': publicationDate, // 🔴 সেভ
    };
  }

  factory Voter.fromMap(Map<String, dynamic> map) {
    return Voter(
      id: map['id'] is int
          ? map['id']
          : (int.tryParse(map['id']?.toString() ?? '0') ?? 0),
      serialNo:
          map['serialNo']?.toString() ?? map['serial_no']?.toString() ?? '',
      voterNo: map['voterNo']?.toString() ?? map['voter_no']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      gender: BanglaHelper.formatGender(map['gender']?.toString() ?? 'পুরুষ'),
      dob: map['dob']?.toString() ?? map['date_of_birth']?.toString() ?? '',
      fatherOrHusband:
          map['fatherOrHusband']?.toString() ?? map['father']?.toString() ?? '',
      mother: map['mother']?.toString() ?? '',
      occupation:
          (map['occupation'] != null &&
              map['occupation'].toString().trim().isNotEmpty)
          ? map['occupation'].toString().trim()
          : 'প্রযোজ্য নয়',
      address: map['address']?.toString() ?? '',
      area: map['area']?.toString() ?? map['voter_area_name']?.toString() ?? '',
      unionOrWardId: map['union_or_ward_id']?.toString() ?? '',
      unionWardId: map['union_ward_id']?.toString() ?? '',
      unionOrWardName: map['union_or_ward_name']?.toString() ?? '',
      unionWardName: map['union_ward_name']?.toString() ?? '',
      ward: map['ward']?.toString() ?? map['union_name']?.toString() ?? '',
      centerName:
          map['center_name']?.toString() ??
          map['centerName']?.toString() ??
          map['voter_center']?.toString() ??
          'অনির্ধারিত কেন্দ্র',
      centerNo:
          map['center_no']?.toString() ?? map['centerNo']?.toString() ?? '',
      centerSerial:
          map['center_serial']?.toString() ??
          map['centerSerial']?.toString() ??
          '',
      boothsCount:
          map['booths_count']?.toString() ??
          map['boothsCount']?.toString() ??
          '',
      centerGenderLabel: BanglaHelper.formatGender(
        map['center_gender_label']?.toString() ??
            map['centerGenderLabel']?.toString() ??
            map['gender']?.toString() ??
            'পুরুষ',
      ),
      pollingCenterId: map['polling_center_id'] is int
          ? map['polling_center_id']
          : (int.tryParse(
                  map['pollingCenterId']?.toString() ??
                      map['polling_center_id']?.toString() ??
                      '0',
                ) ??
                0),
      isMigrated: map['isMigrated'] == 1 || map['isMigrated'] == true,
      publicationDate:
          map['publication_date']?.toString() ??
          map['publicationDate']?.toString() ??
          '', // 🔴 লোড
    );
  }
}
